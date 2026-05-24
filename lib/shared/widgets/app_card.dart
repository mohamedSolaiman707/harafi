import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin; // إضافة المارجن هنا
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin, // استلام المارجن
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      margin: margin, // تطبيق المارجن على الحاوية
      decoration: BoxDecoration(
        color: color ?? AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: child,
    );

    if (onTap == null) return card;
    
    // إذا كان هناك onTap، نغلف الكارت بـ InkWell ونراعي المارجن
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: child,
        ),
      ),
    );
  }
}
