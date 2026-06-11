import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';

class StokScreen extends ConsumerStatefulWidget {
  const StokScreen({super.key});

  @override
  ConsumerState<StokScreen> createState() => _StokScreenState();
}

class _StokScreenState extends ConsumerState<StokScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok',
          style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Excel',
            onPressed: () => _importExcel(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Excel',
            onPressed: () => _exportExcel(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Hampir Habis'),
            Tab(text: 'Kategori'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ProductListTab(),
          _LowStockTab(),
          _CategoryTab(),
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

  // ─── Import Excel ──────────────────────────────────────────────────────────

  Future<void> _importExcel(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.single.path == null) return;

      final bytes = File(result.files.single.path!).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) return;

      int imported = 0;
      final db = ref.read(databaseProvider);

      // Skip header row (row 0)
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty) continue;

        final name = row[0]?.value?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final barcode  = row[1]?.value?.toString().trim();
        final sku      = row[2]?.value?.toString().trim();
        final buyPrice = double.tryParse(row[3]?.value?.toString() ?? '') ?? 0;
        final sellPrice= double.tryParse(row[4]?.value?.toString() ?? '') ?? 0;
        final stock    = int.tryParse(row[5]?.value?.toString() ?? '')    ?? 0;
        final minStock = int.tryParse(row[6]?.value?.toString() ?? '')    ?? 5;
        final unit     = row[7]?.value?.toString().trim() ?? 'pcs';

        await db.productsDao.insertProduct(
          ProductsCompanion.insert(
            name: name,
            barcode: Value(barcode?.isEmpty ?? true ? null : barcode),
            sku:     Value(sku?.isEmpty ?? true ? null : sku),
            buyPrice:  Value(buyPrice),
            sellPrice: Value(sellPrice),
            stock:     Value(stock),
            minStock:  Value(minStock),
            unit:      Value(unit),
          ),
        );
        imported++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$imported produk berhasil diimport'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal import: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ─── Export Excel ──────────────────────────────────────────────────────────

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final products = await db.productsDao.getAllProducts();

      final excel = Excel.createExcel();
      final sheet = excel['Produk'];

      // Header
      final headers = [
        'Nama Produk', 'Barcode', 'SKU',
        'Harga Beli', 'Harga Jual', 'Stok',
        'Stok Min', 'Satuan',
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Data
      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        final row = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(p.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(p.barcode ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(p.sku ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = DoubleCellValue(p.buyPrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = DoubleCellValue(p.sellPrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = IntCellValue(p.stock);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = IntCellValue(p.minStock);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(p.unit);
      }

      // Delete default sheet
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final filename =
          'produk_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.xlsx';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Data Produk KasirKu',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal export: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
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

// ─── Tab: Semua Produk ────────────────────────────────────────────────────────

class _ProductListTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredStokProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    return Column(
      children: [
        // Search bar
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

        // Category filter chips
        categories.when(
          data: (cats) => cats.isEmpty
              ? const SizedBox()
              : SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Semua'),
                          selected: selectedCat == null,
                          onSelected: (_) => ref
                              .read(selectedCategoryProvider.notifier)
                              .state = null,
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ),
                      ),
                      ...cats.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: selectedCat == c.id,
                          onSelected: (_) => ref
                              .read(selectedCategoryProvider.notifier)
                              .state = selectedCat == c.id ? null : c.id,
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ),
                      )),
                    ],
                  ),
                ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),

        // Stats
        filtered.when(
          data: (list) => _StatsBar(products: list),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),

        // Product list
        Expanded(
          child: filtered.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Belum ada produk',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) => _ProductCard(product: list[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ─── Tab: Hampir Habis ────────────────────────────────────────────────────────

class _LowStockTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low = ref.watch(lowStockProvider);
    return low.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                  size: 64, color: AppColors.success),
                const SizedBox(height: 12),
                const Text('Semua stok aman!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
                const SizedBox(height: 6),
                Text('Tidak ada produk yang hampir habis',
                  style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_outlined,
                  color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Text('${list.length} produk perlu restock',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning)),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) => _ProductCard(product: list[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── Tab: Kategori ────────────────────────────────────────────────────────────

class _CategoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return cats.when(
      data: (list) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _CategoryCard(category: list[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProducts = ref.watch(productsStreamProvider);
    final count = allProducts.when(
      data: (list) => list
          .where((p) => p.categoryId == category.id)
          .length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.category_outlined,
            color: AppColors.primary, size: 22),
        ),
        title: Text(category.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$count produk',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                color: AppColors.primary, size: 20),
              onPressed: () => _editCategory(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
              onPressed: count > 0
                  ? null
                  : () => _deleteCategory(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _editCategory(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(databaseProvider).categoriesDao
                  .updateCategory(CategoriesCompanion(
                    id: Value(category.id),
                    name: Value(ctrl.text.trim()),
                  ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan')),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus.'),
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
      await ref.read(databaseProvider).categoriesDao
          .deleteCategory(category.id);
    }
  }
}

// ─── Stats Bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final List<Product> products;
  const _StatsBar({required this.products});

  @override
  Widget build(BuildContext context) {
    final total    = products.length;
    final lowStock = products.where((p) =>
        p.stock <= p.minStock && p.stock > 0).length;
    final outStock = products.where((p) => p.stock == 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: [
        _StatChip(
          label: '$total Produk',
          color: AppColors.primary,
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: '$lowStock Hampir Habis',
          color: AppColors.warning,
          icon: Icons.warning_amber_outlined,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: '$outStock Habis',
          color: AppColors.danger,
          icon: Icons.remove_circle_outline,
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color)),
      ]),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = product.stock == 0;
    final isLow = product.stock <= product.minStock && !isOut;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
          child: Row(children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isOut
                    ? Colors.grey.shade100
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 22,
                color: isOut
                    ? Colors.grey.shade400
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(CurrencyFormatter.format(product.sellPrice),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
                  if (product.barcode != null &&
                      product.barcode!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(product.barcode!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400)),
                  ],
                ],
              ),
            ),

            // Stock badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOut
                        ? AppColors.danger.withOpacity(0.1)
                        : isLow
                            ? AppColors.warning.withOpacity(0.1)
                            : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${product.stock} ${product.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isOut
                          ? AppColors.danger
                          : isLow
                              ? AppColors.warning
                              : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOut ? 'Habis' : isLow ? 'Hampir habis' : 'Aman',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOut
                        ? AppColors.danger
                        : isLow
                            ? AppColors.warning
                            : Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

// ─── Add Product Sheet ────────────────────────────────────────────────────────

class _AddProductSheet extends ConsumerStatefulWidget {
  const _AddProductSheet();

  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  final _nameCtrl     = TextEditingController();
  final _barcodeCtrl  = TextEditingController();
  final _skuCtrl      = TextEditingController();
  final _buyCtrl      = TextEditingController();
  final _sellCtrl     = TextEditingController();
  final _stockCtrl    = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _unitCtrl     = TextEditingController(text: 'pcs');
  int? _selectedCategoryId;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _barcodeCtrl, _skuCtrl,
        _buyCtrl, _sellCtrl, _stockCtrl, _minStockCtrl, _unitCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          const Text('Tambah Produk Baru',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Produk *',
              prefixIcon: Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: Icon(Icons.qr_code)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _skuCtrl,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  prefixIcon: Icon(Icons.tag)),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Category dropdown
          categories.when(
            data: (cats) => DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_outlined)),
              items: [
                const DropdownMenuItem(
                  value: null, child: Text('-- Tanpa Kategori --')),
                ...cats.map((c) => DropdownMenuItem(
                  value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) =>
                  setState(() => _selectedCategoryId = v),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _buyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Stok Awal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _minStockCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Stok Min'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(labelText: 'Satuan'),
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
      final stock = int.tryParse(_stockCtrl.text) ?? 0;
      final productId = await db.productsDao.insertProduct(
        ProductsCompanion.insert(
          name: _nameCtrl.text.trim(),
          barcode: Value(_barcodeCtrl.text.isEmpty
              ? null : _barcodeCtrl.text),
          sku: Value(_skuCtrl.text.isEmpty ? null : _skuCtrl.text),
          categoryId: Value(_selectedCategoryId),
          buyPrice:  Value(double.tryParse(_buyCtrl.text) ?? 0),
          sellPrice: Value(double.tryParse(_sellCtrl.text) ?? 0),
          stock:    Value(stock),
          minStock: Value(int.tryParse(_minStockCtrl.text) ?? 5),
          unit: Value(_unitCtrl.text.isEmpty ? 'pcs' : _unitCtrl.text),
        ),
      );
      // Record initial stock movement
      if (stock > 0) {
        await db.stockMovementsDao.addMovement(
          productId: productId,
          type: 'masuk',
          quantity: stock,
          stockBefore: 0,
          stockAfter: stock,
          notes: 'Stok awal',
        );
      }
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

// ─── Edit Product Sheet ───────────────────────────────────────────────────────

class _EditProductSheet extends ConsumerStatefulWidget {
  final Product product;
  const _EditProductSheet({required this.product});

  @override
  ConsumerState<_EditProductSheet> createState() =>
      _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<_EditProductSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final _nameCtrl  = TextEditingController(text: widget.product.name);
  late final _sellCtrl  = TextEditingController(
      text: widget.product.sellPrice.toStringAsFixed(0));
  late final _buyCtrl   = TextEditingController(
      text: widget.product.buyPrice.toStringAsFixed(0));
  late final _stockCtrl = TextEditingController(
      text: '${widget.product.stock}');
  late final _minCtrl   = TextEditingController(
      text: '${widget.product.minStock}');
  late final _barcodeCtrl = TextEditingController(
      text: widget.product.barcode ?? '');
  late final _adjQtyCtrl  = TextEditingController();
  late final _adjNoteCtrl = TextEditingController();
  int? _selectedCategoryId;
  String _adjType = 'masuk';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _selectedCategoryId = widget.product.categoryId;
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [_nameCtrl, _sellCtrl, _buyCtrl,
        _stockCtrl, _minCtrl, _barcodeCtrl,
        _adjQtyCtrl, _adjNoteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final movements = ref.watch(
        stockMovementsProvider(widget.product.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHandle(),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                          style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        Text(CurrencyFormatter.format(
                          widget.product.sellPrice),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.product.stock == 0
                          ? AppColors.danger.withOpacity(0.1)
                          : widget.product.stock <= widget.product.minStock
                              ? AppColors.warning.withOpacity(0.1)
                              : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Stok: ${widget.product.stock} ${widget.product.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: widget.product.stock == 0
                            ? AppColors.danger
                            : widget.product.stock <= widget.product.minStock
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Edit Produk'),
                    Tab(text: 'Riwayat Stok'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── Edit form ──────────────────────────────────
                SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Produk'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          prefixIcon: Icon(Icons.qr_code)),
                      ),
                      const SizedBox(height: 10),
                      categories.when(
                        data: (cats) =>
                            DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            prefixIcon: Icon(Icons.category_outlined)),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('-- Tanpa Kategori --')),
                            ...cats.map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCategoryId = v),
                        ),
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _buyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly],
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly],
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
                            controller: _minCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Stok Minimum'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Adjustment stok
                      const Text('Penyesuaian Stok',
                        style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: _buildAdjTypeChip('masuk', 'Masuk',
                            Icons.add_circle_outline, AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAdjTypeChip('keluar', 'Keluar',
                            Icons.remove_circle_outline, AppColors.danger),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAdjTypeChip('koreksi', 'Koreksi',
                            Icons.edit_outlined, AppColors.info),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _adjQtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: _adjType == 'koreksi'
                                  ? 'Stok Baru'
                                  : 'Jumlah',
                              prefixIcon: Icon(
                                _adjType == 'masuk'
                                    ? Icons.add
                                    : _adjType == 'keluar'
                                        ? Icons.remove
                                        : Icons.edit,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _adjNoteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Keterangan',
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
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
                            onPressed: () => _delete(context)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _loading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(_loading ? 'Menyimpan...' : 'Simpan'),
                            onPressed: _loading ? null : _update),
                        ),
                      ]),
                    ],
                  ),
                ),

                // ── Riwayat stok ──────────────────────────────
                movements.when(
                  data: (list) => list.isEmpty
                      ? const Center(
                          child: Text('Belum ada riwayat stok'))
                      : ListView.separated(
                          controller: ctrl,
                          padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 20),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (_, i) =>
                              _MovementCard(movement: list[i]),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjTypeChip(
      String value, String label, IconData icon, Color color) {
    final isSelected = _adjType == value;
    return GestureDetector(
      onTap: () => setState(() => _adjType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Column(children: [
          Icon(icon, size: 16,
            color: isSelected ? color : Colors.grey.shade500),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? color : Colors.grey.shade500,
            )),
        ]),
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final adjQty = int.tryParse(_adjQtyCtrl.text) ?? 0;

      await db.productsDao.updateProduct(
        ProductsCompanion(
          id: Value(widget.product.id),
          name: Value(_nameCtrl.text.trim()),
          barcode: Value(_barcodeCtrl.text.isEmpty
              ? null : _barcodeCtrl.text),
          categoryId: Value(_selectedCategoryId),
          buyPrice:  Value(double.tryParse(_buyCtrl.text) ?? 0),
          sellPrice: Value(double.tryParse(_sellCtrl.text) ?? 0),
          minStock:  Value(int.tryParse(_minCtrl.text) ?? 5),
        ),
      );

      // Apply stock adjustment
      if (adjQty > 0) {
        final oldStock = widget.product.stock;
        int newStock;
        if (_adjType == 'masuk') {
          newStock = oldStock + adjQty;
        } else if (_adjType == 'keluar') {
          newStock = (oldStock - adjQty).clamp(0, 999999);
        } else {
          newStock = adjQty; // koreksi = set langsung
        }
        await db.stockMovementsDao.adjustStock(
          db: db,
          productId: widget.product.id,
          newStock: newStock,
          oldStock: oldStock,
          type: _adjType,
          notes: _adjNoteCtrl.text.isEmpty ? null : _adjNoteCtrl.text,
        );
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk diperbarui'),
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

// ─── Movement Card ────────────────────────────────────────────────────────────

class _MovementCard extends StatelessWidget {
  final StockMovement movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isMasuk   = movement.type == 'masuk';
    final isKeluar  = movement.type == 'keluar';
    final color = isMasuk
        ? AppColors.success
        : isKeluar
            ? AppColors.danger
            : AppColors.info;
    final icon = isMasuk
        ? Icons.add_circle_outline
        : isKeluar
            ? Icons.remove_circle_outline
            : Icons.edit_outlined;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${movement.type.toUpperCase()} ${movement.quantity} unit',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
                if (movement.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(movement.notes!,
                    style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
                ],
                const SizedBox(height: 2),
                Text(
                  _formatDate(movement.createdAt),
                  style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${movement.stockBefore} → ${movement.stockAfter}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
              Text('unit', style: TextStyle(
                fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}
