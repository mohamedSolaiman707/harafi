import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/orders_provider.dart';
import '../providers/techs_provider.dart';
import '../providers/admin_actions_provider.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/technician.dart';
import '../../domain/business/order_lifecycle.dart';

class AdminOrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(ordersStreamProvider).whenData(
      (orders) => orders.where((o) => o.id == orderId).firstOrNull,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العملية'),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) return const Center(child: Text('الطلب غير موجود ⚠️'));
          return _buildBody(context, ref, order);
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(
          message: AppErrorHandler.translate(e),
          error: e,
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Order order) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
    final Technician? assignedTech = techs.where((t) => t.id == order.techId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMainInfo(context, order, assignedTech),
              const SizedBox(height: AppSpacing.xl),
              _buildLifecycleCard(order),
              const SizedBox(height: AppSpacing.xl),
              
              if (order.completionImages.isNotEmpty) ...[
                _buildCompletionGallery(context, order.completionImages),
                const SizedBox(height: AppSpacing.xl),
              ],

              _buildTimeline(order),
              const SizedBox(height: AppSpacing.xl),
              if (order.status == OrderStatus.completed) _buildCompletionReport(order),
              const SizedBox(height: AppSpacing.xxl),
              _buildAdminActions(context, ref, order),
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
              const Icon(Icons.camera_alt_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('صور إثبات الإنجاز', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _showFullScreenImage(context, images[index]),
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surface2,
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                    ),
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
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url, errorBuilder: (c,e,s) => const Center(child: Text('فشل تحميل الصورة')))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfo(BuildContext context, Order order, Technician? assignedTech) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('كود التتبع: ${order.trackingCode}', style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
              _StatusBadge(status: order.status),
            ],
          ),
          const Divider(height: 32),
          _infoRow(Icons.person, 'العميل', order.clientName),
          _infoRow(Icons.phone, 'رقم العميل', order.clientPhone),
          _infoRow(Icons.location_on, 'العنوان', order.area ?? 'غير محدد'),
          _infoRow(Icons.build, 'الخدمة', order.service.label),
          
          if (assignedTech != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.engineering, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                   Text('الفني المعين:', style: AppTextStyles.labelLarge),
                  const SizedBox(width: 8),
                  Text(assignedTech.name, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary)),
                  if (assignedTech.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: AppColors.info, size: 16),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 16),
          Text('وصف المشكلة:', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(order.description ?? 'لا يوجد وصف', style: AppTextStyles.bodyLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleCard(Order order) {
    final phase = order.lifecyclePhase;
    final (title, subtitle, color) = switch (phase) {
      OrderLifecyclePhase.newRequest => ('طلب جديد', 'تم استلام الطلب وما زال في بداية المسار.', AppColors.gold),
      OrderLifecyclePhase.awaitingTechnicianResponse => ('بانتظار الفني', 'الطلب تم إرساله أو تعيينه وما زال ينتظر التفاعل.', AppColors.info),
      OrderLifecyclePhase.technicianAccepted => ('تم القبول', 'الفني وافق على الطلب وبدأت المتابعة.', AppColors.info),
      OrderLifecyclePhase.technicianOnTheWay => ('في الطريق', 'الفني متحرك الآن إلى موقع العميل.', Colors.orange),
      OrderLifecyclePhase.technicianArrived => ('الوصول', 'الفني وصل للموقع وجاهز للمعاينة.', Colors.orange),
      OrderLifecyclePhase.inProgress => ('جاري التنفيذ', 'الإصلاح أو التنفيذ بدأ فعليًا.', Colors.blue),
      OrderLifecyclePhase.readyToComplete => ('جاهز للإغلاق', 'العملية اقتربت من الإنهاء وتحتاج تأكيدًا أخيرًا.', AppColors.success),
      OrderLifecyclePhase.completed => ('مكتمل', 'تم إنهاء الطلب بنجاح.', AppColors.success),
      OrderLifecyclePhase.cancelled => ('ملغي', 'تم إيقاف الطلب ولن يستكمل.', AppColors.error),
    };

    return AppCard(
      color: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleLarge.copyWith(color: color)),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Text(
            'الحالة الحالية: ${order.status.label}',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Order order) {
    final logs = order.logs.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سجل الأحداث (Logs)', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.xl),
          if (logs.isEmpty) const Text('لا يوجد سجل أحداث متاح')
          else ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isFirst = index == 0;
              return Row(
                children: [
                  Column(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: isFirst ? AppColors.gold : AppColors.textMuted, shape: BoxShape.circle)),
                      if (index != logs.length - 1) Container(width: 2, height: 40, color: AppColors.borderDefault),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.message ?? log.status.label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: isFirst ? FontWeight.bold : FontWeight.normal)),
                          Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(log.timestamp), style: AppTextStyles.labelMed),
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

  Widget _buildCompletionReport(Order order) {
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقرير الإنجاز المالي والمهني', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _infoRow(Icons.payments, 'السعر النهائي', '${order.finalPrice} ج.م'),
          _infoRow(Icons.notes, 'ملاحظات الفني', order.techNotes ?? 'لا يوجد'),
          if (order.rating != null) ...[
            const Divider(),
            _infoRow(Icons.star, 'تقييم العميل', '${order.rating} / 5'),
            _infoRow(Icons.comment, 'تعليق العميل', order.ratingComment ?? 'بدون تعليق'),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, WidgetRef ref, Order order) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'تواصل مع العميل',
            variant: ButtonVariant.whatsapp,
            onTap: () => launchUrl(WhatsAppUtils.buildUri(order.clientPhone, 'بخصوص طلبك رقم #${order.trackingCode}...')),
          ),
        ),
        const SizedBox(width: 12),
        if (order.status != OrderStatus.cancelled && order.status != OrderStatus.completed)
          IconButton(
            onPressed: () => _cancelOrder(context, ref, order),
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            tooltip: 'إلغاء العملية',
          ),
      ],
    );
  }

  void _cancelOrder(BuildContext context, WidgetRef ref, Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟ سيتم إخطار العميل فوراً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، إلغاء', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ref.read(adminActionsProvider).cancelOrder(order, logMessage: 'تم الإلغاء من قبل الإدارة');
      result.when(
        left: (f) => AppErrorHandler.showSnackBar(context, f.message),
        right: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب بنجاح ✅')))
      );
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label:', style: AppTextStyles.labelLarge),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending: color = AppColors.gold; break;
      case OrderStatus.completed: color = AppColors.success; break;
      case OrderStatus.cancelled: color = AppColors.error; break;
      default: color = AppColors.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
