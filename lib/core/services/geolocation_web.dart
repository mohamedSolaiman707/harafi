import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'geolocation_service.dart';

Future<GeoPosition?> getBrowserPosition() async {
  try {
    if (html.window.navigator.geolocation == null) {
      return null;
    }

    final completer = Completer<GeoPosition?>();

    html.window.navigator.geolocation!.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 10),
      maximumAge: const Duration(seconds: 0),
    ).then((pos) {
      final lat = pos.coords?.latitude?.toDouble();
      final lng = pos.coords?.longitude?.toDouble();

      if (lat != null && lng != null) {
        completer.complete(GeoPosition(
          latitude: lat,
          longitude: lng,
        ));
      } else {
        completer.complete(null);
      }
    }).catchError((err) {
      completer.complete(null);
    });

    return await completer.future.timeout(
      const Duration(seconds: 11),
      onTimeout: () => null,
    );
  } catch (e) {
    return null;
  }
}
