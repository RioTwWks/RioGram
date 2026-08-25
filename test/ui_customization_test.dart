import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/ui_customization_preferences.dart';
import 'package:riogram/models/ui_customization_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UiCustomizationPreferences', () {
    test('сохраняет шрифт, скругления и жесты', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = UiCustomizationPreferences();

      await preferences.setFontPreset(AppFontPreset.openSans);
      await preferences.setCornerRadiusScale(1.5);
      await preferences.setHideNavigationBar(true);
      await preferences.setChatSwipeEndToStart(ChatSwipeAction.mute);
      await preferences.setMessageSwipeEndToStart(MessageSwipeAction.forward);

      expect(preferences.fontPreset, AppFontPreset.openSans);
      expect(preferences.cornerRadiusScale, 1.5);
      expect(preferences.hideNavigationBar, isTrue);
      expect(preferences.chatSwipeEndToStart, ChatSwipeAction.mute);
      expect(preferences.messageSwipeEndToStart, MessageSwipeAction.forward);
    });
  });
}
