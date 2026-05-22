import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum ButtonVariant { primary, ghost, danger, whatsapp, success }

enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.lg,
    this.isLoading = false,
    this.icon,
  });

  Color get _background {
    switch (variant) {
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.danger:
        return AppColors.error;
      case ButtonVariant.whatsapp:
        return const Color(0xFF25D366);
      case ButtonVariant.success:
        return AppColors.success;
      case ButtonVariant.primary:
        return AppColors.gold;
    }
  }

  Color get _foreground {
    switch (variant) {
      case ButtonVariant.ghost:
        return AppColors.textPrimary;
      case ButtonVariant.danger:
      case ButtonVariant.whatsapp:
      case ButtonVariant.success:
        return Colors.white;
      case ButtonVariant.primary:
        return AppColors.background;
    }
  }

  double get _height {
    switch (size) {
      case ButtonSize.sm:
        return 44;
      case ButtonSize.md:
        return 52;
      case ButtonSize.lg:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTextStyles.titleLarge.copyWith(color: _foreground),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _background,
          foregroundColor: _foreground,
          elevation: 0,
          side: variant == ButtonVariant.ghost
              ? const BorderSide(color: AppColors.borderDefault)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: buttonChild,
      ),
    );
  }
}
