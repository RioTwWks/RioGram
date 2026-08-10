import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/proxy/proxy_preferences.dart';
import 'package:riogram/models/proxy_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ProxyEntry.copyWith сохраняет неизменённые поля', () {
    const entry = ProxyEntry(
      id: 1,
      name: 'PhantomProxy',
      host: '178.0.0.1',
      port: 443,
    );

    final updated = entry.copyWith(isActive: true, health: ProxyHealth.ok);

    expect(updated.id, 1);
    expect(updated.isActive, isTrue);
    expect(updated.health, ProxyHealth.ok);
    expect(updated.host, '178.0.0.1');
  });

  test('ProxyPreferences сохраняет настройку auto failover', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ProxyPreferences();

    expect(await preferences.isAutoFailoverEnabled(), isTrue);

    await preferences.setAutoFailoverEnabled(false);
    expect(await preferences.isAutoFailoverEnabled(), isFalse);
  });
}
