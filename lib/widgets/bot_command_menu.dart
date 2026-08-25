import 'package:flutter/material.dart';

import '../models/bot_models.dart';

/// Меню slash-команд бота над полем ввода.
class BotCommandMenu extends StatelessWidget {
  const BotCommandMenu({
    super.key,
    required this.commands,
    required this.onCommandSelected,
  });

  final List<BotCommandModel> commands;
  final ValueChanged<BotCommandModel> onCommandSelected;

  @override
  Widget build(BuildContext context) {
    if (commands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: commands.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final command = commands[index];
            return ListTile(
              dense: true,
              title: Text(command.slashCommand),
              subtitle: Text(command.description),
              onTap: () => onCommandSelected(command),
            );
          },
        ),
      ),
    );
  }
}
