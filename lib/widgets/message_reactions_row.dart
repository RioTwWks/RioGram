import 'package:flutter/material.dart';

import '../models/message_enrichment.dart';

/// Строка реакций под сообщением.
class MessageReactionsRow extends StatelessWidget {
  const MessageReactionsRow({
    super.key,
    required this.reactions,
    this.onReactionTap,
    this.onAddReaction,
  });

  final List<MessageReactionSummary> reactions;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAddReaction;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty && onAddReaction == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...reactions.map(
          (reaction) => ActionChip(
            label: Text('${reaction.emoji} ${reaction.count}'),
            backgroundColor: reaction.isChosen
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            onPressed:
                onReactionTap == null ? null : () => onReactionTap!(reaction.emoji),
          ),
        ),
        if (onAddReaction != null)
          ActionChip(
            avatar: const Icon(Icons.add_reaction_outlined, size: 16),
            label: const Text(''),
            onPressed: onAddReaction,
          ),
      ],
    );
  }
}

/// Быстрый выбор emoji-реакции.
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({super.key});

  static const defaultEmojis = ['👍', '❤️', '🔥', '👏', '😂', '🎉', '😮', '😢'];

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => const ReactionPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: defaultEmojis
              .map(
                (emoji) => InkWell(
                  onTap: () => Navigator.pop(context, emoji),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
