import '../core/tdlib/tdlib_json.dart';
/// Состояние загрузки/выгрузки файла TDLib (updateFile).
class FileTransferState {
  const FileTransferState({
    required this.fileId,
    required this.transferredBytes,
    required this.totalBytes,
    required this.isUpload,
    required this.isActive,
    this.isCompleted = false,
  });

  final int fileId;
  final int transferredBytes;
  final int totalBytes;
  final bool isUpload;
  final bool isActive;
  final bool isCompleted;

  double get progress {
    if (totalBytes <= 0) {
      return 0;
    }
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  String get label {
    if (isCompleted) {
      return isUpload ? 'Загружено' : 'Скачано';
    }
    return isUpload ? 'Отправка…' : 'Загрузка…';
  }

  factory FileTransferState.fromTdlibFile(Map<String, dynamic> file) {
    final fileId = tdIntOr(file['id']);
    final local = file['local'] as Map<String, dynamic>? ?? {};
    final remote = file['remote'] as Map<String, dynamic>? ?? {};
    final expectedSize = tdInt(file['expected_size']) ?? tdInt(remote['size']) ?? 0;

    final isUploadingActive = local['is_uploading_active'] as bool? ?? false;
    final isUploadingCompleted = local['is_uploading_completed'] as bool? ?? false;
    final isDownloadingActive = local['is_downloading_active'] as bool? ?? false;
    final isDownloadingCompleted =
        local['is_downloading_completed'] as bool? ?? false;

    if (isUploadingActive || isUploadingCompleted) {
      final uploaded = tdInt(local['uploaded_size']) ??
          tdIntOr(remote['uploaded_size']);
      return FileTransferState(
        fileId: fileId,
        transferredBytes: uploaded,
        totalBytes: expectedSize > 0 ? expectedSize : tdIntOr(remote['size']),
        isUpload: true,
        isActive: isUploadingActive,
        isCompleted: isUploadingCompleted,
      );
    }

    final downloaded = tdIntOr(local['downloaded_prefix_size']);
    final total = tdInt(remote['size']) ?? expectedSize;
    return FileTransferState(
      fileId: fileId,
      transferredBytes: downloaded,
      totalBytes: total,
      isUpload: false,
      isActive: isDownloadingActive,
      isCompleted: isDownloadingCompleted,
    );
  }
}

/// Голосовое сообщение (messageVoiceNote).
class VoiceNoteInfo {
  const VoiceNoteInfo({
    required this.durationSeconds,
    this.waveform = const [],
  });

  final int durationSeconds;
  final List<int> waveform;

  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}';
  }

  /// Нормализованные высоты 0..1 для отрисовки waveform.
  List<double> get normalizedWaveform {
    if (waveform.isEmpty) {
      return const [0.2, 0.5, 0.35, 0.7, 0.4, 0.55, 0.3];
    }
    return waveform
        .map((value) => (value / 31).clamp(0.05, 1.0))
        .toList(growable: false);
  }

  factory VoiceNoteInfo.fromTdlib(Map<String, dynamic> voiceNote) {
    final raw = voiceNote['waveform'];
    final waveform = raw is List
        ? raw.whereType<int>().toList(growable: false)
        : raw is List<dynamic>
            ? raw.map((value) => tdIntOr(value)).toList(growable: false)
            : const <int>[];

    return VoiceNoteInfo(
      durationSeconds: tdIntOr(voiceNote['duration']),
      waveform: waveform,
    );
  }
}

/// Аудиофайл / музыка (messageAudio).
class AudioTrackInfo {
  const AudioTrackInfo({
    required this.durationSeconds,
    this.title,
    this.performer,
    this.fileName,
    this.coverFileId,
  });

  final int durationSeconds;
  final String? title;
  final String? performer;
  final String? fileName;
  final int? coverFileId;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (fileName != null && fileName!.isNotEmpty) {
      return fileName!;
    }
    return 'Аудио';
  }

  String? get displayArtist {
    if (performer != null && performer!.isNotEmpty) {
      return performer;
    }
    return null;
  }

  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory AudioTrackInfo.fromTdlib(Map<String, dynamic> audio) {
    final cover = audio['album_cover_thumbnail'] as Map<String, dynamic>?;
    final coverFile = cover?['file'] as Map<String, dynamic>?;
    return AudioTrackInfo(
      durationSeconds: tdIntOr(audio['duration']),
      title: audio['title'] as String?,
      performer: audio['performer'] as String?,
      fileName: audio['file_name'] as String?,
      coverFileId: tdInt(coverFile?['id']),
    );
  }
}

/// Парсинг размера документа.
class DocumentFileInfo {
  const DocumentFileInfo({
    this.fileName,
    this.fileSize = 0,
  });

  final String? fileName;
  final int fileSize;

  factory DocumentFileInfo.fromTdlib(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>? ?? {};
    final file = document['document'] as Map<String, dynamic>? ?? {};
    return DocumentFileInfo(
      fileName: document['file_name'] as String?,
      fileSize: tdInt(file['expected_size']) ?? tdInt(file['size']) ?? 0,
    );
  }

  String get sizeLabel => _formatBytes(fileSize);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
