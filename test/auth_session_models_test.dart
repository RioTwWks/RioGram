import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/auth_models.dart';
import 'package:riogram/models/session_models.dart';

void main() {
  group('RegistrationTerms', () {
    test('fromTdlib parses formatted text', () {
      final terms = RegistrationTerms.fromTdlib({
        '@type': 'termsOfService',
        'text': {
          '@type': 'formattedText',
          'text': 'Terms text',
        },
        'min_user_age': 16,
        'show_popup': true,
      });

      expect(terms.text, 'Terms text');
      expect(terms.minUserAge, 16);
      expect(terms.showPopup, isTrue);
    });
  });

  group('ActiveSessionModel', () {
    test('fromTdlib maps device fields', () {
      final session = ActiveSessionModel.fromTdlib({
        '@type': 'session',
        'id': 1001,
        'is_current': true,
        'is_unconfirmed': false,
        'device_model': 'Desktop',
        'platform': 'Linux',
        'application_name': 'RioGram',
        'application_version': '0.12.0',
        'ip_address': '1.2.3.4',
        'location': 'Amsterdam',
        'log_in_date': 1_700_000_000,
        'last_active_date': 1_700_000_100,
      });

      expect(session.id, 1001);
      expect(session.isCurrent, isTrue);
      expect(session.deviceLabel, contains('RioGram'));
    });
  });

  group('SessionsListModel', () {
    test('fromTdlib parses session list', () {
      final list = SessionsListModel.fromTdlib({
        '@type': 'sessions',
        'inactive_session_ttl_days': 90,
        'sessions': [
          {
            '@type': 'session',
            'id': 1,
            'is_current': true,
            'is_unconfirmed': false,
            'device_model': 'Phone',
            'platform': 'Android',
            'application_name': 'Telegram',
            'application_version': '10',
            'ip_address': '',
            'location': '',
            'log_in_date': 0,
            'last_active_date': 0,
          },
        ],
      });

      expect(list.sessions, hasLength(1));
      expect(list.inactiveSessionTtlDays, 90);
    });
  });
}
