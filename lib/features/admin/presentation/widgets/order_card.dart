import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';
import '../providers/techs_provider.dart';
import '../../../../shared/widgets/app_card.dart';

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
    final statusColor = _getStatusColor(order.status);

    return AppCard(
      padding: EdgeInsets.zero,
      color: AppColors.surface1,
      border: Border.all(color: AppColors.borderSubtle.withOpacity(0.4), width: 1),
      child: Stack(
        children: [
          // Subtle background glow based on status
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Meta Header: Tracking & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${order.trackingCode}',
                      style: AppTextStyles.labelMed.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'منذ ${DateTime.now().difference(order.createdAt).inHours} ساعة',
                      style: AppTextStyles.labelMed.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),

                // 2. Main Identity: Service & Price
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(order.service.icon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.service.label,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.2,
                            ),
                          ),
                          _StatusChip(status: order.status, color: statusColor),
                        ],
                      ),
                    ),
                    if (order.finalPrice != null)
                      _PriceTag(price: order.finalPrice!),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Info Strip: Client & Technical Context
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface2.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'العميل',
                        value: order.clientName,
                      ),
                      if (assignedTech != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1, thickness: 0.5, color: AppColors.borderSubtle),
                        ),
                        _InfoRow(
                          icon: Icons.engineering_outlined,
                          label: 'الفني المعتمد',
                          value: assignedTech.name,
                          valueColor: AppColors.gold,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryWhatsAppBtn(
                        onTap: () => _launchWhatsApp(order.clientPhone, assignedTech),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _GhostActionBtn(
                      icon: Icons.phone_in_talk_rounded,
                      color: AppColors.info,
                      onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
                      tooltip: 'اتصال هاتفى',
                    ),
                    const SizedBox(width: 8),
                    _GhostActionBtn(
                      icon: assignedTech == null ? Icons.person_add_alt_1_rounded : Icons.swap_horiz_rounded,
                      color: AppColors.gold,
                      onTap: onAssignTech,
                      tooltip: assignedTech == null ? 'تعيين فني' : 'تغيير الفني',
                    ),
                    const SizedBox(width: 8),
                    _GhostActionBtn(
                      icon: Icons.settings_suggest_rounded,
                      color: AppColors.textSecondary,
                      onTap: onUpdateStatus,
                      tooltip: 'تحديث الحالة',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return AppColors.gold;
      case OrderStatus.assigned: return AppColors.info;
      case OrderStatus.onTheWay: return Colors.orange;
      case OrderStatus.started: return Colors.blue;
      case OrderStatus.completed: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
    }
  }

  void _launchWhatsApp(String phone, dynamic tech) {
    final message = tech != null
        ? WhatsAppUtils.techAssignedClient(tech.name, order.trackingCode)
        : WhatsAppUtils.orderCreated(order.trackingCode);
    launchUrl(WhatsAppUtils.buildUri(phone, message), mode: LaunchMode.externalApplication);
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status.label.toUpperCase(),
          style: AppTextStyles.labelMed.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PriceTag extends StatelessWidget {
  final int price;
  const _PriceTag({required this.price});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$price',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'ج.م',
              style: AppTextStyles.labelMed.copyWith(
                color: AppColors.success.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          'الإجمالي المستحق',
          style: AppTextStyles.labelMed.copyWith(fontSize: 8, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 10),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PrimaryWhatsAppBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryWhatsAppBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.success.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'تواصل مع العميل',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _GhostActionBtn({
    required this.icon,
    required this.color,
    this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}
