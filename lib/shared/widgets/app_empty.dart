import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppEmpty extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const AppEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.headlineMed.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMed.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
