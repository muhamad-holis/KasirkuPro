import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/kasir_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';

class KasirScreen extends ConsumerWidget {
  const KasirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(kasirProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir',
          style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!cart.isEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.danger, size: 18),
              label: const Text('Hapus',
                style: TextStyle(color: AppColors.danger, fontSize: 13)),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(),
          // Product search results
          _ProductResults(),
          const Divider(height: 1),
          // Cart
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : _CartList(cart: cart),
          ),
          if (!cart.isEmpty) _CheckoutPanel(cart: cart),
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
}

class _SearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
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
            onPressed: () {},
            tooltip: 'Scan Barcode',
          ),
        ),
      ]),
    );
  }
}

class _ProductResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productSearchProvider);
    if (query.isEmpty) return const SizedBox();

    final results = ref.watch(filteredProductsProvider);
    return results.when(
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Produk tidak ditemukan',
              style: TextStyle(color: Colors.grey)),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          color: Colors.white,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                dense: true,
                title: Text(p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(CurrencyFormatter.format(p.sellPrice),
                  style: const TextStyle(
                    color: AppColors.primary, fontSize: 12)),
                trailing: Text('Stok: ${p.stock}',
                  style: TextStyle(
                    fontSize: 11,
                    color: p.stock > 0
                        ? Colors.grey.shade500
                        : AppColors.danger,
                  )),
                onTap: () {
                  if (p.stock > 0) {
                    ref.read(kasirProvider.notifier).addProduct(p);
                    ref.read(productSearchProvider.notifier).state = '';
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
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.format(item.product.sellPrice)} × ${item.quantity} = ${CurrencyFormatter.format(item.subtotal)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(children: [
                _QtyBtn(
                  icon: Icons.remove,
                  onTap: () => ref.read(kasirProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity - 1),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
                ),
                _QtyBtn(
                  icon: Icons.add,
                  onTap: () => ref.read(kasirProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity + 1),
                ),
              ]),
            ]),
          ),
        );
      },
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${cart.items.length} item',
                      style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                    Text(CurrencyFormatter.format(cart.total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      )),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Bayar'),
                  onPressed: () => _showPayment(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
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

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet();

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'tunai';
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(kasirProvider);
    final paid = double.tryParse(_amountCtrl.text) ?? 0;
    final change = paid - cart.total;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Pembayaran',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Total: ${CurrencyFormatter.format(cart.total)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 16),

          // Metode bayar
          const Text('Metode Pembayaran',
            style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['tunai', 'qris', 'transfer', 'hutang']
                .map((m) => ChoiceChip(
                  label: Text(m.toUpperCase(),
                    style: const TextStyle(fontSize: 12)),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _method == m ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                ))
                .toList(),
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
              ),
            ),
            const SizedBox(height: 10),
            // Nominal cepat
            Wrap(
              spacing: 8,
              children: _quickAmounts(cart.total)
                  .map((v) => ActionChip(
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
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(CurrencyFormatter.format(change),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

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
              onPressed: _loading ? null : _process,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<double> _quickAmounts(double total) {
    final base = [10000, 20000, 50000, 100000, 200000];
    final result = <double>[total];
    for (final v in base) {
      if (v >= total) result.add(v.toDouble());
      if (result.length >= 4) break;
    }
    return result.toSet().take(4).toList()..sort();
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

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final invoiceNumber =
          await db.transactionsDao.generateInvoiceNumber();
      final amountPaid = _method == 'tunai'
          ? (double.tryParse(_amountCtrl.text) ?? cart.total)
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
      );

      final items = cart.items.map((i) =>
        TransactionItemsCompanion.insert(
          transactionId: const Value(0),
          productId: Value(i.product.id),
          productName: i.product.name,
          price: Value(i.product.sellPrice),
          quantity: Value(i.quantity),
          discount: Value(i.discount),
          subtotal: Value(i.subtotal),
        )).toList();

      await db.transactionsDao.insertTransaction(tx, items);
      ref.read(kasirProvider.notifier).clear();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Transaksi berhasil!'),
            ]),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
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
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
            size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Keranjang Kosong',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
          const SizedBox(height: 6),
          Text('Cari produk di kotak pencarian',
            style: TextStyle(
              color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}
