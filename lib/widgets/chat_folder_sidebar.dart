import 'package:flutter/material.dart';
import '../core/theme/telegram_icons.dart';
import '../core/theme/telegram_theme.dart';
import '../models/chat_models.dart';
class ChatFolderSidebar extends StatelessWidget {
  const ChatFolderSidebar({super.key, required this.activeList, required this.folders, required this.onSelected, required this.onSettings, this.onSavedMessages, this.hasSavedMessages = false});
  final ChatListKey activeList; final List<ChatFolderTab> folders; final ValueChanged<ChatListKey> onSelected; final VoidCallback onSettings; final VoidCallback? onSavedMessages; final bool hasSavedMessages;
  static const width = 72.0;
  @override Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Container(width: width, color: tg.chatListBackground, child: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _SidebarIconButton(icon: TelegramIcons.chats, tooltip: 'Все чаты', selected: activeList is ChatListMain, onTap: () => onSelected(const ChatListMain())),
        ...folders.map((folder) => _SidebarIconButton(icon: _folderIcon(folder.iconName), tooltip: folder.name, selected: switch (activeList) { ChatListFolder(folderId: final id) => id == folder.id, _ => false }, onTap: () => onSelected(folder.listKey))),
        _SidebarIconButton(icon: TelegramIcons.archive, tooltip: 'Архив', selected: activeList is ChatListArchive, onTap: () => onSelected(const ChatListArchive())),
        if (hasSavedMessages && onSavedMessages != null) _SidebarIconButton(icon: TelegramIcons.savedMessages, tooltip: 'Избранное', selected: false, onTap: onSavedMessages!),
      ])),
      _SidebarIconButton(icon: TelegramIcons.settings, tooltip: 'Настройки', selected: false, onTap: onSettings),
      const SizedBox(height: 8),
    ])));
  }
  static IconData _folderIcon(String? iconName) => switch (iconName) { 'Briefcase' => Icons.work_outline, 'Heart' => Icons.favorite_outline, 'Book' => Icons.menu_book_outlined, 'Star' => Icons.star_outline, 'Personal' => TelegramIcons.privateChat, 'Groups' => TelegramIcons.group, 'Channels' => TelegramIcons.channel, 'Bots' => TelegramIcons.bot, _ => TelegramIcons.folder };
}
class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({required this.icon, required this.tooltip, required this.selected, required this.onTap});
  final IconData icon; final String tooltip; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final tg = context.telegramTheme; final color = selected ? tg.accent : tg.textSecondary;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Tooltip(message: tooltip, child: InkWell(onTap: onTap, child: SizedBox(width: ChatFolderSidebar.width, height: 48, child: Row(children: [
      AnimatedContainer(duration: const Duration(milliseconds: 150), width: 3, height: selected ? 24 : 0, decoration: BoxDecoration(color: tg.accent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)))),
      Expanded(child: Icon(icon, color: color, size: 24)),
    ])))));
  }
}
