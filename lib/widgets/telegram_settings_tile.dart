import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/navigation/telegram_routes.dart';
import '../core/theme/telegram_icons.dart';
import '../core/theme/telegram_theme.dart';
import 'chat_avatar.dart';

Color telegramSettingsPageBackground(BuildContext context) {
  final tg = context.telegramTheme;
  return Theme.of(context).brightness == Brightness.light
      ? tg.inputFieldBackground
      : tg.chatListBackground;
}

Color telegramSettingsGroupBackground(BuildContext context) {
  return context.telegramTheme.chatListBackground;
}

bool telegramSettingsUseFlatGroups(BuildContext context) {
  if (!TelegramTypography.isDesktopPlatform) return false;
  return MediaQuery.sizeOf(context).width >= TelegramLayoutBreakpoints.mobile;
}

double telegramSettingsGroupRadius(BuildContext context) {
  return telegramSettingsUseFlatGroups(context)
      ? TelegramRadii.settingsGroupFlat
      : TelegramRadii.buttonPill;
}

EdgeInsets telegramSettingsListPadding(BuildContext context) {
  if (telegramSettingsUseFlatGroups(context)) {
    return const EdgeInsets.fromLTRB(0, 8, 0, 24);
  }
  return const EdgeInsets.fromLTRB(16, 8, 16, 24);
}

TextStyle? telegramSettingsTitleStyle(BuildContext context, {bool destructive = false}) {
  final theme = Theme.of(context);
  return theme.textTheme.titleMedium?.copyWith(
    color: destructive ? theme.colorScheme.error : null,
  );
}

TextStyle? telegramSettingsSubtitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall;

TextStyle? telegramSettingsValueStyle(BuildContext context) {
  final tg = context.telegramTheme;
  return Theme.of(context).textTheme.bodyMedium?.copyWith(color: tg.textSecondary);
}

TextStyle? telegramSettingsSectionHeaderStyle(BuildContext context) {
  final tg = context.telegramTheme;
  return Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: TelegramFontSizes.sectionHeader,
        fontWeight: FontWeight.w500,
        color: tg.textSecondary,
        letterSpacing: 0.2,
      );
}

class TelegramSettingsScaffold extends StatelessWidget {
  const TelegramSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: telegramSettingsPageBackground(context),
      appBar: AppBar(title: Text(title), actions: actions),
      body: TelegramSettingsListView(children: children),
    );
  }
}

class TelegramSettingsListView extends StatelessWidget {
  const TelegramSettingsListView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? telegramSettingsListPadding(context),
      children: children,
    );
  }
}

class TelegramSettingsSectionHeader extends StatelessWidget {
  const TelegramSettingsSectionHeader(this.title, {super.key, EdgeInsetsGeometry? padding})
      : padding = padding ??
            const EdgeInsets.fromLTRB(
              TelegramSpacing.settingsSectionHeaderHorizontalPadding,
              TelegramSpacing.settingsSectionHeaderTopPadding,
              TelegramSpacing.settingsSectionHeaderHorizontalPadding,
              TelegramSpacing.settingsSectionHeaderBottomPadding,
            );

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(title.toUpperCase(), style: telegramSettingsSectionHeaderStyle(context)),
    );
  }
}

class TelegramSettingsGroup extends StatelessWidget {
  const TelegramSettingsGroup({super.key, required this.children, this.margin = const EdgeInsets.symmetric(horizontal: 0)});

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((child) => child is! SizedBox).toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();
    final radius = telegramSettingsGroupRadius(context);
    final borderRadius = BorderRadius.circular(radius);
    final flat = telegramSettingsUseFlatGroups(context);
    final dividerColor = context.telegramTheme.chatListDivider;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: telegramSettingsGroupBackground(context),
          borderRadius: borderRadius,
          border: flat
              ? Border(top: BorderSide(color: dividerColor), bottom: BorderSide(color: dividerColor))
              : null,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Column(mainAxisSize: MainAxisSize.min, children: visibleChildren),
        ),
      ),
    );
  }
}

class TelegramSettingsDivider extends StatelessWidget {
  const TelegramSettingsDivider({super.key, this.inset = TelegramSpacing.settingsDividerInset});
  final double inset;
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: inset, color: context.telegramTheme.chatListDivider);
}

class TelegramSettingsTile extends StatelessWidget {
  const TelegramSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.showDivider = true,
    this.dividerInset,
    this.dense = false,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool showDivider;
  final double? dividerInset;
  final bool dense;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final effectiveInset = dividerInset ??
        (leading != null
            ? TelegramSpacing.settingsDividerInsetWithLeading
            : TelegramSpacing.settingsDividerInset);
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && (value != null || showChevron)) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: telegramSettingsValueStyle(context),
              ),
            ),
          if (showChevron && onTap != null) ...[
            if (value != null) const SizedBox(width: 4),
            Icon(TelegramIcons.chevronRight, size: 20, color: tg.textSecondary.withValues(alpha: 0.65)),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TelegramSpacing.settingsRowHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: telegramSettingsTitleStyle(context, destructive: destructive)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: telegramSettingsSubtitleStyle(context)),
                          ],
                        ],
                      ),
                    ),
                    ?effectiveTrailing,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider) TelegramSettingsDivider(inset: effectiveInset),
      ],
    );
  }
}

class TelegramSettingsSwitch extends StatelessWidget {
  const TelegramSettingsSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final accent = context.telegramTheme.accent;
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: accent);
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

class TelegramSettingsSwitchTile extends StatelessWidget {
  const TelegramSettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
    this.dividerInset,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final double? dividerInset;

  @override
  Widget build(BuildContext context) {
    final effectiveInset = dividerInset ?? TelegramSpacing.settingsDividerInset;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TelegramSpacing.settingsRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: telegramSettingsTitleStyle(context)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: telegramSettingsSubtitleStyle(context)),
                      ],
                    ],
                  ),
                ),
                TelegramSettingsSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
        if (showDivider) TelegramSettingsDivider(inset: effectiveInset),
      ],
    );
  }
}

class TelegramSettingsProfileHeader extends StatelessWidget {
  const TelegramSettingsProfileHeader({
    super.key,
    required this.displayName,
    this.username,
    this.phone,
    this.avatarLocalPath,
    this.onTap,
    this.showChevron = true,
  });

  final String displayName;
  final String? username;
  final String? phone;
  final String? avatarLocalPath;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final theme = Theme.of(context);
    return TelegramSettingsGroup(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(telegramSettingsGroupRadius(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TelegramSpacing.settingsRowHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    ChatAvatar(title: displayName, localPath: avatarLocalPath, radius: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: tg.textPrimary,
                            ),
                          ),
                          if (username != null && username!.isNotEmpty)
                            Text('@$username', style: theme.textTheme.bodyMedium?.copyWith(color: tg.accent)),
                          if (phone != null && phone!.isNotEmpty)
                            Text(phone!, style: theme.textTheme.bodyMedium?.copyWith(color: tg.textSecondary)),
                        ],
                      ),
                    ),
                    if (showChevron && onTap != null)
                      Icon(TelegramIcons.chevronRight, size: 20, color: tg.textSecondary.withValues(alpha: 0.65)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TelegramProfileHeader extends StatelessWidget {
  const TelegramProfileHeader({
    super.key,
    required this.displayName,
    this.username,
    this.phone,
    this.avatarLocalPath,
    this.subtitle,
    this.onUsernameTap,
    this.avatarRadius = TelegramSpacing.profileScreenAvatarRadius,
  });

  final String displayName;
  final String? username;
  final String? phone;
  final String? avatarLocalPath;
  final Widget? subtitle;
  final VoidCallback? onUsernameTap;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          ChatAvatar(title: displayName, localPath: avatarLocalPath, radius: avatarRadius),
          const SizedBox(height: 12),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: tg.textPrimary),
          ),
          if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
          if (username != null && username!.isNotEmpty)
            GestureDetector(
              onTap: onUsernameTap,
              child: Text('@$username', style: theme.textTheme.bodyMedium?.copyWith(color: tg.accent)),
            ),
          if (phone != null && phone!.isNotEmpty)
            Text(phone!, style: theme.textTheme.bodyMedium?.copyWith(color: tg.textSecondary)),
        ],
      ),
    );
  }
}
