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
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    final isUltraWide = width > 1400;

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
              width: isUltraWide ? 280 : 240,
              color: AppColors.surface2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      children: [
                        const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'حرفي | Harafi',
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                                ),
                                child: Text(
                                  'لوحة الإدارة',
                                  style: AppTextStyles.labelMed.copyWith(
                                    color: AppColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.borderDefault, height: 1),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: NavigationRail(
                      backgroundColor: AppColors.surface2,
                      extended: true, // تفعيل النص بجانب الأيقونة
                      selectedIndex: _getSelectedIndex(location),
                      onDestinationSelected: (index) => _onItemTapped(index, context),
                      groupAlignment: -0.9,
                      selectedLabelTextStyle: AppTextStyles.titleMed.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelTextStyle: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      selectedIconTheme: const IconThemeData(color: AppColors.gold, size: 28),
                      unselectedIconTheme: const IconThemeData(color: AppColors.textMuted, size: 24),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('الرئيسية'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment),
                          label: Text('إدارة الطلبات'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('الفنيين والخبراء'),
                        ),
                      ],
                    ),
                  ),
                  // زر الإشعارات في الأسفل للشاشات الكبيرة
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      children: [
                        const NotificationIcon(),
                        const SizedBox(width: 12),
                        Text('التنبيهات', style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (isWide)
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderDefault),
          Expanded(
            child: Container(
              color: AppColors.surface1, // خلفية أهدأ للمحتوى
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _getSelectedIndex(location),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              backgroundColor: AppColors.surface2,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'الطلبات'),
                NavigationDestination(icon: Icon(Icons.people_outline), label: 'الفنيين'),
              ],
            ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/admin/orders')) return 1;
    if (location.startsWith('/admin/techs')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/admin'); break;
      case 1: context.go('/admin/orders'); break;
      case 2: context.go('/admin/techs'); break;
    }
  }
}
