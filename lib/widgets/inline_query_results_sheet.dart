import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bot/bot_manager.dart';
import '../models/bot_models.dart';

/// Выбор результата inline-запроса (@bot query).
class InlineQueryResultsSheet extends StatelessWidget {
  const InlineQueryResultsSheet({
    super.key,
    required this.chatId,
    required this.state,
  });

  final int chatId;
  final InlineQueryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '@${state.botUsername} ${state.query}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = state.results[index];
                  return ListTile(
                    title: Text(result.title),
                    subtitle: result.description.isNotEmpty
                        ? Text(result.description)
                        : Text(result.preview),
                    onTap: () {
                      context.read<BotManager>().sendInlineResult(
                            chatId: chatId,
                            queryId: state.queryId,
                            resultId: result.id,
                          );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
