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
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderDefault.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // الصف العلوي: الحالة والكود
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusBadge(status: order.status),
                      _buildTrackingTag(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // المحتوى الأوسط: الخدمة والأيقونة
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.service.label,
                              style: AppTextStyles.headlineMed.copyWith(
                                fontSize: 26, 
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8, height: 8, 
                                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'منذ ${DateTime.now().difference(order.createdAt).inHours} ساعة',
                                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // أيقونة الخدمة في مربع فخم
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                          ]
                        ),
                        child: Text(order.service.icon, style: const TextStyle(fontSize: 36)),
                      ),
                    ],
                  ),
                  
                  if (assignedTech != null || order.finalPrice != null) ...[
                    const SizedBox(height: 20),
                    _buildExtraDetails(assignedTech),
                  ],
                ],
              ),
            ),

            // شريط العميل (Footer)
            _buildClientFooter(),

            // شريط الأزرار التفاعلية
            _buildActionToolbar(assignedTech),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
      ),
      child: Text(
        '#${order.trackingCode}',
        style: AppTextStyles.labelLarge.copyWith(
          color: const Color(0xFFFFD54F), 
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildExtraDetails(dynamic tech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (tech != null) ...[
            const Icon(Icons.engineering_outlined, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(tech.name, style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
          ],
          const Spacer(),
          if (order.finalPrice != null)
            Text(
              '${order.finalPrice} ج.م',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildClientFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        border: const Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_outlined, size: 22, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text('العميل:', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Text(order.clientName, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (order.area != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(order.area!, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionToolbar(dynamic tech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface1,
      child: Row(
        children: [
          _ActionButton(
            onTap: () => _launchWhatsApp(order.clientPhone, tech),
            icon: Icons.message_outlined,
            label: 'تواصل',
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'اتصال هاتفي',
            onPressed: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
            icon: const Icon(Icons.phone_in_talk_outlined, size: 20, color: AppColors.info),
          ),
          const Spacer(),
          
          if (tech == null)
            IconButton(
              tooltip: 'تعيين فني',
              onPressed: onAssignTech,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.gold),
            )
          else
            IconButton(
              tooltip: 'تغيير الفني',
              onPressed: onAssignTech,
              icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.textMuted),
            ),
            
          IconButton(
            tooltip: 'تحديث حالة الطلب',
            onPressed: onUpdateStatus,
            icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp(String phone, dynamic tech) {
    final message = tech != null 
      ? WhatsAppUtils.techAssignedClient(tech.name, order.trackingCode)
      : WhatsAppUtils.orderCreated(order.trackingCode);
    launchUrl(WhatsAppUtils.buildUri(phone, message), mode: LaunchMode.externalApplication);
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  const _ActionButton({required this.onTap, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
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
      case OrderStatus.pending: color = AppColors.gold; break;
      case OrderStatus.assigned: color = AppColors.info; break;
      case OrderStatus.onTheWay: color = Colors.orange; break;
      case OrderStatus.started: color = Colors.blue; break;
      case OrderStatus.completed: color = const Color(0xFF00C853); break;
      case OrderStatus.cancelled: color = AppColors.error; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8, 
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
            )
          ),
          const SizedBox(width: 10),
          Text(
            status.label, 
            style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 13)
          ),
        ],
      ),
    );
  }
}
