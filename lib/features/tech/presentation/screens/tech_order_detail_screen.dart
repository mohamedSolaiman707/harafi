import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';

class TechOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TechOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<TechOrderDetailScreen> createState() =>
      _TechOrderDetailScreenState();
}

class _TechOrderDetailScreenState extends ConsumerState<TechOrderDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(Order order, OrderStatus nextStatus) async {
    int? finalPrice;
    if (nextStatus == OrderStatus.completed) {
      finalPrice = await _showPriceDialog();
      if (finalPrice == null) return;
    }

    setState(() => _isUpdating = true);
    final result = await ref
        .read(adminActionsProvider)
        .updateOrderStatus(order, nextStatus, finalPrice: finalPrice);

    if (mounted) {
      result.when(
        left: (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message))),
        right: (_) {
          ref.invalidate(ordersStreamProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح')),
          );
        },
      );
      setState(() => _isUpdating = false);
    }
  }

  Future<int?> _showPriceDialog() async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الطلب'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'السعر النهائي المتفق عليه (ج.م)',
            hintText: 'مثال: 150',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد الإنجاز',
            size: ButtonSize.sm,
            onTap: () => Navigator.pop(context, int.tryParse(controller.text)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الشغلة')),
      body: orderAsync.when(
        data: (orders) {
          final order = orders.where((o) => o.id == widget.orderId).firstOrNull;
          if (order == null)
            return const Center(child: Text('الطلب غير موجود'));
          return _buildBody(order);
        },
        loading: () => const LoadingWidget(),
        error: (err, _) => AppErrorWidget(message: 'حدث خطأ', onRetry: () {}),
      ),
    );
  }

  Widget _buildBody(Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildClientSection(order),
          const SizedBox(height: AppSpacing.xl),
          _buildActionSection(order),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تفاصيل الخدمة', style: AppTextStyles.titleLarge),
                const SizedBox(height: AppSpacing.md),
                _DetailItem(
                  label: 'الخدمة',
                  value: '${order.service.icon} ${order.service.label}',
                ),
                _DetailItem(label: 'كود التتبع', value: order.trackingCode),
                _DetailItem(
                  label: 'تاريخ الطلب',
                  value: order.createdAt.toString().split(' ')[0],
                ),
                if (order.description != null)
                  _DetailItem(label: 'وصف المشكلة', value: order.description!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection(Order order) {
    return AppCard(
      color: AppColors.surface2,
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.surface3,
                child: Icon(Icons.person, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.clientName, style: AppTextStyles.headlineMed),
                    Text(
                      order.area ?? 'بدون منطقة',
                      style: AppTextStyles.bodyMed,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'اتصال هاتفـي',
                  icon: Icons.phone,
                  variant: ButtonVariant.ghost,
                  onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'واتسـاب',
                  icon: Icons.chat_bubble_outline,
                  variant: ButtonVariant.whatsapp,
                  onTap: () {
                    final uri = WhatsAppUtils.buildUri(
                      order.clientPhone,
                      'السلام عليكم أ/ ${order.clientName}، أنا الفني بخصوص طلبك في حرافي...',
                    );
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

  Widget _buildActionSection(Order order) {
    if (order.status == OrderStatus.completed) {
      return AppCard(
        color: AppColors.success.withValues(alpha: 0.1),
        child: const Center(
          child: Text(
            'هذا الطلب مكتمل ✅',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned)
          AppButton(
            label: 'أنا في الطريق للعميل 🚀',
            isLoading: _isUpdating,
            onTap: () => _updateStatus(order, OrderStatus.onTheWay),
          ),
        if (order.status == OrderStatus.onTheWay)
          AppButton(
            label: 'بدأت العمل الآن 🛠️',
            isLoading: _isUpdating,
            onTap: () => _updateStatus(order, OrderStatus.started),
          ),
        if (order.status == OrderStatus.started)
          AppButton(
            label: 'تم إنهاء العمل بنجاح ✅',
            isLoading: _isUpdating,
            variant: ButtonVariant.success,
            onTap: () => _updateStatus(order, OrderStatus.completed),
          ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMed.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(value, style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }
}
