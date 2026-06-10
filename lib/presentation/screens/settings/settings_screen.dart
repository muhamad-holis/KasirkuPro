import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan',
          style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section('Tampilan', [
            SwitchListTile(
              title: const Text('Mode Gelap'),
              subtitle: const Text('Aktifkan tema gelap'),
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dark_mode_outlined,
                  color: AppColors.primary, size: 20),
              ),
            ),
          ]),
          _Section('Toko', [
            _Tile(
              icon: Icons.store_outlined,
              title: 'Nama Toko',
              subtitle: 'KasirKu',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.location_on_outlined,
              title: 'Alamat Toko',
              subtitle: 'Belum diset',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.phone_outlined,
              title: 'Nomor Telepon',
              subtitle: 'Belum diset',
              onTap: () {},
            ),
          ]),
          _Section('Printer', [
            _Tile(
              icon: Icons.print_outlined,
              title: 'Pengaturan Printer',
              subtitle: 'Bluetooth thermal printer',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.receipt_outlined,
              title: 'Ukuran Struk',
              subtitle: '58mm',
              onTap: () {},
            ),
          ]),
          _Section('Keamanan', [
            _Tile(
              icon: Icons.lock_outline,
              title: 'PIN Aplikasi',
              subtitle: 'Belum diaktifkan',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.fingerprint_outlined,
              title: 'Biometrik',
              subtitle: 'Fingerprint / Face ID',
              onTap: () {},
            ),
          ]),
          _Section('Data', [
            _Tile(
              icon: Icons.backup_outlined,
              title: 'Backup Data',
              subtitle: 'Simpan data ke file',
              onTap: () {},
              color: AppColors.primary,
            ),
            _Tile(
              icon: Icons.restore_outlined,
              title: 'Restore Data',
              subtitle: 'Pulihkan dari backup',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.delete_forever_outlined,
              title: 'Hapus Semua Data',
              subtitle: 'Reset aplikasi',
              onTap: () {},
              color: AppColors.danger,
            ),
          ]),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(children: [
              Text('KasirKu',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
              SizedBox(height: 4),
              Text('Versi 1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(height: 4),
              Text('Aplikasi Kasir & Manajemen Toko Indonesia',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 11,
              letterSpacing: 0.8,
            )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? color;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: color,
        )),
      subtitle: Text(subtitle,
        style: TextStyle(
          fontSize: 12, color: Colors.grey.shade500)),
      trailing: const Icon(Icons.chevron_right,
        color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
