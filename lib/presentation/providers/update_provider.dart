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
String _driveDownloadUrl(String fileId) =>
    'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';

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

      final downloadUrl = _driveDownloadUrl(info.apkFileId);

      // Download dengan progress
      final request  = http.Request('GET', Uri.parse(downloadUrl));
      final response = await request.send()
          .timeout(const Duration(minutes: 15));

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
        }
      }
      await sink.close();

      // Verifikasi file tidak kosong
      final fileSize = await file.length();
      if (fileSize < 1024 * 1024) {
        // Kurang dari 1MB — kemungkinan bukan APK valid
        throw Exception('File download tidak valid (${fileSize} bytes)');
      }

      state = state.copyWith(status: UpdateStatus.installing);

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
