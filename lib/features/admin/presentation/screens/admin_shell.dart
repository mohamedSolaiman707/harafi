import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/notification_icon.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: isWide ? null : AppBar(
        title: const Text('لوحة التحكم'),
        actions: const [
          NotificationIcon(),
          SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 240,
              color: AppColors.surface2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu,
                              size: 24,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'لوحة التحكم',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const NotificationIcon(),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.borderDefault, height: 1),
                  Expanded(
                    child: NavigationRail(
                      backgroundColor: AppColors.surface2,
                      extended: false,
                      selectedIndex: _getSelectedIndex(location),
                      onDestinationSelected: (index) =>
                          _onItemTapped(index, context),
                      groupAlignment: 0,
                      labelType: NavigationRailLabelType.all,
                      selectedLabelTextStyle: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelTextStyle: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                      selectedIconTheme: const IconThemeData(
                        color: AppColors.gold,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: AppColors.textSecondary,
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('لوحة التحكم'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment),
                          label: Text('الطلبات'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('الفنيين'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (isWide)
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.borderDefault,
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _getSelectedIndex(location),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              backgroundColor: AppColors.surface2,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'الفنيين',
                ),
              ],
            ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/admin/orders')) return 1;
    if (location.startsWith('/admin/techs')) return 2;
    if (location.startsWith('/admin')) return 0;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/orders');
        break;
      case 2:
        context.go('/admin/techs');
        break;
    }
  }
}
