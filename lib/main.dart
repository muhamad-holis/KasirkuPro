import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KasirKuApp()));
}

class KasirKuApp extends ConsumerWidget {
  const KasirKuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'KasirKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      // TODO: aktifkan _PinGate kembali sebelum release ke production
      // home: const _PinGate(),
      home: const MainNavigation(),
    );
  }
}

// ─── PIN Gate: cek PIN sebelum masuk app ──────────────────────────────────────

class _PinGate extends ConsumerWidget {
  const _PinGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinValue = ref.watch(pinProvider);

    // Selama PIN provider belum selesai load (null = loading)
    if (pinValue == null) {
      // Belum bisa tau apakah ada PIN — tunggu sebentar
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pinActive = pinValue.isNotEmpty;
    if (!pinActive) return const MainNavigation();

    return _PinLockScreen(pin: pinValue);
  }
}

class _PinLockScreen extends StatefulWidget {
  final String pin;
  const _PinLockScreen({required this.pin});

  @override
  State<_PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<_PinLockScreen> {
  String _input = '';
  bool _wrong   = false;
  bool _unlocked = false;

  void _onKey(String digit) {
    if (_input.length >= 6) return;
    setState(() {
      _input += digit;
      _wrong  = false;
    });
    if (_input.length == widget.pin.length) {
      _check();
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (_input == widget.pin) {
      setState(() => _unlocked = true);
    } else {
      setState(() { _wrong = true; _input = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const MainNavigation();

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                    color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 24),
                const Text('Masukkan PIN',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Aplikasi terkunci', style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 32),

                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.pin.length, (i) {
                    final filled = i < _input.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _wrong
                            ? AppColors.danger
                            : filled
                                ? AppColors.primary
                                : cs.onSurface.withOpacity(0.15),
                        border: Border.all(
                          color: _wrong
                              ? AppColors.danger
                              : filled
                                  ? AppColors.primary
                                  : cs.onSurface.withOpacity(0.3),
                        ),
                      ),
                    );
                  }),
                ),

                if (_wrong) ...[
                  const SizedBox(height: 12),
                  const Text('PIN salah, coba lagi',
                    style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],

                const SizedBox(height: 32),

                // Numpad
                _Numpad(onKey: _onKey, onDelete: _onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;
  const _Numpad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) {
          if (k.isEmpty) return const SizedBox(width: 80, height: 64);
          return _NumKey(
            label: k,
            onTap: k == '⌫' ? onDelete : () => onKey(k),
          );
        }).toList(),
      )).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 64,
        alignment: Alignment.center,
        child: label == '⌫'
            ? const Icon(Icons.backspace_outlined,
                color: AppColors.primary, size: 22)
            : Text(label, style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
