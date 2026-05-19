import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';

class TrackScreen extends ConsumerWidget {
  final String code;
  const TrackScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('تتبع طلبك')),
      body: FutureBuilder<Order>(
        future: ref.read(ordersRepositoryProvider).getByTrackingCode(code),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AppErrorWidget(
              message: 'تعذر العثور على طلب بهذا الكود. تأكد من صحة الكود.',
              onRetry: () => Navigator.of(context).pop(),
            );
          }
          final order = snapshot.data!;
          final isCompleted = order.status == OrderStatus.completed;
          final isCancelled = order.status == OrderStatus.cancelled;
          final timeline = [
            _ProgressStep(title: 'تم استلام الطلب', completed: true),
            _ProgressStep(title: 'جاري تعيين فني', completed: !isCancelled),
            _ProgressStep(title: 'الفني في الطريق', completed: isCompleted),
            _ProgressStep(
              title: isCompleted ? 'تم إنجاز الشغل' : 'قيد التنفيذ',
              completed: isCompleted,
            ),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isCancelled
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        size: 64,
                        color: isCancelled
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'حالة الطلب: ${order.status.label}',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: isCancelled
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        isCancelled
                            ? 'الطلب ملغي حاليًا. تواصل معنا لمزيد من التفاصيل.'
                            : 'سيتم تحديث حالة الطلب عند كل مرحلة جديدة.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('مسار التتبع', style: AppTextStyles.headlineMed),
                      const SizedBox(height: AppSpacing.md),
                      ...timeline.map((step) => _TimelineRow(step: step)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('بيانات الطلب', style: AppTextStyles.headlineMed),
                      const SizedBox(height: AppSpacing.lg),
                      _DetailRow(
                        label: 'رقم التتبع',
                        value: order.trackingCode,
                      ),
                      _DetailRow(
                        label: 'نوع الخدمة',
                        value: order.service.label,
                      ),
                      _DetailRow(label: 'الاسم', value: order.clientName),
                      _DetailRow(
                        label: 'المنطقة',
                        value: order.area ?? 'غير محدد',
                      ),
                      _DetailRow(
                        label: 'تاريخ الطلب',
                        value: order.createdAt.toString().split(' ')[0],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'سنتواصل معك هاتفياً فور تعيين فني لطلبك. يمكنك أيضًا حفظ كود التتبع للرجوع إليه لاحقاً.',
                          style: AppTextStyles.bodyMed.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressStep {
  final String title;
  final bool completed;

  _ProgressStep({required this.title, required this.completed});
}

class _TimelineRow extends StatelessWidget {
  final _ProgressStep step;

  const _TimelineRow({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.completed ? AppColors.gold : AppColors.surface1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              step.title,
              style: AppTextStyles.bodyLarge.copyWith(
                color: step.completed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: step.completed ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (step.completed)
            const Icon(Icons.check_circle, size: 18, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMed.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
