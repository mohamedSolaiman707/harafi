import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.trackingCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${order.service.icon} ${order.service.label}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _IconText(icon: Icons.person, text: order.clientName),
            _IconText(icon: Icons.phone, text: order.clientPhone),
            _IconText(icon: Icons.location_on, text: order.area ?? 'بدون عنوان'),
            if (order.description != null && order.description!.isNotEmpty)
              _IconText(icon: Icons.description, text: order.description!),
            
            const Divider(height: 32),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
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
                const SizedBox(width: 8),
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
      case OrderStatus.pending: color = Colors.orange; break;
      case OrderStatus.completed: color = Colors.green; break;
      case OrderStatus.cancelled: color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
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
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
