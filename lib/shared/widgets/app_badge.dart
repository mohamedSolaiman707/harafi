import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BadgeVariant { info, success, error, warning, primary }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.info,
    this.icon,
  });

  Color get _background {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success.withValues(alpha: 0.15);
      case BadgeVariant.error:
        return AppColors.error.withValues(alpha: 0.15);
      case BadgeVariant.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case BadgeVariant.primary:
        return AppColors.gold.withValues(alpha: 0.15);
      case BadgeVariant.info:
        return AppColors.info.withValues(alpha: 0.15);
    }
  }

  Color get _borderColor {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success.withValues(alpha: 0.3);
      case BadgeVariant.error:
        return AppColors.error.withValues(alpha: 0.3);
      case BadgeVariant.warning:
        return AppColors.warning.withValues(alpha: 0.3);
      case BadgeVariant.primary:
        return AppColors.gold.withValues(alpha: 0.3);
      case BadgeVariant.info:
        return AppColors.info.withValues(alpha: 0.3);
    }
  }

  Color get _textColor {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.error:
        return AppColors.error;
      case BadgeVariant.warning:
        return AppColors.warning;
      case BadgeVariant.primary:
        return AppColors.gold;
      case BadgeVariant.info:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelMed.copyWith(
              color: _textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
