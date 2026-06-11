import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../providers/kasir_provider.dart';

// ===========================================================================
// Layar utama Kasir / POS
// ===========================================================================
class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kasir = ref.watch(kasirProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context, kasir),
      body: Column(
        children: [
          // Tab: Produk | Keranjang
          _SearchAndTabs(
            tabController: _tabController,
            searchCtrl: _searchCtrl,
            totalItems: kasir.totalItems,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ProductGrid(),
                _CartView(),
              ],
            ),
          ),
        ],
      ),
      // Tombol checkout hanya muncul saat keranjang tidak kosong
      bottomNavigationBar: kasir.cartIsEmpty
          ? null
          : _CheckoutBar(kasirState: kasir),
    );
  }

  AppBar _buildAppBar(BuildContext context, KasirState kasir) {
    return AppBar(
      backgroundColor: AppColors.primary,
      title: const Text(
        'Kasir (POS)',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: [
        if (!kasir.cartIsEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: Colors.white),
            tooltip: 'Kosongkan keranjang',
            onPressed: () => _confirmClear(context),
          ),
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_outlined,
              color: Colors.white),
          tooltip: 'Pilih pelanggan',
          onPressed: () => _showCustomerDialog(context),
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Kosongkan Keranjang?'),
        content:
            const Text('Semua item di keranjang akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(kasirProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerPicker(),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar + TabBar
// ---------------------------------------------------------------------------
class _SearchAndTabs extends ConsumerWidget {
  final TabController tabController;
  final TextEditingController searchCtrl;
  final int totalItems;

  const _SearchAndTabs({
    required this.tabController,
    required this.searchCtrl,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          // Search
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: (v) =>
                  ref.read(kasirProvider.notifier).setSearchQuery(v),
              decoration: const InputDecoration(
                hintText: 'Cari produk / scan barcode…',
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textHint),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          // TabBar
          TabBar(
            controller: tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              const Tab(text: 'Produk'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Keranjang'),
                    if (totalItems > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalItems',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid produk
// ---------------------------------------------------------------------------
class _ProductGrid extends ConsumerWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(kasirProvider).searchQuery;
    final productsAsync =
        ref.watch(kasirProductSearchProvider(query));

    return productsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary)),
      error: (e, _) =>
          Center(child: Text('Error: $e')),
      data: (products) {
        if (products.isEmpty) {
          return _emptyProducts(query);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) =>
              _ProductCard(product: products[i]),
        );
      },
    );
  }

  Widget _emptyProducts(String query) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Belum ada produk'
                  : 'Produk "$query" tidak ditemukan',
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Kartu produk
// ---------------------------------------------------------------------------
class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(kasirProvider).cart;
    final inCart = cart.firstWhereOrNull(
        (i) => i.product.id == product.id);
    final isLowStock = product.stock <= product.minStock;

    return GestureDetector(
      onTap: () {
        if (product.stock <= 0) return;
        ref.read(kasirProvider.notifier).addProduct(product);
        HapticFeedback.lightImpact();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart != null
                ? AppColors.primary
                : AppColors.border,
            width: inCart != null ? 1.5 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikon produk
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(product.sellPrice),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isLowStock
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stok: ${product.stock}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isLowStock
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            // Badge qty di keranjang
            if (inCart != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${inCart.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Overlay stok habis
            if (product.stock <= 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Stok\nHabis',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tampilan keranjang
// ---------------------------------------------------------------------------
class _CartView extends ConsumerWidget {
  const _CartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kasir = ref.watch(kasirProvider);

    if (kasir.cartIsEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 72, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(
              'Keranjang masih kosong',
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambah produk dari tab Produk',
              style: TextStyle(
                  color: Colors.grey.shade300, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Pelanggan terpilih
        if (kasir.selectedCustomer != null)
          _CustomerChip(customer: kasir.selectedCustomer!),

        // List item keranjang
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: kasir.cart.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _CartItemTile(item: kasir.cart[i]),
          ),
        ),

        // Ringkasan harga
        _PriceSummary(kasirState: kasir),
      ],
    );
  }
}

class _CustomerChip extends ConsumerWidget {
  final Customer customer;
  const _CustomerChip({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.person_outline,
            color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            customer.name,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        GestureDetector(
          onTap: () =>
              ref.read(kasirProvider.notifier).setCustomer(null),
          child: const Icon(Icons.close,
              color: AppColors.primary, size: 16),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile item di keranjang
// ---------------------------------------------------------------------------
class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kasirProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Ikon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              // Nama + harga
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      CurrencyFormatter.format(
                          item.product.sellPrice),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Hapus
              GestureDetector(
                onTap: () => notifier
                    .removeProduct(item.product.id),
                child: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Diskon item
              GestureDetector(
                onTap: () =>
                    _showItemDiscountDialog(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.discount > 0
                        ? AppColors.warning.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.discount > 0
                          ? AppColors.warning
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    item.discount > 0
                        ? '- ${CurrencyFormatter.format(item.discount)}'
                        : '+ Diskon',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.discount > 0
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Kontrol qty
              Row(children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () => notifier.updateQuantity(
                      item.product.id, item.quantity - 1),
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () => notifier.updateQuantity(
                      item.product.id, item.quantity + 1),
                ),
              ]),
              // Subtotal
              Text(
                CurrencyFormatter.format(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemDiscountDialog(
      BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: item.discount > 0
            ? item.discount.toStringAsFixed(0)
            : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Diskon Item'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ],
          decoration: const InputDecoration(
            labelText: 'Nominal diskon (Rp)',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val =
                  double.tryParse(ctrl.text) ?? 0;
              ref
                  .read(kasirProvider.notifier)
                  .updateItemDiscount(item.product.id, val);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ringkasan harga di bawah keranjang
// ---------------------------------------------------------------------------
class _PriceSummary extends ConsumerWidget {
  final KasirState kasirState;
  const _PriceSummary({required this.kasirState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _PriceRow('Subtotal',
              CurrencyFormatter.format(kasirState.subtotal)),
          if (kasirState.discountGlobal > 0) ...[
            const SizedBox(height: 4),
            _PriceRow(
              'Diskon',
              '- ${CurrencyFormatter.format(kasirState.discountGlobal)}',
              color: AppColors.danger,
            ),
          ],
          const SizedBox(height: 4),
          // Input diskon global
          GestureDetector(
            onTap: () => _showGlobalDiscountDialog(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kasirState.discountGlobal > 0
                    ? AppColors.warning.withOpacity(0.08)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kasirState.discountGlobal > 0
                      ? AppColors.warning
                      : AppColors.border,
                ),
              ),
              child: Row(children: [
                Icon(
                  Icons.discount_outlined,
                  size: 14,
                  color: kasirState.discountGlobal > 0
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  kasirState.discountGlobal > 0
                      ? 'Edit diskon keseluruhan'
                      : 'Tambah diskon keseluruhan',
                  style: TextStyle(
                    fontSize: 12,
                    color: kasirState.discountGlobal > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ]),
            ),
          ),
          const Divider(height: 16),
          _PriceRow(
            'TOTAL',
            CurrencyFormatter.format(kasirState.total),
            isBold: true,
            color: AppColors.primary,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  void _showGlobalDiscountDialog(
      BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: kasirState.discountGlobal > 0
            ? kasirState.discountGlobal.toStringAsFixed(0)
            : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Diskon Keseluruhan'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ],
          decoration: const InputDecoration(
            labelText: 'Nominal diskon (Rp)',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          if (kasirState.discountGlobal > 0)
            TextButton(
              onPressed: () {
                ref
                    .read(kasirProvider.notifier)
                    .setDiscountGlobal(0);
                Navigator.pop(context);
              },
              child: const Text('Hapus Diskon',
                  style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val =
                  double.tryParse(ctrl.text) ?? 0;
              ref
                  .read(kasirProvider.notifier)
                  .setDiscountGlobal(val);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? color;
  final double fontSize;

  const _PriceRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.color,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight:
                  isBold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.textSecondary,
            )),
        Text(value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight:
                  isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bar checkout di bagian bawah
// ---------------------------------------------------------------------------
class _CheckoutBar extends ConsumerWidget {
  final KasirState kasirState;
  const _CheckoutBar({required this.kasirState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(children: [
        // Metode bayar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormatter.format(kasirState.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${kasirState.totalItems} item',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Tombol bayar
        ElevatedButton.icon(
          onPressed: kasirState.isProcessing
              ? null
              : () => _showPaymentDialog(context, ref),
          icon: kasirState.isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.payment_rounded),
          label: Text(
              kasirState.isProcessing ? 'Memproses…' : 'Bayar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(kasirState: kasirState),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet pembayaran
// ---------------------------------------------------------------------------
class _PaymentSheet extends ConsumerStatefulWidget {
  final KasirState kasirState;
  const _PaymentSheet({required this.kasirState});

  @override
  ConsumerState<_PaymentSheet> createState() =>
      _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _paidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paidCtrl.text =
        widget.kasirState.total.toStringAsFixed(0);
    ref
        .read(kasirProvider.notifier)
        .setAmountPaid(widget.kasirState.total);
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kasir = ref.watch(kasirProvider);
    final notifier = ref.read(kasirProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Proses Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Tagihan',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  Text(
                    CurrencyFormatter.format(kasir.total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metode pembayaran
            const Text('Metode Pembayaran',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: AppConstants.paymentMethods
                  .map((m) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3),
                          child: _PayMethodChip(
                            method: m,
                            selected:
                                kasir.paymentMethod == m,
                            onTap: () => notifier
                                .setPaymentMethod(m),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Jumlah dibayar (hanya untuk tunai)
            if (kasir.paymentMethod == 'tunai') ...[
              const Text('Jumlah Dibayar',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _paidCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: (v) {
                  final val = double.tryParse(v) ?? 0;
                  notifier.setAmountPaid(val);
                },
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 8),
              // Uang kembalian
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kasir.change >= 0
                      ? AppColors.success.withOpacity(0.08)
                      : AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: kasir.change >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      kasir.change >= 0
                          ? 'Kembalian'
                          : 'Kurang',
                      style: TextStyle(
                        color: kasir.change >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(kasir.change),
                      style: TextStyle(
                        color: kasir.change >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Tombol uang pas dan kelipatan
              Wrap(
                spacing: 8,
                children: _quickAmounts(kasir.total)
                    .map(
                      (a) => ActionChip(
                        label: Text(
                          CurrencyFormatter.formatCompact(a),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          _paidCtrl.text =
                              a.toStringAsFixed(0);
                          notifier.setAmountPaid(a);
                        },
                        backgroundColor:
                            AppColors.primaryLight,
                        side: const BorderSide(
                            color: AppColors.primary),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),

            // Tombol proses
            ElevatedButton(
              onPressed: (kasir.isProcessing ||
                      (kasir.paymentMethod == 'tunai' &&
                          kasir.amountPaid < kasir.total))
                  ? null
                  : () => _process(context),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                kasir.isProcessing
                    ? 'Memproses…'
                    : 'Proses Transaksi',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _quickAmounts(double total) {
    final base = (total / 1000).ceil() * 1000;
    return [
      total,
      base.toDouble(),
      (base + 10000).toDouble(),
      (base + 50000).toDouble(),
    ].toSet().toList()
      ..sort();
  }

  Future<void> _process(BuildContext context) async {
    try {
      final invoice = await ref
          .read(kasirProvider.notifier)
          .processTransaction();
      if (!mounted) return;
      Navigator.pop(context); // tutup sheet pembayaran
      _showReceiptDialog(context, invoice ?? '');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showReceiptDialog(
      BuildContext context, String invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptDialog(
        invoice: invoice,
        kasirState: widget.kasirState,
      ),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String method;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (method) {
      case 'tunai':
        return Icons.payments_outlined;
      case 'qris':
        return Icons.qr_code_rounded;
      case 'transfer':
        return Icons.account_balance_outlined;
      case 'hutang':
        return Icons.receipt_long_outlined;
      default:
        return Icons.payment;
    }
  }

  String get _label {
    switch (method) {
      case 'tunai':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'hutang':
        return 'Hutang';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 18,
              color:
                  selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              _label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog struk setelah transaksi berhasil
// ---------------------------------------------------------------------------
class _ReceiptDialog extends ConsumerWidget {
  final String invoice;
  final KasirState kasirState;

  const _ReceiptDialog({
    required this.invoice,
    required this.kasirState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header sukses
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.success,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 56),
              const SizedBox(height: 8),
              const Text(
                'Transaksi Berhasil!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                invoice,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),
          // Ringkasan
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _ReceiptRow('Total',
                  CurrencyFormatter.format(kasirState.total)),
              _ReceiptRow('Dibayar',
                  CurrencyFormatter.format(kasirState.amountPaid)),
              if (kasirState.change > 0)
                _ReceiptRow(
                    'Kembalian',
                    CurrencyFormatter.format(kasirState.change),
                    bold: true),
              _ReceiptRow('Metode',
                  _payLabel(kasirState.paymentMethod)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(kasirProvider.notifier)
                          .resetAfterTransaction();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(kasirProvider.notifier)
                          .resetAfterTransaction();
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak'),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  String _payLabel(String method) {
    const map = {
      'tunai': 'Tunai',
      'qris': 'QRIS',
      'transfer': 'Transfer Bank',
      'hutang': 'Hutang',
    };
    return map[method] ?? method;
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _ReceiptRow(this.label, this.value,
      {this.bold = false});

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
                color: AppColors.textSecondary,
                fontWeight: bold
                    ? FontWeight.w700
                    : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: bold
                    ? AppColors.success
                    : AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog pilih pelanggan
// ---------------------------------------------------------------------------
class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker();

  @override
  ConsumerState<_CustomerPicker> createState() =>
      _CustomerPickerState();
}

class _CustomerPickerState
    extends ConsumerState<_CustomerPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(kasirCustomerListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih Pelanggan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Cari pelanggan…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          // Tanpa pelanggan
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_off_outlined,
                  color: AppColors.primary),
            ),
            title: const Text('Tanpa Pelanggan'),
            onTap: () {
              ref.read(kasirProvider.notifier).setCustomer(null);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary)),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers
                        .where((c) =>
                            c.name.toLowerCase().contains(
                                _query.toLowerCase()) ||
                            (c.phone?.contains(_query) ??
                                false))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('Pelanggan tidak ditemukan'));
                }

                return ListView.builder(
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
                      title: Text(c.name),
                      subtitle: c.phone != null
                          ? Text(c.phone!)
                          : null,
                      onTap: () {
                        ref
                            .read(kasirProvider.notifier)
                            .setCustomer(c);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extension helper
// ---------------------------------------------------------------------------
extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

