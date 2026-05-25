import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';
import '../providers/techs_provider.dart';

class OrderCard extends ConsumerWidget {
  final Order order;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onAssignTech;

  const OrderCard({
    super.key,
    required this.order,
    this.onUpdateStatus,
    this.onAssignTech,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
    final assignedTech = techs.where((t) => t.id == order.techId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          children: [
            // المحتوى الرئيسي
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTrackingTag(),
                      _StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildServiceHeader(),
                  const SizedBox(height: 20),
                  _buildClientInfo(assignedTech),
                ],
              ),
            ),
            // شريط الأزرار (Actions)
            _buildBottomActions(assignedTech),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Text(
        '#${order.trackingCode}',
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildServiceHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(order.service.icon, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.service.label, style: AppTextStyles.headlineMed),
              Text(
                'طلب جديد • منذ ${DateTime.now().difference(order.createdAt).inHours} ساعات',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientInfo(dynamic assignedTech) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.person_outline, label: 'العميل', value: order.clientName),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.phone_android_outlined, label: 'الهاتف', value: order.clientPhone),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.location_on_outlined, label: 'العنوان', value: order.area ?? 'غير محدد'),
          if (assignedTech != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.borderSubtle, height: 1),
            ),
            _InfoRow(
              icon: Icons.engineering_outlined, 
              label: 'الفني المختار', 
              value: assignedTech.name,
              valueColor: AppColors.gold,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(dynamic assignedTech) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          // زر واتساب العميل (أهم إجراء)
          Expanded(
            flex: 2,
            child: TextButton.icon(
              onPressed: () {
                final message = assignedTech != null 
                  ? WhatsAppUtils.techAssignedClient(assignedTech.name, order.trackingCode)
                  : WhatsAppUtils.orderCreated(order.trackingCode);
                launchUrl(WhatsAppUtils.buildUri(order.clientPhone, message), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text('واتساب العميل'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const VerticalDivider(width: 16, color: AppColors.borderSubtle),

          // زر تعيين فني (إذا لم يوجد) أو زر واتساب الفني (إذا وجد)
          if (assignedTech == null)
            Expanded(
              flex: 2,
              child: TextButton.icon(
                onPressed: onAssignTech,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('تعيين فني'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => launchUrl(
                WhatsAppUtils.buildUri(assignedTech.phone, WhatsAppUtils.techAssignedTech(order)),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.engineering_rounded, color: AppColors.gold),
              tooltip: 'واتساب الفني',
            ),

          const Spacer(),
          
          // أيقونة التعديل
          IconButton(
            onPressed: onUpdateStatus,
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.textSecondary),
            tooltip: 'تحديث الحالة',
          ),
          if (assignedTech != null)
            IconButton(
              onPressed: onAssignTech,
              icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.textMuted),
              tooltip: 'تغيير الفني',
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text('$label:', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value, 
            style: AppTextStyles.titleMed.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
        ),
      ],
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
      case OrderStatus.assigned: color = AppColors.info; break;
      case OrderStatus.onTheWay: color = Colors.orange; break;
      case OrderStatus.started: color = Colors.blue; break;
      case OrderStatus.completed: color = AppColors.success; break;
      case OrderStatus.cancelled: color = AppColors.error; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.label, style: AppTextStyles.labelMed.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
