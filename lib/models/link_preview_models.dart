import 'dart:convert';

import 'formatted_text.dart';

/// Превью ссылки из TDLib `linkPreview` (или базовое из URL в тексте).
class LinkPreviewInfo {
  const LinkPreviewInfo({
    required this.url,
    this.displayUrl,
    this.siteName,
    this.title,
    this.description,
    this.thumbnailBytes,
  });

  final String url;
  final String? displayUrl;
  final String? siteName;
  final String? title;
  final String? description;
  final List<int>? thumbnailBytes;

  String get domainLabel {
    for (final raw in [displayUrl, url]) {
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
      final host = uri?.host;
      if (host != null && host.isNotEmpty) {
        return host.startsWith('www.') ? host.substring(4) : host;
      }
    }
    return displayUrl ?? url;
  }

  bool get hasBody =>
      (title != null && title!.isNotEmpty) ||
      (description != null && description!.isNotEmpty) ||
      (siteName != null && siteName!.isNotEmpty);

  factory LinkPreviewInfo.fromTdlib(Map<String, dynamic> json) {
    final descriptionFormatted = FormattedText.fromTdlib(
      json['description'] as Map<String, dynamic>?,
    );
    return LinkPreviewInfo(
      url: json['url'] as String? ?? '',
      displayUrl: json['display_url'] as String?,
      siteName: json['site_name'] as String?,
      title: json['title'] as String?,
      description: descriptionFormatted.text.isEmpty
          ? null
          : descriptionFormatted.text,
      thumbnailBytes: _thumbnailBytesFromType(
        json['type'] as Map<String, dynamic>?,
      ),
    );
  }

  static LinkPreviewInfo? fromFormattedText(FormattedText formatted) {
    for (final entity in formatted.entities) {
      if (entity.kind == TextEntityKind.url ||
          entity.kind == TextEntityKind.textUrl) {
        final url = entity.kind == TextEntityKind.textUrl
            ? entity.url
            : _entityText(formatted.text, entity);
        if (url != null && url.isNotEmpty) {
          return LinkPreviewInfo(url: url, displayUrl: url);
        }
      }
    }
    return null;
  }

  static String? _entityText(String text, TextEntity entity) {
    final start = entity.offset;
    final end = start + entity.length;
    if (start < 0 || end > text.length) return null;
    return text.substring(start, end);
  }

  static List<int>? _thumbnailBytesFromType(Map<String, dynamic>? type) {
    if (type == null) return null;
    return switch (type['@type']) {
      'linkPreviewTypePhoto' => _miniThumbnailFromPhoto(
          type['photo'] as Map<String, dynamic>?,
        ),
      'linkPreviewTypeArticle' => _miniThumbnailFromPhoto(
          type['photo'] as Map<String, dynamic>?,
        ),
      'linkPreviewTypeVideo' => _miniThumbnailFromPhoto(
          type['cover'] as Map<String, dynamic>?,
        ),
      _ => null,
    };
  }

  static List<int>? _miniThumbnailFromPhoto(Map<String, dynamic>? photo) {
    final sizes = photo?['sizes'] as List<dynamic>? ?? [];
    for (final raw in sizes) {
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['type'] as Map<String, dynamic>?;
      if (type?['@type'] != 'thumbnailFormatJpeg') continue;
      final file = raw['photo'] as Map<String, dynamic>?;
      final local = file?['local'] as Map<String, dynamic>?;
      if (local?['is_downloading_completed'] == true) {
        final path = local?['path'] as String?;
        if (path != null && path.isNotEmpty) {
          return null; // local path handled elsewhere if needed
        }
      }
      final mini = raw['minithumbnail'] as Map<String, dynamic>?;
      final data = mini?['data'] as String?;
      if (data != null && data.isNotEmpty) {
        return _decodeBase64(data);
      }
    }
    return null;
  }

  static List<int>? _decodeBase64(String data) {
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}
