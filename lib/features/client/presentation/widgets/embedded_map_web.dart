import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

Widget buildEmbeddedMapWidget({
  required double clientLat,
  required double clientLng,
  required double techLat,
  required double techLng,
  required String orderId,
}) {
  final viewType = 'embedded-map-$orderId-${clientLat.toStringAsFixed(4)}-${clientLng.toStringAsFixed(4)}';

  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    body, html, #map { margin: 0; padding: 0; width: 100%; height: 100%; background: #090d16; }
    .leaflet-container { background: #090d16 !important; }
    .client-icon { display: flex; align-items: center; justify-content: center; }
    .tech-icon { display: flex; align-items: center; justify-content: center; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var clientLat = $clientLat;
    var clientLng = $clientLng;
    var techLat = $techLat;
    var techLng = $techLng;

    var map = L.map('map', { zoomControl: false }).setView([clientLat, clientLng], 15);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap & CartoDB'
    }).addTo(map);

    // Client Marker
    var clientIcon = L.divIcon({
      className: 'client-icon',
      html: '<div style="background:#E2B23B;width:32px;height:32px;border-radius:50%;border:3px solid #ffffff;box-shadow:0 0 15px rgba(226,178,59,0.8);display:flex;align-items:center;justify-content:center;font-size:16px;">🏠</div>',
      iconSize: [32, 32],
      iconAnchor: [16, 16]
    });
    L.marker([clientLat, clientLng], {icon: clientIcon}).addTo(map).bindPopup("<b>منزل العميل 📍</b>");

    // Tech Marker
    var techIcon = L.divIcon({
      className: 'tech-icon',
      html: '<div style="background:#3B82F6;width:36px;height:36px;border-radius:50%;border:3px solid #ffffff;box-shadow:0 0 15px rgba(59,130,246,0.8);display:flex;align-items:center;justify-content:center;font-size:20px;">🛵</div>',
      iconSize: [36, 36],
      iconAnchor: [18, 18]
    });
    L.marker([techLat, techLng], {icon: techIcon}).addTo(map).bindPopup("<b>الفني في الطريق 🛠️</b>");

    // Polyline connecting Tech & Client
    var latlngs = [[techLat, techLng], [clientLat, clientLng]];
    var polyline = L.polyline(latlngs, {
      color: '#E2B23B',
      weight: 4,
      opacity: 0.85,
      dashArray: '8, 10'
    }).addTo(map);

    map.fitBounds(polyline.getBounds(), {padding: [50, 50]});
  </script>
</body>
</html>
''';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final iframe = html.IFrameElement()
      ..srcdoc = htmlContent
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
