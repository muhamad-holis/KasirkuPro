import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../login/login_screen.dart';
import '../../navigation/app_router.dart';
import '../../providers/database_provider.dart';
import '../../providers/auth_provider.dart';

const _kBiometricKey  = 'biometric_enabled';
const _kLastUserId    = 'last_user_id';
const _kLastUserName  = 'last_user_name';
const _kLastUserRole  = 'last_user_role';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _videoReady = false;
  bool _navigated  = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController =
        VideoPlayerController.asset('assets/videos/splash.mp4');
    await _videoController.initialize();

    if (mounted) {
      setState(() => _videoReady = true);
      _videoController.setLooping(false);
      _videoController.setVolume(1.0);
      _videoController.play();
    }

    _videoController.addListener(() {
      if (!_navigated &&
          _videoController.value.duration > Duration.zero &&
          _videoController.value.position >=
              _videoController.value.duration) {
        _afterSplash();
      }
    });

    // Fallback max 5 detik
    Future.delayed(const Duration(seconds: 5), _afterSplash);
  }

  /// Dipanggil setelah video selesai — cek biometrik / session
  Future<void> _afterSplash() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    final prefs          = await SharedPreferences.getInstance();
    final biometricOn    = prefs.getBool(_kBiometricKey) ?? false;
    final lastUserId     = prefs.getInt(_kLastUserId);
    final lastUserName   = prefs.getString(_kLastUserName);
    final lastUserRole   = prefs.getString(_kLastUserRole);

    final hasSession = lastUserId != null &&
        lastUserName != null &&
        lastUserRole != null;

    // Jika biometrik aktif DAN ada session sebelumnya → coba fingerprint
    if (biometricOn && hasSession) {
      final success = await _tryBiometric();
      if (!mounted) return;

      if (success) {
        // Restore session ke provider
        ref.read(authProvider.notifier).restoreSession(
          id:   lastUserId!,
          name: lastUserName!,
          role: lastUserRole!,
        );
        _goToMain();
        return;
      }
      // Gagal biometrik → tetap ke login
    }

    _goToLogin();
  }

  Future<bool> _tryBiometric() async {
    try {
      final auth = LocalAuthentication();
      final bool canCheck   = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final available = await auth.getAvailableBiometrics();
      if (available.isEmpty) return false;

      final hasFace        = available.contains(BiometricType.face);
      final hasFingerprint = available.contains(BiometricType.fingerprint);
      String label = 'Biometrik';
      if (hasFace && hasFingerprint) label = 'Fingerprint / Face ID';
      else if (hasFace) label = 'Face ID';
      else if (hasFingerprint) label = 'Fingerprint';

      return await auth.authenticate(
        localizedReason: 'Gunakan $label untuk masuk ke KasirKu',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigation(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videoReady
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child:  VideoPlayer(_videoController),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
