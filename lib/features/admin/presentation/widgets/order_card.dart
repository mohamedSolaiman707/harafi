import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';

class OrderCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
            _IconText(
              icon: Icons.location_on,
              text: order.area ?? 'بدون عنوان',
            ),
            if (order.description != null && order.description!.isNotEmpty)
              _IconText(icon: Icons.description, text: order.description!),
            if (order.finalPrice != null)
              _IconText(
                icon: Icons.attach_money,
                text: 'السعر النهائي: ${order.finalPrice} ج.م',
              ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    onPressed: () {
                      final link = WhatsAppUtils.buildLink(
                        order.clientPhone,
                        WhatsAppUtils.techMessage(order),
                      );
                      launchUrl(Uri.parse(link));
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('واتساب العميل'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onUpdateStatus,
                  icon: const Icon(Icons.edit_note),
                  tooltip: 'تحديث الحالة',
                ),
                IconButton(
                  onPressed: onAssignTech,
                  icon: const Icon(Icons.person_add_alt_1),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
