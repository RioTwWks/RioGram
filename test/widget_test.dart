import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/config/app_config.dart';

void main() {
  test('AppConfig loads with empty defaults when dotenv unavailable', () async {
    final config = await AppConfig.load();
    expect(config.apiId, 0);
    expect(config.apiHash, '');
  });
}
