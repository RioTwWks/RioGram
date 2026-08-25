import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/anti_recall_models.dart';
import '../../models/chat_models.dart';

/// Локальное хранилище снимков сообщений для анти-отзыва.
class AntiRecallStore extends ChangeNotifier {
  AntiRecallStore({String? accountSuffix}) : _accountSuffix = accountSuffix ?? '';

  final String _accountSuffix;
  final Map<String, AntiRecallSnapshot> _snapshots = {};

  var _isLoaded = false;

  bool get isLoaded => _isLoaded;
  Map<String, AntiRecallSnapshot> get snapshots => Map.unmodifiable(_snapshots);

  AntiRecallSnapshot? snapshotFor(int chatId, int messageId) =>
      _snapshots['$chatId:$messageId'];

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    final file = await _storageFile();
    if (!await file.exists()) {
      _isLoaded = true;
      return;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _snapshots[entry.key] = AntiRecallSnapshot.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Повреждённый файл — начинаем с пустого хранилища.
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> captureMessage(
    ChatMessage message, {
    AntiRecallSnapshotReason reason = AntiRecallSnapshotReason.received,
  }) async {
    await load();
    final key = '${message.chatId}:${message.id}';
    final existing = _snapshots[key];
    if (existing != null && reason == AntiRecallSnapshotReason.received) {
      return;
    }

    _snapshots[key] = AntiRecallSnapshot.fromMessage(
      message,
      reason: reason,
      capturedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markDeleted(ChatMessage message) async {
    await load();
    final key = '${message.chatId}:${message.id}';
    final existing = _snapshots[key];
    _snapshots[key] = AntiRecallSnapshot.fromMessage(
      message,
      reason: AntiRecallSnapshotReason.deleted,
      capturedAt: existing?.capturedAt ?? DateTime.now(),
      preservedContent: existing?.content ?? message.content,
      editDate: message.editDate,
    );
    await _persist();
    notifyListeners();
  }

  Future<File> _storageFile() async {
    final dir = await getApplicationSupportDirectory();
    final suffix = _accountSuffix.isEmpty ? 'default' : _accountSuffix;
    return File('${dir.path}/anti_recall_$suffix.json');
  }

  Future<void> _persist() async {
    final file = await _storageFile();
    final encoded = {
      for (final entry in _snapshots.entries) entry.key: entry.value.toJson(),
    };
    await file.writeAsString(jsonEncode(encoded));
  }
}
