import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/kasir/kasir_screen.dart';
import '../screens/stok/stok_screen.dart';
import '../screens/laporan/laporan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/pelanggan/pelanggan_screen.dart';
import '../screens/hutang/hutang_screen.dart';
import '../screens/notifikasi/notifikasi_screen.dart';
import '../screens/kas/kas_screen.dart';
import '../../core/theme/app_theme.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

// Key untuk nested Navigator di tab Lainnya — agar back button bisa dicegat
final _lainnyaNavKey = GlobalKey<NavigatorState>();

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  /// Buka layar Kas Masuk & Kas Keluar sebagai push route
  static void navigateToKas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: const KasScreen(),
        ),
      ),
    );
  }

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final List<Widget> _screens = [
    const DashboardScreen(),   // 0 Dashboard
    const LaporanScreen(),     // 1 Laporan
    const KasirScreen(),       // 2 Kasir
    const StokScreen(),        // 3 Stok
    const _LainnyaTab(),       // 4 Lainnya (nested navigator)
  ];

  Future<bool> _onWillPop() async {
    final idx = ref.read(currentNavIndexProvider);

    // Jika di tab Lainnya dan ada screen di dalam nested navigator → pop nested dulu
    if (idx == 4) {
      final canPop = _lainnyaNavKey.currentState?.canPop() ?? false;
      if (canPop) {
        _lainnyaNavKey.currentState!.pop();
        return false;
      }
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Keluar Aplikasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari aplikasi?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak',
              style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(currentNavIndexProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: idx, children: _screens),
        bottomNavigationBar: _BottomNavBar(currentIndex: idx, ref: ref),
      ),
    );
  }
}

// ─── Tab Lainnya dengan Nested Navigator ─────────────────────────────────────
// Nested Navigator memungkinkan push sub-screen (Pelanggan, Hutang, dll)
// tanpa bottom nav hilang. Bottom nav tetap kelihatan karena ada di Scaffold
// luar, bukan di dalam Navigator ini.

class _LainnyaTab extends StatelessWidget {
  const _LainnyaTab();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _lainnyaNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const _LainnyaHomeScreen(),
      ),
    );
  }
}

// ─── Halaman utama tab Lainnya (grid menu) ────────────────────────────────────

class _LainnyaHomeScreen extends StatelessWidget {
  const _LainnyaHomeScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu Lainnya',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola pelanggan, hutang, dan pengaturan',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Grid menu ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.55,
                ),
                delegate: SliverChildListDelegate([
                  _MenuCard(
                    icon: Icons.people_rounded,
                    label: 'Pelanggan',
                    description: 'Kelola data pelanggan',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const PelangganScreen(),
                        ),
                      ),
                    ),
                  ),
                  _MenuCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Hutang',
                    description: 'Catat hutang piutang',
                    color: AppColors.warning,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const HutangScreen(),
                        ),
                      ),
                    ),
                  ),
                  _MenuCard(
                    icon: Icons.notifications_rounded,
                    label: 'Notifikasi',
                    description: 'Stok & jatuh tempo',
                    color: AppColors.info,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const NotifikasiScreen(),
                        ),
                      ),
                    ),
                  ),
                  _MenuCard(
                    icon: Icons.settings_rounded,
                    label: 'Pengaturan',
                    description: 'Toko, struk & printer',
                    color: AppColors.textSecondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const SettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card menu Lainnya ────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final descColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10,
                      color: descColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Bottom Nav Bar ────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final WidgetRef ref;

  const _BottomNavBar({
    required this.currentIndex,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.darkSurface : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.07);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              // 0 – Dashboard
              _NavItem(
                index: 0,
                current: currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Dashboard',
                ref: ref,
              ),
              // 1 – Laporan
              _NavItem(
                index: 1,
                current: currentIndex,
                icon: Icons.insert_chart_outlined,
                activeIcon: Icons.insert_chart_rounded,
                label: 'Laporan',
                ref: ref,
              ),
              // 2 – Kasir (FAB tengah)
              _KasirFABItem(
                isActive: currentIndex == 2,
                onTap: () =>
                    ref.read(currentNavIndexProvider.notifier).state = 2,
              ),
              // 3 – Stok
              _NavItem(
                index: 3,
                current: currentIndex,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Stok',
                ref: ref,
              ),
              // 4 – Lainnya (tab, bukan bottom sheet)
              _NavItem(
                index: 4,
                current: currentIndex,
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Lainnya',
                ref: ref,
                // Jika sudah di tab Lainnya & tap lagi → pop ke grid home
                onRetap: () {
                  if (_lainnyaNavKey.currentState?.canPop() ?? false) {
                    _lainnyaNavKey.currentState!
                        .popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kasir FAB di tengah ──────────────────────────────────────────────────────

class _KasirFABItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _KasirFABItem({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kasir',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Item biasa ───────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final int index, current;
  final IconData icon, activeIcon;
  final String label;
  final WidgetRef ref;
  /// Dipanggil ketika tab sudah aktif lalu di-tap lagi (misal: scroll ke atas)
  final VoidCallback? onRetap;

  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.ref,
    this.onRetap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg =
        isDark ? AppColors.darkPrimaryLight : AppColors.primaryLight;
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isActive) {
            onRetap?.call();
          } else {
            ref.read(currentNavIndexProvider.notifier).state = index;
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.primary : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
