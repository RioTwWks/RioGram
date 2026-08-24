import 'chat_models.dart';
import '../core/tdlib/tdlib_json.dart';

/// Тип сети для автозагрузки TDLib.
enum DownloadNetworkType {
  wifi,
  mobile,
  roaming,
  other,
}

extension DownloadNetworkTypeX on DownloadNetworkType {
  String get label => switch (this) {
        DownloadNetworkType.wifi => 'Wi‑Fi',
        DownloadNetworkType.mobile => 'Мобильная',
        DownloadNetworkType.roaming => 'Роуминг',
        DownloadNetworkType.other => 'Другое',
      };

  Map<String, dynamic> toTdlib() => {
        '@type': switch (this) {
          DownloadNetworkType.wifi => 'networkTypeWiFi',
          DownloadNetworkType.mobile => 'networkTypeMobile',
          DownloadNetworkType.roaming => 'networkTypeMobileRoaming',
          DownloadNetworkType.other => 'networkTypeOther',
        },
      };

  static DownloadNetworkType fromTdlib(String type) => switch (type) {
        'networkTypeWiFi' => DownloadNetworkType.wifi,
        'networkTypeMobile' => DownloadNetworkType.mobile,
        'networkTypeMobileRoaming' => DownloadNetworkType.roaming,
        _ => DownloadNetworkType.other,
      };
}

/// Настройки автозагрузки для одного типа сети.
class AutoDownloadSettingsModel {
  const AutoDownloadSettingsModel({
    required this.networkType,
    required this.isEnabled,
    required this.maxPhotoBytes,
    required this.maxVideoBytes,
    required this.maxOtherBytes,
    this.preloadNextAudio = true,
    this.preloadLargeVideo = false,
  });

  final DownloadNetworkType networkType;
  final bool isEnabled;
  final int maxPhotoBytes;
  final int maxVideoBytes;
  final int maxOtherBytes;
  final bool preloadNextAudio;
  final bool preloadLargeVideo;

  static const int mb1 = 1024 * 1024;
  static const int mb10 = 10 * mb1;

  factory AutoDownloadSettingsModel.defaults(DownloadNetworkType networkType) {
    return switch (networkType) {
      DownloadNetworkType.wifi => AutoDownloadSettingsModel(
          networkType: networkType,
          isEnabled: true,
          maxPhotoBytes: mb10,
          maxVideoBytes: mb10,
          maxOtherBytes: mb10,
        ),
      DownloadNetworkType.mobile => AutoDownloadSettingsModel(
          networkType: networkType,
          isEnabled: true,
          maxPhotoBytes: mb1,
          maxVideoBytes: mb1,
          maxOtherBytes: mb1,
        ),
      DownloadNetworkType.roaming => AutoDownloadSettingsModel(
          networkType: networkType,
          isEnabled: false,
          maxPhotoBytes: 0,
          maxVideoBytes: 0,
          maxOtherBytes: 0,
        ),
      DownloadNetworkType.other => AutoDownloadSettingsModel(
          networkType: networkType,
          isEnabled: true,
          maxPhotoBytes: mb10,
          maxVideoBytes: mb10,
          maxOtherBytes: mb10,
        ),
    };
  }

  factory AutoDownloadSettingsModel.fromTdlib(
    Map<String, dynamic> json,
    DownloadNetworkType networkType,
  ) {
    return AutoDownloadSettingsModel(
      networkType: networkType,
      isEnabled: json['is_auto_download_enabled'] as bool? ?? true,
      maxPhotoBytes: tdInt(json['max_photo_file_size']) ?? mb10,
      maxVideoBytes: tdInt(json['max_video_file_size']) ?? mb10,
      maxOtherBytes: tdInt(json['max_other_file_size']) ?? mb10,
      preloadNextAudio: json['preload_next_audio'] as bool? ?? true,
      preloadLargeVideo: json['preload_large_videos'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toTdlib() => {
        '@type': 'autoDownloadSettings',
        'is_auto_download_enabled': isEnabled,
        'max_photo_file_size': maxPhotoBytes,
        'max_video_file_size': maxVideoBytes,
        'max_other_file_size': maxOtherBytes,
        'video_upload_bitrate': 0,
        'preload_large_videos': preloadLargeVideo,
        'preload_next_audio': preloadNextAudio,
        'preload_stories': false,
        'use_less_data_for_calls': false,
      };

  AutoDownloadSettingsModel copyWith({
    bool? isEnabled,
    int? maxPhotoBytes,
    int? maxVideoBytes,
    int? maxOtherBytes,
    bool? preloadNextAudio,
    bool? preloadLargeVideo,
  }) {
    return AutoDownloadSettingsModel(
      networkType: networkType,
      isEnabled: isEnabled ?? this.isEnabled,
      maxPhotoBytes: maxPhotoBytes ?? this.maxPhotoBytes,
      maxVideoBytes: maxVideoBytes ?? this.maxVideoBytes,
      maxOtherBytes: maxOtherBytes ?? this.maxOtherBytes,
      preloadNextAudio: preloadNextAudio ?? this.preloadNextAudio,
      preloadLargeVideo: preloadLargeVideo ?? this.preloadLargeVideo,
    );
  }

  /// Можно ли автоматически скачать сообщение с такими параметрами.
  bool allowsMessageDownload({
    required MessageKind kind,
    required int? fileSizeBytes,
    required bool isOutgoing,
  }) {
    if (isOutgoing) {
      return true;
    }
    if (!isEnabled) {
      return false;
    }
    final size = fileSizeBytes ?? 0;
    return switch (kind) {
      MessageKind.photo =>
        maxPhotoBytes <= 0 || size <= maxPhotoBytes,
      MessageKind.sticker || MessageKind.animation =>
        maxPhotoBytes <= 0 || size <= maxPhotoBytes,
      MessageKind.video || MessageKind.videoNote =>
        maxVideoBytes <= 0 || size <= maxVideoBytes,
      MessageKind.voice || MessageKind.audio || MessageKind.document =>
        maxOtherBytes <= 0 || size <= maxOtherBytes,
      _ => false,
    };
  }
}

/// Статистика хранилища TDLib.
class StorageStatisticsModel {
  const StorageStatisticsModel({
    this.totalSize = 0,
    this.photoSize = 0,
    this.videoSize = 0,
    this.audioSize = 0,
    this.documentSize = 0,
    this.otherSize = 0,
    this.databaseSize = 0,
  });

  final int totalSize;
  final int photoSize;
  final int videoSize;
  final int audioSize;
  final int documentSize;
  final int otherSize;
  final int databaseSize;

  factory StorageStatisticsModel.fromTdlib(Map<String, dynamic> json) {
    int readSize(String key) => tdIntOr(json[key]);
    return StorageStatisticsModel(
      totalSize: readSize('size'),
      photoSize: readSize('photo_size'),
      videoSize: readSize('video_size'),
      audioSize: readSize('audio_size'),
      documentSize: readSize('document_size'),
      otherSize: readSize('other_size'),
      databaseSize: readSize('database_size'),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Тип файла для optimizeStorage / deleteFile.
enum CacheFileType {
  photo,
  video,
  audio,
  document,
  other,
}

extension CacheFileTypeX on CacheFileType {
  Map<String, dynamic> toTdlib() => {
        '@type': switch (this) {
          CacheFileType.photo => 'fileTypePhoto',
          CacheFileType.video => 'fileTypeVideo',
          CacheFileType.audio => 'fileTypeAudio',
          CacheFileType.document => 'fileTypeDocument',
          CacheFileType.other => 'fileTypeUnknown',
        },
      };

  String get label => switch (this) {
        CacheFileType.photo => 'Фото',
        CacheFileType.video => 'Видео',
        CacheFileType.audio => 'Аудио',
        CacheFileType.document => 'Документы',
        CacheFileType.other => 'Прочее',
      };
}

/// Локально закэшированный файл сообщения.
class CachedMediaEntry {
  const CachedMediaEntry({
    required this.fileId,
    required this.localPath,
    required this.kind,
    this.fileSizeBytes = 0,
  });

  final int fileId;
  final String localPath;
  final String kind;
  final int fileSizeBytes;
}
