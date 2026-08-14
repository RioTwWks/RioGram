import 'package:flutter/material.dart';

import '../models/chat_models.dart';

/// Узкая левая колонка с иконками папок (как Telegram Desktop).
class ChatFolderSidebar extends StatelessWidget {
  const ChatFolderSidebar({
    super.key,
    required this.activeList,
    required this.folders,
    required this.onSelected,
    required this.onSettings,
    this.onSavedMessages,
    this.hasSavedMessages = false,
  });

  final ChatListKey activeList;
  final List<ChatFolderTab> folders;
  final ValueChanged<ChatListKey> onSelected;
  final VoidCallback onSettings;
  final VoidCallback? onSavedMessages;
  final bool hasSavedMessages;

  static const width = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: width,
      color: background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SidebarIconButton(
                    icon: Icons.chat_bubble_outline,
                    tooltip: 'Все чаты',
                    selected: activeList is ChatListMain,
                    onTap: () => onSelected(const ChatListMain()),
                  ),
                  ...folders.map(
                    (folder) => _SidebarIconButton(
                      icon: _folderIcon(folder.iconName),
                      tooltip: folder.name,
                      selected: switch (activeList) {
                        ChatListFolder(folderId: final id) => id == folder.id,
                        _ => false,
                      },
                      onTap: () => onSelected(folder.listKey),
                    ),
                  ),
                  _SidebarIconButton(
                    icon: Icons.archive_outlined,
                    tooltip: 'Архив',
                    selected: activeList is ChatListArchive,
                    onTap: () => onSelected(const ChatListArchive()),
                  ),
                  if (hasSavedMessages && onSavedMessages != null)
                    _SidebarIconButton(
                      icon: Icons.bookmark_outline,
                      tooltip: 'Избранное',
                      selected: false,
                      onTap: onSavedMessages!,
                    ),
                ],
              ),
            ),
            _SidebarIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Настройки',
              selected: false,
              onTap: onSettings,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static IconData _folderIcon(String? iconName) {
    return switch (iconName) {
      'Briefcase' => Icons.work_outline,
      'Heart' => Icons.favorite_outline,
      'Book' => Icons.menu_book_outlined,
      'Star' => Icons.star_outline,
      'Personal' => Icons.person_outline,
      'Groups' => Icons.group_outlined,
      'Channels' => Icons.campaign_outlined,
      'Bots' => Icons.smart_toy_outlined,
      _ => Icons.folder_outlined,
    };
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.65)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
