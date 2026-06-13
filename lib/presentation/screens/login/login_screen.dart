import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../navigation/app_router.dart';

// Provider: ambil semua user aktif dari DB
final _activeUsersProvider = FutureProvider.autoDispose<List<User>>((ref) =>
    ref.watch(databaseProvider).usersDao.getActiveUsers());

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinCtrl   = TextEditingController();
  bool  _obscurePin = true;
  bool  _rememberMe = true;
  bool  _loading    = false;
  String? _error;

  // Role yang dipilih: 'kasir' atau 'admin'
  String _selectedRole = 'kasir';

  // User yang dipilih dari dropdown
  User? _selectedUser;

  static const int _pinLength = 4;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  // Filter users berdasarkan role yang dipilih
  List<User> _filterByRole(List<User> all) {
    return all.where((u) => u.role == _selectedRole).toList();
  }

  Future<void> _doLogin() async {
    if (_selectedUser == null) {
      setState(() => _error = 'Pilih nama pengguna terlebih dahulu');
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (pin.length < _pinLength) {
      setState(() => _error = 'PIN harus $_pinLength digit');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final err = await ref.read(authProvider.notifier).login(
      _selectedUser!.name, pin);

    if (!mounted) return;
    setState(() { _loading = false; });

    if (err != null) {
      setState(() => _error = err);
      _pinCtrl.clear();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_activeUsersProvider);

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
                  usersAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(
                      child: Text('Gagal memuat data: $e',
                        style: const TextStyle(color: AppColors.danger))),
                    data: (users) => _buildLoginCard(users),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoBox(),
                  const SizedBox(height: 12),
                  Text(
                    '© 2024 KasirKu. Semua hak dilindungi.',
                    style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ──────────────────────────────────────────────────────────────

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
      child: Stack(children: [
        Positioned(top: -40, left: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.12)))),
        Positioned(top: 80, right: 20, child: _buildDots()),
        Positioned(top: 180, left: 16, child: _buildDots()),
        Positioned(bottom: 0, left: 0, right: 0,
          child: ClipPath(
            clipper: _WaveClipper(),
            child: Container(height: 120,
              color: AppColors.primary.withOpacity(0.15)))),
      ]),
    );
  }

  Widget _buildDots() {
    return Column(children: List.generate(3, (r) =>
      Row(children: List.generate(3, (c) =>
        Container(width: 5, height: 5, margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.35)))))));
  }

  // ── Header ──────────────────────────────────────────────────────────────────

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
        'Kelola transaksi, stok, dan laporan\ntoko jadi lebih mudah.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
    ]);
  }

  // ── Login Card ──────────────────────────────────────────────────────────────

  Widget _buildLoginCard(List<User> allUsers) {
    final filtered = _filterByRole(allUsers);

    // Reset selected user jika tidak ada di list filtered
    if (_selectedUser != null &&
        !filtered.any((u) => u.id == _selectedUser!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() { _selectedUser = null; _pinCtrl.clear(); _error = null; });
      });
    }

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
          // Judul
          const Text('Selamat Datang Kembali!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Silakan login untuk melanjutkan',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 22),

          // ── Role selector ──
          _buildLabel('Login sebagai'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildRoleCard(
              role: 'kasir',
              icon: Icons.point_of_sale_rounded,
              label: 'Kasir',
              sub: 'Akses kasir',
              count: allUsers.where((u) => u.role == 'kasir').length,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildRoleCard(
              role: 'admin',
              icon: Icons.shield_outlined,
              label: 'Owner',
              sub: 'Akses penuh',
              count: allUsers.where((u) => u.role == 'admin').length,
            )),
          ]),
          const SizedBox(height: 20),

          // ── Dropdown Nama ──
          _buildLabel('Nama Pengguna'),
          const SizedBox(height: 6),
          _buildNameDropdown(filtered),
          const SizedBox(height: 16),

          // ── PIN ──
          _buildLabel('PIN'),
          const SizedBox(height: 6),
          TextField(
            controller: _pinCtrl,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            maxLength: _pinLength,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: '••••',
              counterText: '',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.primary, size: 22),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary, size: 20),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              filled: true, fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 2)),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.danger, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.error_outline,
                  size: 14, color: AppColors.danger),
              const SizedBox(width: 4),
              Expanded(child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.danger))),
            ]),
          ],

          const SizedBox(height: 14),

          // Ingat saya + Lupa PIN
          Row(children: [
            SizedBox(width: 20, height: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) =>
                    setState(() => _rememberMe = v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              )),
            const SizedBox(width: 8),
            const Text('Ingat saya',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Hubungi Admin untuk reset PIN'))),
              child: const Text('Lupa PIN?',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            ),
          ]),

          const SizedBox(height: 20),

          // Tombol Masuk
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
        ],
      ),
    );
  }

  // ── Dropdown nama berdasarkan role ──────────────────────────────────────────

  Widget _buildNameDropdown(List<User> filtered) {
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          const Icon(Icons.person_off_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Text(
            _selectedRole == 'admin'
                ? 'Belum ada Owner terdaftar'
                : 'Belum ada Kasir terdaftar',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }

    return DropdownButtonFormField<User>(
      value: _selectedUser,
      hint: const Text('Pilih nama pengguna',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_outline_rounded,
            color: AppColors.primary, size: 22),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      items: filtered.map((u) => DropdownMenuItem<User>(
        value: u,
        child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            child: Text(u.name[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Text(u.name,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      )).toList(),
      onChanged: (u) {
        setState(() { _selectedUser = u; _error = null; _pinCtrl.clear(); });
      },
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      dropdownColor: Colors.white,
      isExpanded: true,
    );
  }

  // ── Role Card ───────────────────────────────────────────────────────────────

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String label,
    required String sub,
    required int count,
  }) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRole = role;
        _selectedUser = null;
        _pinCtrl.clear();
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.06)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1)),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.12)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18,
              color: selected
                  ? AppColors.primary : AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary : const Color(0xFF111827))),
              Text('$count pengguna',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 16,
            color: selected
                ? AppColors.primary : AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: Color(0xFF374151)));
  }

  // ── Info Box ────────────────────────────────────────────────────────────────

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.5))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.info_outline_rounded,
              size: 16, color: Colors.white)),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login pertama kali?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
            SizedBox(height: 2),
            Text.rich(TextSpan(
              style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
              children: [
                TextSpan(text: 'Pilih role '),
                TextSpan(text: 'Owner',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
                TextSpan(text: ' → nama '),
                TextSpan(text: 'Admin',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
                TextSpan(text: ' → PIN '),
                TextSpan(text: '1234',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              ],
            )),
          ],
        )),
      ]),
    );
  }
}

// ── Wave Clipper ────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.25, 0,
        size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.8,
        size.width, size.height * 0.3);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
