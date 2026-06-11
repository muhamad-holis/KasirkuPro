import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/settings_provider.dart';
import '../../providers/database_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark   = ref.watch(themeModeProvider);
    final store    = ref.watch(storeSettingsProvider);
    final printer  = ref.watch(printerSettingsProvider);
    final pinValue = ref.watch(pinProvider);
    final pinActive = pinValue != null && pinValue.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [

          // ── Tampilan ──────────────────────────────────────
          _Section('Tampilan', [
            SwitchListTile(
              title: const Text('Mode Gelap'),
              subtitle: const Text('Aktifkan tema gelap'),
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
              secondary: _TileIcon(
                  Icons.dark_mode_outlined, AppColors.primary),
            ),
          ]),

          // ── Toko ──────────────────────────────────────────
          _Section('Toko', [
            _Tile(
              icon: Icons.store_outlined,
              title: 'Nama Toko',
              subtitle: store.storeName.isEmpty
                  ? 'Belum diset' : store.storeName,
              onTap: () => _editField(
                context, ref,
                label: 'Nama Toko',
                value: store.storeName,
                onSave: (v) => ref.read(storeSettingsProvider.notifier)
                    .update((s) => s.copyWith(storeName: v)),
              ),
            ),
            _Tile(
              icon: Icons.location_on_outlined,
              title: 'Alamat Toko',
              subtitle: store.storeAddress.isEmpty
                  ? 'Belum diset' : store.storeAddress,
              onTap: () => _editField(
                context, ref,
                label: 'Alamat Toko',
                value: store.storeAddress,
                maxLines: 3,
                onSave: (v) => ref.read(storeSettingsProvider.notifier)
                    .update((s) => s.copyWith(storeAddress: v)),
              ),
            ),
            _Tile(
              icon: Icons.phone_outlined,
              title: 'Nomor Telepon',
              subtitle: store.storePhone.isEmpty
                  ? 'Belum diset' : store.storePhone,
              onTap: () => _editField(
                context, ref,
                label: 'Nomor Telepon',
                value: store.storePhone,
                keyboardType: TextInputType.phone,
                onSave: (v) => ref.read(storeSettingsProvider.notifier)
                    .update((s) => s.copyWith(storePhone: v)),
              ),
            ),
          ]),

          // ── Struk ─────────────────────────────────────────
          _Section('Struk', [
            _Tile(
              icon: Icons.receipt_long_outlined,
              title: 'Catatan Struk',
              subtitle: store.storeNote.isEmpty
                  ? 'Belum diset' : store.storeNote,
              onTap: () => _editField(
                context, ref,
                label: 'Catatan di bawah struk',
                value: store.storeNote,
                maxLines: 3,
                onSave: (v) => ref.read(storeSettingsProvider.notifier)
                    .update((s) => s.copyWith(storeNote: v)),
              ),
            ),
            _Tile(
              icon: Icons.straighten_outlined,
              title: 'Ukuran Kertas',
              subtitle: store.receiptSize,
              onTap: () => _pickReceiptSize(context, ref, store),
            ),
            SwitchListTile(
              title: const Text('Tampilkan Logo'),
              subtitle: const Text('Logo toko di struk'),
              value: store.showLogo,
              onChanged: (v) =>
                  ref.read(storeSettingsProvider.notifier)
                      .update((s) => s.copyWith(showLogo: v)),
              secondary: _TileIcon(
                  Icons.image_outlined, AppColors.primary),
            ),
            SwitchListTile(
              title: const Text('Cetak Otomatis'),
              subtitle: const Text('Print struk setelah transaksi'),
              value: store.printAfterTransaction,
              onChanged: (v) =>
                  ref.read(storeSettingsProvider.notifier)
                      .update((s) =>
                          s.copyWith(printAfterTransaction: v)),
              secondary: _TileIcon(
                  Icons.print_outlined, AppColors.primary),
            ),
            _Tile(
              icon: Icons.preview_outlined,
              title: 'Preview Struk',
              subtitle: 'Lihat contoh tampilan struk',
              onTap: () => _showReceiptPreview(context, store),
            ),
          ]),

          // ── Printer ───────────────────────────────────────
          _Section('Printer Bluetooth', [
            if (printer.deviceName != null) ...[
              ListTile(
                leading: _TileIcon(
                    Icons.bluetooth_connected, AppColors.success),
                title: Text(printer.deviceName!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(printer.deviceAddress ?? '',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(printerSettingsProvider.notifier)
                      .clearPrinter(),
                  child: const Text('Putus',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ),
            ],
            _Tile(
              icon: printer.deviceName != null
                  ? Icons.bluetooth_searching
                  : Icons.bluetooth_outlined,
              title: printer.deviceName != null
                  ? 'Ganti Printer'
                  : 'Hubungkan Printer',
              subtitle: 'Cari printer Bluetooth thermal',
              onTap: () => _showBluetoothScanner(context, ref),
            ),
            _Tile(
              icon: Icons.print_outlined,
              title: 'Test Print',
              subtitle: 'Cetak struk uji coba',
              color: printer.deviceName != null
                  ? AppColors.primary : Colors.grey,
              onTap: printer.deviceName != null
                  ? () => _testPrint(context, ref, store)
                  : null,
            ),
          ]),

          // ── Keamanan ──────────────────────────────────────
          _Section('Keamanan', [
            _Tile(
              icon: pinActive
                  ? Icons.lock_rounded
                  : Icons.lock_outline,
              title: 'PIN Aplikasi',
              subtitle: pinActive
                  ? 'Aktif — ketuk untuk ubah atau nonaktifkan'
                  : 'Belum diaktifkan',
              color: pinActive ? AppColors.success : null,
              onTap: () => _showPinSetup(context, ref, isPinActive: pinActive),
            ),
            _Tile(
              icon: Icons.fingerprint_outlined,
              title: 'Biometrik',
              subtitle: 'Fingerprint / Face ID',
              onTap: () {},
            ),
          ]),

          // ── Data ──────────────────────────────────────────
          _Section('Data', [
            _Tile(
              icon: Icons.backup_outlined,
              title: 'Backup Data',
              subtitle: 'Ekspor database ke file',
              color: AppColors.primary,
              onTap: () => _backupData(context, ref),
            ),
            _Tile(
              icon: Icons.delete_forever_outlined,
              title: 'Hapus Semua Data',
              subtitle: 'Reset aplikasi ke awal',
              color: AppColors.danger,
              onTap: () => _confirmReset(context, ref),
            ),
          ]),

          // ── About ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              Text('KasirKu',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              SizedBox(height: 4),
              Text('Versi 1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              SizedBox(height: 4),
              Text('Solusi Kasir Praktis untuk Bisnismu',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Edit field dialog ──────────────────────────────────────────────────────

  void _editField(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String value,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = TextEditingController(text: value);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () async {
                await onSave(ctrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan')),
        ],
      ),
    );
  }

  // ── Pick receipt size ──────────────────────────────────────────────────────

  void _pickReceiptSize(
      BuildContext context, WidgetRef ref, StoreSettings store) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ukuran Kertas Struk',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            for (final size in ['58mm', '80mm'])
              ListTile(
                title: Text(size),
                subtitle: Text(size == '58mm'
                    ? 'Printer thermal standar'
                    : 'Printer thermal lebar'),
                leading: Radio<String>(
                  value: size,
                  groupValue: store.receiptSize,
                  onChanged: (v) {
                    ref.read(storeSettingsProvider.notifier)
                        .update((s) =>
                            s.copyWith(receiptSize: v));
                    Navigator.pop(context);
                  },
                  activeColor: AppColors.primary,
                ),
                onTap: () {
                  ref.read(storeSettingsProvider.notifier)
                      .update((s) => s.copyWith(receiptSize: size));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Receipt preview ────────────────────────────────────────────────────────

  void _showReceiptPreview(
      BuildContext context, StoreSettings store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                const Expanded(
                  child: Text('Preview Struk',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Container(
                    width: store.receiptSize == '58mm' ? 220 : 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: _ReceiptPreview(store: store),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bluetooth scanner ──────────────────────────────────────────────────────

  void _showBluetoothScanner(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _BluetoothScanSheet(),
      ),
    );
  }

  // ── Test print ─────────────────────────────────────────────────────────────

  Future<void> _testPrint(
      BuildContext context, WidgetRef ref, StoreSettings store) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mengirim test print ke printer...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ── PIN setup ──────────────────────────────────────────────────────────────

  void _showPinSetup(BuildContext context, WidgetRef ref,
      {required bool isPinActive}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _PinSetupSheet(isPinActive: isPinActive),
      ),
    );
  }

  // ── Backup data ────────────────────────────────────────────────────────────

  Future<void> _backupData(BuildContext context, WidgetRef ref) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/kasirku.db');
      if (!dbFile.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database tidak ditemukan')));
        return;
      }
      final now = DateTime.now();
      final backupName =
          'kasirku_backup_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.db';
      final backup = File('${dir.path}/$backupName');
      await dbFile.copy(backup.path);
      await Share.shareXFiles(
        [XFile(backup.path)],
        subject: 'Backup KasirKu',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup: $e'),
              backgroundColor: AppColors.danger));
      }
    }
  }

  // ── Reset data ─────────────────────────────────────────────────────────────

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Hapus Semua Data?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Semua data produk, transaksi, dan pengaturan akan dihapus permanen.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Ketik HAPUS untuk konfirmasi:',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'HAPUS',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, ctrl.text == 'HAPUS'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Hapus Semua')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil dihapus. Restart aplikasi.'),
          backgroundColor: AppColors.danger));
    }
  }
}

// ─── Receipt Preview Widget ───────────────────────────────────────────────────

class _ReceiptPreview extends StatelessWidget {
  final StoreSettings store;
  const _ReceiptPreview({required this.store});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Courier', fontSize: 11);
    const bold  = TextStyle(
        fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.w700);
    final divider = Text('-' * 32,
        style: style.copyWith(color: Colors.grey));

    return DefaultTextStyle(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Text(store.storeName,
              style: bold.copyWith(fontSize: 14),
              textAlign: TextAlign.center),
          if (store.storeAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(store.storeAddress,
                style: style.copyWith(fontSize: 10),
                textAlign: TextAlign.center),
          ],
          if (store.storePhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Telp: ${store.storePhone}',
                style: style.copyWith(fontSize: 10),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 6),
          divider,
          const SizedBox(height: 4),
          Text('No: INV-20240101-001', style: style),
          Text('Kasir: Kasir Pagi',   style: style),
          Text('Tgl: 01/01/2024 08:00', style: style),
          const SizedBox(height: 4),
          divider,
          const SizedBox(height: 4),
          // Items
          _ReceiptItem('Aqua Botol 600ml', 2, 4000),
          _ReceiptItem('Indomie Goreng',   3, 3500),
          _ReceiptItem('Kopi Sachet',      1, 2000),
          const SizedBox(height: 4),
          divider,
          const SizedBox(height: 4),
          _ReceiptRow('Subtotal', 'Rp 19.500'),
          _ReceiptRow('Diskon',   '-Rp 0'),
          _ReceiptRow('Total',    'Rp 19.500', bold: true),
          _ReceiptRow('Bayar',    'Rp 20.000'),
          _ReceiptRow('Kembali',  'Rp 500',   bold: true),
          const SizedBox(height: 4),
          divider,
          const SizedBox(height: 6),
          Text(store.storeNote,
              style: style.copyWith(fontSize: 10),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('* * *',
              style: style.copyWith(
                  letterSpacing: 4, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ReceiptItem extends StatelessWidget {
  final String name;
  final int qty;
  final int price;
  const _ReceiptItem(this.name, this.qty, this.price);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Courier', fontSize: 11);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: style),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('  $qty x ${CurrencyFormatter.format(price.toDouble())}',
                  style: style),
              Text(CurrencyFormatter.format((qty * price).toDouble()),
                  style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _ReceiptRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Courier',
      fontSize: bold ? 12 : 11,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value,  style: style),
      ],
    );
  }
}

// ─── Bluetooth Scan Sheet ─────────────────────────────────────────────────────

class _BluetoothScanSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BluetoothScanSheet> createState() =>
      _BluetoothScanSheetState();
}

class _BluetoothScanSheetState
    extends ConsumerState<_BluetoothScanSheet> {
  bool _scanning = false;

  // Mock devices — replace with actual bluetooth scan
  final _devices = [
    {'name': 'Printer Thermal 58mm', 'address': 'DC:0D:30:11:22:33'},
    {'name': 'RPP02N',               'address': 'DC:0D:30:44:55:66'},
    {'name': 'MPT-II',               'address': 'DC:0D:30:77:88:99'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Pilih Printer Bluetooth',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16))),
            IconButton(
                icon: Icon(
                    _scanning ? Icons.stop : Icons.refresh,
                    color: AppColors.primary),
                onPressed: () {
                  setState(() => _scanning = !_scanning);
                  if (_scanning) {
                    Future.delayed(const Duration(seconds: 2),
                        () { if (mounted) setState(() => _scanning = false); });
                  }
                }),
          ]),
          if (_scanning) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('Mencari perangkat...',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ..._devices.map((d) => ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.print_outlined,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(d['name']!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(d['address']!,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            trailing: ElevatedButton(
              onPressed: () async {
                await ref.read(printerSettingsProvider.notifier)
                    .setPrinter(d['name']!, d['address']!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${d['name']} terhubung'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8)),
              child: const Text('Pilih',
                  style: TextStyle(fontSize: 13)),
            ),
          )),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.info_outline, size: 14),
              label: const Text('Pastikan Bluetooth aktif & printer menyala',
                  style: TextStyle(fontSize: 12)),
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PIN Setup Sheet ──────────────────────────────────────────────────────────

class _PinSetupSheet extends ConsumerStatefulWidget {
  final bool isPinActive;
  const _PinSetupSheet({required this.isPinActive});

  @override
  ConsumerState<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<_PinSetupSheet> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_pin1.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN minimal 4 digit')));
      return;
    }
    if (_pin1.text != _pin2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN tidak cocok'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(pinProvider.notifier).setPin(_pin1.text);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ PIN berhasil disimpan' : 'Gagal menyimpan PIN'),
        backgroundColor: ok ? AppColors.success : AppColors.danger));
  }

  Future<void> _clearPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nonaktifkan PIN?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Aplikasi tidak akan meminta PIN saat dibuka.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(pinProvider.notifier).clearPin();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN dinonaktifkan')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isPinActive ? 'Ubah PIN Aplikasi' : 'Set PIN Aplikasi',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text('PIN digunakan untuk membuka aplikasi',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _pin1,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.isPinActive
                  ? 'PIN Baru (4-6 digit)'
                  : 'PIN Baru (4-6 digit)',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Konfirmasi PIN',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan PIN'),
              onPressed: _saving ? null : _savePin,
            ),
          ),
          if (widget.isPinActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.lock_open_outlined,
                    size: 18, color: AppColors.danger),
                label: const Text('Nonaktifkan PIN',
                    style: TextStyle(color: AppColors.danger)),
                onPressed: _clearPin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

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
                  letterSpacing: 0.8)),
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
  final VoidCallback? onTap;
  final Color? color;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return ListTile(
      leading: _TileIcon(icon, c),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12, color: Colors.grey.shade500)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right,
              color: Colors.grey, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _TileIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
