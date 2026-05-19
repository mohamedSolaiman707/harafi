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
    // جلب بيانات كل الفنيين لنجد الفني المعين لهذا الطلب ونحصل على رقمه
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
                    color: AppColors.info.withOpacity(0.12),
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
            if (order.description != null && order.description!.isNotEmpty)
              _IconText(icon: Icons.description, text: order.description!),
            
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.lg),
            
            Row(
              children: [
                // زر الواتساب للعميل (أخضر)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // لون واتساب
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: () {
                      final uri = WhatsAppUtils.buildUri(
                        order.clientPhone,
                        WhatsAppUtils.clientMessage(order),
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('عميل', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                
                // زر الواتساب للفني (أصفر/برتقالي)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    onPressed: assignedTech == null 
                      ? null // معطل إذا لم يتم تعيين فني
                      : () {
                          final uri = WhatsAppUtils.buildUri(
                            assignedTech.phone,
                            WhatsAppUtils.techMessage(order),
                          );
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                    icon: const Icon(Icons.engineering_outlined, size: 18),
                    label: Text(
                      assignedTech == null ? 'فني (لم يحدد)' : 'فني',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
      case OrderStatus.pending:
        color = AppColors.info;
        break;
      case OrderStatus.assigned:
        color = Colors.orange;
        break;
      case OrderStatus.onTheWay:
        color = Colors.amber;
        break;
      case OrderStatus.started:
        color = Colors.blue;
        break;
      case OrderStatus.completed:
        color = AppColors.success;
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
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
              style: AppTextStyles.displayMedium.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
