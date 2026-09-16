import 'package:url_launcher/url_launcher.dart';

class MapUtils {
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
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
