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
import '../providers/client_screen_providers.dart';

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

              if (order.status == OrderStatus.completed) ...[
                _WarrantyBadgeCard(order: order),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (order.status == OrderStatus.cancelled && order.techNotes != null && order.techNotes!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اعتذر الفني عن قبول الطلب ❌',
                              style: AppTextStyles.titleLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.techNotes!,
                              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'يمكنك اختيار فني آخر أو تقديم طلب جديد عبر التطبيق.',
                              style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              
              if (order.completionImages.isNotEmpty) ...[
                _buildCompletionGallery(context, order.completionImages),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (tech != null) _TechInfoCard(tech: tech, orderStatus: order.status),
              
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

class _RatingCard extends ConsumerStatefulWidget {
  final Order order;
  const _RatingCard({required this.order});

  @override
  ConsumerState<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<_RatingCard> {
  final _commentController = TextEditingController();

  final List<String> _lowRatingReasons = [
    'تأخير عن الموعد',
    'سعر مرتفع جداً',
    'تعامل غير مريح',
    'جودة عمل ضعيفة',
    'عدم الاهتمام بالنظافة',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRating = ref.watch(ratingSelectedStarsProvider);
    final isSubmitting = ref.watch(ratingSubmittingProvider);
    final selectedReasons = ref.watch(ratingSelectedReasonsProvider);

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
                  index < selectedRating ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                  size: 32,
                ),
                onPressed: () {
                  ref.read(ratingSelectedStarsProvider.notifier).state = index + 1;
                  if (index + 1 > 3) ref.read(ratingSelectedReasonsProvider.notifier).state = [];
                },
              );
            }),
          ),
          
          if (selectedRating > 0 && selectedRating <= 3) ...[
            const SizedBox(height: 16),
            const Text('ما الذي لم يعجبك؟', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _lowRatingReasons.map((reason) {
                final isSelected = selectedReasons.contains(reason);
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      ref.read(ratingSelectedReasonsProvider.notifier).state = [...selectedReasons, reason];
                    } else {
                      ref.read(ratingSelectedReasonsProvider.notifier).state = selectedReasons.where((r) => r != reason).toList();
                    }
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

          if (selectedRating > 0) ...[
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
            AppButton(
              label: 'إرسال التقييم',
              isLoading: isSubmitting,
              onTap: () async {
                ref.read(ratingSubmittingProvider.notifier).state = true;
                String finalComment = _commentController.text.trim();
                if (selectedReasons.isNotEmpty) {
                  finalComment = '[${selectedReasons.join(" - ")}] $finalComment';
                }

                final messenger = ScaffoldMessenger.of(context);
                await ref.read(adminActionsProvider).rateOrder(
                  widget.order.id, 
                  selectedRating,
                  comment: finalComment,
                );
                
                if (mounted) {
                  ref.read(ratingSubmittingProvider.notifier).state = false;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('شكراً لتقييمك! نحن نهتم برأيك جداً')),
                  );
                }
              },
            ),
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
          const SizedBox(height: 6),
          Text(
            status.label,
            style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, fontSize: 24),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stepItem('تم الاستلام', Icons.assignment_turned_in_outlined, status == OrderStatus.pending || status == OrderStatus.assigned || status == OrderStatus.onTheWay || status == OrderStatus.started || status == OrderStatus.completed),
              _stepLine(status == OrderStatus.onTheWay || status == OrderStatus.started || status == OrderStatus.completed),
              _stepItem('في الطريق', Icons.directions_run_outlined, status == OrderStatus.onTheWay || status == OrderStatus.started || status == OrderStatus.completed),
              _stepLine(status == OrderStatus.started || status == OrderStatus.completed),
              _stepItem('جاري التنفيذ', Icons.build_outlined, status == OrderStatus.started || status == OrderStatus.completed),
              _stepLine(status == OrderStatus.completed),
              _stepItem('مكتمل 🛡️', Icons.verified_user_outlined, status == OrderStatus.completed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepItem(String label, IconData icon, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surface2,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppColors.gold : AppColors.borderSubtle, width: 1.5),
          ),
          child: Icon(icon, size: 18, color: isActive ? AppColors.gold : AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppColors.gold : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? AppColors.gold : AppColors.borderSubtle,
      ),
    );
  }
}

class _WarrantyBadgeCard extends StatelessWidget {
  final Order order;
  const _WarrantyBadgeCard({required this.order});

  void _openWarrantyComplaintWhatsApp() {
    final message = Uri.encodeComponent(
      'مرحباً فريق دعم حرفي 🛡️\nأريد تقديم استفسار / شكوى حول ضمان الصيانة للطلب رقم: *${order.trackingCode}*\nالخدمة: ${order.service.label}\nاسم العميل: ${order.clientName}'
    );
    final url = Uri.parse('https://wa.me/201014250577?text=$message');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = order.isWarrantyActive;
    final remainingDays = order.warrantyRemainingDays;

    return AppCard(
      color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success.withValues(alpha: 0.2) : AppColors.surface3,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.shield_rounded : Icons.shield_outlined,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'ضمان الصيانة 30 يوم مفعّل 🛡️' : 'فترة الضمان انتهت 🛡️',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isActive ? AppColors.success : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isActive 
                        ? 'متبقي $remainingDays يوم في ضمان الصيانة ضد عيوب التصليح.'
                        : 'انتهت فترة الضمان لهذه الخدمة (كانت سارية لمدة 30 يوم).',
                      style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            AppButton(
              label: 'تقديم شكوى / طلب ضمان عبر واتساب 🛡️',
              icon: Icons.chat_rounded,
              variant: ButtonVariant.success,
              onTap: _openWarrantyComplaintWhatsApp,
            ),
          ],
        ],
      ),
    );
  }
}

class _TechInfoCard extends StatelessWidget {
  final dynamic tech;
  final OrderStatus orderStatus;
  const _TechInfoCard({required this.tech, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    final bool isWaitingApproval = orderStatus == OrderStatus.assigned;
    
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.surface1,
            backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl) : null,
            child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWaitingApproval ? 'الفني المختار' : 'الفني القادم إليك', 
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)
                ),
                Text(tech.name, style: AppTextStyles.titleLarge),
              ],
            ),
          ),
          if (!isWaitingApproval)
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
          _row('تاريخ الطلب', intl.DateFormat('d MMM yyyy').format(order.createdAt)),
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
