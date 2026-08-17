import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum ButtonVariant { primary, ghost, danger, whatsapp, success, secondary }

enum ButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
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

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Gradient? get _gradient {
    if (widget.variant == ButtonVariant.primary) {
      return AppGradients.goldButton;
    }
    return null;
  }

  Color get _background {
    switch (widget.variant) {
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.secondary:
        return AppColors.surface2;
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
    switch (widget.variant) {
      case ButtonVariant.ghost:
      case ButtonVariant.secondary:
        return AppColors.textPrimary;
      case ButtonVariant.danger:
      case ButtonVariant.whatsapp:
      case ButtonVariant.success:
        return Colors.white;
      case ButtonVariant.primary:
        return const Color(0xFF090D16); // Dark Obsidian text on Gold
    }
  }

  double get _height {
    switch (widget.size) {
      case ButtonSize.sm:
        return 42;
      case ButtonSize.md:
        return 50;
      case ButtonSize.lg:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null && !widget.isLoading;

    final buttonChild = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: _foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: _foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: _height,
          decoration: BoxDecoration(
            color: _gradient == null ? _background : null,
            gradient: _gradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: widget.variant == ButtonVariant.ghost
                ? Border.all(color: AppColors.borderDefault)
                : widget.variant == ButtonVariant.secondary
                    ? Border.all(color: AppColors.borderSubtle)
                    : null,
            boxShadow: widget.variant == ButtonVariant.primary
                ? AppShadows.goldGlow
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: isEnabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Center(child: buttonChild),
            ),
          ),
        ),
      ),
    );
  }
}
