import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    order.trackingCode,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${order.service.icon} ${order.service.label}',
              style: AppTextStyles.headlineMed,
            ),
            const SizedBox(height: AppSpacing.md),
            _IconText(icon: Icons.person, text: order.clientName),
            _IconText(icon: Icons.phone, text: order.clientPhone),
            _IconText(icon: Icons.location_on, text: order.area ?? 'بدون عنوان'),
            
            if (order.rating != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.gold, size: 16),
                        const SizedBox(width: 4),
                        Text('تقييم العميل: ${order.rating}/5', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
                      ],
                    ),
                    if (order.ratingComment != null && order.ratingComment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('💬 ${order.ratingComment}', style: AppTextStyles.bodyMed),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.lg),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: () {
                      final message = assignedTech != null 
                        ? WhatsAppUtils.techAssignedClient(assignedTech.name, order.trackingCode)
                        : WhatsAppUtils.orderCreated(order.trackingCode);
                      final uri = WhatsAppUtils.buildUri(order.clientPhone, message);
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('واتساب العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    onPressed: assignedTech == null 
                      ? null 
                      : () {
                          final uri = WhatsAppUtils.buildUri(assignedTech.phone, WhatsAppUtils.techAssignedTech(order));
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                    icon: const Icon(Icons.engineering_outlined, size: 18),
                    label: Text(assignedTech == null ? 'لا يوجد فني' : 'واتساب الفني', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onUpdateStatus,
                  icon: const Icon(Icons.edit_note, color: Colors.white70),
                  tooltip: 'تحديث الحالة',
                ),
                IconButton(
                  onPressed: onAssignTech,
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white70),
                  tooltip: 'تعيين فني',
                ),
              ],
            ),
          ],
        ),
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
      case OrderStatus.pending: color = AppColors.info; break;
      case OrderStatus.assigned: color = Colors.orange; break;
      case OrderStatus.onTheWay: color = Colors.amber; break;
      case OrderStatus.started: color = Colors.blue; break;
      case OrderStatus.completed: color = AppColors.success; break;
      case OrderStatus.cancelled: color = AppColors.error; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(status.label, style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
