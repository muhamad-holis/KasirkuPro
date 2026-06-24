import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

// ─── Konfigurasi GitHub ───────────────────────────────────────────────────────

const _kGithubOwner = 'muhamad-holis';
const _kGithubRepo  = 'KasirkuPro';
const _kApiUrl =
    'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest';

// ─── Model ────────────────────────────────────────────────────────────────────

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

enum UpdateStatus {
  idle, checking, available, downloading, installing, upToDate, error
}

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
    status:           status ?? this.status,
    info:             info ?? this.info,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    errorMessage:     errorMessage ?? this.errorMessage,
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  // ── Cek update dari GitHub Releases API ──────────────────────────────────
  Future<void> checkUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);

    try {
      final packageInfo    = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(_kApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('GitHub API error: ${response.statusCode}');
      }

      final data       = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag  = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final assets     = data['assets'] as List<dynamic>? ?? [];

      // Cari file APK di assets release
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset == null) {
        throw Exception('APK tidak ditemukan di release terbaru');
      }

      final downloadUrl = apkAsset['browser_download_url'] as String;
      final hasUpdate   = _isNewerVersion(latestTag, currentVersion);

      state = state.copyWith(
        status: hasUpdate ? UpdateStatus.available : UpdateStatus.upToDate,
        info: UpdateInfo(
          latestVersion:  latestTag,
          currentVersion: currentVersion,
          downloadUrl:    downloadUrl,
          hasUpdate:      hasUpdate,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status:       UpdateStatus.error,
        errorMessage: 'Gagal cek update: ${e.toString()}',
      );
    }
  }

  // ── Download APK dari GitHub Releases dan install ─────────────────────────
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

      // Download dengan progress — GitHub Releases support direct download
      final client   = http.Client();
      final request  = http.Request('GET', Uri.parse(info.downloadUrl));
      request.headers['Accept'] = 'application/octet-stream';
      final response = await client.send(request)
          .timeout(const Duration(minutes: 15));

      if (response.statusCode != 200) {
        throw Exception('Download error: ${response.statusCode}');
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
          // Estimasi jika tidak ada Content-Length
          state = state.copyWith(
            downloadProgress:
                (receivedBytes / (100 * 1024 * 1024)).clamp(0.0, 0.99),
          );
        }
      }

      await sink.close();
      client.close();

      // Verifikasi file — APK minimal 5MB
      final fileSize = await file.length();
      if (fileSize < 5 * 1024 * 1024) {
        throw Exception(
            'File tidak valid (${(fileSize / 1024).toStringAsFixed(0)} KB)');
      }

      state = state.copyWith(
        status:           UpdateStatus.installing,
        downloadProgress: 1.0,
      );

      // Trigger install APK
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
        status:       UpdateStatus.error,
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
