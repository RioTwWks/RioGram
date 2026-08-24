import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/cache_models.dart';
import '../../models/chat_models.dart';
import '../tdlib/tdlib_client.dart';

/// Кэш медиа, автозагрузка и очистка хранилища TDLib.
class MediaCacheManager extends ChangeNotifier {
  MediaCacheManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  DownloadNetworkType _currentNetwork = DownloadNetworkType.other;
  final Map<DownloadNetworkType, AutoDownloadSettingsModel> _autoDownload = {};
  StorageStatisticsModel? _storageStats;
  String? _filesDirectory;
  var _isLoadingStats = false;
  var _isOptimizing = false;
  String? _lastError;
  int _requestId = 0;

  DownloadNetworkType get currentNetwork => _currentNetwork;
  StorageStatisticsModel? get storageStats => _storageStats;
  String? get filesDirectory => _filesDirectory;
  bool get isLoadingStats => _isLoadingStats;
  bool get isOptimizing => _isOptimizing;
  String? get lastError => _lastError;

  AutoDownloadSettingsModel settingsFor(DownloadNetworkType type) {
    return _autoDownload[type] ?? AutoDownloadSettingsModel.defaults(type);
  }

  AutoDownloadSettingsModel get currentAutoDownloadSettings =>
      settingsFor(_currentNetwork);

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    _connectivitySub ??=
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    unawaited(_refreshFilesDirectory());
    unawaited(_detectInitialNetwork());
    _initializeDefaultSettings();
    unawaited(loadAutoDownloadPresets());
    unawaited(refreshStorageStatistics());
  }

  void _initializeDefaultSettings() {
    for (final type in DownloadNetworkType.values) {
      _autoDownload.putIfAbsent(
        type,
        () => AutoDownloadSettingsModel.defaults(type),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _refreshFilesDirectory() async {
    final dir = await getApplicationSupportDirectory();
    _filesDirectory = '${dir.path}/tdlib_files';
    notifyListeners();
  }

  Future<void> _detectInitialNetwork() async {
    final results = await Connectivity().checkConnectivity();
    await _applyConnectivity(results);
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    await _applyConnectivity(results);
  }

  Future<void> _applyConnectivity(List<ConnectivityResult> results) async {
    final network = _mapConnectivity(results);
    if (network == _currentNetwork) {
      return;
    }
    _currentNetwork = network;
    _client.send({
      '@type': 'setNetworkType',
      'type': network.toTdlib(),
    });
    notifyListeners();
  }

  DownloadNetworkType _mapConnectivity(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return DownloadNetworkType.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return DownloadNetworkType.mobile;
    }
    return DownloadNetworkType.other;
  }

  Future<void> loadAutoDownloadPresets() async {
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getAutoDownloadSettingsPresets',
      '@extra': 'autoDownloadPresets_$requestId',
    });
  }

  Future<void> saveAutoDownloadSettings(AutoDownloadSettingsModel settings) async {
    _autoDownload[settings.networkType] = settings;
    notifyListeners();
    _client.send({
      '@type': 'setAutoDownloadSettings',
      'type': settings.networkType.toTdlib(),
      'settings': settings.toTdlib(),
    });
  }

  Future<void> refreshStorageStatistics() async {
    _isLoadingStats = true;
    _lastError = null;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getStorageStatistics',
      'chat_limit': 0,
      '@extra': 'storageStats_$requestId',
    });
  }

  Future<void> optimizeStorage({
    int size = 0,
    int ttl = 86400,
    int count = 0,
    List<CacheFileType> fileTypes = const [],
  }) async {
    _isOptimizing = true;
    _lastError = null;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'optimizeStorage',
      'size': size,
      'ttl': ttl,
      'count': count,
      'immunity_delay': 0,
      'file_types': fileTypes.map((type) => type.toTdlib()).toList(),
      '@extra': 'optimizeStorage_$requestId',
    });
  }

  void clearPhotosCache() {
    unawaited(optimizeStorage(
      fileTypes: const [CacheFileType.photo],
      count: 1000,
    ));
  }

  void clearVideosCache() {
    unawaited(optimizeStorage(
      fileTypes: const [CacheFileType.video],
      count: 1000,
    ));
  }

  void clearAudioCache() {
    unawaited(optimizeStorage(
      fileTypes: const [CacheFileType.audio],
      count: 1000,
    ));
  }

  void clearDocumentsCache() {
    unawaited(optimizeStorage(
      fileTypes: const [CacheFileType.document],
      count: 1000,
    ));
  }

  void clearAllMediaCache() {
    unawaited(optimizeStorage(
      fileTypes: const [
        CacheFileType.photo,
        CacheFileType.video,
        CacheFileType.audio,
        CacheFileType.document,
      ],
      count: 10_000,
    ));
  }

  void deleteCachedFile(int fileId) {
    _client.send({
      '@type': 'deleteFile',
      'file_id': fileId,
    });
  }

  void requestDownload(int fileId, {int priority = 16}) {
    _client.send({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': priority,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  bool shouldAutoDownload(ChatMessage message) {
    if (message.mediaFileId == null) {
      return false;
    }
    return currentAutoDownloadSettings.allowsMessageDownload(
      kind: message.content.kind,
      fileSizeBytes: message.content.fileSizeBytes,
      isOutgoing: message.isOutgoing,
    );
  }

  bool shouldAutoDownloadCover(ChatMessage message) {
    if (message.coverFileId == null) {
      return false;
    }
    return currentAutoDownloadSettings.isEnabled;
  }

  Future<int> estimateCacheDirectoryBytes() async {
    final path = _filesDirectory;
    if (path == null) {
      return 0;
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String?;
    final extra = update['@extra'] as String?;

    if (type == 'autoDownloadSettingsPresets' &&
        extra != null &&
        extra.startsWith('autoDownloadPresets_')) {
      void applyPreset(
        Map<String, dynamic>? preset,
        DownloadNetworkType network,
      ) {
        if (preset != null) {
          _autoDownload[network] =
              AutoDownloadSettingsModel.fromTdlib(preset, network);
        }
      }

      applyPreset(
        update['low'] as Map<String, dynamic>?,
        DownloadNetworkType.roaming,
      );
      applyPreset(
        update['medium'] as Map<String, dynamic>?,
        DownloadNetworkType.mobile,
      );
      applyPreset(
        update['high'] as Map<String, dynamic>?,
        DownloadNetworkType.wifi,
      );
      applyPreset(
        update['high'] as Map<String, dynamic>?,
        DownloadNetworkType.other,
      );
      notifyListeners();
      return;
    }

    if (type == 'storageStatistics' && extra != null && extra.startsWith('storageStats_')) {
      _storageStats = StorageStatisticsModel.fromTdlib(update);
      _isLoadingStats = false;
      notifyListeners();
      return;
    }

    if (extra != null && extra.startsWith('optimizeStorage_')) {
      _isOptimizing = false;
      if (type == 'storageStatistics') {
        _storageStats = StorageStatisticsModel.fromTdlib(update);
      } else if (type == 'error') {
        _lastError = update['message'] as String? ?? 'Ошибка очистки кэша';
      }
      notifyListeners();
      if (type != 'error') {
        unawaited(refreshStorageStatistics());
      }
      return;
    }

    if (type == 'error' && extra != null && extra.startsWith('storageStats_')) {
      _isLoadingStats = false;
      _lastError = update['message'] as String? ?? 'Не удалось получить статистику';
      notifyListeners();
    }
  }
}
