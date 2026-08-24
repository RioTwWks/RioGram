import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../models/location_models.dart';

typedef LiveLocationUpdateCallback = void Function(LocationPoint point);

/// Периодическое обновление live location через GPS.
class LiveLocationTracker {
  LiveLocationTracker({
    this.updateInterval = const Duration(seconds: 15),
  });

  final Duration updateInterval;

  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  LiveLocationUpdateCallback? _onUpdate;

  bool get isTracking => _subscription != null || _timer != null;

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationPoint?> getCurrentPosition() async {
    if (!await ensurePermission()) {
      return null;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        horizontalAccuracy: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> start(LiveLocationUpdateCallback onUpdate) async {
    if (isTracking) {
      return false;
    }
    if (!await ensurePermission()) {
      return false;
    }

    _onUpdate = onUpdate;
    final initial = await getCurrentPosition();
    if (initial != null) {
      onUpdate(initial);
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: updateInterval,
      ),
    ).listen(
      (position) {
        _onUpdate?.call(
          LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            horizontalAccuracy: position.accuracy,
          ),
        );
      },
      onError: (_) {},
    );

    _timer = Timer.periodic(updateInterval, (_) async {
      final point = await getCurrentPosition();
      if (point != null) {
        _onUpdate?.call(point);
      }
    });

    return true;
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _onUpdate = null;
  }
}
