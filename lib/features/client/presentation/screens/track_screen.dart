import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
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
      appBar: AppBar(
        title: const Text('تتبع حالة الطلب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (order.status == OrderStatus.completed && order.rating == null)
                 _RatingCard(order: order),
              
              const SizedBox(height: AppSpacing.md),
              _StatusCard(status: order.status),
              const SizedBox(height: AppSpacing.xl),
              
              // عرض صور الإنجاز للعميل
              if (order.completionImages.isNotEmpty) ...[
                _buildCompletionGallery(context, order.completionImages),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (tech != null) _TechInfoCard(tech: tech),
              
              if (order.status == OrderStatus.pending || order.status == OrderStatus.assigned)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: TextButton.icon(
                    onPressed: () => _showCancelDialog(context, ref, order),
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 16),
                    label: const Text('إلغاء الطلب', style: TextStyle(color: AppColors.error)),
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),
              _OrderLogsSection(order: order),
              
              const SizedBox(height: AppSpacing.xxl),
              _OrderDetailsCard(order: order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionGallery(BuildContext context, List<String> images) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('صور إتمام العمل', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _showFullScreenImage(context, images[index]),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء طلب الخدمة'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء الطلب؟ لن نتمكن من إرسال الفني إليك بعد الإلغاء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(adminActionsProvider).cancelOrder(
                order, 
                logMessage: 'تم إلغاء الطلب بواسطة العميل',
              );
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء طلبك بنجاح')));
              }
            },
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
          ),
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

class _OrderLogsSection extends StatelessWidget {
  final Order order;
  const _OrderLogsSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final logs = order.logs.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('خطوات التنفيذ', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.xl),
          if (logs.isEmpty)
            const Text('جاري معالجة طلبك...')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isLast = index == logs.length - 1;
                final isFirst = index == 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isFirst ? AppColors.gold : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: AppColors.borderDefault,
                          ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    log.message ?? log.status.label,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: isFirst ? AppColors.textPrimary : AppColors.textSecondary,
                                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  intl.DateFormat('HH:mm').format(log.timestamp),
                                  style: AppTextStyles.labelMed,
                                ),
                              ],
                            ),
                            Text(
                              intl.DateFormat('d MMM yyyy').format(log.timestamp),
                              style: AppTextStyles.labelMed.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
          
          if (_selectedRating > 0 && _selectedRating <= 3) ...[
            const SizedBox(height: 16),
            const Text('ما الذي لم يعجبك؟', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
