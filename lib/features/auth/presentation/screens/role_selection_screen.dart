import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _adminTapCount = 0;
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
    
    setState(() {
      _adminTapCount++;
    });

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      
      // حل مشكلة الـ Rebuild: نحفظ الدور كأدمن فوراً قبل الانتقال
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'admin');
      
      if (mounted) {
        context.push('/login');
      }
    } else {
      // إعادة التصفير لو توقف عن الضغط لمدة ثانية (وقت كافي للماوس)
      _adminTapTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() => _adminTapCount = 0);
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gold.withOpacity(0.1),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // استخدام Material و InkWell لضمان استجابة الماوس في الويب
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleAdminAccess,
                          borderRadius: BorderRadius.circular(50),
                          splashColor: AppColors.gold.withOpacity(0.1),
                          highlightColor: Colors.transparent,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Icon(
                                Icons.build_circle_outlined, 
                                size: 80, 
                                color: _adminTapCount > 0 ? AppColors.gold : AppColors.gold.withOpacity(0.8)
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'أهلاً بك في حرفي', 
                        style: AppTextStyles.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'اختر نوع الحساب للمتابعة',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
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

                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
