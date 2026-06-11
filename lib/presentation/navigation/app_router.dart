import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/kasir/kasir_screen.dart';
import '../screens/stok/stok_screen.dart';
import '../screens/laporan/laporan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../../core/theme/app_theme.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  static const _screens = [
    DashboardScreen(),
    KasirScreen(),
    StokScreen(),
    LaporanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(currentNavIndexProvider);
    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  current: idx,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Dashboard',
                  ref: ref,
                ),
                _NavItem(
                  index: 1,
                  current: idx,
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale_rounded,
                  label: 'Kasir (POS)',
                  ref: ref,
                ),
                _NavItem(
                  index: 2,
                  current: idx,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Stok Barang',
                  ref: ref,
                ),
                _NavItem(
                  index: 3,
                  current: idx,
                  icon: Icons.insert_chart_outlined,
                  activeIcon: Icons.insert_chart_rounded,
                  label: 'Laporan',
                  ref: ref,
                ),
                _NavItem(
                  index: 4,
                  current: idx,
                  icon: Icons.menu_rounded,
                  activeIcon: Icons.menu_rounded,
                  label: 'Menu',
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () =>
          ref.read(currentNavIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              )),
          ],
        ),
      ),
    );
  }
}
