import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

// ─── Konfigurasi Google Drive ─────────────────────────────────────────────────

// File ID version.json di Google Drive folder KasirkuPro-Release
// Update file ID ini jika version.json dipindah
const _kVersionJsonFileId = '12kAROePLOYrf1frMzPR3lJWGQvVOWtpA';

// File ID APK tetap (KasirkuPro-latest.apk) — tidak berubah tiap release
const _kApkFileId = '1aCYrsoJI5RoVWzo75A5vASagmH14GP9W';

// URL direct download Google Drive
// Untuk file besar, Google Drive redirect ke halaman konfirmasi virus scan.
// Gunakan endpoint /uc dengan confirm=1 dan tambah cookie bypass.
String _driveDownloadUrl(String fileId) =>
    'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t&authuser=0';

// ─── Model ────────────────────────────────────────────────────────────────────

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String apkFileId;
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.apkFileId,
    required this.hasUpdate,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

enum UpdateStatus { idle, checking, available, downloading, installing, upToDate, error }

class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? info;
  final double downloadProgress;
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? info,
    double? downloadProgress,
    String? errorMessage,
  }) => UpdateState(
    status: status ?? this.status,
    info: info ?? this.info,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  // ── Cek update dari version.json di Google Drive ──────────────────────────
  Future<void> checkUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);

    try {
      // Ambil versi aplikasi yang terpasang
      final packageInfo    = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch version.json dari Google Drive
      final url      = _driveDownloadUrl(_kVersionJsonFileId);
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Gagal fetch version.json (${response.statusCode})');
      }

      final data          = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String? ?? '';
      final apkFileId     = data['apk_file_id'] as String? ?? _kApkFileId;

      if (latestVersion.isEmpty) {
        throw Exception('Format version.json tidak valid');
      }

      final hasUpdate = _isNewerVersion(latestVersion, currentVersion);

      state = state.copyWith(
        status: hasUpdate ? UpdateStatus.available : UpdateStatus.upToDate,
        info: UpdateInfo(
          latestVersion:  latestVersion,
          currentVersion: currentVersion,
          apkFileId:      apkFileId,
          hasUpdate:      hasUpdate,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Gagal cek update: ${e.toString()}',
      );
    }
  }

  // ── Download APK dari Google Drive dan install ────────────────────────────
  Future<void> downloadAndInstall() async {
    final info = state.info;
    if (info == null) return;

    state = state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0);

    try {
      final tempDir  = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/kasirkupro_update.apk';
      final file     = File(savePath);

      // Hapus file lama jika ada
      if (await file.exists()) await file.delete();

      final downloadUrl = _driveDownloadUrl(info.apkFileId);

      // Download dengan progress + handle redirect Google Drive
      final client  = http.Client();
      var   uri     = Uri.parse(downloadUrl);
      http.StreamedResponse response;

      // Follow redirect manual (Google Drive kadang redirect beberapa kali)
      int redirectCount = 0;
      while (true) {
        final request = http.Request('GET', uri);
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36';
        response = await client.send(request)
            .timeout(const Duration(minutes: 15));

        if ((response.statusCode == 301 || response.statusCode == 302 ||
             response.statusCode == 303 || response.statusCode == 307) &&
            redirectCount < 5) {
          final location = response.headers['location'];
          if (location == null) break;
          uri = Uri.parse(location);
          redirectCount++;
          await response.stream.drain(); // buang body redirect
          continue;
        }
        break;
      }

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final totalBytes    = response.contentLength ?? 0;
      var   receivedBytes = 0;
      final sink          = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          state = state.copyWith(
            downloadProgress: receivedBytes / totalBytes,
          );
        } else {
          // Tidak ada Content-Length — estimasi dari ukuran file
          state = state.copyWith(
            downloadProgress: (receivedBytes / (100 * 1024 * 1024))
                .clamp(0.0, 0.99),
          );
        }
      }
      await sink.close();
      client.close();

      // Verifikasi file — APK minimal 5MB
      final fileSize = await file.length();
      if (fileSize < 5 * 1024 * 1024) {
        throw Exception(
            'File download tidak valid (${(fileSize / 1024).toStringAsFixed(0)} KB). '
            'Pastikan file di Google Drive dapat diakses publik.');
      }

      state = state.copyWith(
        status: UpdateStatus.installing,
        downloadProgress: 1.0,
      );

      // Trigger install
      final result = await OpenFile.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        throw Exception('Gagal membuka installer: ${result.message}');
      }

      state = state.copyWith(status: UpdateStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Gagal download: ${e.toString()}',
      );
    }
  }

  void reset() => state = const UpdateState();

  // ── Util: bandingkan versi semver ─────────────────────────────────────────
  bool _isNewerVersion(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (var i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
