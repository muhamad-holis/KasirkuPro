import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/customers_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen Utama
// ─────────────────────────────────────────────────────────────────────────────

class PelangganScreen extends ConsumerStatefulWidget {
  const PelangganScreen({super.key});

  @override
  ConsumerState<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends ConsumerState<PelangganScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredCustomersProvider);
    final stats    = ref.watch(customerStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Tambah Pelanggan',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(customerSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Cari nama, telepon, atau alamat...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(customerSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Stats bar ────────────────────────────────────────────────────────
          stats.when(
            data: (s) => _StatsBar(stats: s),
            loading: () => const SizedBox(height: 36),
            error: (_, __) => const SizedBox(),
          ),

          // ── List pelanggan ───────────────────────────────────────────────────
          Expanded(
            child: filtered.when(
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(
                    isSearching: _searchCtrl.text.isNotEmpty,
                    onAdd: () => _showAddSheet(context),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _CustomerCard(
                    customer: list[i],
                    onTap: () => _showDetail(context, list[i]),
                    onEdit: () => _showEditSheet(context, list[i]),
                    onDelete: () => _confirmDelete(context, list[i]),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah Pelanggan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ─── Buka sheet tambah ─────────────────────────────────────────────────────

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _CustomerFormSheet(),
      ),
    );
  }

  // ─── Buka sheet edit ───────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _CustomerFormSheet(customer: customer),
      ),
    );
  }

  // ─── Buka detail pelanggan ────────────────────────────────────────────────

  void _showDetail(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _CustomerDetailSheet(customer: customer),
      ),
    );
  }

  // ─── Konfirmasi hapus ──────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, Customer c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text('Data "${c.name}" akan dihapus permanen.'),
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

    if (confirm == true && context.mounted) {
      try {
        await ref.read(databaseProvider).customersDao
            .deleteCustomer(c.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pelanggan dihapus'),
              backgroundColor: AppColors.danger));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal hapus: $e'),
              backgroundColor: AppColors.danger));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(children: [
        _Chip(
          label: '${stats['total']} Pelanggan',
          icon: Icons.people_outline,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: '${stats['withPhone']} Punya No. HP',
          icon: Icons.phone_outlined,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: '${stats['withPoints']} Punya Poin',
          icon: Icons.stars_outlined,
          color: AppColors.warning,
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip({required this.label, required this.icon, required this.color});

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
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Card
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // ── Avatar inisial ──────────────────────────────────────────────
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  if (customer.phone != null &&
                      customer.phone!.isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(customer.phone!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  ] else
                    Text('Belum ada no. HP',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic)),
                  if (customer.address != null &&
                      customer.address!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(customer.address!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ],
              ),
            ),

            // ── Poin + aksi ───────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (customer.points > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.stars_rounded,
                          size: 12, color: AppColors.warning),
                      const SizedBox(width: 3),
                      Text('${customer.points} poin',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                    ]),
                  ),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.danger),
                    ),
                  ),
                ]),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onAdd;
  const _EmptyState({required this.isSearching, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'Pelanggan tidak ditemukan'
                : 'Belum ada pelanggan',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'Coba kata kunci lain'
                : 'Tambahkan pelanggan pertama Anda',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
          if (!isSearching) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Tambah Pelanggan'),
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Sheet — Tambah & Edit (satu widget, bisa keduanya)
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? customer; // null = tambah, non-null = edit

  const _CustomerFormSheet({this.customer});

  @override
  ConsumerState<_CustomerFormSheet> createState() =>
      _CustomerFormSheetState();
}

class _CustomerFormSheetState
    extends ConsumerState<_CustomerFormSheet> {
  late final _nameCtrl    = TextEditingController(
      text: widget.customer?.name ?? '');
  late final _phoneCtrl   = TextEditingController(
      text: widget.customer?.phone ?? '');
  late final _addressCtrl = TextEditingController(
      text: widget.customer?.address ?? '');
  late final _notesCtrl   = TextEditingController(
      text: widget.customer?.notes ?? '');
  late final _pointsCtrl  = TextEditingController(
      text: widget.customer != null
          ? '${widget.customer!.points}'
          : '0');

  bool _loading = false;
  bool get _isEdit => widget.customer != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20, left: 20, right: 20,
      ),
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

          // Judul
          Text(
            _isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _isEdit
                ? 'Ubah data pelanggan'
                : 'Isi data pelanggan baru',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Nama *
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Pelanggan *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),

          // No HP
          TextField(
            controller: _phoneCtrl,
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
            controller: _addressCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Alamat',
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          // Poin (hanya saat edit, supaya tidak disalahgunakan)
          if (_isEdit) ...[
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Poin Loyalitas',
                prefixIcon: Icon(Icons.stars_outlined),
                helperText: 'Atur poin secara manual jika diperlukan',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Catatan
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              prefixIcon: Icon(Icons.note_alt_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // Tombol simpan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_loading
                  ? 'Menyimpan...'
                  : _isEdit
                      ? 'Simpan Perubahan'
                      : 'Tambah Pelanggan'),
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama pelanggan wajib diisi'),
            backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);

      if (_isEdit) {
        // ── Update ────────────────────────────────────────────────────────────
        await db.customersDao.updateCustomer(
          CustomersCompanion(
            id:      Value(widget.customer!.id),
            name:    Value(_nameCtrl.text.trim()),
            phone:   Value(_phoneCtrl.text.isEmpty
                ? null : _phoneCtrl.text.trim()),
            address: Value(_addressCtrl.text.isEmpty
                ? null : _addressCtrl.text.trim()),
            notes:   Value(_notesCtrl.text.isEmpty
                ? null : _notesCtrl.text.trim()),
            points:  Value(int.tryParse(_pointsCtrl.text) ?? 0),
          ),
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Data pelanggan diperbarui'),
                backgroundColor: AppColors.success));
        }
      } else {
        // ── Insert ────────────────────────────────────────────────────────────
        await db.customersDao.insertCustomer(
          CustomersCompanion.insert(
            name:    _nameCtrl.text.trim(),
            phone:   Value(_phoneCtrl.text.isEmpty
                ? null : _phoneCtrl.text.trim()),
            address: Value(_addressCtrl.text.isEmpty
                ? null : _addressCtrl.text.trim()),
            notes:   Value(_notesCtrl.text.isEmpty
                ? null : _notesCtrl.text.trim()),
          ),
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Pelanggan berhasil ditambahkan'),
                backgroundColor: AppColors.success));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan: $e'),
              backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Sheet — lihat info lengkap + riwayat hutang
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerDetailSheet extends ConsumerWidget {
  final Customer customer;
  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header pelanggan ────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        if (customer.phone != null &&
                            customer.phone!.isNotEmpty)
                          Text(customer.phone!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (customer.points > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_rounded,
                              size: 18, color: AppColors.warning),
                          Text('${customer.points}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                  fontSize: 14)),
                          const Text('poin',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.warning)),
                        ],
                      ),
                    ),
                ]),
                const SizedBox(height: 20),

                // ── Info detail ─────────────────────────────────────────────
                _SectionTitle('Informasi'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Nomor HP',
                  value: customer.phone?.isNotEmpty == true
                      ? customer.phone!
                      : '-',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Alamat',
                  value: customer.address?.isNotEmpty == true
                      ? customer.address!
                      : '-',
                ),
                _InfoRow(
                  icon: Icons.note_alt_outlined,
                  label: 'Catatan',
                  value: customer.notes?.isNotEmpty == true
                      ? customer.notes!
                      : '-',
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bergabung',
                  value: _formatDate(customer.createdAt),
                ),
                const SizedBox(height: 20),

                // ── Hutang pelanggan ────────────────────────────────────────
                _SectionTitle('Riwayat Hutang'),
                const SizedBox(height: 8),
                _CustomerDebtsSection(customerId: customer.id),
                const SizedBox(height: 20),

                // ── Tombol aksi ─────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Hubungi'),
                      onPressed: customer.phone?.isNotEmpty == true
                          ? () => _callPhone(context, customer.phone!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Data'),
                      onPressed: () {
                        Navigator.pop(context);
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          () {
                            if (context.mounted) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24))),
                                builder: (_) => ProviderScope(
                                  parent: ProviderScope.containerOf(context),
                                  child: _CustomerFormSheet(
                                      customer: customer),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _callPhone(BuildContext context, String phone) {
    // Buka dialer — membutuhkan url_launcher jika ingin dial langsung.
    // Sementara copy nomor ke clipboard.
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('No. HP $phone disalin ke clipboard'),
          backgroundColor: AppColors.success));
  }
}

// ─── Hutang per pelanggan ─────────────────────────────────────────────────────

class _CustomerDebtsSection extends ConsumerWidget {
  final int customerId;
  const _CustomerDebtsSection({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Debt>>(
      future: ref.read(databaseProvider).debtsDao.getAllDebts().then(
          (all) => all.where((d) => d.customerId == customerId).toList()),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator()));
        }
        final debts = snap.data!;
        if (debts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              const Text('Tidak ada hutang',
                  style: TextStyle(color: AppColors.success,
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }

        // Hitung total
        final totalHutang = debts.fold<double>(
            0, (s, d) => s + d.amount);
        final totalLunas  = debts.fold<double>(
            0, (s, d) => s + d.paidAmount);
        final totalSisa   = totalHutang - totalLunas;

        return Column(children: [
          // Ringkasan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: totalSisa > 0
                  ? AppColors.danger.withOpacity(0.05)
                  : AppColors.success.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: totalSisa > 0
                    ? AppColors.danger.withOpacity(0.2)
                    : AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DebtStat('Total Hutang',
                    CurrencyFormatter.format(totalHutang),
                    AppColors.danger),
                _DebtStat('Sudah Bayar',
                    CurrencyFormatter.format(totalLunas),
                    AppColors.success),
                _DebtStat('Sisa',
                    CurrencyFormatter.format(totalSisa),
                    totalSisa > 0
                        ? AppColors.danger
                        : AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List hutang
          ...debts.map((d) => _DebtRow(debt: d)),
        ]);
      },
    );
  }
}

class _DebtStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DebtStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color)),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }
}

class _DebtRow extends StatelessWidget {
  final Debt debt;
  const _DebtRow({required this.debt});

  @override
  Widget build(BuildContext context) {
    final sisa   = debt.amount - debt.paidAmount;
    final isLunas = debt.status == 'paid';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isLunas ? AppColors.success : AppColors.danger)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isLunas
                ? Icons.check_circle_outline
                : Icons.receipt_long_outlined,
            size: 16,
            color: isLunas ? AppColors.success : AppColors.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CurrencyFormatter.format(debt.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                isLunas
                    ? 'Lunas'
                    : 'Sisa: ${CurrencyFormatter.format(sisa)}',
                style: TextStyle(
                    fontSize: 11,
                    color: isLunas
                        ? AppColors.success
                        : AppColors.danger)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(debt.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statusLabel(debt.status),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(debt.status))),
        ),
      ]),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid':    return 'Lunas';
      case 'partial': return 'Sebagian';
      default:        return 'Belum Bayar';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':    return AppColors.success;
      case 'partial': return AppColors.warning;
      default:        return AppColors.danger;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.3));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
