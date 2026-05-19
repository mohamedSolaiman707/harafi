import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/models/order_log.dart';

class TrackScreen extends ConsumerStatefulWidget {
  final String code;
  const TrackScreen({super.key, required this.code});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> with SingleTickerProviderStateMixin {
  late Future<Order> _orderFuture;
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSearchingPhone = false;
  bool _isRating = false;
  int _selectedRating = 0;
  List<Order>? _foundOrders;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
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
      setState(() => _foundOrders = results);
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

  Future<void> _submitRating(String orderId) async {
    if (_selectedRating == 0) return;
    setState(() => _isRating = true);
    try {
      await ref.read(ordersRepositoryProvider).rateOrder(
        orderId, 
        _selectedRating,
        comment: _commentController.text,
      );
      _loadOrder();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال التقييم')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRating = false);
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
          Text('نسيت كود التتبع؟', style: AppTextStyles.headlineMed),
          const SizedBox(height: AppSpacing.md),
          Text(
            'أدخل رقم الهاتف المستخدم في الطلب لاسترجاع بياناتك',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
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
                  Text('الطلبات الموجودة:', style: AppTextStyles.titleMed),
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
                Text(order.service.label, style: AppTextStyles.titleMed),
                Text('كود: ${order.trackingCode}', style: AppTextStyles.bodyMed),
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
    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
    final tech = techs.where((t) => t.id == order.techId).firstOrNull;

    final steps = [
      _StepData(
        title: 'استلام الطلب',
        icon: Icons.receipt_long,
        isDone: true,
      ),
      _StepData(
        title: 'تم تعيين فني',
        icon: Icons.engineering,
        isDone: order.status != OrderStatus.pending,
        isActive: order.status == OrderStatus.pending && !isCancelled,
      ),
      _StepData(
        title: 'الفني في الطريق',
        icon: Icons.local_shipping,
        isDone: ![OrderStatus.pending, OrderStatus.assigned].contains(order.status),
        isActive: order.status == OrderStatus.assigned && !isCancelled,
      ),
      _StepData(
        title: 'قيد التنفيذ',
        icon: Icons.construction,
        isDone: [OrderStatus.completed].contains(order.status),
        isActive: order.status == OrderStatus.started && !isCancelled,
      ),
      _StepData(
        title: 'تم الإنجاز',
        icon: Icons.verified,
        isDone: isCompleted,
        isActive: false,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHeader(order: order, isCancelled: isCancelled),
          const SizedBox(height: AppSpacing.xl),

          if (isCompleted && order.rating == null)
            _buildRatingPrompt(order)
          else if (isCompleted && order.rating != null)
            _buildRatingSummary(order),

          if (order.estimatedArrival != null && !isCompleted && !isCancelled)
            _buildETA(order.estimatedArrival!),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسار تقدم الطلب', style: AppTextStyles.headlineMed),
                const SizedBox(height: AppSpacing.xl),
                ...List.generate(steps.length, (index) {
                  return _StepperRow(
                    step: steps[index],
                    isLast: index == steps.length - 1,
                    pulseAnimation: _pulseController,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (order.logs.isNotEmpty) ...[
            Text('سجل التحديثات', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _buildLogsTimeline(order.logs),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (tech != null && !isCancelled)
            AppCard(
              color: AppColors.surface1,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.gold.withOpacity(0.1),
                    child: Text(tech.spec.icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفني المتخصص', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
                        Text(tech.name, style: AppTextStyles.headlineMed),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk, color: AppColors.success),
                    onPressed: () => launchUrl(Uri.parse('tel:${tech.phone}')),
                  ),
                ],
              ),
            ),
          
          if (order.adminNotes != null && order.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              color: AppColors.info.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Text('رسالة من "حرفي"', style: AppTextStyles.titleMed.copyWith(color: AppColors.info)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(order.adminNotes!, style: AppTextStyles.bodyLarge),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تفاصيل الخدمة', style: AppTextStyles.headlineMed),
                const SizedBox(height: AppSpacing.lg),
                _DetailRow(label: 'نوع الخدمة', value: order.service.label),
                _DetailRow(label: 'رقم التتبع', value: order.trackingCode, isCopyable: true),
                _DetailRow(label: 'المنطقة', value: order.area ?? 'غير محدد'),
                _DetailRow(label: 'تاريخ الطلب', value: order.createdAt.toString().split(' ')[0]),
                if (isCompleted && order.finalPrice != null)
                  _DetailRow(label: 'السعر النهائي', value: '${order.finalPrice} ج.م', isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'واتساب الدعم الفني',
            onTap: () => launchUrl(Uri.parse('https://wa.me/201012121211')),
            variant: ButtonVariant.ghost,
            icon: Icons.help_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildETA(DateTime eta) {
    final diff = eta.difference(DateTime.now());
    final minutes = diff.inMinutes;
    
    if (minutes <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom:AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الوقت المتوقع للوصول', style: AppTextStyles.titleMed),
                Text(
                  'سيصل الفني خلال $minutes دقيقة تقريباً',
                  style: AppTextStyles.headlineMed.copyWith(color: AppColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingPrompt(Order order) {
    return AppCard(
      color: AppColors.success.withOpacity(0.05),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text('كيف كانت تجربتك؟', style: AppTextStyles.headlineMed),
          const SizedBox(height: AppSpacing.sm),
          Text('تقييمك يساعدنا في تحسين جودة خدماتنا', style: AppTextStyles.bodyMed),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                  size: 32,
                ),
                onPressed: () => setState(() => _selectedRating = index + 1),
              );
            }),
          ),
          if (_selectedRating > 0) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _commentController,
              label: 'أضف تعليقاً (اختياري)',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'إرسال التقييم',
              isLoading: _isRating,
              onTap: () => _submitRating(order.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSummary(Order order) {
    return AppCard(
      color: AppColors.surface2,
      child: Row(
        children: [
          const Icon(Icons.stars, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Text('تقييمك للخدمة: ', style: AppTextStyles.titleMed),
          ...List.generate(5, (index) => Icon(
            index < order.rating! ? Icons.star : Icons.star_border,
            color: AppColors.gold,
            size: 16,
          )),
        ],
      ),
    );
  }

  Widget _buildLogsTimeline(List<OrderLog> logs) {
    return Column(
      children: logs.map((log) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: AppColors.surface2,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.message ?? log.status.label,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final Order order;
  final bool isCancelled;
  const _StatusHeader({required this.order, required this.isCancelled});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: isCancelled ? AppColors.error.withOpacity(0.1) : AppColors.surface2,
      child: Column(
        children: [
          Icon(
            isCancelled ? Icons.cancel_outlined : (order.status == OrderStatus.completed ? Icons.verified : Icons.sync),
            size: 48,
            color: isCancelled ? AppColors.error : (order.status == OrderStatus.completed ? AppColors.success : AppColors.gold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isCancelled ? 'تم إلغاء الطلب' : 'الطلب ${order.status.label}',
            style: AppTextStyles.headlineLarge.copyWith(
              color: isCancelled ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final String title;
  final IconData icon;
  final bool isDone;
  final bool isActive;
  _StepData({required this.title, required this.icon, required this.isDone, this.isActive = false});
}

class _StepperRow extends StatelessWidget {
  final _StepData step;
  final bool isLast;
  final Animation<double> pulseAnimation;

  const _StepperRow({required this.step, required this.isLast, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final color = step.isDone ? AppColors.gold : (step.isActive ? AppColors.gold : AppColors.textMuted);
    
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              ScaleTransition(
                scale: step.isActive ? pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(step.isDone || step.isActive ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(step.isDone ? Icons.check : step.icon, size: 16, color: color),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.isDone ? AppColors.gold : AppColors.surface2,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTextStyles.titleMed.copyWith(
                    color: step.isDone || step.isActive ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: step.isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCopyable;
  final bool isHighlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isCopyable = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          if (isHighlight)
            Text(value, style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold))
          else
            Text(value, style: AppTextStyles.bodyLarge),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الكود')),
                );
              },
            ),
        ],
      ),
    );
  }
}
