import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

Widget buildEmbeddedMapWidget({
  required double clientLat,
  required double clientLng,
  required double techLat,
  required double techLng,
  required String orderId,
}) {
  return Container(
    color: AppColors.surface2,
    child: const Center(
      child: Text(
        '🗺️ الخريطة التفاعلية الحية',
        style: TextStyle(color: AppColors.textMuted),
      ),
    ),
  );
}
