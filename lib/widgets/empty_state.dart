import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme/telegram_theme.dart';

enum EmptyStateIllustration {
  selectChat('assets/illustrations/empty_select_chat.svg'),
  noChats('assets/illustrations/empty_no_chats.svg'),
  archive('assets/illustrations/empty_archive.svg'),
  folder('assets/illustrations/empty_folder.svg'),
  contacts('assets/illustrations/empty_contacts.svg'),
  search('assets/illustrations/empty_search.svg'),
  searchNoResults('assets/illustrations/empty_search_no_results.svg');
  const EmptyStateIllustration(this.assetPath);
  final String assetPath;
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key, required this.illustration, required this.title, this.subtitle});
  final EmptyStateIllustration illustration;
  final String title;
  final String? subtitle;
  static const double illustrationSize = 160;
  @override
  Widget build(BuildContext context) {
    final telegram = context.telegramTheme;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(illustration.assetPath, width: illustrationSize, height: illustrationSize,
            colorFilter: ColorFilter.mode(telegram.accent.withValues(alpha: 0.82), BlendMode.srcIn)),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: telegram.textPrimary, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: telegram.textSecondary))],
        ]),
      ),
    );
  }
}
