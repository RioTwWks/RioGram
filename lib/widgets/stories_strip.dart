import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../core/stories/story_manager.dart';
import '../models/story_models.dart';
import '../screens/stories/post_story_screen.dart';
import '../screens/stories/story_viewer_screen.dart';
import 'story_avatar_ring.dart';

/// Горизонтальная лента историй над списком чатов.
class StoriesStrip extends StatefulWidget {
  const StoriesStrip({super.key});

  @override
  State<StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<StoriesStrip> {
  var _initialized = false;

  @override
  Widget build(BuildContext context) {
    final storyManager = context.watch<StoryManager>();
    final chatManager = context.watch<ChatManager>();
    final savedMessagesChatId = chatManager.savedMessagesChatId;

    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (savedMessagesChatId != null) {
          storyManager.setSavedMessagesChatId(savedMessagesChatId);
        }
        storyManager.loadMainStoryList();
      });
    } else if (savedMessagesChatId != null) {
      storyManager.setSavedMessagesChatId(savedMessagesChatId);
    }

    final posters = storyManager.posters;

    if (posters.isEmpty &&
        !storyManager.isLoadingList &&
        savedMessagesChatId == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _MyStoryTile(
            onTap: () => _openPostStory(context),
          ),
          ...posters.map((poster) {
            final chat = chatManager.chatById(poster.chatId);
            final title = poster.title.isNotEmpty
                ? poster.title
                : chat?.title ?? 'История';
            final avatarPath =
                poster.avatarLocalPath ?? chat?.avatarLocalPath;
            return _PosterStoryTile(
              poster: poster.copyWith(
                title: title,
                avatarLocalPath: avatarPath,
              ),
              onTap: () => _openPosterStories(context, poster),
            );
          }),
        ],
      ),
    );
  }

  void _openPostStory(BuildContext context) {
    context.read<StoryManager>().preparePostStory();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PostStoryScreen(),
      ),
    );
  }

  void _openPosterStories(BuildContext context, StoryPosterSummary poster) {
    if (poster.stories.isEmpty) {
      return;
    }
    final chatManager = context.read<ChatManager>();
    final chat = chatManager.chatById(poster.chatId);
    final title = poster.title.isNotEmpty
        ? poster.title
        : chat?.title ?? 'История';
    final startStory = poster.stories.firstWhere(
      (story) => story.storyId > poster.maxReadStoryId,
      orElse: () => poster.stories.first,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryViewerScreen(
          posterChatId: poster.chatId,
          initialStoryId: startStory.storyId,
          posterTitle: title,
        ),
      ),
    );
  }
}

class _MyStoryTile extends StatelessWidget {
  const _MyStoryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  StoryAvatarRing(
                    title: 'Я',
                    readState: StoryReadState.none,
                    radius: 24,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Моя',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterStoryTile extends StatelessWidget {
  const _PosterStoryTile({
    required this.poster,
    required this.onTap,
  });

  final StoryPosterSummary poster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              StoryAvatarRing(
                title: poster.title,
                localPath: poster.avatarLocalPath,
                readState: poster.readState,
                radius: 24,
                onTap: onTap,
              ),
              const SizedBox(height: 6),
              Text(
                poster.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
