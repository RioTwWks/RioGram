import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/location_models.dart';

void main() {
  group('LocationPoint', () {
    test('fromTdlib и toTdlib', () {
      final point = LocationPoint.fromTdlib({
        '@type': 'location',
        'latitude': 55.7558,
        'longitude': 37.6173,
        'horizontal_accuracy': 12.5,
      });

      expect(point.latitude, closeTo(55.7558, 0.0001));
      expect(point.longitude, closeTo(37.6173, 0.0001));
      expect(point.horizontalAccuracy, 12.5);
      expect(point.isValid, isTrue);

      final tdlib = point.toTdlib();
      expect(tdlib['@type'], 'location');
      expect(tdlib['latitude'], point.latitude);
    });
  });

  group('LocationMessageInfo', () {
    test('static location preview', () {
      final info = LocationMessageInfo.fromStaticLocation({
        '@type': 'messageLocation',
        'location': {
          '@type': 'location',
          'latitude': 40.7128,
          'longitude': -74.0060,
          'horizontal_accuracy': 0,
        },
      });

      expect(info.isLive, isFalse);
      expect(info.preview(), contains('40.71280'));
    });

    test('live location preview', () {
      final info = LocationMessageInfo.fromLiveLocation({
        '@type': 'messageLiveLocation',
        'location': {
          '@type': 'liveLocation',
          'location': {
            '@type': 'location',
            'latitude': 51.5074,
            'longitude': -0.1278,
            'horizontal_accuracy': 0,
          },
          'live_period': 3600,
          'heading': 0,
          'proximity_alert_radius': 0,
        },
        'expires_in': 1800,
      });

      expect(info.isLive, isTrue);
      expect(info.isExpired, isFalse);
      expect(info.preview(), '📍 Трансляция геопозиции');
    });
  });

  group('VenueMessageInfo', () {
    test('venue preview uses title', () {
      final info = VenueMessageInfo.fromTdlib({
        '@type': 'messageVenue',
        'venue': {
          '@type': 'venue',
          'location': {
            '@type': 'location',
            'latitude': 48.8566,
            'longitude': 2.3522,
            'horizontal_accuracy': 0,
          },
          'title': 'Paris',
          'address': 'France',
          'provider': '',
          'id': '',
          'type': '',
        },
      });

      expect(info.preview(), '📍 Paris');
    });
  });

  group('MessageContent location parsing', () {
    test('messageLocation -> MessageKind.location', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageLocation',
        'location': {
          '@type': 'location',
          'latitude': 1,
          'longitude': 2,
          'horizontal_accuracy': 0,
        },
      });

      expect(content.kind, MessageKind.location);
      expect(content.locationInfo, isNotNull);
    });

    test('messageVenue -> MessageKind.venue', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageVenue',
        'venue': {
          '@type': 'venue',
          'location': {
            '@type': 'location',
            'latitude': 1,
            'longitude': 2,
            'horizontal_accuracy': 0,
          },
          'title': 'Cafe',
          'address': 'Street 1',
          'provider': '',
          'id': '',
          'type': '',
        },
      });

      expect(content.kind, MessageKind.venue);
      expect(content.venueInfo?.venue.title, 'Cafe');
    });
  });
}
