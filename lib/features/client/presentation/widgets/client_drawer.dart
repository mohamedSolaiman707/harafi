import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class ClientDrawer extends ConsumerWidget {
  const ClientDrawer({super.key});

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (context.mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.surface1,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.home_outlined,
                  title: 'الرئيسية',
                  onTap: () => context.go('/'),
                ),
                _buildMenuItem(
                  icon: Icons.history,
                  title: 'سجل طلباتي',
                  onTap: () => context.push('/my-orders'),
                ),
                _buildMenuItem(
                  icon: Icons.favorite_border_rounded,
                  title: 'الفنيين المفضلين',
                  onTap: () => context.push('/favorites'),
                ),
                _buildMenuItem(
                  icon: Icons.build_circle_outlined,
                  title: 'كل الخدمات',
                  onTap: () => context.push('/services'),
                ),
                const Divider(color: AppColors.borderDefault, height: 32, indent: 20, endIndent: 20),
                _buildMenuItem(
                  icon: Icons.swap_horiz_rounded,
                  title: 'تبديل نوع الحساب',
                  onTap: () => _switchRole(context),
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'عن حرفي',
                  onTap: () {
                    // يمكن إضافة شاشة معلومات لاحقاً
                  },
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.build_circle_rounded, color: AppColors.gold, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text('خدمات منزلية في كفر الزيات', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 0,
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Text(
            'الإصدار 1.0.0',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'صنع بكل ❤️ في كفر الزيات',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
