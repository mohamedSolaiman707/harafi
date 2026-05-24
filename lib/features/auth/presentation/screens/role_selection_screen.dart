import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _setRole(String role, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (context.mounted) {
      context.go(role == 'client' ? '/' : '/tech/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gold.withValues(alpha: 0.1),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined, size: 80, color: AppColors.gold),
                const SizedBox(height: AppSpacing.xl),
                Text('أهلاً بك في حرفي', style: AppTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'اختر نوع الحساب للمتابعة',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                
                _RoleCard(
                  title: 'أنا عميل',
                  subtitle: 'أبحث عن فني لإصلاح أعطال منزلي',
                  icon: Icons.person_search_outlined,
                  onTap: () => _setRole('client', context),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                _RoleCard(
                  title: 'أنا فني (حرفي)',
                  subtitle: 'أريد استقبال طلبات العمل وزيادة دخلي',
                  icon: Icons.engineering_outlined,
                  isPrimary: true,
                  onTap: () => _setRole('tech', context),
                ),

                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text(
                    'دخول الإدارة',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: isPrimary ? AppColors.surface3 : AppColors.surface2,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.gold, size: 32),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
