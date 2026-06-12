// lib/presentation/screens/stok/stok_screen.dart — PATCH untuk Manajemen Kategori
// ─────────────────────────────────────────────────────────────────────────────
// PATCH P2: Tambahkan komponen berikut ke stok_screen.dart yang ada.
// Cari komentar "─── Tab: Kategori ───" dan ganti _KategoriTab + _CategoryCard
// dengan versi lengkap di bawah ini.
// ─────────────────────────────────────────────────────────────────────────────

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STEP 1: Tambahkan FAB di StokScreen build() untuk Tab Kategori
// Di dalam _StokScreenState.build(), tambahkan floatingActionButton conditional:
//
//   floatingActionButton: _tab.index == 2 ? _buildKategoriFAB() : _buildProdukFAB(),
//
// Tambahkan method _buildKategoriFAB():
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// COPY seluruh kelas berikut ke stok_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/products_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TAB KATEGORI LENGKAP (P2)
// Ganti class _CategoryTab yang lama dengan ini
// ─────────────────────────────────────────────────────────────────────────────

class KategoriTabFull extends ConsumerWidget {
  const KategoriTabFull({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Stack(
      children: [
        catsAsync.when(
          data: (cats) {
            if (cats.isEmpty) {
              return _KategoriEmptyState(
                onAdd: () => _showAddSheet(context, ref),
              );
            }
            return productsAsync.when(
              data: (products) => ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: cats.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) => _CategoryCardFull(
                  category: cats[i],
                  productCount: products
                      .where((p) => p.categoryId == cats[i].id)
                      .length,
                ),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Error: $e')),
        ),
        // FAB Tambah Kategori
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_kategori',
            onPressed: () => _showAddSheet(context, ref),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _CategoryFormSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CARD LENGKAP
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCardFull extends ConsumerWidget {
  final Category category;
  final int productCount;

  const _CategoryCardFull({
    required this.category,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _iconFromName(category.icon ?? category.name);
    final colorData = _colorFromName(category.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorData.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: colorData, size: 22),
        ),
        title: Text(category.name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          '$productCount produk',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: Colors.grey.shade600),
              onPressed: () => _showEditSheet(context, ref),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.danger),
              onPressed: productCount > 0
                  ? () => _showCannotDelete(context)
                  : () => _confirmDelete(context, ref),
              tooltip:
                  productCount > 0 ? 'Ada produk' : 'Hapus',
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('makanan') || n.contains('food')) {
      return Icons.fastfood_outlined;
    }
    if (n.contains('minum') || n.contains('drink') ||
        n.contains('beverage')) {
      return Icons.local_drink_outlined;
    }
    if (n.contains('snack') || n.contains('camilan')) {
      return Icons.cookie_outlined;
    }
    if (n.contains('rokok') || n.contains('tembakau')) {
      return Icons.smoking_rooms_outlined;
    }
    if (n.contains('sembako') || n.contains('bahan pokok')) {
      return Icons.shopping_basket_outlined;
    }
    if (n.contains('bersih') || n.contains('sabun') ||
        n.contains('deterjen')) {
      return Icons.cleaning_services_outlined;
    }
    if (n.contains('sehat') || n.contains('obat') ||
        n.contains('vitamin')) {
      return Icons.medical_services_outlined;
    }
    if (n.contains('elektronik') || n.contains('gadget')) {
      return Icons.devices_outlined;
    }
    if (n.contains('pakaian') || n.contains('baju')) {
      return Icons.checkroom_outlined;
    }
    return Icons.category_outlined;
  }

  Color _colorFromName(String name) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.danger,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _CategoryFormSheet(category: category),
      ),
    );
  }

  void _showCannotDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tidak Bisa Dihapus'),
        content: Text(
          'Kategori "${category.name}" masih memiliki $productCount produk. '
          'Pindahkan atau hapus semua produk terlebih dahulu.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () async {
              await ref
                  .read(databaseProvider)
                  .categoriesDao
                  .deleteCategory(category.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY FORM SHEET — Tambah & Edit
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? category;
  const _CategoryFormSheet({this.category});

  @override
  ConsumerState<_CategoryFormSheet> createState() =>
      _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  late final TextEditingController _nameCtrl;
  String _selectedIcon = 'category';
  bool _loading = false;

  bool get _isEdit => widget.category != null;

  final _icons = <String, IconData>{
    'category': Icons.category_outlined,
    'fastfood': Icons.fastfood_outlined,
    'drink': Icons.local_drink_outlined,
    'snack': Icons.cookie_outlined,
    'smoke': Icons.smoking_rooms_outlined,
    'basket': Icons.shopping_basket_outlined,
    'clean': Icons.cleaning_services_outlined,
    'health': Icons.medical_services_outlined,
    'devices': Icons.devices_outlined,
    'clothes': Icons.checkroom_outlined,
    'home': Icons.home_outlined,
    'star': Icons.star_outline_rounded,
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.icon ?? 'category';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama kategori wajib diisi')));
      return;
    }

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      if (_isEdit) {
        await db.categoriesDao.updateCategory(
          CategoriesCompanion(
            id: Value(widget.category!.id),
            name: Value(name),
            icon: Value(_selectedIcon),
          ),
        );
      } else {
        await db.categoriesDao.insertCategory(
          CategoriesCompanion.insert(
            name: name,
            icon: Value(_selectedIcon),
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEdit ? 'Kategori diperbarui' : 'Kategori ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),

            // Nama
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                hintText: 'cth: Minuman Dingin',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Ikon selector
            const Text('Pilih Ikon',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.entries.map((e) {
                final isSelected = _selectedIcon == e.key;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIcon = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent),
                    ),
                    child: Icon(e.value,
                        size: 22,
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade600),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Kategori',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _KategoriEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _KategoriEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Belum ada kategori',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Buat kategori untuk mengelompokkan produk Anda',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
