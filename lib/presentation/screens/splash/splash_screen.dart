import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../navigation/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _videoReady = false;
  bool _navigated = false; // guard agar navigasi hanya dipanggil 1x

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset(
      'assets/videos/splash.mp4',
    );

    await _videoController.initialize();

    if (mounted) {
      setState(() => _videoReady = true);
      _videoController.setLooping(false);
      _videoController.setVolume(1.0);
      _videoController.play();
    }

    // Navigasi setelah video selesai
    _videoController.addListener(() {
      if (!_navigated &&
          _videoController.value.duration > Duration.zero &&
          _videoController.value.position >= _videoController.value.duration) {
        _navigateToMain();
      }
    });

    // Fallback: navigasi max 5 detik kalau video lama
    Future.delayed(const Duration(seconds: 5), () {
      _navigateToMain();
    });
  }

  void _navigateToMain() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigation(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
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
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
    );
  }
}
