import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/kasir_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/database/app_database.dart';
import '../dashboard/dashboard_screen.dart' show dashboardStatsProvider;
import '../../navigation/app_router.dart' show currentNavIndexProvider;

// Index tab "Kasir" pada bottom navigation (lihat _screens di app_router.dart)
const int _kKasirTabIndex = 2;

class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Cek draft tersimpan
      final notifier = ref.read(kasirProvider.notifier);
      final has = await notifier.hasDraft();
      if (has && mounted) {
        final draftTime = await notifier.getDraftTime();
        final timeStr = draftTime != null
            ? DateFormat('HH:mm, dd MMM').format(draftTime)
            : '';
        if (!mounted) return;
        final load = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Ada Draft Tersimpan'),
            content: Text('Draft transaksi dari $timeStr ditemukan. Lanjutkan?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Mulai Baru')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lanjutkan')),
            ],
          ),
        );
        if (load == true) {
          await notifier.loadDraft();
        } else {
          await notifier.clearDraft();
        }
      }
      // Catatan: scanner TIDAK lagi auto-dibuka saat cold start.
      // Scanner hanya dibuka saat user aktif menekan tab "Kasir"
      // di bottom navigation — lihat ref.listen di method build().
    });
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _BarcodeScannerSheet(
          onDetected: (code) async {
            final db = ref.read(databaseProvider);
            final product = await db.productsDao.getByBarcode(code);
            if (!mounted) return;
            if (product != null) {
              ref.read(kasirProvider.notifier).addProduct(product);
              HapticFeedback.mediumImpact();
              await SoundService.instance.beepScan();
            } else {
              await SoundService.instance.beepError();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Barcode "\$code" tidak ditemukan di produk'),
                  ]),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(kasirProvider);

    // Buka scanner hanya saat user aktif berpindah ke tab "Kasir",
    // bukan saat cold start (IndexedStack membangun semua screen sekaligus).
    ref.listen<int>(currentNavIndexProvider, (previous, next) {
      if (next == _kKasirTabIndex && previous != _kKasirTabIndex) {
        _openScanner();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir',
          style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!cart.isEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined,
                color: Colors.white70, size: 18),
              label: const Text('Hapus',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(onFocused: _onSearchFocused),
          _ProductResults(),
          if (!cart.isEmpty)
            Expanded(
              child: _KasirBody(cart: cart),
            )
          else
            const Expanded(child: _EmptyCart()),
        ],
      ),
    );
  }

  // Dipanggil saat search bar difokus → tutup scanner
  void _onSearchFocused() {
    Navigator.of(context).popUntil((route) {
      return route.isFirst || !(route.settings.name == null);
    });
    // Tutup bottom sheet scanner jika terbuka
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Keranjang?'),
        content: const Text('Semua item akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ref.read(kasirProvider.notifier).clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger),
            child: const Text('Hapus')),
        ],
      ),
    );
  }
}

// ─── Kasir Body (scroll: keranjang + ringkasan + bayar) ───────────────────────

class _KasirBody extends ConsumerWidget {
  final KasirState cart;
  const _KasirBody({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : const Color(0xFFF5F7FA);

    return Container(
      color: bgColor,
      child: CustomScrollView(
        slivers: [
          // ── Header keranjang ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                    size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Keranjang (${cart.totalItems})',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline,
                      size: 14, color: AppColors.danger),
                    label: const Text('Bersihkan',
                      style: TextStyle(
                        fontSize: 12, color: AppColors.danger)),
                    onPressed: () => _confirmClear(context, ref),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Daftar item keranjang ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = cart.items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(item.product.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      ),
                      onDismissed: (_) {
                        ref.read(kasirProvider.notifier)
                            .removeProduct(item.product.id);
                        HapticFeedback.mediumImpact();
                      },
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.inventory_2_outlined,
                                size: 22, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(item.product.sellPrice),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Qty + harga kanan
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(children: [
                                  _QtyBtn(
                                    icon: Icons.remove,
                                    onTap: () {
                                      ref.read(kasirProvider.notifier)
                                          .updateQuantity(item.product.id,
                                              item.quantity - 1);
                                      HapticFeedback.lightImpact();
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () => _editQty(context, ref, item),
                                    child: SizedBox(
                                      width: 32,
                                      child: Text('${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                    ),
                                  ),
                                  _QtyBtn(
                                    icon: Icons.add,
                                    onTap: () {
                                      ref.read(kasirProvider.notifier)
                                          .updateQuantity(item.product.id,
                                              item.quantity + 1);
                                      HapticFeedback.lightImpact();
                                    },
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(item.subtotal),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
                childCount: cart.items.length,
              ),
            ),
          ),

          // ── Ringkasan Pembayaran ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ringkasan Pembayaran',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Subtotal',
                        value: CurrencyFormatter.format(cart.subtotal)),
                      if (cart.discountTotal > 0) ...[
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Diskon',
                          value: '- ${CurrencyFormatter.format(cart.discountTotal)}',
                          valueColor: AppColors.danger),
                      ],
                      if (cart.taxAmount > 0) ...[
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Pajak (${cart.taxPercent.toStringAsFixed(0)}%)',
                          value: '+ ${CurrencyFormatter.format(cart.taxAmount)}',
                          valueColor: AppColors.warning),
                      ],
                      if (cart.redeemPoints > 0) ...[
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Diskon Poin',
                          value: '- ${CurrencyFormatter.format(cart.pointDiscount)}',
                          valueColor: AppColors.primary),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(CurrencyFormatter.format(cart.total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Tombol Diskon, Pajak ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_offer_outlined, size: 16),
                    label: Text(
                      cart.discountTotal > 0
                          ? 'Diskon ${CurrencyFormatter.format(cart.discountTotal)}'
                          : 'Tambah Diskon',
                      style: const TextStyle(fontSize: 12)),
                    onPressed: () => _showDiscount(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cart.discountTotal > 0
                          ? AppColors.danger : null,
                      side: cart.discountTotal > 0
                          ? const BorderSide(color: AppColors.danger) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.percent_outlined, size: 16),
                    label: Text(
                      cart.taxPercent > 0
                          ? 'Pajak ${cart.taxPercent.toStringAsFixed(0)}%'
                          : 'Tambah Pajak',
                      style: const TextStyle(fontSize: 12)),
                    onPressed: () => _showTax(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cart.taxPercent > 0
                          ? AppColors.warning : null,
                      side: cart.taxPercent > 0
                          ? const BorderSide(color: AppColors.warning) : null,
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Tombol Simpan Draft + Bayar ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(children: [
                // Simpan Draft
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan Draft'),
                  onPressed: () => _saveDraft(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(width: 8),
                // Bayar
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(
                      'Bayar  ${CurrencyFormatter.format(cart.total)}  →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: () => _showPayment(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Keranjang?'),
        content: const Text('Semua item akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ref.read(kasirProvider.notifier).clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger),
            child: const Text('Hapus')),
        ],
      ),
    );
  }

  void _editQty(BuildContext context, WidgetRef ref, CartItem item) {
    final ctrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.product.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Jumlah',
            suffixText: item.product.unit,
            helperText: 'Stok tersedia: ${item.product.stock}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text) ?? 1;
              ref.read(kasirProvider.notifier)
                  .updateQuantity(item.product.id, qty);
              Navigator.pop(context);
            },
            child: const Text('OK')),
        ],
      ),
    );
  }

  void _showDiscount(BuildContext context, WidgetRef ref) {
    final cart = ref.read(kasirProvider);
    final initialPercent = (cart.subtotal > 0 && cart.discountTotal > 0)
        ? (cart.discountTotal / cart.subtotal * 100)
        : 0.0;
    final ctrl = TextEditingController(
      text: initialPercent > 0
          ? (initialPercent % 1 == 0
              ? initialPercent.toStringAsFixed(0)
              : initialPercent.toStringAsFixed(2))
          : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Tambah Diskon',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Diskon dihitung dari subtotal ${CurrencyFormatter.format(cart.subtotal)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Persentase Diskon',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent_outlined))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () {
                    ref.read(kasirProvider.notifier).setDiscount(0);
                    Navigator.pop(context);
                  },
                  child: const Text('Hapus Diskon'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    double percent = double.tryParse(ctrl.text) ?? 0;
                    if (percent < 0) percent = 0;
                    if (percent > 100) percent = 100;
                    final discAmount = cart.subtotal * (percent / 100);
                    ref.read(kasirProvider.notifier).setDiscount(discAmount);
                    Navigator.pop(context);
                  },
                  child: const Text('Terapkan'))),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showTax(BuildContext context, WidgetRef ref) {
    final cart = ref.read(kasirProvider);
    final ctrl = TextEditingController(
      text: cart.taxPercent > 0 ? cart.taxPercent.toStringAsFixed(0) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Atur Pajak',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Persentase Pajak', suffixText: '%')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () {
                  ref.read(kasirProvider.notifier).setTax(0);
                  Navigator.pop(context);
                },
                child: const Text('Hapus Pajak'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  final tax = double.tryParse(ctrl.text) ?? 0;
                  ref.read(kasirProvider.notifier).setTax(tax.clamp(0, 100));
                  Navigator.pop(context);
                },
                child: const Text('Terapkan'))),
            ]),
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
  }

  void _showPayment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _PaymentSheet(),
      ),
    );
  }

  Future<void> _saveDraft(BuildContext context, WidgetRef ref) async {
    await ref.read(kasirProvider.notifier).saveDraft();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Draft berhasil disimpan'),
          ]),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─── Summary Row Helper ───────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: valueColor ?? Theme.of(context).textTheme.bodyMedium?.color)),
      ],
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  final VoidCallback? onFocused;
  const _SearchBar({this.onFocused});

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // Tutup scanner saat user tap search bar
        widget.onFocused?.call();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _BarcodeScannerSheet(
          onDetected: (code) async {
            // Lookup produk by barcode → langsung masuk keranjang
            final db = ref.read(databaseProvider);
            final product = await db.productsDao.getByBarcode(code);
            if (!mounted) return;
            if (product != null) {
              ref.read(kasirProvider.notifier).addProduct(product);
              HapticFeedback.mediumImpact();
              await SoundService.instance.beepScan(); // ✅ beep sukses
            } else {
              // Barcode tidak ditemukan → fallback ke search
              _ctrl.text = code;
              ref.read(productSearchProvider.notifier).state = code;
              await SoundService.instance.beepError(); // ❌ beep error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Barcode "$code" tidak ditemukan di produk'),
                  ]),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: (v) =>
                ref.read(productSearchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Cari nama / barcode produk...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner,
              color: Colors.white, size: 22),
            onPressed: _openScanner,
            tooltip: 'Scan Barcode',
          ),
        ),
      ]),
    );
  }
}

// ─── Barcode Scanner Sheet ────────────────────────────────────────────────────

class _BarcodeScannerSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String code) onDetected;
  const _BarcodeScannerSheet({required this.onDetected});

  @override
  ConsumerState<_BarcodeScannerSheet> createState() =>
      _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState
    extends ConsumerState<_BarcodeScannerSheet> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _processing = false;
  bool _torchOn = false;

  // Riwayat scan dalam sesi ini: barcode -> jumlah scan
  final Map<String, int> _scanLog = {};
  // Nama produk terakhir yang berhasil discan
  String? _lastProductName;
  // Kode terakhir (untuk debounce)
  String? _lastCode;
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null || code.isEmpty) return;

    // Debounce: abaikan scan yang sama dalam 1.5 detik
    final now = DateTime.now();
    if (_lastCode == code &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 1500) return;

    _lastCode = code;
    _lastScanTime = now;
    _processing = true;

    HapticFeedback.mediumImpact();

    // Panggil callback (lookup + addProduct di parent)
    await widget.onDetected(code);

    if (mounted) {
      setState(() {
        _scanLog[code] = (_scanLog[code] ?? 0) + 1;
        _processing = false;
      });
    } else {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.72;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(children: [
              const Expanded(
                child: Text('Scan Barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
              ),
              // Torch toggle
              IconButton(
                icon: Icon(
                  _torchOn
                      ? Icons.flashlight_on
                      : Icons.flashlight_off_outlined,
                  color: _torchOn ? Colors.yellow : Colors.white70,
                ),
                onPressed: () {
                  _scannerCtrl.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Camera view
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Scanner
                  MobileScanner(
                    controller: _scannerCtrl,
                    onDetect: _onDetect,
                  ),
                  // Overlay viewfinder
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(children: [
                        // Corner decorators
                        _Corner(Alignment.topLeft),
                        _Corner(Alignment.topRight),
                        _Corner(Alignment.bottomLeft),
                        _Corner(Alignment.bottomRight),
                      ]),
                    ),
                  ),
                  // Hint text
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Arahkan kamera ke barcode produk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Scan Counter Panel ───────────────────────────────────
          if (_scanLog.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.shopping_cart_outlined,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Sudah masuk keranjang (${_scanLog.values.fold(0, (a, b) => a + b)} item)',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ..._scanLog.entries.map((e) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key.length > 22
                                    ? '${e.key.substring(0, 22)}…'
                                    : e.key,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withOpacity(0.8),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'x${e.value}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ]),
                      )),
                ],
              ),
            ),

          // Tombol selesai scan
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline,
                    size: 18),
                label: Text(_scanLog.isEmpty
                    ? 'Scan Barcode untuk mulai'
                    : 'Selesai – ${_scanLog.values.fold(0, (a, b) => a + b)} item ditambahkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _scanLog.isEmpty
                      ? Colors.white24
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _scanLog.isEmpty
                    ? null
                    : () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Corner decorator untuk viewfinder
class _Corner extends StatelessWidget {
  final Alignment alignment;
  const _Corner(this.alignment);

  @override
  Widget build(BuildContext context) {
    final isTop    = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft   = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    return Positioned(
      top:    isTop    ? -1 : null,
      bottom: !isTop   ? -1 : null,
      left:   isLeft   ? -1 : null,
      right:  !isLeft  ? -1 : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top:    isTop    ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            bottom: !isTop   ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            left:   isLeft   ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            right:  !isLeft  ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─── Product Search Results ───────────────────────────────────────────────────

class _ProductResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productSearchProvider);
    if (query.isEmpty) return const SizedBox();

    final results = ref.watch(filteredProductsProvider);
    return results.when(
      data: (list) {
        if (list.isEmpty) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.search_off, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 8),
                Text('Produk tidak ditemukan',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = list[i];
              final outOfStock = p.stock <= 0;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? Colors.grey.shade100
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: outOfStock
                        ? Colors.grey.shade400
                        : AppColors.primary,
                  ),
                ),
                title: Text(p.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: outOfStock ? Colors.grey : null,
                  )),
                subtitle: Text(CurrencyFormatter.format(p.sellPrice),
                  style: const TextStyle(
                    color: AppColors.primary, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? AppColors.danger.withOpacity(0.1)
                        : p.stock <= p.minStock
                            ? AppColors.warning.withOpacity(0.1)
                            : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    outOfStock ? 'Habis' : 'Stok: ${p.stock}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: outOfStock
                          ? AppColors.danger
                          : p.stock <= p.minStock
                              ? AppColors.warning
                              : AppColors.success,
                    ),
                  ),
                ),
                onTap: () {
                  if (!outOfStock) {
                    ref.read(kasirProvider.notifier).addProduct(p);
                    ref.read(productSearchProvider.notifier).state = '';
                    HapticFeedback.lightImpact();
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
    );
  }
}

// _CartHeader sudah digantikan _KasirBody

// ─── Cart List ────────────────────────────────────────────────────────────────

class _CartList extends ConsumerWidget {
  final KasirState cart;
  const _CartList({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final item = cart.items[i];
        return Dismissible(
          key: ValueKey(item.product.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
          onDismissed: (_) {
            ref.read(kasirProvider.notifier).removeProduct(item.product.id);
            HapticFeedback.mediumImpact();
          },
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                    size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.format(item.product.sellPrice)} × ${item.quantity} = ${CurrencyFormatter.format(item.subtotal)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(children: [
                  _QtyBtn(
                    icon: Icons.remove,
                    onTap: () {
                      ref.read(kasirProvider.notifier)
                          .updateQuantity(item.product.id, item.quantity - 1);
                      HapticFeedback.lightImpact();
                    },
                  ),
                  GestureDetector(
                    onTap: () => _editQty(context, ref, item),
                    child: SizedBox(
                      width: 36,
                      child: Text('${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                    ),
                  ),
                  _QtyBtn(
                    icon: Icons.add,
                    onTap: () {
                      ref.read(kasirProvider.notifier)
                          .updateQuantity(item.product.id, item.quantity + 1);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _editQty(BuildContext context, WidgetRef ref, CartItem item) {
    final ctrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.product.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Jumlah',
            suffixText: item.product.unit,
            helperText: 'Stok tersedia: ${item.product.stock}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text) ?? 1;
              ref.read(kasirProvider.notifier)
                  .updateQuantity(item.product.id, qty);
              Navigator.pop(context);
            },
            child: const Text('OK')),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─── Checkout Panel ───────────────────────────────────────────────────────────

class _CheckoutPanel extends ConsumerWidget {
  final KasirState cart;
  const _CheckoutPanel({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Redeem poin - ditampilkan di Payment Sheet
            if (cart.discountTotal > 0 || cart.taxAmount > 0 || cart.redeemPoints > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal',
                    style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
                  Text(CurrencyFormatter.format(cart.subtotal),
                    style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              if (cart.redeemPoints > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diskon Poin (${cart.redeemPoints} poin)',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                    Text('- ${CurrencyFormatter.format(cart.pointDiscount)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              if (cart.discountTotal > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diskon',
                      style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                    Text('- ${CurrencyFormatter.format(cart.discountTotal)}',
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.danger)),
                  ],
                ),
              ],
              if (cart.taxAmount > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pajak (${cart.taxPercent.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                    Text('+ ${CurrencyFormatter.format(cart.taxAmount)}',
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.warning)),
                  ],
                ),
              ],
              const Divider(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Total harga — ambil sisa space yang tidak dipakai tombol
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${cart.totalItems} item',
                        style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                      Text(CurrencyFormatter.format(cart.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Diskon
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_offer_outlined, size: 16),
                  label: const Text('Diskon', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showDiscount(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                // Tombol Pajak
                OutlinedButton.icon(
                  icon: const Icon(Icons.percent_outlined, size: 16),
                  label: Text(
                    cart.taxPercent > 0
                        ? 'Pajak ${cart.taxPercent.toStringAsFixed(0)}%'
                        : 'Pajak',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _showTax(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: cart.taxPercent > 0
                        ? AppColors.warning
                        : null,
                    side: cart.taxPercent > 0
                        ? const BorderSide(color: AppColors.warning)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                // Tombol Bayar
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Bayar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _showPayment(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDiscount(BuildContext context, WidgetRef ref) {
    final cart = ref.read(kasirProvider);
    final ctrl = TextEditingController(
      text: cart.discountTotal > 0
          ? cart.discountTotal.toStringAsFixed(0)
          : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tambah Diskon',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nominal Diskon',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(kasirProvider.notifier).setDiscount(0);
                    Navigator.pop(context);
                  },
                  child: const Text('Hapus Diskon')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final disc = double.tryParse(ctrl.text) ?? 0;
                    ref.read(kasirProvider.notifier).setDiscount(disc);
                    Navigator.pop(context);
                  },
                  child: const Text('Terapkan')),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTax(BuildContext context, WidgetRef ref) {
    final cart = ref.read(kasirProvider);
    final ctrl = TextEditingController(
      text: cart.taxPercent > 0
          ? cart.taxPercent.toStringAsFixed(0)
          : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Atur Pajak',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Pajak dihitung dari subtotal sebelum diskon',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Persentase Pajak (%)',
                suffixText: '%',
                prefixIcon: Icon(Icons.percent_outlined),
                helperText: 'Contoh: 11 untuk PPN 11%',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1.0, 5.0, 10.0, 11.0].map((v) => ActionChip(
                label: Text('${v.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  ctrl.text = v.toStringAsFixed(0);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(kasirProvider.notifier).setTax(0);
                    Navigator.pop(context);
                  },
                  child: const Text('Hapus Pajak')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final tax = double.tryParse(ctrl.text) ?? 0;
                    ref.read(kasirProvider.notifier).setTax(tax.clamp(0, 100));
                    Navigator.pop(context);
                  },
                  child: const Text('Terapkan')),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPayment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _PaymentSheet(),
      ),
    );
  }
}

// ─── Payment Sheet ────────────────────────────────────────────────────────────

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet();

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _method = 'tunai';
  bool _loading = false;

  // Untuk metode hutang
  Customer? _selectedCustomer;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(kasirProvider);
    final paid = double.tryParse(_amountCtrl.text) ?? 0;
    final change = paid - cart.total;
    final canPay = _method != 'tunai' || paid >= cart.total;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pembayaran',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Total Pembayaran',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.format(cart.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    )),
                  Text('${cart.totalItems} item',
                    style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Metode Pembayaran',
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodChip('tunai', Icons.payments_outlined, 'Tunai'),
                const SizedBox(width: 8),
                _buildMethodChip('qris', Icons.qr_code, 'QRIS'),
                const SizedBox(width: 8),
                _buildMethodChip('transfer', Icons.account_balance_outlined, 'Transfer'),
                const SizedBox(width: 8),
                _buildMethodChip('hutang', Icons.receipt_long_outlined, 'Hutang'),
              ],
            ),
            const SizedBox(height: 16),

            if (_method == 'tunai') ...[
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Jumlah Uang Diterima',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8, runSpacing: 8,
                children: _quickAmounts(cart.total)
                    .map((v) => ActionChip(
                      avatar: Icon(Icons.add, size: 14,
                        color: AppColors.primary),
                      label: Text(CurrencyFormatter.formatCompact(v),
                        style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _amountCtrl.text = v.toStringAsFixed(0);
                        setState(() {});
                      },
                    ))
                    .toList(),
              ),

              if (change > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.change_circle_outlined,
                          color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        const Text('Kembalian',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                      Text(CurrencyFormatter.format(change),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        )),
                    ],
                  ),
                ),
              ] else if (_amountCtrl.text.isNotEmpty && change < 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined,
                      color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Text('Kurang ${CurrencyFormatter.format(-change)}',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                    color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _method == 'hutang'
                          ? 'Transaksi akan dicatat sebagai hutang'
                          : 'Pastikan pembayaran sudah diterima sebelum konfirmasi',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ]),
              ),
              // ── Customer picker — tersedia untuk semua metode ─────────────
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickCustomer,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedCustomer != null
                          ? AppColors.primary
                          : (_method == 'hutang'
                              ? AppColors.warning
                              : Colors.grey.shade300)),
                    borderRadius: BorderRadius.circular(12),
                    color: _selectedCustomer != null
                        ? AppColors.primaryLight
                        : null,
                  ),
                  child: Row(children: [
                    Icon(
                      _selectedCustomer != null
                          ? Icons.person
                          : Icons.person_add_alt_outlined,
                      color: _selectedCustomer != null
                          ? AppColors.primary
                          : (_method == 'hutang'
                              ? AppColors.warning
                              : Colors.grey.shade500),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer != null
                                ? _selectedCustomer!.name
                                : _method == 'hutang'
                                    ? 'Pilih Pelanggan (wajib)'
                                    : 'Pilih Pelanggan (opsional)',
                            style: TextStyle(
                              fontWeight: _selectedCustomer != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedCustomer != null
                                  ? AppColors.primary
                                  : (_method == 'hutang'
                                      ? AppColors.warning
                                      : Colors.grey.shade500),
                              fontSize: 13,
                            ),
                          ),
                          if (_selectedCustomer != null) ...[
                            const SizedBox(height: 2),
                            Builder(builder: (ctx) {
                              final cart = ref.read(kasirProvider);
                              final pts = (cart.total / 10000).floor();
                              return Text(
                                '+$pts poin • Total poin: ${_selectedCustomer!.points + pts}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    if (_selectedCustomer != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedCustomer = null),
                        child: const Icon(Icons.close,
                          color: AppColors.danger, size: 18),
                      )
                    else
                      Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 18),
                  ]),
                ),
              ),
              if (_method == 'hutang') ...[
              ],
              const SizedBox(height: 16),
            ],


            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                prefixIcon: Icon(Icons.note_alt_outlined),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(_loading
                    ? 'Memproses...'
                    : 'Konfirmasi Pembayaran'),
                onPressed: (_loading || !canPay) ? null : _process,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canPay
                      ? AppColors.success
                      : Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String value, IconData icon, String label) {
    final isSelected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(height: 3),
              Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                )),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _quickAmounts(double total) {
    final base = [10000.0, 20000.0, 50000.0, 100000.0, 200000.0, 500000.0];
    final result = <double>[total];
    for (final v in base) {
      if (v >= total) result.add(v);
      if (result.length >= 4) break;
    }
    return result.toSet().take(4).toList()..sort();
  }

  Future<void> _pickCustomer() async {
    final db = ref.read(databaseProvider);
    List<Customer> allCustomers = await db.customersDao.getAllCustomers();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final filtered = query.isEmpty
                ? allCustomers
                : allCustomers
                    .where((c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                const Text('Pilih Pelanggan',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setLocalState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama pelanggan...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text(
                        'Tambah pelanggan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        // Tutup sheet pilih pelanggan dulu
                        Navigator.pop(ctx);
                        // Buka form tambah pelanggan
                        await _showAddCustomerForm(db);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('Pelanggan tidak ditemukan',
                            style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  c.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                              subtitle: c.phone != null
                                  ? Text(c.phone!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500))
                                  : null,
                              onTap: () {
                                setState(() => _selectedCustomer = c);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddCustomerForm(AppDatabase db) async {
    if (!context.mounted) return;

    final nameCtrl    = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final addressCtrl = TextEditingController();
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 20, left: 20, right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text(
                      'Tambah Pelanggan',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Isi data pelanggan baru',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Nama
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pelanggan *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // No HP
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+62 ',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alamat
                    TextField(
                      controller: addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: loading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(loading ? 'Menyimpan...' : 'Tambah Pelanggan'),
                        onPressed: loading
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nama pelanggan wajib diisi'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }
                                setLocalState(() => loading = true);
                                try {
                                  final newId = await db.customersDao.insertCustomer(
                                    CustomersCompanion.insert(
                                      name: nameCtrl.text.trim(),
                                      phone: Value(phoneCtrl.text.isEmpty
                                          ? null
                                          : phoneCtrl.text.trim()),
                                      address: Value(addressCtrl.text.isEmpty
                                          ? null
                                          : addressCtrl.text.trim()),
                                    ),
                                  );
                                  // Ambil customer yang baru saja ditambahkan
                                  final allCustomers =
                                      await db.customersDao.getAllCustomers();
                                  final newCustomer = allCustomers
                                      .where((c) => c.id == newId)
                                      .firstOrNull;
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (newCustomer != null) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() => _selectedCustomer = newCustomer);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Pelanggan "${newCustomer.name}" berhasil ditambahkan dan dipilih'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    });
                                  }
                                } catch (e) {
                                  setLocalState(() => loading = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal menyimpan: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Tunggu animasi penutupan bottom sheet selesai sebelum dispose controller,
    // agar TextField yang masih dalam proses unmount tidak kehilangan listener
    // controller secara tiba-tiba (penyebab error '_dependents.isEmpty').
    await Future.delayed(const Duration(milliseconds: 300));
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _process() async {
    final cart = ref.read(kasirProvider);

    if (_method == 'tunai') {
      final paid = double.tryParse(_amountCtrl.text) ?? 0;
      if (paid < cart.total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uang tidak cukup!'),
            backgroundColor: AppColors.danger));
        return;
      }
    }

    // Validasi pelanggan wajib untuk hutang
    if (_method == 'hutang' && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan terlebih dahulu untuk hutang!'),
          backgroundColor: AppColors.warning));
      return;
    }

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final invoiceNumber =
          await db.transactionsDao.generateInvoiceNumber();
      final amountPaid = _method == 'tunai'
          ? (double.tryParse(_amountCtrl.text) ?? cart.total)
          : _method == 'hutang'
              ? 0.0
              : cart.total;

      final tx = TransactionsCompanion.insert(
        invoiceNumber: invoiceNumber,
        subtotal: Value(cart.subtotal),
        discountAmount: Value(cart.discountTotal),
        taxAmount: Value(cart.taxAmount),
        total: Value(cart.total),
        amountPaid: Value(amountPaid),
        change: Value(amountPaid - cart.total),
        paymentMethod: Value(_method),
        notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
      );

      final items = cart.items.map((i) =>
        TransactionItemsCompanion.insert(
          transactionId: 0,
          productId: i.product.id,
          productName: i.product.name,
          price: i.product.sellPrice,
          quantity: i.quantity,
          discount: Value(i.discount),
          subtotal: i.subtotal,
        )).toList();

      final txId = await db.transactionsDao.insertTransaction(
        tx, items,
        customerId: _selectedCustomer?.id,
        kasirId:   ref.read(authProvider)?.id,
        kasirName: ref.read(authProvider)?.name,
      );

      // ── Kurangi poin yang diredeem ─────────────────────────────────────────
      if (cart.redeemPoints > 0 && _selectedCustomer != null) {
        final customer = _selectedCustomer!;
        final newPoints = (customer.points - cart.redeemPoints).clamp(0, customer.points);
        await db.customersDao.updateCustomer(
          CustomersCompanion(
            id: Value(customer.id),
            points: Value(newPoints),
          ),
        );
      }

      // ── Insert ke tabel Debts jika metode hutang ──────────────────────────
      if (_method == 'hutang' && _selectedCustomer != null) {
        await db.debtsDao.insertDebt(
          DebtsCompanion.insert(
            customerId: _selectedCustomer!.id,
            transactionId: Value(txId),
            amount: cart.total,
            paidAmount: const Value(0),
            status: const Value('unpaid'),
            notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
          ),
        );
      }

      ref.read(kasirProvider.notifier).clear();

      // FIX: Invalidate dashboardStatsProvider agar kartu ringkasan di
      // Dashboard langsung refresh setelah transaksi selesai.
      // StreamProvider sudah reaktif via watchTodayTransactions, tapi
      // invalidate ini memastikan data kemarin juga ikut diperbarui.
      ref.invalidate(dashboardStatsProvider);

      if (context.mounted) {
        Navigator.pop(context);
        _showSuccessDialog(context, invoiceNumber, cart, amountPaid,
            ref.read(authProvider)?.name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(
    BuildContext context,
    String invoiceNumber,
    KasirState cart,
    double amountPaid,
    String? kasirName,
  ) {
    final change = amountPaid - cart.total;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _SuccessDialog(
          invoiceNumber: invoiceNumber,
          cart: cart,
          amountPaid: amountPaid,
          change: change,
          paymentMethod: _method,
          kasirName: kasirName,
        ),
      ),
    );
  }
}

// ─── Success Dialog dengan opsi cetak ────────────────────────────────────────

class _SuccessDialog extends ConsumerStatefulWidget {
  final String invoiceNumber;
  final KasirState cart;
  final double amountPaid;
  final double change;
  final String paymentMethod;
  final String? kasirName;

  const _SuccessDialog({
    required this.invoiceNumber,
    required this.cart,
    required this.amountPaid,
    required this.change,
    required this.paymentMethod,
    this.kasirName,
  });

  @override
  ConsumerState<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends ConsumerState<_SuccessDialog> {
  bool _printing = false;
  bool _savingPdf = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Transaksi Berhasil!',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(widget.invoiceNumber,
            style: TextStyle(
              color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 16),
          _ReceiptRow('Total', CurrencyFormatter.format(widget.cart.total)),
          _ReceiptRow('Bayar', CurrencyFormatter.format(widget.amountPaid)),
          if (widget.change > 0)
            _ReceiptRow('Kembalian', CurrencyFormatter.format(widget.change),
              highlight: true),
          const SizedBox(height: 20),

          // Tombol cetak Bluetooth
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _printing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_outlined, size: 18),
              label: Text(_printing ? 'Mencetak...' : 'Cetak Struk (Bluetooth)'),
              onPressed: _printing ? null : _cetakBluetooth,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 8),

          // Tombol simpan / share PDF
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _savingPdf
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_savingPdf ? 'Membuat PDF...' : 'Simpan / Share PDF'),
              onPressed: _savingPdf ? null : _sharePdf,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Selesai'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cetak Bluetooth Thermal ──────────────────────────────────────────────

  Future<void> _cetakBluetooth() async {
    setState(() => _printing = true);
    try {
      // Cek apakah Bluetooth tersedia
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        // Tampilkan dialog pilih printer
        if (context.mounted) {
          await _showBluetoothPrinterDialog();
        }
        return;
      }
      await _doPrint();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _showBluetoothPrinterDialog() async {
    final List<dynamic> devices =
        await PrintBluetoothThermal.pairedBluetooths;

    if (!context.mounted) return;

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada printer Bluetooth yang dipasangkan'),
          backgroundColor: AppColors.warning));
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pilih Printer',
          style: TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (_, i) {
              final d = devices[i];
              return ListTile(
                leading: const Icon(Icons.print_outlined,
                  color: AppColors.primary),
                title: Text(d.name ?? 'Printer ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(d.macAdress ?? '',
                  style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
                onTap: () async {
                  Navigator.pop(context);
                  final bool result = await PrintBluetoothThermal.connect(
                    macPrinterAddress: d.macAdress ?? '');
                  if (result) {
                    await _doPrint();
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal terhubung ke printer'),
                          backgroundColor: AppColors.danger));
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ],
      ),
    );
  }

  // ── Helper load logo (sama dengan settings_screen) ─────────────────────────
  Future<img.Image?> _loadLogoImage(int maxWidth) async {
    try {
      final store = ref.read(storeSettingsProvider);
      img.Image? original;

      // Pakai logo custom jika ada
      if (store.logoPath.isNotEmpty && File(store.logoPath).existsSync()) {
        final bytes = await File(store.logoPath).readAsBytes();
        original = img.decodeImage(bytes);
      } else {
        // Fallback ke logo default dari assets
        final ByteData data =
            await rootBundle.load('assets/images/app_icon.png');
        final Uint8List bytes = data.buffer.asUint8List();
        original = img.decodeImage(bytes);
      }

      if (original == null) return null;
      if (original.width > maxWidth) {
        original = img.copyResize(original, width: maxWidth);
      }
      return img.grayscale(original);
    } catch (_) {
      return null;
    }
  }

  Future<void> _doPrint() async {
    final settings    = ref.read(storeSettingsProvider);
    final storeName   = settings.storeName.isEmpty ? 'KasirKu' : settings.storeName;
    final storeAddress = settings.storeAddress;
    final storePhone  = settings.storePhone;
    final storeNote   = settings.storeNote;
    final paperSize   = settings.receiptSize == '80mm'
        ? PaperSize.mm80 : PaperSize.mm58;
    final logoMaxWidth = settings.receiptSize == '80mm' ? 300 : 200;

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    var bytes = <int>[];

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // ── Logo ────────────────────────────────────────────────────────────────
    if (settings.showLogo) {
      final logoImg = await _loadLogoImage(logoMaxWidth);
      if (logoImg != null) {
        bytes += generator.image(logoImg);
        bytes += generator.feed(1);
      }
    }

    // ── Header toko ─────────────────────────────────────────────────────────
    bytes += generator.text(storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
    if (storeAddress.isNotEmpty) {
      bytes += generator.text(storeAddress,
        styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone',
        styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr();
    bytes += generator.text('No: ${widget.invoiceNumber}',
      styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(dateStr,
      styles: const PosStyles(align: PosAlign.center));
    if (widget.kasirName != null && widget.kasirName!.isNotEmpty) {
      bytes += generator.text('Kasir: ${widget.kasirName}',
        styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr();

    // ── Items ────────────────────────────────────────────────────────────────
    for (final item in widget.cart.items) {
      bytes += generator.text(item.product.name,
        styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(
          text: '  ${item.quantity} x ${CurrencyFormatter.format(item.product.sellPrice)}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
          text: CurrencyFormatter.format(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();

    // ── Summary ──────────────────────────────────────────────────────────────
    if (widget.cart.discountTotal > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 6,
          styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
          text: '- ${CurrencyFormatter.format(widget.cart.discountTotal)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(
        text: CurrencyFormatter.format(widget.cart.total),
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Bayar', width: 6,
        styles: const PosStyles(align: PosAlign.left)),
      PosColumn(
        text: CurrencyFormatter.format(widget.amountPaid),
        width: 6,
        styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (widget.change > 0) {
      bytes += generator.row([
        PosColumn(text: 'Kembali', width: 6,
          styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
          text: CurrencyFormatter.format(widget.change),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();

    // ── Footer dari pengaturan ───────────────────────────────────────────────
    if (storeNote.isNotEmpty) {
      bytes += generator.text(storeNote,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    bytes += generator.feed(3);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Struk berhasil dicetak!'),
          backgroundColor: AppColors.success));
    }
  }

  // ─── Share PDF ─────────────────────────────────────────────────────────────

  Future<void> _sharePdf() async {
    setState(() => _savingPdf = true);
    try {
      final settings    = ref.read(storeSettingsProvider);
      final storeName   = settings.storeName;
      final storeAddress = settings.storeAddress ?? '';

      final pdfBytes = await _buildPdf(storeName, storeAddress);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Struk ${widget.invoiceNumber}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal buat PDF: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf(String storeName, String storeAddress) async {
    await initializeDateFormatting('id', null);
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'id').format(now);

    // Warna tema
    const primaryColor = PdfColor.fromInt(0xFF0D9488);
    const successColor = PdfColor.fromInt(0xFF10B981);
    const dangerColor  = PdfColor.fromInt(0xFFEF4444);
    const greyColor    = PdfColor.fromInt(0xFF6B7280);
    const lightGrey    = PdfColor.fromInt(0xFFF3F4F6);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll57,
      margin: const pw.EdgeInsets.all(8),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header toko
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(children: [
                pw.Text(storeName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  textAlign: pw.TextAlign.center),
                if (storeAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(storeAddress,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: const PdfColor(1, 1, 1, 0.7)),
                    textAlign: pw.TextAlign.center),
                ],
              ]),
            ),
            pw.SizedBox(height: 8),

            // Info invoice
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('No. Invoice',
                      style: const pw.TextStyle(
                        fontSize: 8, color: greyColor)),
                    pw.Text(widget.invoiceNumber,
                      style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tanggal',
                      style: const pw.TextStyle(
                        fontSize: 8, color: greyColor)),
                    pw.Text(dateStr,
                      style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Metode',
                      style: const pw.TextStyle(
                        fontSize: 8, color: greyColor)),
                    pw.Text(_methodLabel(widget.paymentMethod),
                      style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ]),
            ),
            pw.SizedBox(height: 8),

            // Header kolom item
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6, vertical: 4),
              decoration: const pw.BoxDecoration(color: primaryColor),
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text('Produk',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white))),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('Qty',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                    textAlign: pw.TextAlign.center)),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text('Subtotal',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                    textAlign: pw.TextAlign.right)),
              ]),
            ),

            // Item rows
            ...widget.cart.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final bg = idx.isOdd ? PdfColors.white : lightGrey;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
                color: bg,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(item.product.name,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity}',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center)),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.right)),
                    ]),
                    pw.Text(
                      '@ ${CurrencyFormatter.format(item.product.sellPrice)}',
                      style: const pw.TextStyle(
                        fontSize: 7, color: greyColor)),
                  ],
                ),
              );
            }),

            pw.Divider(thickness: 0.5),

            // Summary
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Column(children: [
                if (widget.cart.discountTotal > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Diskon',
                        style: const pw.TextStyle(
                          fontSize: 8, color: dangerColor)),
                      pw.Text(
                        '- ${CurrencyFormatter.format(widget.cart.discountTotal)}',
                        style: const pw.TextStyle(
                          fontSize: 8, color: dangerColor)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                ],
                if (widget.cart.taxAmount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Pajak (${widget.cart.taxPercent.toStringAsFixed(0)}%)',
                        style: const pw.TextStyle(fontSize: 8, color: greyColor)),
                      pw.Text(
                        '+ ${CurrencyFormatter.format(widget.cart.taxAmount)}',
                        style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                ],
                // Total besar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 6, horizontal: 8),
                  decoration: const pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius:
                        pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                      pw.Text(
                        CurrencyFormatter.format(widget.cart.total),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Dibayar',
                      style: const pw.TextStyle(fontSize: 8, color: greyColor)),
                    pw.Text(CurrencyFormatter.format(widget.amountPaid),
                      style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                if (widget.change > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Kembali',
                        style: const pw.TextStyle(
                          fontSize: 8, color: successColor)),
                      pw.Text(CurrencyFormatter.format(widget.change),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: successColor)),
                    ],
                  ),
                ],
              ]),
            ),

            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // Footer
            pw.Text('Terima kasih telah berbelanja!',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor),
              textAlign: pw.TextAlign.center),
            pw.Text('Simpan struk ini sebagai bukti pembelian',
              style: const pw.TextStyle(
                fontSize: 7, color: greyColor),
              textAlign: pw.TextAlign.center),
          ],
        );
      },
    ));

    return doc.save();
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'tunai':    return 'Tunai';
      case 'qris':     return 'QRIS';
      case 'transfer': return 'Transfer Bank';
      case 'hutang':   return 'Hutang';
      default:         return method;
    }
  }
}

// ─── Receipt Row ──────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ReceiptRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600)),
          Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AppColors.success : null,
            )),
        ],
      ),
    );
  }
}

// ─── Empty Cart ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
              size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('Keranjang Kosong',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
          const SizedBox(height: 8),
          Text('Cari produk di kotak pencarian di atas',
            style: TextStyle(
              color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Cari Produk'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
