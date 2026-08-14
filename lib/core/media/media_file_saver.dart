import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Сохранение медиафайла в каталог «Загрузки» / Documents.
class MediaFileSaver {
  const MediaFileSaver._();

  static Future<String?> saveToDownloads(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      return null;
    }

    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {
      targetDir = null;
    }
    targetDir ??= await getApplicationDocumentsDirectory();

    final fileName = p.basename(sourcePath);
    final destination = File(p.join(targetDir.path, fileName));
    if (await destination.exists()) {
      final stem = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      final stamped = '$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
      final unique = File(p.join(targetDir.path, stamped));
      await source.copy(unique.path);
      return unique.path;
    }

    await source.copy(destination.path);
    return destination.path;
  }

  static Future<void> copyPathToClipboard(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
  }
}
