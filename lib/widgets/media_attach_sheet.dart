import 'package:flutter/material.dart';

import '../models/media_models.dart';

/// Выбор типа вложения: сжатие vs файл, альбом, кружочек.
class MediaAttachSheet extends StatelessWidget {
  const MediaAttachSheet({super.key});

  static Future<MediaAttachAction?> show(BuildContext context) {
    return showModalBottomSheet<MediaAttachAction>(
      context: context,
      builder: (_) => const MediaAttachSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Фото (сжатое)'),
            subtitle: const Text('Отправить как фото'),
            onTap: () =>
                Navigator.pop(context, MediaAttachAction.photoCompressed),
          ),
          ListTile(
            leading: const Icon(Icons.photo_size_select_large_outlined),
            title: const Text('Фото (как файл)'),
            subtitle: const Text('Без сжатия, как документ'),
            onTap: () => Navigator.pop(context, MediaAttachAction.photoAsFile),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Видео (сжатое)'),
            subtitle: const Text('Inline-воспроизведение в чате'),
            onTap: () =>
                Navigator.pop(context, MediaAttachAction.videoCompressed),
          ),
          ListTile(
            leading: const Icon(Icons.video_file_outlined),
            title: const Text('Видео (как файл)'),
            onTap: () => Navigator.pop(context, MediaAttachAction.videoAsFile),
          ),
          ListTile(
            leading: const Icon(Icons.radio_button_checked_outlined),
            title: const Text('Видеосообщение'),
            subtitle: const Text('Кружочек (выбор видеофайла)'),
            onTap: () => Navigator.pop(context, MediaAttachAction.videoNote),
          ),
          ListTile(
            leading: const Icon(Icons.collections_outlined),
            title: const Text('Альбом'),
            subtitle: const Text('Несколько фото или видео'),
            onTap: () => Navigator.pop(context, MediaAttachAction.album),
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: const Text('Аудиофайл'),
            subtitle: const Text('Музыка / MP3 как messageAudio'),
            onTap: () => Navigator.pop(context, MediaAttachAction.audio),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Файл'),
            onTap: () => Navigator.pop(context, MediaAttachAction.document),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Геолокация'),
            subtitle: const Text('Точка на карте'),
            onTap: () => Navigator.pop(context, MediaAttachAction.location),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Live Location'),
            subtitle: const Text('Трансляция геопозиции'),
            onTap: () => Navigator.pop(context, MediaAttachAction.liveLocation),
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Место'),
            subtitle: const Text('Venue с названием и адресом'),
            onTap: () => Navigator.pop(context, MediaAttachAction.venue),
          ),
        ],
      ),
    );
  }
}
