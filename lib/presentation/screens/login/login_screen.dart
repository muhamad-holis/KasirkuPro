import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../navigation/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  String _pin     = '';
  String? _error;
  bool _loading   = false;

  static const int _pinLength = 4; // PIN 4 digit

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() { _pin += digit; _error = null; });
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _doLogin() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() { _error = 'Masukkan nama kasir terlebih dahulu'; _pin = ''; });
      return;
    }
    if (_pin.length < _pinLength) {
      setState(() { _error = 'PIN harus $_pinLength digit'; });
      return;
    }
    setState(() { _loading = true; _error = null; });

    final err = await ref.read(authProvider.notifier).login(name, _pin);

    if (!mounted) return;
    setState(() { _loading = false; });

    if (err != null) {
      setState(() { _error = err; _pin = ''; });
      HapticFeedback.heavyImpact();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? AppColors.darkBg    : AppColors.bg;
    final card = isDark ? AppColors.darkCard  : Colors.white;
    final sub  = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final text = isDark ? Colors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.point_of_sale_rounded,
                    color: AppColors.primary, size: 42),
              ),
              const SizedBox(height: 16),
              Text('KasirKu',
                  style: TextStyle(fontSize: 26,
                      fontWeight: FontWeight.w800, color: text)),
              const SizedBox(height: 4),
              Text('Masuk untuk melanjutkan',
                  style: TextStyle(fontSize: 13, color: sub)),
              const SizedBox(height: 36),

              // Input nama
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 0.5),
                ),
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600, color: text),
                  decoration: InputDecoration(
                    hintText: 'Nama kasir',
                    hintStyle: TextStyle(color: sub, fontWeight: FontWeight.w400),
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.primary, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Label PIN
              Text('PIN', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
              const SizedBox(height: 16),

              // Dot indikator (4 digit)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled  = i < _pin.length;
                  final isError = _error != null;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isError
                          ? AppColors.danger
                          : filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: isError
                            ? AppColors.danger
                            : filled
                                ? AppColors.primary
                                : isDark
                                    ? const Color(0xFF475569)
                                    : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              // Error
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.danger)),
                          ],
                        ),
                      )
                    : const SizedBox(height: 12),
              ),
              const SizedBox(height: 24),

              // Numpad / loading
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _Numpad(onKey: _onKey, onDelete: _onDelete),

              const SizedBox(height: 20),

              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _doLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Info default
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Login pertama: Nama "Admin", PIN 1234',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.primary.withOpacity(0.9)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
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
    const rows = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Column(
      children: rows.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) {
          if (k.isEmpty) return const SizedBox(width: 88, height: 64);
          return _NumKey(label: k,
              onTap: k == '⌫' ? onDelete : () => onKey(k));
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
        width: 88, height: 64,
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
