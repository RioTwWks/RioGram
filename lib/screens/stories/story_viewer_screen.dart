import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/stories/story_manager.dart';
import '../../models/story_models.dart';

/// Полноэкранный просмотр историй с реакциями и ответом.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.posterChatId,
    required this.initialStoryId,
    required this.posterTitle,
  });

  final int posterChatId;
  final int initialStoryId;
  final String posterTitle;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int _currentStoryId;
  VideoPlayerController? _videoController;
  final _replyController = TextEditingController();
  var _showReplyField = false;
  StoryManager? _storyManager;

  @override
  void initState() {
    super.initState();
    _currentStoryId = widget.initialStoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final manager = context.read<StoryManager>();
      _storyManager = manager;
      manager.loadAvailableReactions();
      manager.openStoryViewer(widget.posterChatId, _currentStoryId);
      manager.refreshPosterStories(widget.posterChatId);
      manager.loadStory(widget.posterChatId, _currentStoryId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storyManager ??= context.read<StoryManager>();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _replyController.dispose();
    _storyManager?.closeStoryViewer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyManager = context.watch<StoryManager>();
    final poster = storyManager.posterForChat(widget.posterChatId);
    final story =
        storyManager.storyFor(widget.posterChatId, _currentStoryId);
    final reactions = storyManager.availableReactions;

    _syncVideoController(story);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final width = MediaQuery.sizeOf(context).width;
                if (details.globalPosition.dx < width * 0.35) {
                  _goPrevious(poster);
                } else {
                  _goNext(poster);
                }
              },
              child: Center(child: _buildMedia(story)),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.posterTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  if (poster != null && poster.stories.length > 1)
                    Row(
                      children: [
                        for (final info in poster.stories)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              color: info.storyId <= _currentStoryId
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (story?.caption.isNotEmpty == true)
              Positioned(
                left: 16,
                right: 16,
                bottom: 120,
                child: Text(
                  story!.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(story, reactions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(StoryModel? story) {
    if (story == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (story.mediaKind == StoryMediaKind.live) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, color: Colors.redAccent, size: 48),
          SizedBox(height: 12),
          Text(
            'Live-история',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    final path = story.mediaLocalPath;
    if (path == null || path.isEmpty) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Загрузка…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (story.mediaKind == StoryMediaKind.video) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white);
      }
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      );
    }

    if (story.mediaKind == StoryMediaKind.photo) {
      return InteractiveViewer(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
        ),
      );
    }

    return const Text(
      'Формат истории не поддерживается',
      style: TextStyle(color: Colors.white70),
    );
  }

  Widget _buildBottomBar(
    StoryModel? story,
    List<StoryReactionOption> reactions,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showReplyField && story?.canBeReplied == true) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ответить…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendReply(story!),
                  ),
                ),
                IconButton(
                  onPressed: () => _sendReply(story!),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: reactions.take(8).map((reaction) {
                      final isChosen =
                          story?.chosenReactionEmoji == reaction.emoji;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ActionChip(
                          label: Text(reaction.emoji),
                          backgroundColor:
                              isChosen ? Colors.white24 : Colors.white12,
                          onPressed: story == null
                              ? null
                              : () {
                                  if (isChosen) {
                                    context
                                        .read<StoryManager>()
                                        .removeStoryReaction(
                                          posterChatId: widget.posterChatId,
                                          storyId: _currentStoryId,
                                        );
                                  } else {
                                    context
                                        .read<StoryManager>()
                                        .setStoryReaction(
                                          posterChatId: widget.posterChatId,
                                          storyId: _currentStoryId,
                                          emoji: reaction.emoji,
                                        );
                                  }
                                },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (story?.canBeReplied == true)
                IconButton(
                  tooltip: 'Ответить',
                  onPressed: () {
                    setState(() => _showReplyField = !_showReplyField);
                  },
                  icon: Icon(
                    _showReplyField ? Icons.close : Icons.reply,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncVideoController(StoryModel? story) {
    if (story?.mediaKind != StoryMediaKind.video) {
      _videoController?.dispose();
      _videoController = null;
      return;
    }
    final path = story?.mediaLocalPath;
    if (path == null || path.isEmpty) {
      return;
    }
    if (_videoController?.dataSource == path) {
      return;
    }
    _videoController?.dispose();
    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller
        ..setLooping(true)
        ..play();
      setState(() {});
    });
  }

  void _goPrevious(StoryPosterSummary? poster) {
    if (poster == null) {
      Navigator.of(context).pop();
      return;
    }
    final index = poster.stories.indexWhere(
      (story) => story.storyId == _currentStoryId,
    );
    if (index <= 0) {
      Navigator.of(context).pop();
      return;
    }
    final previous = poster.stories[index - 1];
    setState(() {
      _currentStoryId = previous.storyId;
      _showReplyField = false;
      _replyController.clear();
    });
    final manager = context.read<StoryManager>();
    manager.advanceViewerStory(widget.posterChatId, _currentStoryId);
  }

  void _goNext(StoryPosterSummary? poster) {
    if (poster == null) {
      Navigator.of(context).pop();
      return;
    }
    final index = poster.stories.indexWhere(
      (story) => story.storyId == _currentStoryId,
    );
    if (index < 0 || index >= poster.stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    final next = poster.stories[index + 1];
    setState(() {
      _currentStoryId = next.storyId;
      _showReplyField = false;
      _replyController.clear();
    });
    final manager = context.read<StoryManager>();
    manager.advanceViewerStory(widget.posterChatId, _currentStoryId);
  }

  void _sendReply(StoryModel story) {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      return;
    }
    context.read<StoryManager>().replyToStory(
          posterChatId: widget.posterChatId,
          storyId: _currentStoryId,
          text: text,
        );
    _replyController.clear();
    setState(() => _showReplyField = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ответ отправлен')),
    );
  }
}
