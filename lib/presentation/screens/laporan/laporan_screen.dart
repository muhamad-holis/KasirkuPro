import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/database_provider.dart';

class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen>
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
      case 'today': return DateTime(now.year, now.month, now.day);
      case '7d':    return now.subtract(const Duration(days: 7));
      case '30d':   return now.subtract(const Duration(days: 30));
      default:      return DateTime(now.year, now.month, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan',
          style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Penjualan'),
            Tab(text: 'Kas'),
            Tab(text: 'Stok'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter periode
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _Chip('Hari Ini', 'today', _period,
                  (v) => setState(() => _period = v)),
                _Chip('7 Hari', '7d', _period,
                  (v) => setState(() => _period = v)),
                _Chip('30 Hari', '30d', _period,
                  (v) => setState(() => _period = v)),
                _Chip('Bulan Ini', 'month', _period,
                  (v) => setState(() => _period = v)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SalesTab(start: _start, end: DateTime.now()),
                _CashTab(start: _start, end: DateTime.now()),
                const _StockTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _Chip(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sel ? Colors.white : null,
          )),
        selected: sel,
        onSelected: (_) => onTap(value),
        selectedColor: AppColors.primary,
      ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  final DateTime start, end;
  const _SalesTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(databaseProvider)
          .reportsDao.getDailySalesChart(start, end),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final omzet = data.fold<double>(
          0, (s, r) => s + (r['omzet'] as num));
        final count = data.fold<int>(
          0, (s, r) => s + (r['jumlah'] as int));
        final avg = count > 0 ? omzet / count : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary cards
              Row(children: [
                Expanded(child: _InfoCard(
                  title: 'Total Omzet',
                  value: CurrencyFormatter.formatCompact(omzet),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                )),
                const SizedBox(width: 10),
                Expanded(child: _InfoCard(
                  title: 'Transaksi',
                  value: '$count',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                )),
              ]),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Rata-rata per Transaksi',
                value: CurrencyFormatter.format(avg.toDouble()),
                icon: Icons.analytics_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(height: 20),

              if (data.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Grafik Penjualan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: BarChart(BarChartData(
                    barGroups: data.asMap().entries.map((e) =>
                      BarChartGroupData(
                        x: e.key,
                        barRods: [BarChartRodData(
                          toY: (e.value['omzet'] as num).toDouble(),
                          color: AppColors.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        )],
                      )).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          getTitlesWidget: (v, _) => Text(
                            CurrencyFormatter.formatCompact(v),
                            style: const TextStyle(fontSize: 9)),
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade200, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                  )),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Belum ada data transaksi',
                    style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CashTab extends ConsumerWidget {
  final DateTime start, end;
  const _CashTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, double>>(
      future: ref.read(databaseProvider)
          .reportsDao.getCashReport(start, end),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _InfoCard(
                title: 'Kas Masuk',
                value: CurrencyFormatter.format(d['income']!),
                icon: Icons.arrow_circle_down_rounded,
                color: AppColors.success,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Kas Keluar',
                value: CurrencyFormatter.format(d['expense']!),
                icon: Icons.arrow_circle_up_rounded,
                color: AppColors.danger,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Saldo Bersih',
                value: CurrencyFormatter.format(d['saldo']!),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(databaseProvider)
          .productsDao.getLowStockProducts(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                  size: 60, color: AppColors.success),
                const SizedBox(height: 12),
                const Text('Semua stok aman!',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
                ),
                title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Stok minimum: ${p.minStock} ${p.unit}'),
                trailing: Text('${p.stock} ${p.unit}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  )),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                )),
              const SizedBox(height: 2),
              Text(value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            ],
          ),
        ]),
      ),
    );
  }
}
