import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/products_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final lowStock = ref.watch(lowStockProvider);
    final topProducts = ref.watch(topProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('KasirKu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(topProductsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              const Text('Selamat Datang! 👋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
              const SizedBox(height: 16),

              // Summary Cards
              summary.when(
                data: (data) => _SummaryCards(data: data),
                loading: () => _buildShimmerCards(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 20),

              // Low Stock Warning
              lowStock.when(
                data: (list) => list.isEmpty
                    ? const SizedBox()
                    : _LowStockCard(products: list),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 20),

              // Top Products
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Produk Terlaris Bulan Ini',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                ],
              ),
              const SizedBox(height: 12),
              topProducts.when(
                data: (data) => _TopProductsList(data: data),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi ☀️';
    if (hour < 15) return 'Selamat Siang 🌤️';
    if (hour < 18) return 'Selamat Sore 🌅';
    return 'Selamat Malam 🌙';
  }

  Widget _buildShimmerCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: List.generate(4, (_) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
      )),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          title: 'Omzet Hari Ini',
          value: CurrencyFormatter.formatCompact(
            (data['omzet'] as num?)?.toDouble() ?? 0),
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
        ),
        _StatCard(
          title: 'Transaksi',
          value: '${data['jumlah_transaksi'] ?? 0}x',
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              )),
            Text(title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              )),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final List products;
  const _LowStockCard({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
            const SizedBox(width: 6),
            Text('Stok Hampir Habis (${products.length} produk)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
                fontSize: 13,
              )),
          ]),
          const SizedBox(height: 8),
          ...products.take(3).map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(p.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                ),
                Text('Sisa: ${p.stock} ${p.unit}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _TopProductsList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(Icons.bar_chart_outlined,
              size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Belum ada data penjualan',
              style: TextStyle(color: Colors.grey.shade400)),
          ]),
        ),
      );
    }
    return Column(
      children: data.asMap().entries.map((e) {
        final idx = e.key;
        final item = e.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: idx == 0
                    ? AppColors.warning.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('${idx + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: idx == 0 ? AppColors.warning : AppColors.primary,
                )),
            ),
            title: Text('${item['name']}',
              style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Terjual: ${item['total_qty']} pcs',
              style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500)),
            trailing: Text(
              CurrencyFormatter.formatCompact(
                (item['total_omzet'] as num).toDouble()),
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              )),
          ),
        );
      }).toList(),
    );
  }
}
