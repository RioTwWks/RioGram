import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';
import '../models/chat_models.dart';

enum BubbleGroupPosition { single, first, middle, last }

sealed class ChatListEntry {}

final class ChatListDateEntry extends ChatListEntry {
  ChatListDateEntry(this.date);
  final DateTime date;
}

final class ChatListMessageEntry extends ChatListEntry {
  ChatListMessageEntry({
    required this.listIndex,
    required this.message,
    required this.groupPosition,
    required this.showSenderName,
  });
  final int listIndex;
  final ChatMessage message;
  final BubbleGroupPosition groupPosition;
  final bool showSenderName;
}

abstract final class MessageBubbleGrouping {
  static const _senderColors = [
    Color(0xFFCC5049), Color(0xFFD67736), Color(0xFF955CDB), Color(0xFF40A920),
    Color(0xFF4FAE4E), Color(0xFF2EADD4), Color(0xFF3390EC), Color(0xFF7B71C6),
    Color(0xFFD75093), Color(0xFFE17076),
  ];

  static Color senderNameColor(int? id, Color fallback) =>
      id == null ? fallback : _senderColors[id.abs() % _senderColors.length];

  static bool isSameGroup(ChatMessage a, ChatMessage b) {
    if (a.isServiceMessage || b.isServiceMessage) return false;
    if (a.isOutgoing != b.isOutgoing) return false;
    if (a.senderUserId != b.senderUserId) return false;
    return _sameDay(a.date, b.date);
  }

  static BorderRadius bubbleBorderRadius({
    required bool isOutgoing,
    required BubbleGroupPosition position,
  }) {
    final l = TelegramRadii.bubbleLarge;
    final s = TelegramRadii.bubbleGrouped;
    if (isOutgoing) {
      return switch (position) {
        BubbleGroupPosition.single => BorderRadius.circular(l),
        BubbleGroupPosition.first => BorderRadius.only(
            topLeft: Radius.circular(l), topRight: Radius.circular(l),
            bottomLeft: Radius.circular(l), bottomRight: Radius.circular(s)),
        BubbleGroupPosition.middle => BorderRadius.only(
            topLeft: Radius.circular(s), topRight: Radius.circular(l),
            bottomLeft: Radius.circular(s), bottomRight: Radius.circular(l)),
        BubbleGroupPosition.last => BorderRadius.only(
            topLeft: Radius.circular(s), topRight: Radius.circular(l),
            bottomLeft: Radius.circular(l), bottomRight: Radius.circular(l)),
      };
    }
    return switch (position) {
      BubbleGroupPosition.single => BorderRadius.circular(l),
      BubbleGroupPosition.first => BorderRadius.only(
          topLeft: Radius.circular(l), topRight: Radius.circular(l),
          bottomLeft: Radius.circular(s), bottomRight: Radius.circular(l)),
      BubbleGroupPosition.middle => BorderRadius.only(
          topLeft: Radius.circular(l), topRight: Radius.circular(s),
          bottomLeft: Radius.circular(l), bottomRight: Radius.circular(s)),
      BubbleGroupPosition.last => BorderRadius.only(
          topLeft: Radius.circular(l), topRight: Radius.circular(s),
          bottomLeft: Radius.circular(l), bottomRight: Radius.circular(l)),
    };
  }

  static bool shouldShowTail({
    required BubbleGroupPosition position,
    required bool showTail,
  }) =>
      showTail &&
      (position == BubbleGroupPosition.single ||
          position == BubbleGroupPosition.last);

  static List<ChatListEntry> buildListEntries({
    required List<ChatMessage> messages,
    required bool showSenderNamesInGroups,
  }) {
    final visible = _visibleIndices(messages);
    final entries = <ChatListEntry>[];
    DateTime? lastDate;
    for (var vi = 0; vi < visible.length; vi++) {
      final index = visible[vi];
      final message = messages[index];
      if (!message.isServiceMessage) {
        final d = message.date;
        if (lastDate == null || !_sameDay(lastDate, d)) {
          entries.add(ChatListDateEntry(d));
          lastDate = d;
        }
      }
      final prev = vi > 0 ? visible[vi - 1] : null;
      final next = vi < visible.length - 1 ? visible[vi + 1] : null;
      final pos = _positionAt(messages, index, prev, next);
      final showName = showSenderNamesInGroups &&
          !message.isOutgoing &&
          !message.isServiceMessage &&
          message.senderName != null &&
          (pos == BubbleGroupPosition.single ||
              pos == BubbleGroupPosition.first);
      entries.add(ChatListMessageEntry(
        listIndex: index,
        message: message,
        groupPosition: pos,
        showSenderName: showName,
      ));
    }
    return entries;
  }

  static List<int> _visibleIndices(List<ChatMessage> messages) {
    final indices = <int>[];
    for (var i = 0; i < messages.length; i++) {
      final g = messages[i].groupedId;
      if (g != null && g != 0 && i > 0 && messages[i - 1].groupedId == g) {
        continue;
      }
      indices.add(i);
    }
    return indices;
  }

  static BubbleGroupPosition _positionAt(
    List<ChatMessage> messages,
    int index,
    int? prev,
    int? next,
  ) {
    final m = messages[index];
    if (m.isServiceMessage) return BubbleGroupPosition.single;
    final hasPrev = prev != null && isSameGroup(messages[prev], m);
    final hasNext = next != null && isSameGroup(m, messages[next]);
    if (!hasPrev && !hasNext) return BubbleGroupPosition.single;
    if (!hasPrev && hasNext) return BubbleGroupPosition.first;
    if (hasPrev && hasNext) return BubbleGroupPosition.middle;
    return BubbleGroupPosition.last;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
