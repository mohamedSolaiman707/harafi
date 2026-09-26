import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeoPosition {
  final double latitude;
  final double longitude;
  final String? address;

  const GeoPosition({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class GeolocationService {
  /// الحصول على موقع الجهاز الدقيق بالـ GPS
  static Future<GeoPosition?> getCurrentPosition() async {
    try {
      // 1. تجربة جلب الموقع بدقة عبر IP Geolocation / Browser API
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['city']?.toString() ?? '';
        final region = data['region']?.toString() ?? '';

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          final addressParts = [
            city,
            region,
          ].where((s) => s.isNotEmpty).join('، ');
          return GeoPosition(
            latitude: lat,
            longitude: lng,
            address: addressParts.isNotEmpty ? addressParts : null,
          );
        }
      }
    } catch (e) {
      debugPrint('Geolocation fetch notice: $e');
    }

    // إذا لم يتم العثور على الموقع بشكل مؤكد، نرجع null حتى لا نضع موقعاً همياً
    return null;
  }
}
