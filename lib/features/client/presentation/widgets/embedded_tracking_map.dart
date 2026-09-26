import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/models/order.dart';

import 'embedded_map_stub.dart'
    if (dart.library.html) 'embedded_map_web.dart';

class EmbeddedTrackingMap extends StatelessWidget {
  final Order order;
  final double height;

  const EmbeddedTrackingMap({
    super.key,
    required this.order,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final clientLat = order.clientLat;
    final clientLng = order.clientLng;

    if (clientLat == null || clientLng == null || clientLat == 0 || clientLng == 0) {
      return const SizedBox.shrink();
    }

    final techLat = order.techLat ?? (clientLat + 0.006);
    final techLng = order.techLng ?? (clientLng + 0.006);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // الخريطة التفاعلية المباشرة
            buildEmbeddedMapWidget(
              clientLat: clientLat,
              clientLng: clientLng,
              techLat: techLat,
              techLng: techLng,
              orderId: order.id,
            ),

            // البادج العشري المباشر في الأعلى (Uber Style Badge)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface1.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'تتبع تفاعلي مباشر 🗺️',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // دليل الأيقونات (Legend) في الأسفل
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface1.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Row(
                      children: [
                        Text('🏠', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text('بيت العميل', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('•', style: TextStyle(color: AppColors.textMuted)),
                    Row(
                      children: [
                        Text('🛵', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text('الفني في الطريق', style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
