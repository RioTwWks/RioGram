import 'package:url_launcher/url_launcher.dart';

import '../../models/location_models.dart';

/// Открытие координат во внешнем картографическом приложении.
class MapLauncher {
  const MapLauncher._();

  static Uri mapsUri(LocationPoint point, {String? label}) {
    final query = label != null && label.isNotEmpty
        ? Uri.encodeComponent('$label@${point.latitude},${point.longitude}')
        : '${point.latitude},${point.longitude}';
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  }

  static Uri geoUri(LocationPoint point) {
    return Uri.parse('geo:${point.latitude},${point.longitude}');
  }

  static Future<bool> openLocation(
    LocationPoint point, {
    String? label,
  }) async {
    final candidates = <Uri>[
      geoUri(point),
      mapsUri(point, label: label),
    ];

    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          return true;
        }
      }
    }
    return false;
  }
}
