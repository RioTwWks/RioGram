import 'package:flutter/material.dart';

/// Централизованное сопоставление иконок RioGram с Telegram (§9.11).
///
/// Используются Material Icons в outline-стиле, ближайшие к классическому
/// Telegram Desktop / Android до Liquid Glass. Базовый размер навигации и
/// действий — [size] (24dp).
///
/// | RioGram / Telegram UI | Material Icon |
/// |-----------------------|---------------|
/// | Вкладка «Чаты» | [chats] → `chat_bubble_outline` |
/// | Вкладка «Контакты» | [contacts] → `contacts_outlined` |
/// | Вкладка «Настройки» | [settings] → `settings_outlined` |
/// | Прикрепить файл / медиа | [attach] → `attach_file` |
/// | Стикеры и GIF | [emoji] → `emoji_emotions_outlined` |
/// | Клавиатура | [keyboard] → `keyboard` |
/// | Голосовое сообщение | [mic] → `mic` |
/// | Отправить | [send] → `send` |
/// | Отложенная отправка | [scheduleSend] → `schedule_send` |
/// | Подтвердить редактирование | [check] → `check` |
/// | Закрыть / отмена | [close] → `close` |
/// | Расписание | [schedule] → `schedule` |
/// | Поиск в чате | [search] → `search` |
/// | Меню чата (⋮) | [moreVert] → `more_vert` |
/// | Аудиозвонок | [call] → `call` |
/// | Видеозвонок | [videocam] → `videocam_outlined` |
/// | Групповой звонок | [groupCall] → `groups_outlined` |
/// | Видеочат с камерой | [videoChat] → `video_chat` |
/// | Удалить | [delete] → `delete_outline` |
/// | Переслать | [forward] → `forward` |
/// | Закрепить | [pin] → `push_pin` |
/// | Без звука | [mute] → `notifications_off_outlined` |
/// | Черновик | [draft] → `edit_outlined` |
/// | Фото в preview | [photo] → `photo_camera_outlined` |
/// | Видео в preview | [video] → `videocam_outlined` |
/// | Документ в preview | [document] → `attach_file` |
/// | Музыка в preview | [music] → `music_note_outlined` |
/// | GIF в preview | [gif] → `gif_box_outlined` |
/// | Опрос в preview | [poll] → `poll_outlined` |
/// | Личный чат | [privateChat] → `person_outline` |
/// | Группа | [group] → `group_outlined` |
/// | Канал | [channel] → `campaign_outlined` |
/// | Бот | [bot] → `smart_toy_outlined` |
/// | Секретный чат | [secretChat] → `lock_outline` |
/// | Избранное | [savedMessages] → `bookmark_outline` |
/// | Отправляется (часы) | [deliverySending] → `access_time` |
/// | Ошибка отправки | [deliveryFailed] → `error_outline` |
/// | Отправлено (1 галочка) | [deliverySent] → `check` |
/// | Доставлено / прочитано (2 галочки) | [deliveryDelivered] → `done_all` |
/// | Просмотры (канал) | [visibility] → `visibility_outlined` |
abstract final class TelegramIcons {
  static const double size = 24;
  static const IconData chats = Icons.chat_bubble_outline;
  static const IconData contacts = Icons.contacts_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData attach = Icons.attach_file;
  static const IconData emoji = Icons.emoji_emotions_outlined;
  static const IconData keyboard = Icons.keyboard;
  static const IconData mic = Icons.mic;
  static const IconData send = Icons.send;
  static const IconData scheduleSend = Icons.schedule_send;
  static const IconData check = Icons.check;
  static const IconData close = Icons.close;
  static const IconData schedule = Icons.schedule;
  static const IconData search = Icons.search;
  static const IconData moreVert = Icons.more_vert;
  static const IconData call = Icons.call;
  static const IconData videocam = Icons.videocam_outlined;
  static const IconData groupCall = Icons.groups_outlined;
  static const IconData videoChat = Icons.video_chat;
  static const IconData delete = Icons.delete_outline;
  static const IconData forward = Icons.forward;
  static const IconData pin = Icons.push_pin;
  static const IconData mute = Icons.notifications_off_outlined;
  static const IconData draft = Icons.edit_outlined;
  static const IconData photo = Icons.photo_camera_outlined;
  static const IconData video = Icons.videocam_outlined;
  static const IconData document = Icons.attach_file;
  static const IconData music = Icons.music_note_outlined;
  static const IconData gif = Icons.gif_box_outlined;
  static const IconData poll = Icons.poll_outlined;
  static const IconData privateChat = Icons.person_outline;
  static const IconData group = Icons.group_outlined;
  static const IconData channel = Icons.campaign_outlined;
  static const IconData bot = Icons.smart_toy_outlined;
  static const IconData secretChat = Icons.lock_outline;
  static const IconData savedMessages = Icons.bookmark_outline;
  static const IconData deliverySending = Icons.access_time;
  static const IconData deliveryFailed = Icons.error_outline;
  static const IconData deliverySent = Icons.check;
  static const IconData deliveryDelivered = Icons.done_all;
  static const IconData visibility = Icons.visibility_outlined;
}
