import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/features/riogram_features_manager.dart';
import '../models/chat_models.dart';

/// Показывает сохранённую версию сообщения (анти-отзыв).
class AntiRecallBanner extends StatelessWidget {
  const AntiRecallBanner({
    super.key,
    required this.reasonLabel,
    required this.preview,
    this.caption,
  });

  final String reasonLabel;
  final String preview;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                reasonLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            style: theme.textTheme.bodyMedium,
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Диалог с переводом сообщения.
class MessageTranslationSheet extends StatefulWidget {
  const MessageTranslationSheet({
    super.key,
    required this.message,
    required this.targetLanguage,
  });

  final ChatMessage message;
  final String targetLanguage;

  static Future<void> show(
    BuildContext context, {
    required ChatMessage message,
    required String targetLanguage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MessageTranslationSheet(
        message: message,
        targetLanguage: targetLanguage,
      ),
    );
  }

  @override
  State<MessageTranslationSheet> createState() => _MessageTranslationSheetState();
}

class _MessageTranslationSheetState extends State<MessageTranslationSheet> {
  String? _translation;
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final translator = context.read<MessageTranslator>();
    final cached = translator.cachedTranslation(
      widget.message.chatId,
      widget.message.id,
      widget.targetLanguage,
    );
    if (cached != null) {
      setState(() {
        _translation = cached;
        _isLoading = false;
      });
      return;
    }

    final result = await translator.translateMessage(
      chatId: widget.message.chatId,
      messageId: widget.message.id,
      toLanguageCode: widget.targetLanguage,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _translation = result;
      _error = result == null ? translator.lastError : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.message.content.formattedText?.text ??
        widget.message.content.preview;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Перевод',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Оригинал',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(original),
            const Divider(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              Text(
                'Перевод (${widget.targetLanguage})',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(_translation ?? ''),
            ],
          ],
        ),
      ),
    );
  }
}
