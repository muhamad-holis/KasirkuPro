// lib/presentation/screens/login/login_screen.dart
//
// SECURITY PATCH:
// - Login field: USERNAME (bukan nama dropdown) + PIN 6 digit
// - Tidak ada hint "PIN default 1234" di UI
// - Tampilkan pesan lockout dengan countdown
// - Redirect ke ChangePinScreen jika mustChangePin = true
// - Redirect ke SetupWizard jika DB kosong

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../navigation/app_router.dart';
import '../setup_wizard/setup_wizard_screen.dart';
import 'change_pin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl      = TextEditingController();
  bool  _obscurePin   = true;
  bool  _loading      = false;
  String? _error;

  // SECURITY: PIN minimal 6 digit
  static const int _pinLength = 6;

  @override
  void initState() {
    super.initState();
    _checkSetupNeeded();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  /// Jika DB kosong, redirect ke Setup Wizard
  Future<void> _checkSetupNeeded() async {
    final needsSetup =
        await ref.read(databaseProvider).needsSetup();
    if (needsSetup && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
      );
    }
  }

  Future<void> _doLogin() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    final pin      = _pinCtrl.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Username tidak boleh kosong');
      return;
    }
    // SECURITY: minimum 6 digit
    if (pin.length < _pinLength) {
      setState(() => _error = 'PIN harus minimal $_pinLength digit');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final err = await ref.read(authProvider.notifier).login(username, pin);

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
      _pinCtrl.clear();
      return;
    }

    // Cek mustChangePin
    final user = ref.read(authProvider);
    if (user?.mustChangePin == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChangePinScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildLoginCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB2DFDB), Color(0xFFE0F7F5), Color(0xFFF0FAFA)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 16, offset: const Offset(0, 6))]),
        child: const Icon(Icons.point_of_sale_rounded,
            color: AppColors.primary, size: 42)),
      const SizedBox(height: 14),
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'Kasir',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
              color: Color(0xFF111827))),
        TextSpan(text: 'Ku',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
              color: AppColors.primary)),
      ])),
      const SizedBox(height: 6),
      const Text(
        'Kelola transaksi, stok, dan laporan toko.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
    ]);
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 24, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Login',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Masukkan username dan PIN Anda',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 22),

          // Username field
          _label('Username'),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameCtrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: _inputDeco(
              hint: 'Masukkan username Anda',
              prefix: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 16),

          // PIN field
          _label('PIN (min. $_pinLength digit)'),
          const SizedBox(height: 6),
          TextField(
            controller: _pinCtrl,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 8,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _loading ? null : _doLogin(),
            decoration: _inputDeco(
              hint: '••••••',
              prefix: Icons.lock_outline_rounded,
              counter: '',
              suffix: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary, size: 20),
                onPressed: () =>
                    setState(() => _obscurePin = !_obscurePin),
              ),
            ),
          ),

          // Error box
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.danger))),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // Tombol masuk
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _doLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded, size: 20),
              label: Text(
                _loading ? 'Memproses...' : 'Masuk',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text('Lupa PIN? Hubungi admin untuk reset.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  InputDecoration _inputDeco({
    required String hint,
    required IconData prefix,
    String? counter,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: counter,
      prefixIcon: Icon(prefix, color: AppColors.primary, size: 22),
      suffixIcon: suffix,
      filled: true, fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
