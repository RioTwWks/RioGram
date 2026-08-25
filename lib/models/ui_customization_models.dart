/// Пресет шрифта интерфейса (§7.3).
enum AppFontPreset {
  system,
  roboto,
  openSans,
  googleSans,
}

extension AppFontPresetX on AppFontPreset {
  String get label => switch (this) {
        AppFontPreset.system => 'Системный',
        AppFontPreset.roboto => 'Roboto',
        AppFontPreset.openSans => 'Open Sans',
        AppFontPreset.googleSans => 'Google Sans',
      };

  /// Имя семейства для [ThemeData.fontFamily]; null — платформенный default.
  String? get fontFamily => switch (this) {
        AppFontPreset.system => null,
        AppFontPreset.roboto => 'Roboto',
        AppFontPreset.openSans => 'Open Sans',
        AppFontPreset.googleSans => 'Google Sans',
      };

  static AppFontPreset fromStorage(String? value) {
    return AppFontPreset.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppFontPreset.system,
    );
  }
}

/// Действие свайпа по чату (список чатов).
enum ChatSwipeAction {
  none,
  archive,
  mute,
  delete,
  markRead,
  pin,
}

extension ChatSwipeActionX on ChatSwipeAction {
  String get label => switch (this) {
        ChatSwipeAction.none => 'Нет',
        ChatSwipeAction.archive => 'Архив',
        ChatSwipeAction.mute => 'Без звука',
        ChatSwipeAction.delete => 'Удалить',
        ChatSwipeAction.markRead => 'Прочитано',
        ChatSwipeAction.pin => 'Закрепить',
      };
}

/// Действие свайпа по сообщению.
enum MessageSwipeAction {
  none,
  reply,
  forward,
  delete,
}

extension MessageSwipeActionX on MessageSwipeAction {
  String get label => switch (this) {
        MessageSwipeAction.none => 'Нет',
        MessageSwipeAction.reply => 'Ответить',
        MessageSwipeAction.forward => 'Переслать',
        MessageSwipeAction.delete => 'Удалить',
      };
}
