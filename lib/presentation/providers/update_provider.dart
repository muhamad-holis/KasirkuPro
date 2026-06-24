import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // ── Buka halaman download di browser ─────────────────────────────────────
  Future<void> downloadAndInstall() async {
    try {
      final uri = Uri.parse(
          'https://muhamad-holis.github.io/KasirkuPOS/#download');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Tidak dapat membuka browser');
      }
    } catch (e) {
      state = state.copyWith(
        status:       UpdateStatus.error,
        errorMessage: 'Gagal membuka halaman download: ${e.toString()}',
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
