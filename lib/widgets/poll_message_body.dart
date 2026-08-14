import 'package:flutter/material.dart';

import '../models/message_enrichment.dart';

/// Тело сообщения-опроса.
class PollMessageBody extends StatelessWidget {
  const PollMessageBody({
    super.key,
    required this.poll,
    this.onVote,
  });

  final PollContent poll;
  final void Function(int optionId)? onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVote = !poll.isClosed && onVote != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll.question,
          style: theme.textTheme.titleSmall,
        ),
        if (poll.kind == PollKind.quiz)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Викторина',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ...poll.options.map((option) {
          final percentage = option.votePercentage.clamp(0, 100);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: canVote ? () => onVote!(option.id) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: option.isChosen
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(option.text)),
                        if (poll.totalVoterCount > 0)
                          Text('${percentage.toStringAsFixed(0)}%'),
                      ],
                    ),
                    if (poll.totalVoterCount > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 4,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        Text(
          poll.isClosed
              ? 'Опрос закрыт · ${poll.totalVoterCount} голосов'
              : '${poll.totalVoterCount} голосов',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Диалог создания опроса.
class PollComposeDialog extends StatefulWidget {
  const PollComposeDialog({super.key});

  static Future<({String question, List<String> options, PollKind kind, int? correctOptionId})?>
      show(BuildContext context) {
    return showDialog<
        ({String question, List<String> options, PollKind kind, int? correctOptionId})>(
      context: context,
      builder: (_) => const PollComposeDialog(),
    );
  }

  @override
  State<PollComposeDialog> createState() => _PollComposeDialogState();
}

class _PollComposeDialogState extends State<PollComposeDialog> {
  final _questionController = TextEditingController();
  final _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  PollKind _kind = PollKind.regular;
  int _correctOptionId = 0;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) {
      return;
    }
    setState(() => _optionControllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый опрос'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(labelText: 'Вопрос'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PollKind>(
                segments: const [
                  ButtonSegment(value: PollKind.regular, label: Text('Опрос')),
                  ButtonSegment(value: PollKind.quiz, label: Text('Викторина')),
                ],
                selected: {_kind},
                onSelectionChanged: (value) {
                  setState(() => _kind = value.first);
                },
              ),
              const SizedBox(height: 12),
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (_kind == PollKind.quiz)
                        Radio<int>(
                          value: index,
                          groupValue: _correctOptionId,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _correctOptionId = value);
                            }
                          },
                        ),
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Вариант ${index + 1}',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить вариант'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final question = _questionController.text.trim();
            final options = _optionControllers
                .map((controller) => controller.text.trim())
                .where((text) => text.isNotEmpty)
                .toList();
            if (question.isEmpty || options.length < 2) {
              return;
            }
            Navigator.pop(
              context,
              (
                question: question,
                options: options,
                kind: _kind,
                correctOptionId:
                    _kind == PollKind.quiz ? _correctOptionId : null,
              ),
            );
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
