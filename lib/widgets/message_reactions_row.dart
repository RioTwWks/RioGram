import 'package:flutter/material.dart';
import '../core/theme/telegram_theme.dart';
import '../models/message_enrichment.dart';
class MessageReactionsRow extends StatelessWidget {
  const MessageReactionsRow({super.key, required this.reactions, this.onReactionTap, this.onAddReaction});
  final List<MessageReactionSummary> reactions; final void Function(String emoji)? onReactionTap; final VoidCallback? onAddReaction;
  @override Widget build(BuildContext context) {
    if (reactions.isEmpty && onAddReaction == null) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: [
      ...reactions.map((reaction) => _ReactionPill(label: '${reaction.emoji} ${reaction.count}', chosen: reaction.isChosen, onTap: onReactionTap == null ? null : () => onReactionTap!(reaction.emoji))),
      if (onAddReaction != null) _ReactionPill(icon: Icons.add_reaction_outlined, onTap: onAddReaction),
    ]);
  }
}
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({this.label, this.icon, this.chosen = false, this.onTap});
  final String? label; final IconData? icon; final bool chosen; final VoidCallback? onTap;
  @override Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Material(color: chosen ? tg.accent.withValues(alpha: 0.12) : tg.searchFieldBackground, elevation: 0, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: EdgeInsets.symmetric(horizontal: icon != null ? 8 : 10, vertical: 4), child: icon != null ? Icon(icon, size: 16, color: tg.textSecondary) : Text(label!, style: TextStyle(fontSize: 13, height: 1.2, color: chosen ? tg.accent : tg.textPrimary, fontWeight: chosen ? FontWeight.w600 : FontWeight.w400))))));
  }
}
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({super.key});
  static const defaultEmojis = ['👍', '❤️', '🔥', '👏', '😂', '🎉', '😮', '😢'];
  static Future<String?> show(BuildContext context) => showModalBottomSheet<String>(context: context, builder: (_) => const ReactionPickerSheet());
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 12, runSpacing: 12, children: defaultEmojis.map((emoji) => InkWell(onTap: () => Navigator.pop(context, emoji), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(8), child: Text(emoji, style: const TextStyle(fontSize: 28))))).toList())));
}
