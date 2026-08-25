import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stories/story_manager.dart';

/// Публикация фото/видео-истории.
class PostStoryScreen extends StatefulWidget {
  const PostStoryScreen({super.key});

  @override
  State<PostStoryScreen> createState() => _PostStoryScreenState();
}

class _PostStoryScreenState extends State<PostStoryScreen> {
  final _captionController = TextEditingController();
  String? _selectedPath;
  var _isVideo = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyManager = context.watch<StoryManager>();
    final postState = storyManager.postState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая история'),
        actions: [
          TextButton(
            onPressed: postState.isPosting ||
                    !postState.canPost ||
                    _selectedPath == null
                ? null
                : _publish,
            child: postState.isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Опубликовать'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (postState.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                postState.lastError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: postState.isPosting ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Фото'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: postState.isPosting ? null : _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Видео'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedPath != null) ...[
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isVideo
                    ? Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white,
                        ),
                      )
                    : Image.file(
                        File(_selectedPath!),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Подпись',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'История будет видна всем контактам в течение 24 часов.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPath = path;
      _isVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPath = path;
      _isVideo = true;
    });
  }

  void _publish() {
    final path = _selectedPath;
    if (path == null) {
      return;
    }
    final caption = _captionController.text.trim();
    final manager = context.read<StoryManager>();
    if (_isVideo) {
      manager.postVideoStory(path: path, caption: caption);
    } else {
      manager.postPhotoStory(path: path, caption: caption);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('История публикуется…')),
    );
  }
}
