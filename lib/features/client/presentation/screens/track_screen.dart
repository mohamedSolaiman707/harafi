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
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../admin/presentation/providers/warranty_claims_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/order_messages_provider.dart';
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
                if (order.finalPrice != null) _InvoiceCard(order: order),
                if (order.finalPrice != null) const SizedBox(height: AppSpacing.xl),
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

              if (order.status == OrderStatus.completed) ...[
                const SizedBox(height: AppSpacing.xl),
                _WarrantyBannerAndButton(order: order),
              ],

              if (order.status != OrderStatus.pending && order.status != OrderStatus.cancelled) ...[
                const SizedBox(height: AppSpacing.xl),
                _buildLiveChatButton(context, order),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveChatButton(BuildContext context, Order order) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderLiveChatSheet(
          order: order,
          senderType: 'client',
          senderName: order.clientName,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black, size: 22),
            const SizedBox(width: 8),
            Text(
              'تواصل مع الفني مباشرة 💬',
              style: AppTextStyles.titleMed.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
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
    final dateStr = order.scheduledDate != null
        ? intl.DateFormat('EEEE، d MMMM yyyy').format(order.scheduledDate!)
        : null;

    return AppCard(
      color: AppColors.surface3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل الطلب', style: AppTextStyles.titleLarge),
          const Divider(height: 24),
          _row('نوع الخدمة', order.service.label),
          _row('كود التتبع', order.trackingCode),
          _row('نوع الطلب', order.isScheduled ? 'حجز مجدول مسبقاً 📅' : 'طلب فوري (الآن) ⚡'),
          if (order.isScheduled && dateStr != null)
            _row('الموعد المحدّد', dateStr),
          if (order.isScheduled && order.preferredTimeSlot != null && order.preferredTimeSlot!.isNotEmpty)
            _row('الفترة الزمنية', order.preferredTimeSlot!),
          _row('تاريخ تقديم الطلب', intl.DateFormat('d MMM yyyy • HH:mm').format(order.createdAt)),
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
          Text(value, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Order order;
  const _InvoiceCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasBreakdown = order.inspectionFee != null || order.laborFee != null || order.partsFee != null;
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text('فاتورة الخدمة', style: AppTextStyles.titleLarge.copyWith(color: AppColors.success)),
          ]),
          const SizedBox(height: 16),

          if (hasBreakdown) ...[
            if ((order.inspectionFee ?? 0) > 0)
              _invoiceRow('رسوم الكشف والمعاينة', '${order.inspectionFee} ج.م'),
            if ((order.laborFee ?? 0) > 0)
              _invoiceRow('مصنعية الفني', '${order.laborFee} ج.م'),
            if ((order.partsFee ?? 0) > 0)
              _invoiceRow('قطع الغيار', '${order.partsFee} ج.م'),
            const Divider(height: 20),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('الاجمالي المدفوع', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              Text('${order.finalPrice} ج.م', style: AppTextStyles.headlineMed.copyWith(color: AppColors.success, fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _WarrantyBannerAndButton extends ConsumerWidget {
  final Order order;
  const _WarrantyBannerAndButton({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(warrantyClaimsStreamProvider);
    final isWarrantyValid = order.warrantyUntil.isAfter(DateTime.now());

    return claimsAsync.when(
      data: (claims) {
        final existingClaim = claims.where((c) => c.orderId == order.id).firstOrNull;

        return AppCard(
          color: AppColors.success.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ضمان حرفي المالي المفعّل 🛡️',
                          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'محتفظ بضمان مجاني حتى ${intl.DateFormat('d MMMM yyyy').format(order.warrantyUntil)}',
                          style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (existingClaim != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم تقديم مطالبة ضمان سابقة بحالة (${existingClaim.status == 'pending' ? "قيد المراجعة ⏱️" : existingClaim.status == 'resolved' ? "تمت المعالجة 🟢" : "مرفوضة 🔴"})',
                          style: AppTextStyles.labelMed.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isWarrantyValid) ...[
                AppButton(
                  label: 'تقديم مطالبة ضمان / إعادة زيارة 🛡️',
                  icon: Icons.assignment_return_rounded,
                  variant: ButtonVariant.ghost,
                  onTap: () => _showClaimModal(context, ref),
                ),
              ] else ...[
                Text(
                  'انتهت فترة الضمان لهذه الخدمة (30 يوماً).',
                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  void _showClaimModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WarrantyClaimSheet(order: order),
    );
  }
}

class _WarrantyClaimSheet extends ConsumerStatefulWidget {
  final Order order;
  const _WarrantyClaimSheet({required this.order});

  @override
  ConsumerState<_WarrantyClaimSheet> createState() => _WarrantyClaimSheetState();
}

class _WarrantyClaimSheetState extends ConsumerState<_WarrantyClaimSheet> {
  final _descController = TextEditingController();
  final List<String> _images = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final storage = StorageService();
      final url = await storage.uploadImage(
        image: image,
        path: 'warranty_claims',
        fileName: 'claim_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (url != null) {
        setState(() => _images.add(url));
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitClaim() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى شرح سبب المطالبة أو المشكلة المترتبة')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final claimData = {
        'order_id': widget.order.id,
        'tracking_code': widget.order.trackingCode,
        'client_name': widget.order.clientName,
        'client_phone': widget.order.clientPhone,
        'tech_id': widget.order.techId,
        'issue_description': desc,
        'claim_images': _images,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('warranty_claims').insert(claimData);
      ref.invalidate(warrantyClaimsStreamProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تقديم مطالبة الضمان بنجاح! ستتواصل معك الإدارة فوراً 🛡️')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: AppColors.success, size: 24),
                    const SizedBox(width: 8),
                    Text('تقديم مطالبة ضمان مجانية 🛡️', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'طلب رقم: ${widget.order.trackingCode} • الخدمة: ${widget.order.service.label}',
              style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'شرح المشكلة التي ظهرت بعد الصيانة',
                hintText: 'مثال: التسريب عاد مرة أخرى بعد يومين من الإصلاح...',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Text('صور إثبات المشكلة (اختياري):', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._images.map((url) => Container(
                        width: 70, height: 70,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                        ),
                      )),
                  if (_isUploading)
                    const SizedBox(width: 70, height: 70, child: Center(child: CircularProgressIndicator()))
                  else
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined, color: AppColors.gold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'إرسال مطالبة الضمان',
              onTap: _submitClaim,
              isLoading: _isSubmitting,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderLiveChatSheet extends ConsumerStatefulWidget {
  final Order order;
  final String senderType;
  final String senderName;

  const _OrderLiveChatSheet({
    required this.order,
    required this.senderType,
    required this.senderName,
  });

  @override
  ConsumerState<_OrderLiveChatSheet> createState() => _OrderLiveChatSheetState();
}

class _OrderLiveChatSheetState extends ConsumerState<_OrderLiveChatSheet> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _msgController.clear();
    try {
      await sendOrderMessage(
        orderId: widget.order.id,
        senderType: widget.senderType,
        senderName: widget.senderName,
        message: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _msgController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgsAsync = ref.watch(orderMessagesStreamProvider(widget.order.id));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.12), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: const Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('محادثة مباشرة', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                        Row(children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('متصل • طلب ${widget.order.trackingCode}', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ─── Messages List ────────────────────────────────────
            Expanded(
              child: msgsAsync.when(
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded, size: 42, color: AppColors.gold),
                          ),
                          const SizedBox(height: 16),
                          Text('لا توجد رسائل بعد', style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('ابدأ المحادثة مع الفني الآن 👋', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final msg = msgs[i];
                      final isMe = msg.senderType == widget.senderType;
                      final showAvatar = i == 0 || msgs[i - 1].senderType != msg.senderType;
                      final initials = msg.senderName.isNotEmpty ? msg.senderName[0] : '؟';
                      return _ChatBubble(
                        message: msg.message,
                        senderName: msg.senderName,
                        time: intl.DateFormat('HH:mm').format(msg.createdAt),
                        isMe: isMe,
                        showAvatar: showAvatar,
                        initials: initials,
                        accentColor: AppColors.gold,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (e, _) => Center(
                  child: Text('خطأ في تحميل الرسائل', style: AppTextStyles.bodyMed.copyWith(color: AppColors.error)),
                ),
              ),
            ),

            // ─── Input Bar ────────────────────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                border: const Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.8)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: TextField(
                        controller: _msgController,
                        textDirection: TextDirection.rtl,
                        maxLines: 4,
                        minLines: 1,
                        style: AppTextStyles.bodyMed,
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك للفني...',
                          hintStyle: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isSending ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: _isSending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                          : const Icon(Icons.send_rounded, color: Colors.black, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// فقاعة رسالة واحدة مع أفاتار
class _ChatBubble extends StatelessWidget {
  final String message;
  final String senderName;
  final String time;
  final bool isMe;
  final bool showAvatar;
  final String initials;
  final Color accentColor;

  const _ChatBubble({
    required this.message,
    required this.senderName,
    required this.time,
    required this.isMe,
    required this.showAvatar,
    required this.initials,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // أفاتار الطرف الآخر (على اليسار)
          if (!isMe) ...[
            if (showAvatar)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF37474F),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderDefault, width: 1.5),
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              )
            else
              const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],

          // فقاعة الرسالة
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isMe ? accentColor : AppColors.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe ? accentColor.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showAvatar) ...[
                    Text(
                      senderName,
                      style: TextStyle(
                        color: isMe ? Colors.black.withValues(alpha: 0.6) : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.black : AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.black.withValues(alpha: 0.45) : AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // أفاتار المرسل (على اليمين)
          if (isMe) ...[
            const SizedBox(width: 8),
            if (showAvatar)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.7)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              )
            else
              const SizedBox(width: 34),
          ],
        ],
      ),
    );
  }
}
