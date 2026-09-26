import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  /// فتح الملاحة التلقائية وتوجيه الفني إلى منزل العميل مباشر بالـ GPS
  static Future<bool> openNavigationToClient({
    double? lat,
    double? lng,
    String? address,
    String city = 'كفر الزيات',
  }) async {
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      // توجيه قيادة حي ومباشر بالـ GPS لنقطة المنزل الحقيقية
      final navUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
      final uri = Uri.parse(navUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    // Fallback: البحث بالعنوان والمدينة إذا لم تكن الإحداثيات متاحة
    final cleanAddress = (address ?? '').trim().isEmpty ? city : '$city $address';
    return await openMapWithAddress(cleanAddress, city: city);
  }

  static Future<bool> openMapWithAddress(String address, {String city = 'كفر الزيات'}) async {
    final query = Uri.encodeComponent('$city $address');
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> openMapWithCoordinates(double lat, double lng) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
