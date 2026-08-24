import '../core/tdlib/tdlib_json.dart';
/// Точка на карте (TDLib `location`).
class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.horizontalAccuracy = 0,
  });

  final double latitude;
  final double longitude;
  final double horizontalAccuracy;

  factory LocationPoint.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const LocationPoint(latitude: 0, longitude: 0);
    }
    return LocationPoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      horizontalAccuracy:
          (json['horizontal_accuracy'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toTdlib() => {
        '@type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'horizontal_accuracy': horizontalAccuracy,
      };

  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

/// Метаданные live location (TDLib `liveLocation`).
class LiveLocationMeta {
  const LiveLocationMeta({
    required this.livePeriod,
    this.heading = 0,
    this.proximityAlertRadius = 0,
  });

  final int livePeriod;
  final int heading;
  final int proximityAlertRadius;

  /// Постоянная трансляция (0x7FFFFFFF).
  static const int permanentPeriod = 0x7FFFFFFF;

  factory LiveLocationMeta.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const LiveLocationMeta(livePeriod: 0);
    }
    return LiveLocationMeta(
      livePeriod: tdIntOr(json['live_period']),
      heading: tdIntOr(json['heading']),
      proximityAlertRadius: tdIntOr(json['proximity_alert_radius']),
    );
  }

  Map<String, dynamic> toTdlib(LocationPoint point) => {
        '@type': 'liveLocation',
        'location': point.toTdlib(),
        'live_period': livePeriod,
        'heading': heading,
        'proximity_alert_radius': proximityAlertRadius,
      };

  bool get isActive => livePeriod > 0;

  String get periodLabel {
    if (livePeriod == permanentPeriod) {
      return 'Постоянно';
    }
    if (livePeriod >= 3600) {
      return '${livePeriod ~/ 3600} ч';
    }
    if (livePeriod >= 60) {
      return '${livePeriod ~/ 60} мин';
    }
    return '$livePeriod сек';
  }
}

/// Место / venue (TDLib `venue`).
class VenueInfo {
  const VenueInfo({
    required this.location,
    required this.title,
    required this.address,
    this.provider = '',
    this.id = '',
    this.type = '',
  });

  final LocationPoint location;
  final String title;
  final String address;
  final String provider;
  final String id;
  final String type;

  factory VenueInfo.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return VenueInfo(
        location: const LocationPoint(latitude: 0, longitude: 0),
        title: 'Место',
        address: '',
      );
    }
    return VenueInfo(
      location: LocationPoint.fromTdlib(
        json['location'] as Map<String, dynamic>?,
      ),
      title: json['title'] as String? ?? 'Место',
      address: json['address'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toTdlib() => {
        '@type': 'venue',
        'location': location.toTdlib(),
        'title': title,
        'address': address,
        'provider': provider,
        'id': id,
        'type': type,
      };

  String preview() => title.isNotEmpty ? title : address;
}

/// Содержимое `messageLocation` / `messageLiveLocation`.
class LocationMessageInfo {
  const LocationMessageInfo({
    required this.point,
    this.liveMeta,
    this.expiresIn,
  });

  final LocationPoint point;
  final LiveLocationMeta? liveMeta;
  final int? expiresIn;

  bool get isLive => liveMeta != null || (expiresIn != null && expiresIn! > 0);

  bool get isExpired => isLive && (expiresIn == null || expiresIn! <= 0);

  factory LocationMessageInfo.fromStaticLocation(Map<String, dynamic> content) {
    return LocationMessageInfo(
      point: LocationPoint.fromTdlib(
        content['location'] as Map<String, dynamic>?,
      ),
    );
  }

  factory LocationMessageInfo.fromLiveLocation(Map<String, dynamic> content) {
    final liveRaw = content['location'] as Map<String, dynamic>? ?? {};
    return LocationMessageInfo(
      point: LocationPoint.fromTdlib(
        liveRaw['location'] as Map<String, dynamic>?,
      ),
      liveMeta: LiveLocationMeta.fromTdlib(liveRaw),
      expiresIn: tdInt(content['expires_in']),
    );
  }

  String preview() {
    if (isLive && !isExpired) {
      return '📍 Трансляция геопозиции';
    }
    return '📍 ${point.coordinatesLabel}';
  }
}

/// Содержимое `messageVenue`.
class VenueMessageInfo {
  const VenueMessageInfo({required this.venue});

  final VenueInfo venue;

  factory VenueMessageInfo.fromTdlib(Map<String, dynamic> content) {
    return VenueMessageInfo(
      venue: VenueInfo.fromTdlib(content['venue'] as Map<String, dynamic>?),
    );
  }

  String preview() {
    final title = venue.title;
    if (title.isNotEmpty) {
      return '📍 $title';
    }
    return '📍 ${venue.location.coordinatesLabel}';
  }
}

/// Режим отправки геолокации из UI.
enum LocationSendMode {
  staticPoint,
  liveLocation,
  venue,
}

/// Данные формы отправки геолокации.
class LocationSendRequest {
  const LocationSendRequest({
    required this.mode,
    required this.point,
    this.livePeriod = 3600,
    this.venueTitle = '',
    this.venueAddress = '',
    this.startBroadcast = false,
  });

  final LocationSendMode mode;
  final LocationPoint point;
  final int livePeriod;
  final String venueTitle;
  final String venueAddress;
  final bool startBroadcast;
}
