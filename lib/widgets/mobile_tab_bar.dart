import 'package:flutter/material.dart';

import '../core/theme/telegram_icons.dart';
import '../core/theme/telegram_theme.dart';

class MobileTabBar extends StatelessWidget {
  const MobileTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const destinations = <({IconData icon, String label})>[
    (icon: TelegramIcons.chats, label: 'Чаты'),
    (icon: TelegramIcons.contacts, label: 'Контакты'),
    (icon: TelegramIcons.settings, label: 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telegram = theme.extension<TelegramThemeData>();
    final background =
        telegram?.chatListBackground ?? theme.colorScheme.surface;
    final accent = telegram?.accent ?? theme.colorScheme.primary;
    final secondary =
        telegram?.textSecondary ?? theme.colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomNavigationBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: selectedIndex == i,
                    accent: accent,
                    secondary: secondary,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.secondary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : secondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: TelegramIcons.size),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: TelegramFontSizes.time,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
