import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'geolocation_stub.dart'
    if (dart.library.html) 'geolocation_web.dart';

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
  /// الحصول على موقع الجهاز الدقيق بالـ GPS من مستشعر الهاتف/المتصفح الحقيقي
  static Future<GeoPosition?> getCurrentPosition() async {
    try {
      // 1. جلب موقع جهاز العميل بدقة GPS عالية (مستشعر الهاتف/المتصفح)
      GeoPosition? browserPos = await getBrowserPosition();

      if (browserPos != null) {
        // 2. تحويل الإحداثيات الدقيقة إلى اسم المنطقة/القرية بالعربي عبر OpenStreetMap Nominatim
        final address = await reverseGeocode(browserPos.latitude, browserPos.longitude);
        return GeoPosition(
          latitude: browserPos.latitude,
          longitude: browserPos.longitude,
          address: address,
        );
      }
    } catch (e) {
      debugPrint('GPS Browser fetch notice: $e');
    }

    // 3. خيار احتياطي في حال تم رفض إذن الـ GPS من العميل: استخدام IP Geolocation
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['city']?.toString() ?? '';
        final region = data['region']?.toString() ?? '';

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          final addressParts = [city, region].where((s) => s.isNotEmpty).join('، ');
          return GeoPosition(
            latitude: lat,
            longitude: lng,
            address: addressParts.isNotEmpty ? addressParts : null,
          );
        }
      }
    } catch (e) {
      debugPrint('IP Geolocation fetch notice: $e');
    }

    return null;
  }

  /// تحويل الإحداثيات (lat, lng) إلى اسم القرية/المدينة بالعربي بدقة متناهية
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'HarafiApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressObj = data['address'] as Map<String, dynamic>?;

        if (addressObj != null) {
          final village = addressObj['village'] ?? 
                          addressObj['town'] ?? 
                          addressObj['suburb'] ?? 
                          addressObj['neighbourhood'] ??
                          addressObj['city_district'];
          final city = addressObj['city'] ?? 
                       addressObj['county'] ?? 
                       addressObj['municipality'];
          final state = addressObj['state'];

          final parts = [village, city, state]
              .where((p) => p != null && p.toString().isNotEmpty)
              .map((p) => p.toString().replaceAll('محافظة ', ''))
              .toSet()
              .toList();

          if (parts.isNotEmpty) {
            return parts.join('، ');
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName.split(',').take(3).join('، ');
        }
      }
    } catch (e) {
      debugPrint('Reverse Geocode notice: $e');
    }
    return null;
  }
}
