import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/kasir/kasir_screen.dart';
import '../screens/stok/stok_screen.dart';
import '../screens/laporan/laporan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/pelanggan/pelanggan_screen.dart';
import '../screens/kas/kas_screen.dart';
import '../../core/theme/app_theme.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  // Urutan tab: 0=Dashboard, 1=Laporan, 2=Kasir(FAB), 3=Stock, 4=Pelanggan
  // Settings diakses lewat header Dashboard
  // KasScreen diakses via navigateToKas (push route)
  static final List<Widget> _screens = [
    const DashboardScreen(),  // 0 Dashboard
    const LaporanScreen(),    // 1 Laporan
    const KasirScreen(),      // 2 Kasir
    const StokScreen(),       // 3 Stock
    const PelangganScreen(),  // 4 Pelanggan
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(currentNavIndexProvider);

    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: _BottomNavBar(currentIndex: idx, ref: ref),
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
              // 3 – Stock
              _NavItem(
                index: 3,
                current: currentIndex,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Stock',
                ref: ref,
              ),
              // 4 – Pelanggan
              _NavItem(
                index: 4,
                current: currentIndex,
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Pelanggan',
                ref: ref,
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
