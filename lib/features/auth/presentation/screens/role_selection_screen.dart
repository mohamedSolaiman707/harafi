import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_screen_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  Timer? _adminTapTimer;

  Future<void> _setRole(String role, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (context.mounted) {
      context.go(role == 'client' ? '/' : '/tech/login');
    }
  }

  Future<void> _handleAdminAccess() async {
    _adminTapTimer?.cancel(); 
    
    final currentCount = ref.read(adminTapCountProvider) + 1;
    ref.read(adminTapCountProvider.notifier).state = currentCount;

    if (currentCount >= 5) {
      ref.read(adminTapCountProvider.notifier).state = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'admin');
      if (mounted) {
        context.push('/login');
      }
    } else {
      _adminTapTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          ref.read(adminTapCountProvider.notifier).state = 0;
        }
      });
    }
  }

  @override
  void dispose() {
    _adminTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminTapCount = ref.watch(adminTapCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hidden Admin Trigger
                    GestureDetector(
                      onTap: _handleAdminAccess,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface1,
                          border: Border.all(
                            color: adminTapCount > 0 ? AppColors.gold : AppColors.borderSubtle,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.engineering, 
                          size: 60, 
                          color: adminTapCount > 0 ? AppColors.gold : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    
                    Text(
                      'أهلاً بك في حرفي',
                      style: AppTextStyles.displayMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'اختر كيف تريد استخدام التطبيق اليوم',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AppSpacing.xxxl),
                    
                    _UberRoleCard(
                      title: 'أنا عميل',
                      subtitle: 'أبحث عن فني لإصلاح أعطال منزلي',
                      icon: Icons.person_search,
                      onTap: () => _setRole('client', context),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    _UberRoleCard(
                      title: 'أنا فني (حرفي)',
                      subtitle: 'أريد استقبال طلبات العمل وزيادة دخلي',
                      icon: Icons.construction,
                      isHighlight: true,
                      onTap: () => _setRole('tech', context),
                    ),
                    
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UberRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlight;

  const _UberRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: isHighlight ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isHighlight ? AppColors.gold.withOpacity(0.5) : AppColors.borderSubtle,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.headlineMed.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMed.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHighlight ? AppColors.gold : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isHighlight ? Colors.black : AppColors.gold,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
