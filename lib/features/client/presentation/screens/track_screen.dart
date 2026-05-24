import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';

class TrackScreen extends ConsumerWidget {
  final String code;
  const TrackScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersStream = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع حالة الطلب')),
      body: ordersStream.when(
        data: (orders) {
          final order = orders.where((o) => o.trackingCode == code).firstOrNull;
          if (order == null) return _buildNotFound(context);
          return _buildOrderTrackingBody(context, ref, order);
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(
          message: 'خطأ في التتبع',
          error: e,
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildOrderTrackingBody(BuildContext context, WidgetRef ref, Order order) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
    final tech = techs.where((t) => t.id == order.techId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          if (order.status == OrderStatus.completed && order.rating == null)
             _RatingCard(order: order),
          
          const SizedBox(height: AppSpacing.md),
          _StatusCard(status: order.status),
          const SizedBox(height: AppSpacing.xl),
          if (tech != null) _TechInfoCard(tech: tech),
          const SizedBox(height: AppSpacing.xl),
          _OrderTimeline(currentStatus: order.status),
          const SizedBox(height: AppSpacing.xxl),
          _OrderDetailsCard(order: order),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('عذراً، لم نجد طلباً بهذا الكود'),
          const SizedBox(height: 16),
          AppButton(
            label: 'العودة للرئيسية',
            onTap: () => context.go('/'),
            variant: ButtonVariant.ghost,
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  final Order order;
  const _RatingCard({required this.order});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  final List<String> _selectedReasons = [];
  bool _isSubmitting = false;

  final List<String> _lowRatingReasons = [
    'تأخير عن الموعد',
    'سعر مرتفع جداً',
    'تعامل غير مريح',
    'جودة عمل ضعيفة',
    'عدم الاهتمام بالنظافة',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.gold.withValues(alpha: 0.1),
      child: Column(
        children: [
          Text('كيف كانت تجربتك مع الفني؟', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                  size: 32,
                ),
                onPressed: () => setState(() {
                  _selectedRating = index + 1;
                  if (_selectedRating > 3) _selectedReasons.clear();
                }),
              );
            }),
          ),
          
          // إظهار الأسباب لو التقييم 3 نجوم أو أقل
          if (_selectedRating > 0 && _selectedRating <= 3) ...[
            const SizedBox(height: 16),
            const Text('ما الذي لم يعجبك؟ (يمكنك اختيار أكثر من سبب)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _lowRatingReasons.map((reason) {
                final isSelected = _selectedReasons.contains(reason);
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      val ? _selectedReasons.add(reason) : _selectedReasons.remove(reason);
                    });
                  },
                  selectedColor: AppColors.gold.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.gold : AppColors.textPrimary,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],

          if (_selectedRating > 0) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'اكتب رأيك هنا (اختياري)...',
                fillColor: AppColors.surface1,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Consumer(builder: (context, ref, child) {
              return AppButton(
                label: 'إرسال التقييم',
                isLoading: _isSubmitting,
                onTap: () async {
                  setState(() => _isSubmitting = true);
                  
                  // دمج الأسباب مع التعليق
                  String finalComment = _commentController.text.trim();
                  if (_selectedReasons.isNotEmpty) {
                    finalComment = '[${_selectedReasons.join(" - ")}] $finalComment';
                  }

                  await ref.read(adminActionsProvider).rateOrder(
                    widget.order.id, 
                    _selectedRating,
                    comment: finalComment,
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('شكراً لتقييمك! نحن نهتم برأيك جداً')),
                    );
                  }
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final OrderStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.gold.withValues(alpha: 0.05),
      child: Column(
        children: [
          Text('حالة طلبك الآن', style: AppTextStyles.bodyMed),
          const SizedBox(height: 8),
          Text(
            status.label,
            style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _TechInfoCard extends StatelessWidget {
  final dynamic tech;
  const _TechInfoCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.surface1,
            child: Text(tech.spec.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الفني القادم إليك', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
                Text(tech.name, style: AppTextStyles.titleLarge),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.success),
            onPressed: () => launchUrl(Uri.parse('tel:${tech.phone}')),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final OrderStatus currentStatus;
  const _OrderTimeline({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final stages = [
      OrderStatus.pending,
      OrderStatus.assigned,
      OrderStatus.onTheWay,
      OrderStatus.started,
      OrderStatus.completed,
    ];

    return Column(
      children: stages.map((stage) {
        final isDone = stages.indexOf(currentStatus) >= stages.indexOf(stage);
        final isCurrent = currentStatus == stage;
        
        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.gold : AppColors.surface3,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: isDone ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
                ),
                if (stage != OrderStatus.completed)
                  Container(width: 2, height: 30, color: isDone ? AppColors.gold : AppColors.surface3),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              stage.label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDone ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  final Order order;
  const _OrderDetailsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل الطلب', style: AppTextStyles.titleLarge),
          const Divider(height: 24),
          _row('نوع الخدمة', order.service.label),
          _row('كود التتبع', order.trackingCode),
          _row('تاريخ الطلب', order.createdAt.toString().split(' ')[0]),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMed),
          Text(value, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
