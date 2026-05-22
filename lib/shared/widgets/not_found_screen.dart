import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 100, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.xxl),
              Text('404', style: AppTextStyles.displayLarge.copyWith(color: AppColors.gold)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'عذراً، هذه الصفحة غير موجودة',
                style: AppTextStyles.headlineMed,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'يبدو أنك سلكت طريقاً خاطئاً أو أن الرابط قد تعطل.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AppButton(
                  label: 'العودة للرئيسية',
                  onTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
