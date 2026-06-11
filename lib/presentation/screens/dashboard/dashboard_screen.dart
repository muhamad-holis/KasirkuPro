import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../navigation/app_router.dart';
import '../../../data/database/app_database.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
// Jika DashboardStats sudah didefinisikan di dashboard_provider.dart,
// hapus class ini dan pastikan export-nya benar di provider tersebut.

class DashboardStats {
  final double omzetToday;
  final double omzetChange;
  final int txToday;
  final double txChange;
  final double avgToday;
  final double avgChange;
  final int productsSold;

  const DashboardStats({
    this.omzetToday = 0,
    this.omzetChange = 0,
    this.txToday = 0,
    this.txChange = 0,
    this.avgToday = 0,
    this.avgChange = 0,
    this.productsSold = 0,
  });
}

// Provider untuk DashboardStats — override di dashboard_provider.dart jika sudah ada
final dashboardStatsProvider =
    FutureProvider<DashboardStats>((ref) async {
  // Ambil data dari database melalui databaseProvider
  final db = ref.watch(databaseProvider);

  // Data hari ini
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday =
      startOfToday.subtract(const Duration(days: 1));

  final todayTx = await db.transactionsDao
      .getTransactionsByDateRange(startOfToday, now);
  final yesterdayTx = await db.transactionsDao
      .getTransactionsByDateRange(startOfYesterday, startOfToday);

  final omzetToday =
      todayTx.fold<double>(0, (sum, t) => sum + t.total);
  final omzetYesterday =
      yesterdayTx.fold<double>(0, (sum, t) => sum + t.total);

  double pctChange(double today, double yesterday) {
    if (yesterday == 0) return today > 0 ? 100.0 : 0.0;
    return ((today - yesterday) / yesterday) * 100;
  }

  final txToday = todayTx.length;
  final txYesterday = yesterdayTx.length;

  final avgToday = txToday > 0 ? omzetToday / txToday : 0.0;
  final avgYesterday =
      txYesterday > 0 ? omzetYesterday / txYesterday : 0.0;

  final productsSold =
      todayTx.fold<int>(0, (sum, t) => sum + (t.itemCount ?? 0));

  return DashboardStats(
    omzetToday: omzetToday,
    omzetChange: pctChange(omzetToday, omzetYesterday),
    txToday: txToday,
    txChange: pctChange(txToday.toDouble(), txYesterday.toDouble()),
    avgToday: avgToday,
    avgChange: pctChange(avgToday, avgYesterday),
    productsSold: productsSold,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats    = ref.watch(dashboardStatsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final todayTx  = ref.watch(todayTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header()),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Ringkasan hari ini
                _SectionTitle(
                  'Ringkasan Hari Ini',
                  action: 'Lihat semua',
                  onAction: () => ref
                      .read(currentNavIndexProvider.notifier)
                      .state = 4, // tab Laporan
                ),
                const SizedBox(height: 10),
                stats.when(
                  data: (s) => _SummaryGrid(stats: s),
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
                      : _LowStockBanner(
                          products: list,
                          onLihatStok: () => ref
                              .read(currentNavIndexProvider.notifier)
                              .state = 2, // tab Stok
                        ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // Transaksi terakhir
                _SectionTitle(
                  'Transaksi Terakhir',
                  action: 'Lihat semua',
                  onAction: () => ref
                      .read(currentNavIndexProvider.notifier)
                      .state = 4, // tab Laporan
                ),
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

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider);

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
                  const Text('Halo, Kasir 👋',
                    style: TextStyle(
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
              // Bell icon — dekoratif, belum ada sistem notifikasi
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Nama toko dari storeSettingsProvider
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.storeName.isNotEmpty
                          ? settings.storeName
                          : 'KasirKu',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      )),
                    Text(
                      settings.storeAddress.isNotEmpty
                          ? settings.storeAddress
                          : 'Pengaturan toko',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

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
            onTap: onAction,
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

// ─── Summary Grid ─────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final DashboardStats stats;
  const _SummaryGrid({required this.stats});

  String _badge(double pct) {
    if (pct == 0) return '= sama seperti kemarin';
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}% dari kemarin';
  }

  bool _isUp(double pct) => pct >= 0;

  @override
  Widget build(BuildContext context) {
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
          value: CurrencyFormatter.format(stats.omzetToday),
          badge: _badge(stats.omzetChange),
          isUp: _isUp(stats.omzetChange),
          icon: Icons.shopping_bag_outlined,
          color: AppColors.primary,
        ),
        _StatCard(
          title: 'Transaksi',
          value: '${stats.txToday}',
          badge: _badge(stats.txChange),
          isUp: _isUp(stats.txChange),
          icon: Icons.receipt_long_outlined,
          color: AppColors.info,
        ),
        _StatCard(
          title: 'Rata-rata Transaksi',
          value: CurrencyFormatter.format(stats.avgToday),
          badge: _badge(stats.avgChange),
          isUp: _isUp(stats.avgChange),
          icon: Icons.bar_chart_rounded,
          color: AppColors.success,
        ),
        _StatCard(
          title: 'Produk Terjual',
          value: '${stats.productsSold}',
          badge: 'hari ini',
          isUp: true,
          icon: Icons.inventory_2_outlined,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, badge;
  final bool isUp;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.badge,
    required this.isUp,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isUp ? AppColors.success : AppColors.danger;
    final badgeIcon = isUp
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

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
            Icon(badgeIcon, size: 10, color: badgeColor),
            const SizedBox(width: 2),
            Flexible(
              child: Text(badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                )),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickAction(
        icon: Icons.shopping_cart_outlined,
        label: 'Mulai\nKasir',
        color: AppColors.primary,
        onTap: () => ref
            .read(currentNavIndexProvider.notifier)
            .state = 1, // tab Kasir
      ),
      _QuickAction(
        icon: Icons.add_box_outlined,
        label: 'Tambah\nProduk',
        color: AppColors.success,
        onTap: () {
          // Navigasi ke Stok dulu, lalu buka sheet tambah produk
          ref.read(currentNavIndexProvider.notifier).state = 2;
          // Kecil delay agar screen sudah mount
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => ProviderScope(
                  parent: ProviderScope.containerOf(context),
                  child: const _AddProductQuickSheet(),
                ),
              );
            }
          });
        },
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'Riwayat\nTransaksi',
        color: AppColors.info,
        onTap: () => ref
            .read(currentNavIndexProvider.notifier)
            .state = 4, // tab Laporan
      ),
      _QuickAction(
        icon: Icons.insert_chart_outlined_rounded,
        label: 'Laporan\nHari Ini',
        color: AppColors.warning,
        onTap: () => ref
            .read(currentNavIndexProvider.notifier)
            .state = 4, // tab Laporan
      ),
    ];

    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _QuickActionCard(action: a),
                ),
              ))
          .toList(),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
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
              child: Icon(action.icon, color: action.color, size: 22),
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

// ─── Low Stock Banner ─────────────────────────────────────────────────────────

class _LowStockBanner extends StatelessWidget {
  final List products;
  final VoidCallback onLihatStok;
  const _LowStockBanner({
    required this.products,
    required this.onLihatStok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  const Text('Stok Hampir Habis',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                ]),
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
                  onTap: onLihatStok,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
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
            size: 56,
            color: AppColors.warning.withOpacity(0.3)),
        ],
      ),
    );
  }
}

// ─── Transaction List ─────────────────────────────────────────────────────────

class _TxList extends ConsumerWidget {
  final List<Transaction> transactions;
  const _TxList({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: transactions
          .map((tx) => GestureDetector(
                onTap: () => _showTxDetail(context, ref, tx),
                child: Container(
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
                          child: Text(
                            _methodLabel(tx.paymentMethod),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            )),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textSecondary),
                  ]),
                ),
              ))
          .toList(),
    );
  }

  void _showTxDetail(
      BuildContext context, WidgetRef ref, Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _TxDetailSheet(transaction: tx),
      ),
    );
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'tunai':    return 'Tunai';
      case 'transfer': return 'Transfer';
      case 'qris':     return 'QRIS';
      case 'hutang':   return 'Hutang';
      default:         return 'Selesai';
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Transaction Detail Sheet ─────────────────────────────────────────────────

class _TxDetailSheet extends ConsumerWidget {
  final Transaction transaction;
  const _TxDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsFuture = ref.watch(
      _txItemsProvider(transaction.id),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.invoiceNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      )),
                    Text(
                      _formatDate(transaction.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _methodLabel(transaction.paymentMethod),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                // Item produk
                const Text('Item Produk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  )),
                const SizedBox(height: 8),
                itemsFuture.when(
                  data: (items) => items.isEmpty
                      ? const Text('Tidak ada item',
                          style: TextStyle(
                              color: AppColors.textSecondary))
                      : Column(
                          children: items
                              .map((item) => _ItemRow(item: item))
                              .toList()),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )),
                  error: (e, _) => Text('Error: $e'),
                ),
                const Divider(height: 24),
                // Ringkasan bayar
                _SummaryRow('Subtotal',
                  CurrencyFormatter.format(transaction.subtotal)),
                if ((transaction.discountAmount) > 0)
                  _SummaryRow(
                    'Diskon',
                    '- ${CurrencyFormatter.format(transaction.discountAmount)}',
                    color: AppColors.danger,
                  ),
                if ((transaction.taxAmount) > 0)
                  _SummaryRow(
                    'Pajak',
                    CurrencyFormatter.format(transaction.taxAmount),
                  ),
                const Divider(height: 16),
                _SummaryRow(
                  'Total',
                  CurrencyFormatter.format(transaction.total),
                  bold: true,
                  color: AppColors.primary,
                ),
                _SummaryRow(
                  'Dibayar',
                  CurrencyFormatter.format(transaction.amountPaid),
                ),
                if (transaction.change > 0)
                  _SummaryRow(
                    'Kembalian',
                    CurrencyFormatter.format(transaction.change),
                    color: AppColors.success,
                  ),
                if (transaction.notes != null &&
                    transaction.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.notes_rounded,
                        size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transaction.notes!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          )),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'tunai':    return 'Tunai';
      case 'transfer': return 'Transfer';
      case 'qris':     return 'QRIS';
      case 'hutang':   return 'Hutang';
      default:         return 'Selesai';
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// Provider untuk items per transaction
final _txItemsProvider =
    FutureProvider.family<List<TransactionItem>, int>((ref, txId) =>
        ref
            .watch(databaseProvider)
            .transactionsDao
            .getTransactionItems(txId));

class _ItemRow extends StatelessWidget {
  final TransactionItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
              Text(
                '${item.quantity}x ${CurrencyFormatter.format(item.price)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                )),
            ],
          ),
        ),
        Text(CurrencyFormatter.format(item.subtotal),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w500,
              color: bold
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            )),
          Text(value,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight:
                  bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            )),
        ],
      ),
    );
  }
}

// ─── Add Product Quick Sheet ──────────────────────────────────────────────────
// Sheet sederhana redirect ke Stok screen — produk form sudah ada di sana

class _AddProductQuickSheet extends ConsumerWidget {
  const _AddProductQuickSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.inventory_2_outlined,
            size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Tambah Produk',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 8),
          const Text(
            'Kamu sudah ada di tab Stok. '
            'Tap tombol + di bawah layar untuk menambah produk baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Oke, Mengerti',
                style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
