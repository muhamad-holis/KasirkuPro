import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary    = ref.watch(dashboardSummaryProvider);
    final lowStock   = ref.watch(lowStockProvider);
    final topProducts= ref.watch(topProductsProvider);
    final todayTx    = ref.watch(todayTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header teal
          SliverToBoxAdapter(child: _Header()),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Ringkasan hari ini
                _SectionTitle('Ringkasan Hari Ini', action: 'Lihat semua'),
                const SizedBox(height: 10),
                summary.when(
                  data: (d) => _SummaryGrid(data: d),
                  loading: () => _shimmer(),
                  error: (e, _) => Text('$e'),
                ),
                const SizedBox(height: 20),

                // Aksi Cepat
                _SectionTitle('Aksi Cepat'),
                const SizedBox(height: 10),
                _QuickActions(),
                const SizedBox(height: 20),

                // Low stock banner
                lowStock.when(
                  data: (list) => list.isEmpty
                      ? const SizedBox()
                      : _LowStockBanner(products: list),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // Transaksi terakhir
                _SectionTitle('Transaksi Terakhir',
                  action: 'Lihat semua'),
                const SizedBox(height: 10),
                todayTx.when(
                  data: (list) => list.isEmpty
                      ? _emptyTx()
                      : _TxList(transactions: list.take(5).toList()),
                  loading: () => _shimmer(),
                  error: (e, _) => Text('$e'),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer() => Container(
    height: 120,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
    ),
  );

  Widget _emptyTx() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined,
          size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Belum ada transaksi hari ini',
          style: TextStyle(color: Colors.grey.shade400)),
      ]),
    ),
  );
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Halo, Kasir 👋',
                    style:
const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(height: 2),
                  const Text('Selamat datang kembali',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    )),
                ],
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 22),
                  ),
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Toko card
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_outlined,
                  color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toko Sejahtera',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      )),
                    Text('Kasir Pagi',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionTitle(this.title, {this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          )),
        if (action != null)
          GestureDetector(
            onTap: () {},
            child: Row(children: [
              Text(action!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                )),
              const Icon(Icons.chevron_right,
                size: 16, color: AppColors.primary),
            ]),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final omzet = (data['omzet'] as num?)?.toDouble() ?? 0;
    final count = data['jumlah_transaksi'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Total Penjualan',
          value: CurrencyFormatter.format(omzet),
          badge: '+12% dari kemarin',
          icon: Icons.shopping_bag_outlined,
          color: AppColors.primary,
        ),
        _StatCard(
          title: 'Transaksi',
          value: '$count',
          badge: '+8% dari kemarin',
          icon: Icons.receipt_long_outlined,
          color: AppColors.info,
        ),
        _StatCard(
          title: 'Rata-rata Transaksi',
          value: CurrencyFormatter.format(
            count > 0 ? omzet / count : 0),
          badge: '+5% dari kemarin',
          icon: Icons.bar_chart_rounded,
          color: AppColors.success,
        ),
        _StatCard(
          title: 'Produk Terjual',
          value: '0',
          badge: '+10% dari kemarin',
          icon: Icons.inventory_2_outlined,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, badge;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.badge,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            )),
          Text(title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.arrow_upward_rounded,
              size: 10, color: AppColors.success),
            Text(badge,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              )),
          ]),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.shopping_cart_outlined,
        label: 'Mulai\nKasir',
        color: AppColors.primary,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.add_box_outlined,
        label: 'Tambah\nProduk',
        color: AppColors.success,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'Riwayat\nTransaksi',
        color: AppColors.info,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.insert_chart_outlined_rounded,
        label: 'Laporan\nHari Ini',
        color: AppColors.warning,
        onTap: () {},
      ),
    ];

    return Row(
      children: actions.map((a) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _QuickActionCard(action: a),
        ),
      )).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon,
                color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              )),
          ],
        ),
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  final List products;
  const _LowStockBanner({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stok Hampir Habis',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
                const SizedBox(height: 4),
                Text(
                  '${products.length} produk stoknya hampir habis. '
                  'Segera lakukan restok agar penjualan tetap lancar.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  )),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Lihat Stok',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.inventory_2_outlined,
            size: 60,
            color: AppColors.primary.withOpacity(0.3)),
        ],
      ),
    );
  }
}

class _TxList extends ConsumerWidget {
  final List<Transaction> transactions;
  const _TxList({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: transactions.map((tx) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
              color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.invoiceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
                Text(
                  _formatDate(tx.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.format(tx.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                )),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Selesai',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  )),
              ),
            ],
          ),
        ]),
      )).toList(),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun',
                    'Jul','Ags','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month-1]} ${dt.year} • '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }
}
