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
    // الحصول على المسار الحالي لتحديد العنصر النشط
    final location = GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: AppColors.background,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md), // تقليل المسافة من xl إلى md
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.home_rounded,
                    title: 'الرئيسية',
                    isActive: location == '/',
                    onTap: () => context.go('/'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.business_center_rounded,
                    title: 'سجل طلباتي',
                    isActive: location == '/my-orders',
                    onTap: () => context.push('/my-orders'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.handyman_rounded,
                    title: 'الفنيين المفضلين',
                    isActive: location == '/favorites',
                    onTap: () => context.push('/favorites'),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), // تقليل المسافة حول الخط الفاصل
                    child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.grid_view_rounded,
                    title: 'كل الخدمات',
                    isActive: location == '/services',
                    onTap: () => context.push('/services'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'تبديل نوع الحساب',
                    onTap: () => _switchRole(context),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), // تقليل المسافة حول الخط الفاصل
                    child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'عن حرفي',
                    isActive: location == '/about',
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24), // تقليل الـ bottom padding
      decoration: BoxDecoration(
        color: AppColors.surface1.withOpacity(0.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const CircleAvatar(
              radius: 42, // تصغير بسيط
              backgroundColor: Color(0xFF131B2A),
              backgroundImage: AssetImage('assets/images/logo1.png'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'حرفي | Harafi',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 22, // تصغير بسيط
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'خدمات منزلية في الغربية',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6), // تقليل المسافة السفلية من 12 إلى 6
      decoration: BoxDecoration(
        color: isActive ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(16), // تقليل الزوايا قليلاً لتناسب الحجم الأصغر
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        dense: true, // جعل العنصر أكثر تكدساً
        trailing: Icon(
          icon,
          color: isActive ? const Color(0xFF090D16) : AppColors.textSecondary,
          size: 20, // تصغير الأيقونة قليلاً
        ),
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyLarge.copyWith(
            color: isActive ? const Color(0xFF090D16) : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
            fontSize: 15, // تصغير الخط قليلاً
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg), // تقليل الهوامش
      child: Column(
        children: [
          Text(
            'الإصدار 1.1.2',
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'صنع بكل ',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary),
              ),
              const Icon(Icons.favorite_rounded, color: Colors.red, size: 12),
              Text(
                ' في كفر الزيات',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
