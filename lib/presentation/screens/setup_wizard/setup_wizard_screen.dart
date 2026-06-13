// lib/presentation/screens/setup_wizard/setup_wizard_screen.dart
//
// NEW SCREEN: Tampil saat aplikasi pertama kali dijalankan (DB kosong).
// Memaksa membuat akun admin pertama dengan:
//   - Username unik (min 3 karakter)
//   - Display name
//   - PIN minimal 6 digit
//   - Konfirmasi PIN

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pin_hasher.dart';
import '../../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/auth_provider.dart';
import '../login/login_screen.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _usernameCtrl    = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  String _pin        = '';
  String _pinConfirm = '';
  bool   _saving     = false;
  String? _error;

  // Step: 0=info, 1=data, 2=pin, 3=confirm
  int _step = 0;

  static const int _pinLength = 6;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  // ─── Validasi ──────────────────────────────────────────────────────────────

  String? _validateStep1() {
    final username    = _usernameCtrl.text.trim().toLowerCase();
    final displayName = _displayNameCtrl.text.trim();
    if (username.length < 3) {
      return 'Username minimal 3 karakter';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Username hanya boleh huruf kecil, angka, dan underscore';
    }
    if (displayName.isEmpty) {
      return 'Nama tampilan tidak boleh kosong';
    }
    return null;
  }

  // ─── Navigasi step ─────────────────────────────────────────────────────────

  void _next() {
    setState(() => _error = null);
    if (_step == 1) {
      final err = _validateStep1();
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    if (_step == 2 && _pin.length < _pinLength) {
      setState(() => _error = 'PIN harus $_pinLength digit');
      return;
    }
    if (_step == 3) {
      _saveAdmin();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _error = null;
      if (_step == 2) { _pin = ''; _pinConfirm = ''; }
    });
  }

  // ─── Simpan admin ──────────────────────────────────────────────────────────

  Future<void> _saveAdmin() async {
    if (_pin != _pinConfirm) {
      setState(() => _error = 'Konfirmasi PIN tidak cocok');
      return;
    }
    if (_pin.length < _pinLength) {
      setState(() => _error = 'PIN harus $_pinLength digit');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final db = ref.read(databaseProvider);
      final username    = _usernameCtrl.text.trim().toLowerCase();
      final displayName = _displayNameCtrl.text.trim();

      await db.usersDao.insertFirstAdmin(UsersCompanion.insert(
        username:    username,
        displayName: displayName,
        pin:         PinHasher.hashPin(_pin),
        role:        const Value('admin'),
      ));

      if (!mounted) return;

      // Navigasi ke login — user harus login dengan akun yang baru dibuat
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Akun admin berhasil dibuat. Silakan login.'),
        backgroundColor: AppColors.success,
      ));
    } on UsernameTakenException {
      setState(() => _error = 'Username sudah dipakai');
    } on UnauthorizedException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Numpad helpers ────────────────────────────────────────────────────────

  void _onPinKey(String d) {
    if (_step == 2) {
      if (_pin.length >= _pinLength) return;
      setState(() => _pin += d);
      if (_pin.length == _pinLength) {
        // Auto-advance ke step konfirmasi
        Future.delayed(const Duration(milliseconds: 200),
            () => setState(() => _step = 3));
      }
    } else if (_step == 3) {
      if (_pinConfirm.length >= _pinLength) return;
      setState(() => _pinConfirm += d);
    }
  }

  void _onPinDel() {
    if (_step == 2) {
      if (_pin.isEmpty) return;
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_step == 3) {
      if (_pinConfirm.isEmpty) return;
      setState(() => _pinConfirm = _pinConfirm.substring(0, _pinConfirm.length - 1));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress indicator
              _buildProgress(),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: _buildStep(),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    const steps = ['Mulai', 'Akun', 'PIN', 'Konfirmasi'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _step;
        final isDone   = i < _step;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.success
                        : isActive
                            ? AppColors.primary
                            : Colors.grey.shade200,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : Text('${i + 1}', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : Colors.grey)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i], style: TextStyle(
                    fontSize: 10,
                    color: isActive ? AppColors.primary : Colors.grey,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
              ]),
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(height: 2,
                    color: isDone ? AppColors.success : Colors.grey.shade200),
              ),
          ]),
        );
      }),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStepInfo();
      case 1:
        return _buildStepData();
      case 2:
        return _buildStepPin('Buat PIN Admin', _pin);
      case 3:
        return _buildStepPin('Konfirmasi PIN', _pinConfirm);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepInfo() {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.admin_panel_settings_rounded,
            color: AppColors.primary, size: 42),
      ),
      const SizedBox(height: 24),
      const Text('Selamat Datang di KasirKu!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Text(
        'Ini adalah pertama kali aplikasi dijalankan.\n'
        'Buat akun Admin utama untuk memulai.\n\n'
        'Admin dapat mengelola kasir, produk, dan pengaturan toko.',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      _infoTile(Icons.lock_rounded, 'PIN minimal 6 digit'),
      const SizedBox(height: 8),
      _infoTile(Icons.person_rounded, 'Username harus unik'),
      const SizedBox(height: 8),
      _infoTile(Icons.security_rounded, 'Tidak ada akun bawaan'),
    ]);
  }

  Widget _infoTile(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(
            fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildStepData() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Data Akun Admin',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Informasi ini digunakan untuk login.',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 24),

      // Username
      const Text('Username',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _usernameCtrl,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          hintText: 'Contoh: admin_toko',
          prefixIcon: const Icon(Icons.alternate_email_rounded,
              color: AppColors.primary),
          helperText: 'Huruf kecil, angka, dan underscore',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Display name
      const Text('Nama Tampilan',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _displayNameCtrl,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          hintText: 'Contoh: Budi Santoso',
          prefixIcon: const Icon(Icons.person_outline_rounded,
              color: AppColors.primary),
          helperText: 'Nama yang ditampilkan di UI',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    ]);
  }

  Widget _buildStepPin(String title, String currentPin) {
    return Column(children: [
      Text(title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
        _step == 2
            ? 'PIN digunakan untuk login setiap hari.\nGunakan minimal 6 digit yang mudah diingat tapi sulit ditebak.'
            : 'Masukkan kembali PIN yang sama untuk konfirmasi.',
        style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),

      // Dot indicator
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinLength, (i) {
          final filled = i < currentPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: filled ? AppColors.primary : Colors.grey.shade300,
                width: 2,
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),

      // Numpad
      _buildNumpad(),
    ]);
  }

  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) {
          if (k.isEmpty) return const SizedBox(width: 88, height: 60);
          return GestureDetector(
            onTap: k == '⌫' ? _onPinDel : () => _onPinKey(k),
            child: Container(
              width: 88, height: 60,
              alignment: Alignment.center,
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined,
                      color: AppColors.primary, size: 22)
                  : Text(k, style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }

  Widget _buildActions() {
    return Row(children: [
      if (_step > 0)
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : _back,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Kembali'),
          ),
        ),
      if (_step > 0) const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: (_saving || (_step == 2 || _step == 3)) ? null : _next,
          onLongPress: (_step == 2 || _step == 3) ? null : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  _step == 0 ? 'Mulai Setup' :
                  _step == 1 ? 'Lanjut ke PIN' : 'Simpan',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
