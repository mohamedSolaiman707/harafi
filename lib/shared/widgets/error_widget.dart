import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final dynamic error;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key, 
    required this.message, 
    this.error,
    this.onRetry,
  });

  bool get _isNetworkError {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socketexception') || 
           errorStr.contains('network_error') || 
           errorStr.contains('connection failed') ||
           error is SocketException;
  }

  @override
  Widget build(BuildContext context) {
    final isNetError = _isNetworkError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetError ? Icons.wifi_off_rounded : Icons.error_outline_rounded, 
              size: 64, 
              color: isNetError ? AppColors.textMuted : AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isNetError ? 'لا يوجد اتصال بالإنترنت' : message,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isNetError 
                ? 'يرجى التحقق من اتصالك بالشبكة والمحاولة مرة أخرى' 
                : 'حدث خطأ غير متوقع، نحن نعمل على إصلاحه',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMed.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: AppButton(
                  label: 'إعادة المحاولة',
                  onTap: onRetry!,
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.md,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
