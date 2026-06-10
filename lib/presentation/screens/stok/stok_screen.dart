import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';

class StokScreen extends ConsumerWidget {
  const StokScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok',
          style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Excel',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (v) =>
                  ref.read(productSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          // Stats bar
          products.when(
            data: (list) => _StatsBar(products: list),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          Expanded(
            child: products.when(
              data: (list) {
                final query = ref.watch(productSearchProvider);
                final filtered = query.isEmpty
                    ? list
                    : list.where((p) =>
                        p.name.toLowerCase().contains(query.toLowerCase()) ||
                        (p.barcode?.contains(query) ?? false)).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Belum ada produk'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) =>
                      _ProductCard(product: filtered[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProduct(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddProduct(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _AddProductSheet(),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<Product> products;
  const _StatsBar({required this.products});

  @override
  Widget build(BuildContext context) {
    final lowStock = products.where((p) => p.stock <= p.minStock).length;
    final outOfStock = products.where((p) => p.stock == 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(children: [
        _StatChip(
          label: '${products.length} Produk',
          color: AppColors.primary),
        const SizedBox(width: 8),
        _StatChip(
          label: '$lowStock Hampir Habis',
          color: AppColors.warning),
        const SizedBox(width: 8),
        _StatChip(
          label: '$outOfStock Habis',
          color: AppColors.danger),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.stock <= product.minStock && product.stock > 0;
    final isOut = product.stock == 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(CurrencyFormatter.format(product.sellPrice),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product.stock} ${product.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isOut
                        ? AppColors.danger
                        : isLow
                            ? AppColors.warning
                            : AppColors.success,
                  )),
                if (isOut)
                  const Text('Habis',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ))
                else if (isLow)
                  const Text('Hampir habis',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _EditProductSheet(product: product),
      ),
    );
  }
}

class _AddProductSheet extends ConsumerStatefulWidget {
  const _AddProductSheet();

  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  final _nameCtrl     = TextEditingController();
  final _barcodeCtrl  = TextEditingController();
  final _buyCtrl      = TextEditingController();
  final _sellCtrl     = TextEditingController();
  final _stockCtrl    = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _unitCtrl     = TextEditingController(text: 'pcs');
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _barcodeCtrl.dispose();
    _buyCtrl.dispose(); _sellCtrl.dispose();
    _stockCtrl.dispose(); _minStockCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20, left: 20, right: 20,
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
          const Text('Tambah Produk Baru',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Produk *',
              prefixIcon: Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _barcodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Barcode (opsional)',
              prefixIcon: Icon(Icons.qr_code)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _buyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Beli',
                  prefixText: 'Rp '),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _sellCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Jual *',
                  prefixText: 'Rp '),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok Awal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _minStockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok Minimum'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Satuan'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_loading ? 'Menyimpan...' : 'Simpan Produk'),
              onPressed: _loading ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _sellCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan harga jual wajib diisi'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      await db.productsDao.insertProduct(
        ProductsCompanion.insert(
          name: _nameCtrl.text.trim(),
          barcode: Value(_barcodeCtrl.text.isEmpty
              ? null : _barcodeCtrl.text),
          buyPrice: Value(double.tryParse(_buyCtrl.text) ?? 0),
          sellPrice: Value(double.tryParse(_sellCtrl.text) ?? 0),
          stock: Value(int.tryParse(_stockCtrl.text) ?? 0),
          minStock: Value(int.tryParse(_minStockCtrl.text) ?? 5),
          unit: Value(_unitCtrl.text.isEmpty ? 'pcs' : _unitCtrl.text),
        ),
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil ditambahkan'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EditProductSheet extends ConsumerStatefulWidget {
  final Product product;
  const _EditProductSheet({required this.product});

  @override
  ConsumerState<_EditProductSheet> createState() =>
      _EditProductSheetState();
}

class _EditProductSheetState
    extends ConsumerState<_EditProductSheet> {
  late final _nameCtrl =
      TextEditingController(text: widget.product.name);
  late final _sellCtrl = TextEditingController(
      text: widget.product.sellPrice.toStringAsFixed(0));
  late final _buyCtrl = TextEditingController(
      text: widget.product.buyPrice.toStringAsFixed(0));
  late final _stockCtrl =
      TextEditingController(text: '${widget.product.stock}');
  late final _minCtrl =
      TextEditingController(text: '${widget.product.minStock}');
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20, left: 20, right: 20,
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
          const Text('Edit Produk',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Produk'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _buyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Beli',
                  prefixText: 'Rp '),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _sellCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Jual',
                  prefixText: 'Rp '),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok Min'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger, size: 18),
                label: const Text('Hapus',
                  style: TextStyle(color: AppColors.danger)),
                onPressed: () => _delete(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
                onPressed: _loading ? null : _update,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      await db.productsDao.updateProduct(
        ProductsCompanion(
          id: Value(widget.product.id),
          name: Value(_nameCtrl.text.trim()),
          buyPrice: Value(double.tryParse(_buyCtrl.text) ?? 0),
          sellPrice: Value(double.tryParse(_sellCtrl.text) ?? 0),
          stock: Value(int.tryParse(_stockCtrl.text) ?? 0),
          minStock: Value(int.tryParse(_minCtrl.text) ?? 5),
        ),
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk diperbarui'),
            backgroundColor: AppColors.success));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('${widget.product.name} akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger),
            child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(databaseProvider)
          .productsDao.deleteProduct(widget.product.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
