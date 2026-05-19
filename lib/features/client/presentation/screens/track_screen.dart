import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';

class TrackScreen extends ConsumerStatefulWidget {
  final String code;
  const TrackScreen({super.key, required this.code});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  late Future<Order> _orderFuture;
  final _phoneController = TextEditingController();
  bool _isSearchingPhone = false;
  List<Order>? _foundOrders;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    _orderFuture = ref.read(ordersRepositoryProvider).getByTrackingCode(widget.code);
  }

  Future<void> _searchByPhone() async {
    if (_phoneController.text.isEmpty) return;
    setState(() {
      _isSearchingPhone = true;
      _foundOrders = null;
    });

    try {
      final results = await ref.read(ordersRepositoryProvider).getByPhone(_phoneController.text);
      setState(() {
        _foundOrders = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء البحث')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingPhone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تتبع طلبك')),
      body: FutureBuilder<Order>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }

          // في حالة عدم العثور على الطلب بالكود
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildNotFoundView();
          }

          final order = snapshot.data!;
          return _buildOrderDetails(order);
        },
      ),
    );
  }

  Widget _buildNotFoundView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppErrorWidget(
            message: 'تعذر العثور على طلب بهذا الكود (${widget.code}).',
            onRetry: () => context.go('/'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const Divider(),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'نسيت كود التتبع؟',
            style: AppTextStyles.headlineMed,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'أدخل رقم الهاتف المستخدم في الطلب لاسترجاع بياناتك',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'بحث عن طلباتي',
            onTap: _isSearchingPhone ? null : _searchByPhone,
            isLoading: _isSearchingPhone,
          ),
          if (_foundOrders != null) ...[
            const SizedBox(height: AppSpacing.xl),
            if (_foundOrders!.isEmpty)
              const Text('لم يتم العثور على أي طلبات لهذا الرقم')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('الطلبات الموجودة:', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  ..._foundOrders!.map((order) => _buildFoundOrderCard(order)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoundOrderCard(Order order) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: () => context.go('/track/${order.trackingCode}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(order.service.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.service.label, style: AppTextStyles.titleMedium),
                Text('كود: ${order.trackingCode}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Order order) {
    final isCompleted = order.status == OrderStatus.completed;
    final isCancelled = order.status == OrderStatus.cancelled;
    
    final timeline = [
      _ProgressStep(title: 'تم استلام الطلب', completed: true),
      _ProgressStep(title: 'جاري تعيين فني', completed: !isCancelled && order.techId != null),
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
              children: [
                Icon(
                  isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                  size: 64,
                  color: isCancelled ? AppColors.error : AppColors.success,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'حالة الطلب: ${order.status.label}',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: isCancelled ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: order.trackingCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ كود التتبع')));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy, size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text('كود التتبع: ${order.trackingCode}', style: AppTextStyles.labelLarge),
                      ],
                    ),
                  ),
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
                _DetailRow(label: 'نوع الخدمة', value: order.service.label),
                _DetailRow(label: 'الاسم', value: order.clientName),
                _DetailRow(label: 'المنطقة', value: order.area ?? 'غير محدد'),
                _DetailRow(label: 'تاريخ الطلب', value: order.createdAt.toString().split(' ')[0]),
              ],
            ),
          ),
        ],
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
                color: step.completed ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: step.completed ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (step.completed) const Icon(Icons.check_circle, size: 18, color: AppColors.gold),
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
          Text(label, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
