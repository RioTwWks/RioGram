import 'package:shared_preferences/shared_preferences.dart';
import 'telegram_routes.dart';
class DesktopLayoutPreferences {
  DesktopLayoutPreferences({SharedPreferences? preferences}) : _preferences = preferences;
  SharedPreferences? _preferences;
  static const _key = 'desktop_chat_list_width';
  Future<void> init() async => _preferences ??= await SharedPreferences.getInstance();
  double get chatListWidth => (_preferences?.getDouble(_key) ?? TelegramLayoutBreakpoints.chatListWidth).clamp(TelegramLayoutBreakpoints.chatListWidthMin, TelegramLayoutBreakpoints.chatListWidthMax);
  Future<void> setChatListWidth(double w) async { await init(); await _preferences!.setDouble(_key, w.clamp(TelegramLayoutBreakpoints.chatListWidthMin, TelegramLayoutBreakpoints.chatListWidthMax)); }
}
