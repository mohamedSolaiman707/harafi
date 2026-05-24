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
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersStreamProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusBanner(status: order.status),
                  const SizedBox(height: AppSpacing.lg),
                  _buildClientInfo(order),
                  const SizedBox(height: AppSpacing.xl),
                  _buildOrderDescription(order),
                  if (order.techNotes != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _buildTechReport(order),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildActionButtons(context, ref, order),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, s) => Scaffold(
        body: AppErrorWidget(
          message: 'خطأ في تحميل البيانات',
          error: e,
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
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
                  variant: ButtonVariant.whatsapp,
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

  Widget _buildTechReport(Order order) {
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تقرير الإنجاز الخاص بك', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
          const SizedBox(height: 8),
          Text(order.techNotes!, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 12),
          Text('المبلغ الإجمالي: ${order.finalPrice} ج.م', style: AppTextStyles.titleMed),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == OrderStatus.completed) {
      return const AppCard(
        color: AppColors.success,
        child: Center(child: Text('تم إنجاز هذا الطلب بنجاح', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return const AppCard(
        color: AppColors.error,
        child: Center(child: Text('هذا الطلب ملغي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned)
          AppButton(
            label: 'أنا في الطريق للعميل',
            icon: Icons.directions_bike,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(
              order, 
              OrderStatus.onTheWay,
              logMessage: 'الفني تحرك الآن وفي طريقه إليك',
            ),
          ),

        if (order.status == OrderStatus.onTheWay)
          AppButton(
            label: 'وصلت للعميل (بدء العمل)',
            icon: Icons.play_arrow,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(
              order, 
              OrderStatus.started,
              logMessage: 'وصل الفني لموقع العميل وبدأ في تنفيذ المهمة',
            ),
          ),

        if (order.status == OrderStatus.started)
          AppButton(
            label: 'تم الإنجاز (إغلاق الطلب)',
            icon: Icons.check_circle,
            variant: ButtonVariant.success,
            onTap: () => _showCompletionDialog(context, ref, order),
          ),
      ],
    );
  }

  void _showCompletionDialog(BuildContext context, WidgetRef ref, Order order) {
    final priceController = TextEditingController();
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('إغلاق الطلب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ماذا تم في هذه المهمة؟'),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف العمل المنجز',
                  hintText: 'مثال: تم تغيير قلب الحنفية وإصلاح التسريب الخارجي',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر النهائي (ج.م)',
                  hintText: 'أدخل المبلغ المتفق عليه مع العميل',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final price = int.tryParse(priceController.text);
              if (price == null || notesController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء جميع البيانات')));
                return;
              }
              
              // تم التعديل هنا لاستخدام adminActionsProvider بدلاً من repository مباشرة
              await ref.read(adminActionsProvider).updateOrderStatus(
                order, 
                OrderStatus.completed,
                finalPrice: price,
                techNotes: notesController.text.trim(),
                logMessage: 'تم إنجاز المهمة بنجاح، شكراً لتعاملكم مع حرافي',
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                context.pop();
              }
            },
            child: const Text('تأكيد الإنجاز'),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final OrderStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.gold;
    if (status == OrderStatus.completed) color = AppColors.success;
    if (status == OrderStatus.cancelled) color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            'الحالة الحالية: ${status.label}',
            style: AppTextStyles.titleMed.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
