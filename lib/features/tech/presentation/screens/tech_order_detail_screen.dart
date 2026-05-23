import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';

class TechOrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const TechOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(ordersStreamProvider).whenData(
      (orders) => orders.where((o) => o.id == orderId).firstOrNull,
    );

    return orderAsync.when(
      data: (order) {
        if (order == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود')));

        return Scaffold(
          appBar: AppBar(title: Text('طلب #${order.trackingCode}')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildClientInfo(order),
                const SizedBox(height: AppSpacing.xl),
                _buildOrderDescription(order),
                const SizedBox(height: AppSpacing.xl),
                _buildActionButtons(context, ref, order),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, s) => Scaffold(body: AppErrorWidget(message: 'خطأ في تحميل البيانات', onRetry: () {})),
    );
  }

  Widget _buildClientInfo(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بيانات العميل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyLarge),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'اتصال',
                  icon: Icons.phone,
                  variant: ButtonVariant.ghost,
                  onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'واتساب',
                  icon: Icons.chat,
                  variant: ButtonVariant.whatsapp, // استخدام التنوع المخصص للواتساب
                  onTap: () {
                    final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDescription(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل المشكلة', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
          const SizedBox(height: AppSpacing.md),
          Text(
            order.description ?? 'لا يوجد وصف مضاف',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: AppColors.gold),
                const SizedBox(width: 12),
                Text(order.service.label, style: AppTextStyles.titleMed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == OrderStatus.completed) {
      return const AppCard(
        color: AppColors.success,
        child: Center(child: Text('تم إنجاز هذا الطلب بنجاح', style: TextStyle(fontWeight: FontWeight.bold))),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned)
          AppButton(
            label: 'بدء العمل الآن',
            icon: Icons.play_arrow,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(order, OrderStatus.started),
          ),
        if (order.status == OrderStatus.started)
          AppButton(
            label: 'تم الإنجاز (إنهاء الطلب)',
            icon: Icons.check_circle,
            variant: ButtonVariant.success, // استخدام التنوع المخصص للنجاح
            onTap: () => _showCompletionDialog(context, ref, order),
          ),
      ],
    );
  }

  void _showCompletionDialog(BuildContext context, WidgetRef ref, Order order) {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء المهمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ما هو السعر النهائي الذي تم الاتفاق عليه مع العميل؟'),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر النهائي (ج.م)',
                hintText: 'أدخل المبلغ الإجمالي',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceController.text);
              if (price == null) return;
              
              await ref.read(adminActionsProvider).updateOrderStatus(
                order, 
                OrderStatus.completed,
                finalPrice: price,
              );
              if (context.mounted) {
                Navigator.pop(context);
                context.pop(); // العودة للداشبورد
              }
            },
            child: const Text('تأكيد وإغلاق الطلب'),
          ),
        ],
      ),
    );
  }
}
