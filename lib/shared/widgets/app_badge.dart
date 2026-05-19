import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BadgeVariant { info, success, error, warning }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.info,
  });

  Color get _background {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success.withAlpha(36);
      case BadgeVariant.error:
        return AppColors.error.withAlpha(36);
      case BadgeVariant.warning:
      case BadgeVariant.info:
        return AppColors.info.withAlpha(36);
    }
  }

  Color get _textColor {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.error:
        return AppColors.error;
      case BadgeVariant.warning:
      case BadgeVariant.info:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMed.copyWith(
          color: _textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
