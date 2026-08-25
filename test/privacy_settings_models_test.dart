import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/privacy_settings_models.dart';

void main() {
  group('PrivacyRulesModel', () {
    test('detectPreset reads allowAll as everybody', () {
      final rules = PrivacyRulesModel(
        rules: const [
          {'@type': 'userPrivacySettingRuleAllowAll'},
        ],
      );

      expect(
        rules.detectPreset(allowMode: true),
        PrivacyRulePreset.everybody,
      );
      expect(
        rules.detectPreset(allowMode: false),
        PrivacyRulePreset.everybody,
      );
    });

    test('toTdlibRules maps nobody to restrictAll', () {
      expect(
        PrivacyRulePreset.nobody.toTdlibRules(allowMode: true),
        [
          {'@type': 'userPrivacySettingRuleRestrictAll'},
        ],
      );
    });
  });

  group('PrivacySettingKind', () {
    test('toTdlib uses stable type names', () {
      expect(
        PrivacySettingKind.showPhoneNumber.toTdlib()['@type'],
        'userPrivacySettingShowPhoneNumber',
      );
    });
  });
}
