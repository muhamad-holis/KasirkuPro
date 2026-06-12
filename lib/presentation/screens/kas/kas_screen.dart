// lib/presentation/screens/kas/kas_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Kas Masuk & Kas Keluar — P3
// Fitur: Daftar arus kas, Tambah kas masuk/keluar, Laporan Laba Rugi
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/kas_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN UTAMA KAS
// ─────────────────────────────────────────────────────────────────────────────

class KasScreen extends ConsumerStatefulWidget {
  const KasScreen({super.key});

  @override
  ConsumerState<KasScreen> createState() => _KasScreenState();
}

class _KasScreenState extends ConsumerState<KasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _period = '7d';

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

  DateTime get _start {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(
        kasSummaryProvider(DateRange(start: _start, end: DateTime.now())));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kas & Keuangan',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Catat Kas',
            onSelected: (type) => _showFormSheet(context, type),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'income',
                child: Row(children: [
                  Icon(Icons.arrow_downward_rounded,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text('Kas Masuk'),
                ]),
              ),
              const PopupMenuItem(
                value: 'expense',
                child: Row(children: [
                  Icon(Icons.arrow_upward_rounded,
                      color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text('Kas Keluar'),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Arus Kas'),
            Tab(text: 'Masuk'),
            Tab(text: 'Keluar'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Period filter ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _PeriodChip('Hari Ini', 'today', _period,
                    (v) => setState(() => _period = v)),
                _PeriodChip('7 Hari', '7d', _period,
                    (v) => setState(() => _period = v)),
                _PeriodChip('30 Hari', '30d', _period,
                    (v) => setState(() => _period = v)),
                _PeriodChip('Bulan Ini', 'month', _period,
                    (v) => setState(() => _period = v)),
              ],
            ),
          ),

          // ── Summary bar ───────────────────────────────────────────────────
          summary.when(
            data: (s) => _KasSummaryBar(summary: s),
            loading: () => const SizedBox(height: 72),
            error: (_, __) => const SizedBox(),
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ArusKasTab(start: _start, end: DateTime.now()),
                _KasListTab(
                    start: _start,
                    end: DateTime.now(),
                    type: 'income'),
                _KasListTab(
                    start: _start,
                    end: DateTime.now(),
                    type: 'expense'),
              ],
            ),
          ),
        ],
      ),
      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_keluar',
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            onPressed: () => _showFormSheet(context, 'expense'),
            tooltip: 'Kas Keluar',
            child: const Icon(Icons.arrow_upward_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'fab_masuk',
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            onPressed: () => _showFormSheet(context, 'income'),
            icon: const Icon(Icons.arrow_downward_rounded),
            label: const Text('Kas Masuk'),
          ),
        ],
      ),
    );
  }

  void _showFormSheet(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _KasFormSheet(initialType: type),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _KasSummaryBar extends StatelessWidget {
  final KasSummary summary;
  const _KasSummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _KasCard(
            label: 'Kas Masuk',
            value: CurrencyFormatter.format(summary.totalIncome),
            color: AppColors.success,
            icon: Icons.arrow_downward_rounded,
          ),
          const SizedBox(width: 8),
          _KasCard(
            label: 'Kas Keluar',
            value: CurrencyFormatter.format(summary.totalExpense),
            color: AppColors.danger,
            icon: Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 8),
          _KasCard(
            label: 'Saldo',
            value: CurrencyFormatter.format(summary.saldo),
            color:
                summary.saldo >= 0 ? AppColors.success : AppColors.danger,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _KasCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _KasCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARUS KAS TAB — Laba Rugi Sederhana
// ─────────────────────────────────────────────────────────────────────────────

class _ArusKasTab extends ConsumerWidget {
  final DateTime start, end;
  const _ArusKasTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labaAsync = ref.watch(
        labaRugiProvider(DateRange(start: start, end: end)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Laporan Laba Rugi ────────────────────────────────────────────
          labaAsync.when(
            data: (lr) => _LabaRugiCard(data: lr),
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 16),

          // ── Arus Kas Stream ───────────────────────────────────────────────
          StreamBuilder<List<CashFlow>>(
            stream: ref
                .read(databaseProvider)
                .reportsDao
                .watchCashFlows(start, end),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              final flows = snap.data!;
              if (flows.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Belum ada transaksi kas',
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Riwayat Kas',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  ...flows.map((f) => _CashFlowRow(flow: f)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAPORAN LABA RUGI CARD (P3)
// ─────────────────────────────────────────────────────────────────────────────

class _LabaRugiCard extends StatelessWidget {
  final LabaRugiData data;
  const _LabaRugiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Laporan Laba Rugi',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy', 'id')
                      .format(DateTime.now()),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Pendapatan
                _LabaRow(
                  label: 'Total Penjualan (Omzet)',
                  value: data.omzet,
                  color: AppColors.success,
                  bold: false,
                ),
                _LabaRow(
                  label: 'HPP (Harga Pokok Penjualan)',
                  value: -data.hpp,
                  color: AppColors.danger,
                  prefix: '- ',
                ),
                const Divider(height: 20),
                _LabaRow(
                  label: 'Laba Kotor',
                  value: data.labaKotor,
                  color: data.labaKotor >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  bold: true,
                ),
                const SizedBox(height: 8),

                // Biaya operasional
                _LabaRow(
                  label: 'Kas Masuk (Non-Penjualan)',
                  value: data.kasIncome,
                  color: AppColors.success,
                ),
                _LabaRow(
                  label: 'Kas Keluar (Biaya Operasional)',
                  value: -data.kasExpense,
                  color: AppColors.danger,
                  prefix: '- ',
                ),
                const Divider(height: 20),

                // Laba bersih
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (data.labaBersih >= 0
                            ? AppColors.success
                            : AppColors.danger)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('LABA BERSIH',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(
                            data.labaBersih.abs()),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: data.labaBersih >= 0
                                ? AppColors.success
                                : AppColors.danger),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                // Margin indicator
                _MarginIndicator(
                    margin: data.marginPersen,
                    omzet: data.omzet),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabaRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;
  final String prefix;

  const _LabaRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 13 : 12,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal,
                    color: bold
                        ? Colors.black87
                        : Colors.grey.shade700)),
          ),
          Text(
            '$prefix${CurrencyFormatter.format(value.abs())}',
            style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}

class _MarginIndicator extends StatelessWidget {
  final double margin, omzet;
  const _MarginIndicator({required this.margin, required this.omzet});

  @override
  Widget build(BuildContext context) {
    if (omzet == 0) return const SizedBox();
    final pct = margin.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Margin Laba Bersih: ',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
            Text('${margin.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: margin >= 20
                        ? AppColors.success
                        : margin >= 10
                            ? AppColors.warning
                            : AppColors.danger)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              margin >= 20
                  ? AppColors.success
                  : margin >= 10
                      ? AppColors.warning
                      : AppColors.danger,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KAS LIST TAB
// ─────────────────────────────────────────────────────────────────────────────

class _KasListTab extends ConsumerWidget {
  final DateTime start, end;
  final String type;
  const _KasListTab(
      {required this.start, required this.end, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<CashFlow>>(
      stream: ref
          .read(databaseProvider)
          .reportsDao
          .watchCashFlows(start, end),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final filtered = all.where((f) => f.type == type).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'income'
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 48,
                  color: (type == 'income'
                          ? AppColors.success
                          : AppColors.danger)
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  type == 'income'
                      ? 'Belum ada kas masuk'
                      : 'Belum ada kas keluar',
                  style:
                      TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _CashFlowRow(flow: filtered[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CASH FLOW ROW
// ─────────────────────────────────────────────────────────────────────────────

class _CashFlowRow extends StatelessWidget {
  final CashFlow flow;
  const _CashFlowRow({required this.flow});

  @override
  Widget build(BuildContext context) {
    final isIncome = flow.type == 'income';
    final color = isIncome ? AppColors.success : AppColors.danger;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 18,
            color: color,
          ),
        ),
        title: Text(
          _categoryLabel(flow.category),
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: flow.description != null && flow.description!.isNotEmpty
            ? Text(flow.description!,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis)
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(flow.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: color),
            ),
            Text(
              DateFormat('dd MMM, HH:mm', 'id').format(flow.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    const labels = {
      'penjualan': 'Penjualan',
      'pelunasan_hutang': 'Pelunasan Hutang',
      'modal': 'Modal',
      'lain': 'Lain-lain',
      'operasional': 'Biaya Operasional',
      'pembelian_stok': 'Pembelian Stok',
      'gaji': 'Gaji Karyawan',
      'sewa': 'Biaya Sewa',
      'listrik_air': 'Listrik & Air',
    };
    return labels[cat] ?? cat;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KAS FORM SHEET — Input Kas Masuk / Keluar
// ─────────────────────────────────────────────────────────────────────────────

class _KasFormSheet extends ConsumerStatefulWidget {
  final String initialType;
  const _KasFormSheet({required this.initialType});

  @override
  ConsumerState<_KasFormSheet> createState() => _KasFormSheetState();
}

class _KasFormSheetState extends ConsumerState<_KasFormSheet> {
  late String _type;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'operasional';
  bool _loading = false;

  static const _incomeCategories = {
    'penjualan': 'Penjualan',
    'pelunasan_hutang': 'Pelunasan Hutang',
    'modal': 'Tambah Modal',
    'lain': 'Lain-lain',
  };

  static const _expenseCategories = {
    'pembelian_stok': 'Pembelian Stok',
    'operasional': 'Biaya Operasional',
    'gaji': 'Gaji Karyawan',
    'sewa': 'Biaya Sewa',
    'listrik_air': 'Listrik & Air',
    'lain': 'Lain-lain',
  };

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = _type == 'income' ? 'penjualan' : 'operasional';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _categories =>
      _type == 'income' ? _incomeCategories : _expenseCategories;

  Future<void> _save() async {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masukkan jumlah kas')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(databaseProvider).reportsDao.addCashFlow(
            type: _type,
            category: _category,
            amount: amount,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_type == 'income' ? 'Kas masuk' : 'Kas keluar'} ${CurrencyFormatter.format(amount)} dicatat'),
            backgroundColor: _type == 'income'
                ? AppColors.success
                : AppColors.danger,
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
    final isIncome = _type == 'income';
    final color = isIncome ? AppColors.success : AppColors.danger;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    isIncome ? 'Catat Kas Masuk' : 'Catat Kas Keluar',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),

            // Type toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _type = 'income';
                      _category = 'penjualan';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'income'
                            ? AppColors.success
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward_rounded,
                              size: 16,
                              color: _type == 'income'
                                  ? Colors.white
                                  : Colors.grey),
                          const SizedBox(width: 4),
                          Text('Masuk',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _type == 'income'
                                      ? Colors.white
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _type = 'expense';
                      _category = 'operasional';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'expense'
                            ? AppColors.danger
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward_rounded,
                              size: 16,
                              color: _type == 'expense'
                                  ? Colors.white
                                  : Colors.grey),
                          const SizedBox(width: 4),
                          Text('Keluar',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _type == 'expense'
                                      ? Colors.white
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kategori
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),

            // Jumlah
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Jumlah',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Deskripsi
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Keterangan (opsional)',
                hintText: 'cth: Bayar tagihan listrik bulan Mei',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
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
                    : Text(
                        isIncome
                            ? 'Simpan Kas Masuk'
                            : 'Simpan Kas Keluar',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper
class _PeriodChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onChanged;
  const _PeriodChip(this.label, this.value, this.current,
      this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}
