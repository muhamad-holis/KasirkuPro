import 'package:flutter/material.dart';
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

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  // Urutan tab: 0=Dashboard, 1=Laporan, 2=Kasir(FAB), 3=Stok, 4=More(bottom sheet)
  // More berisi: Pelanggan, Hutang, Notifikasi, Pengaturan
  static final List<Widget> _screens = [
    const DashboardScreen(),  // 0 Dashboard
    const LaporanScreen(),    // 1 Laporan
    const KasirScreen(),      // 2 Kasir
    const StokScreen(),       // 3 Stok
  ];

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

  /// Buka More Menu bottom sheet
  static void showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _MoreMenuSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(currentNavIndexProvider);

    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: _BottomNavBar(currentIndex: idx, ref: ref),
    );
  }
}

// ─── More Menu Bottom Sheet ───────────────────────────────────────────────────

class _MoreMenuSheet extends StatelessWidget {
  const _MoreMenuSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Menu Lainnya',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _MoreMenuItem(
                icon: Icons.people_rounded,
                label: 'Pelanggan',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: const PelangganScreen(),
                      ),
                    ),
                  );
                },
              ),
              _MoreMenuItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Hutang',
                color: AppColors.warning,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: const HutangScreen(),
                      ),
                    ),
                  );
                },
              ),
              _MoreMenuItem(
                icon: Icons.notifications_rounded,
                label: 'Notifikasi',
                color: AppColors.info,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: const NotifikasiScreen(),
                      ),
                    ),
                  );
                },
              ),
              _MoreMenuItem(
                icon: Icons.settings_rounded,
                label: 'Pengaturan',
                color: AppColors.textSecondary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: const SettingsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
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
              // 4 – More
              _MoreNavItem(context: context),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lingkaran besar teal
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
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── More Nav Item ────────────────────────────────────────────────────────────

class _MoreNavItem extends StatelessWidget {
  final BuildContext context;

  const _MoreNavItem({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Expanded(
      child: GestureDetector(
        onTap: () => MainNavigation.showMoreMenu(context),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Lainnya',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
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

  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;

    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(currentNavIndexProvider.notifier).state = index,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
