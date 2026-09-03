import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';
import '../../../admin/presentation/providers/order_messages_provider.dart';
import '../providers/tech_screen_providers.dart';

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
        if (order == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود ⚠️')));
        return Scaffold(
          appBar: AppBar(title: Text('طلب #${order.trackingCode}')),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersStreamProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusBanner(status: order.status),
                      if (order.status == OrderStatus.assigned) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ResponseDeadlineCard(order: order),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _buildScheduleInfo(order),
                      const SizedBox(height: AppSpacing.lg),
                      _buildClientInfo(order),
                      const SizedBox(height: AppSpacing.xl),
                      _buildOrderDescription(order),
                      
                      if (order.completionImages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _buildCompletionImages(context, order.completionImages),
                      ],

                      if (order.techNotes != null && order.techNotes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _buildTechReport(order),
                      ],
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildLiveChatButton(context, order),
                      const SizedBox(height: AppSpacing.lg),
                      _buildActionButtons(context, ref, order),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, s) => Scaffold(
        body: AppErrorWidget(
          message: AppErrorHandler.translate(e),
          error: e,
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildCompletionImages(BuildContext context, List<String> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text('صور إثبات العمل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _showFullScreenImage(context, images[index]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppColors.surface2,
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  },
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                      const SizedBox(height: 4),
                      Text('فشل التحميل', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context, 
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, 
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url, errorBuilder: (c,e,s) => const Center(child: Text('عذراً، تعذر تحميل الصورة 🖼️', style: TextStyle(color: Colors.white))))),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfo(Order order) {
    final isScheduled = order.isScheduled;
    final dateStr = order.scheduledDate != null
        ? intl.DateFormat('EEEE، d MMMM yyyy').format(order.scheduledDate!)
        : null;

    return AppCard(
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isScheduled
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isScheduled
                      ? AppColors.gold.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isScheduled ? Icons.event_available_rounded : Icons.flash_on_rounded,
                color: isScheduled ? AppColors.gold : AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isScheduled ? 'طلب مجدول مسبقاً' : 'طلب صيانة فوري (الآن)',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isScheduled ? AppColors.gold : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isScheduled ? '📅' : '⚡',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isScheduled) ...[
                    Text(
                      'الموعد: ${dateStr ?? "غير محدد"}',
                      style: AppTextStyles.bodyMed.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (order.preferredTimeSlot != null && order.preferredTimeSlot!.isNotEmpty)
                      Text(
                        'الفترة الزمنية: ${order.preferredTimeSlot}',
                        style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                      ),
                  ] else ...[
                    Text(
                      'العميل يحتاج الفني في أسرع وقت ممكن',
                      style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بيانات العميل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              const Icon(Icons.person_pin_outlined, color: AppColors.gold, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyLarge)),
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'واتساب',
                  icon: Icons.chat,
                  variant: ButtonVariant.whatsapp,
                  onTap: () {
                    final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}، أنا الفني من حرفي وبخصوص طلبك...');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'التوجه للموقع على الخريطة 🗺️',
            icon: Icons.map_outlined,
            variant: ButtonVariant.ghost,
            onTap: () => MapUtils.openMapWithAddress(order.area ?? 'كفر الزيات'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Text(
              order.description ?? 'لا يوجد وصف مضاف',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.build_circle_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: 12),
              Text('نوع الخدمة: ', style: AppTextStyles.labelLarge),
              Text(order.service.label, style: AppTextStyles.titleMed.copyWith(color: AppColors.gold)),
            ],
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
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: 12),
              Text('تقرير الإنجاز المالي', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.techNotes!, style: AppTextStyles.bodyLarge.copyWith(height: 1.5)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ الإجمالي المحصل:', style: AppTextStyles.bodyLarge),
              Text('${order.finalPrice} ج.م', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    final isResponseExpired = order.status == OrderStatus.assigned && _isResponseExpired(order);

    if (order.status == OrderStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 12),
              Text('تم إنجاز هذا الطلب وإغلاقه بنجاح', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
        ),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text('اعتذرت عن قبول هذا الطلب أو تم إلغاؤه', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
            if (order.techNotes != null && order.techNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(order.techNotes!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned) ...[
          AppButton(
            label: isResponseExpired ? 'انتهت مهلة الرد' : 'أنا في الطريق للعميل الآن 🚴',
            icon: Icons.directions_bike,
            onTap: isResponseExpired
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('انتهت مهلة قبول الطلب، برجاء الاعتذار أو التواصل مع الدعم')),
                    );
                  }
                : () async {
                    final res = await ref.read(adminActionsProvider).updateOrderStatus(
                      order,
                      OrderStatus.onTheWay,
                      logMessage: 'الفني تحرك الآن وهو في طريقه إليك',
                    );
                    res.when(
                      left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                      right: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بالتوفيق! العميل في انتظارك ⏱️'))),
                    );
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'اعتذار عن قبول الطلب ❌',
            icon: Icons.cancel_outlined,
            variant: ButtonVariant.ghost,
            onTap: () => _showRejectionSheet(context, ref, order),
          ),
        ],

        if (order.status == OrderStatus.onTheWay)
          AppButton(
            label: 'وصلت للعميل (بدء العمل)',
            icon: Icons.play_arrow,
            onTap: () async {
              final res = await ref.read(adminActionsProvider).updateOrderStatus(
                order, 
                OrderStatus.started,
                logMessage: 'وصل الفني لموقع العميل وبدأ في تنفيذ المهمة',
              );
              res.when(
                left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                right: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأت المهمة، بالتوفيق يا بشمهندس! 🛠️')))
              );
            },
          ),

        if (order.status == OrderStatus.started)
          AppButton(
            label: 'تم الإنجاز (إغلاق المهمة)',
            icon: Icons.check_circle,
            variant: ButtonVariant.success,
            onTap: () => _showCompletionSheet(context, ref, order),
          ),
      ],
    );
  }

  void _showRejectionSheet(BuildContext context, WidgetRef ref, Order order) {
    final width = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => _RejectionSheet(order: order),
    );
  }

  void _showCompletionSheet(BuildContext context, WidgetRef ref, Order order) {
    final width = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => _CompletionSheet(order: order),
    );
  }

  bool _isResponseExpired(Order order) {
    final assignedAt = order.logs
        .where((log) => log.status == OrderStatus.assigned)
        .map((log) => log.timestamp)
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });

    if (assignedAt == null) return false;
    return DateTime.now().isAfter(assignedAt.add(const Duration(minutes: 3)));
  }

  Widget _buildLiveChatButton(BuildContext context, Order order) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TechOrderLiveChatSheet(
          order: order,
          senderType: 'tech',
          senderName: 'الفني',
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.info, AppColors.info.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'تواصل مع العميل مباشرة 💬',
              style: AppTextStyles.titleMed.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechOrderLiveChatSheet extends ConsumerStatefulWidget {
  final Order order;
  final String senderType;
  final String senderName;
  const _TechOrderLiveChatSheet({required this.order, required this.senderType, required this.senderName});

  @override
  ConsumerState<_TechOrderLiveChatSheet> createState() => _TechOrderLiveChatSheetState();
}

class _TechOrderLiveChatSheetState extends ConsumerState<_TechOrderLiveChatSheet> {
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
            // ─── Drag Handle ─────────────────────────────────────
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

            // ─── Header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.info.withValues(alpha: 0.12), Colors.transparent],
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
                      color: AppColors.info,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('محادثة مع العميل', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
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
                              color: AppColors.info.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded, size: 42, color: AppColors.info),
                          ),
                          const SizedBox(height: 16),
                          Text('لا توجد رسائل بعد', style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('ابدأ المحادثة مع العميل الآن 👋', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
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
                      return _TechChatBubble(
                        message: msg.message,
                        senderName: msg.senderName,
                        time: intl.DateFormat('HH:mm').format(msg.createdAt),
                        isMe: isMe,
                        showAvatar: showAvatar,
                        initials: initials,
                        accentColor: AppColors.info,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.info)),
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
                          hintText: 'اكتب رسالتك للعميل...',
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
                        color: AppColors.info,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: _isSending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
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

class _TechChatBubble extends StatelessWidget {
  final String message;
  final String senderName;
  final String time;
  final bool isMe;
  final bool showAvatar;
  final String initials;
  final Color accentColor;

  const _TechChatBubble({
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
                        color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.55) : AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            if (showAvatar)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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


class _ResponseDeadlineCard extends StatelessWidget {
  final Order order;
  const _ResponseDeadlineCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final assignedAt = order.logs
        .where((log) => log.status == OrderStatus.assigned)
        .map((log) => log.timestamp)
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });

    final deadline = assignedAt?.add(const Duration(minutes: 3));
    final remaining = deadline?.difference(DateTime.now());
    final isExpired = remaining?.isNegative ?? false;

    final text = deadline == null
        ? 'لا توجد مهلة رد مسجلة لهذا الطلب'
        : isExpired
            ? 'انتهت مهلة الرد، ويجب التواصل مع الدعم أو الاعتذار عن الطلب'
            : 'متبقي ${remaining!.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')} للرد على الطلب';

    return AppCard(
      color: isExpired ? AppColors.error.withValues(alpha: 0.08) : AppColors.info.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(isExpired ? Icons.warning_amber_rounded : Icons.timer_outlined, color: isExpired ? AppColors.error : AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMed.copyWith(
                color: isExpired ? AppColors.error : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionSheet extends ConsumerStatefulWidget {
  final Order order;
  const _CompletionSheet({required this.order});

  @override
  ConsumerState<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends ConsumerState<_CompletionSheet> {
  final _inspectionFeeController = TextEditingController();
  final _laborFeeController = TextEditingController();
  final _partsFeeController = TextEditingController();
  final _notesController = TextEditingController();
  final _actualDiagnosisController = TextEditingController();
  final _repairActionController = TextEditingController();
  final _partsController = TextEditingController();
  final _picker = ImagePicker();
  bool _firstVisitFix = true;
  bool _repeatIssue = false;
  bool _warrantyClaimed = false;

  int get _totalFee {
    final inspection = int.tryParse(_inspectionFeeController.text) ?? 0;
    final labor = int.tryParse(_laborFeeController.text) ?? 0;
    final parts = int.tryParse(_partsFeeController.text) ?? 0;
    return inspection + labor + parts;
  }

  @override
  void initState() {
    super.initState();
    _inspectionFeeController.addListener(() => setState(() {}));
    _laborFeeController.addListener(() => setState(() {}));
    _partsFeeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inspectionFeeController.dispose();
    _laborFeeController.dispose();
    _partsFeeController.dispose();
    _notesController.dispose();
    _actualDiagnosisController.dispose();
    _repairActionController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  void _showCongratulationDialog(BuildContext context, Order order, int finalPrice) {
    final width = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface1,
        insetPadding: EdgeInsets.symmetric(horizontal: width > 600 ? (width - 500) / 2 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: AppColors.gold, width: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: 20),
            Text('تهانينا يا بشمهندس! 🎉', textAlign: TextAlign.center, style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('تم تسجيل إتمام المهمة بنجاح، وتفعيل ضمان الصيانه للعميل ✨', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text('$finalPrice ج.م', style: AppTextStyles.headlineMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
          ],
        ),
        actions: [
          AppButton(label: 'لوحة التحكم 🏠', onTap: () { Navigator.pop(dialogContext); context.go('/tech/dashboard'); }),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1000);
    if (images.isNotEmpty) {
      final currentImages = ref.read(techOrderCompletionImagesProvider);
      ref.read(techOrderCompletionImagesProvider.notifier).state = [...currentImages, ...images];
    }
  }

  Future<void> _submit() async {
    final inspection = int.tryParse(_inspectionFeeController.text);
    final labor = int.tryParse(_laborFeeController.text);
    if (_notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة تقرير العمل المنجز')));
      return;
    }
    if (inspection == null && labor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال رسوم الكشف أو المصنوعية على الأقل')));
      return;
    }
    final total = _totalFee;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الإجمالي يجب أن يكون أكبر من صفر')));
      return;
    }

    ref.read(techOrderSheetLoadingProvider.notifier).state = true;
    try {
      final storage = StorageService();
      final List<String> imageUrls = [];
      final selectedImages = ref.read(techOrderCompletionImagesProvider);
      for (var img in selectedImages) {
        final image = img as XFile;
        final url = await storage.uploadImage(image: image, path: 'order_completions', fileName: '${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}');
        if (url != null) imageUrls.add(url);
      }
      final outcomeData = {
        'technician_actual_diagnosis': _actualDiagnosisController.text.trim(),
        'repair_action_taken': _repairActionController.text.trim(),
        'first_visit_fix': _firstVisitFix,
        'repeat_issue': _repeatIssue,
        'warranty_claimed': _warrantyClaimed,
        'parts_used': _partsController.text.trim().isEmpty ? null : _partsController.text.trim(),
      };
      final res = await ref.read(adminActionsProvider).completeOrder(
        widget.order,
        finalPrice: total,
        inspectionFee: inspection ?? 0,
        laborFee: labor ?? 0,
        partsFee: int.tryParse(_partsFeeController.text) ?? 0,
        techNotes: _notesController.text.trim(),
        logMessage: 'تم إنجاز المهمة بنجاح، نتمنى أن نكون عند حسن ظنكم',
        outcomeData: outcomeData,
      );
      res.when(
        left: (f) => AppErrorHandler.showSnackBar(context, f.message),
        right: (_) async {
          if (imageUrls.isNotEmpty) {
            await ref.read(ordersRepositoryProvider).update(widget.order.id, {'completion_images': imageUrls});
          }
          if (mounted) { Navigator.of(context).pop(); _showCongratulationDialog(context, widget.order, total); }
        }
      );
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) ref.read(techOrderSheetLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(techOrderSheetLoadingProvider);
    final selectedImages = ref.watch(techOrderCompletionImagesProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('إغلاق الطلب وإثبات العمل', style: AppTextStyles.headlineMed),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 20),

            TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'تقرير العمل المنجز *', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(controller: _actualDiagnosisController, maxLines: 2, decoration: const InputDecoration(labelText: 'التشخيص الفعلي للمشكلة', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(controller: _repairActionController, maxLines: 2, decoration: const InputDecoration(labelText: 'الإجراء المتخذ', alignLabelWithHint: true)),
            const SizedBox(height: 20),

            // تفاصيل الفاتورة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                    Text('تفاصيل الفاتورة', style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: TextField(controller: _inspectionFeeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رسوم الكشف', prefixIcon: Icon(Icons.search_outlined), suffixText: 'ج.م'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _laborFeeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مصنعية الفني', prefixIcon: Icon(Icons.build_outlined), suffixText: 'ج.م'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _partsFeeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة قطع الغيار (ان وجدت)', prefixIcon: Icon(Icons.construction_outlined), suffixText: 'ج.م')),
                  const SizedBox(height: 12),
                  TextField(controller: _partsController, maxLines: 1, decoration: const InputDecoration(labelText: 'اسماء قطع الغيار المستخدمة', prefixIcon: Icon(Icons.list_alt_outlined))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('الاجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$_totalFee ج.م', style: AppTextStyles.headlineMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _firstVisitFix, onChanged: (v) => setState(() => _firstVisitFix = v), title: const Text('اتحلت من اول زيارة')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _repeatIssue, onChanged: (v) => setState(() => _repeatIssue = v), title: const Text('فيه احتمال رجوع نفس المشكلة')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _warrantyClaimed, onChanged: (v) => setState(() => _warrantyClaimed = v), title: const Text('تم فتح مطالبة ضمان')),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('صور العمل (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('اضافة صور')),
            ]),
            if (selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, index) {
                    final image = selectedImages[index] as XFile;
                    return Stack(alignment: Alignment.topRight, children: [
                      Container(width: 100, margin: const EdgeInsets.only(left: 8, top: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: FileImage(File(image.path)), fit: BoxFit.cover), border: Border.all(color: AppColors.borderDefault))),
                      IconButton(onPressed: () => ref.read(techOrderCompletionImagesProvider.notifier).state = [...selectedImages]..removeAt(index), icon: const CircleAvatar(radius: 10, backgroundColor: AppColors.error, child: Icon(Icons.close, size: 12, color: Colors.white))),
                    ]);
                  },
                ),
              ),
            const SizedBox(height: 32),
            AppButton(label: 'تاكيد انجاز المهمة', onTap: _submit, isLoading: isLoading, icon: Icons.done_all_rounded),
            const SizedBox(height: 32),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.info_outline, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(child: Text('حالة الطلب: ${status.label}', style: AppTextStyles.titleLarge.copyWith(color: color, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

class _RejectionSheet extends ConsumerStatefulWidget {
  final Order order;
  const _RejectionSheet({required this.order});
  @override
  ConsumerState<_RejectionSheet> createState() => _RejectionSheetState();
}

class _RejectionSheetState extends ConsumerState<_RejectionSheet> {
  final _reasonController = TextEditingController();
  @override
  void dispose() { _reasonController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(techOrderSheetLoadingProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('الاعتذار عن قبول الطلب', style: AppTextStyles.headlineMed.copyWith(color: AppColors.error)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'سبب الاعتذار (اختياري)')),
          const SizedBox(height: 24),
          AppButton(
            label: 'تاكيد الاعتذار',
            onTap: () async {
              ref.read(techOrderSheetLoadingProvider.notifier).state = true;
              final result = await ref.read(adminActionsProvider).rejectOrderByTech(widget.order, reason: _reasonController.text.trim());
              result.when(
                left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                right: (_) { Navigator.pop(context); context.go('/tech/dashboard'); }
              );
              ref.read(techOrderSheetLoadingProvider.notifier).state = false;
            },
            isLoading: isLoading,
            variant: ButtonVariant.ghost,
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}
