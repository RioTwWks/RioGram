import 'package:flutter/material.dart';

import '../models/user_models.dart';
import 'chat_avatar.dart';
import 'user_status_subtitle.dart';

/// Элемент списка контактов.
class ContactListTile extends StatelessWidget {
  const ContactListTile({
    super.key,
    required this.user,
    required this.onTap,
    this.trailing,
  });

  final UserSummary user;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ChatAvatar(
        title: user.displayName,
        localPath: user.avatarLocalPath,
      ),
      title: Text(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.username != null && user.username!.isNotEmpty)
            Text('@${user.username}'),
          UserStatusSubtitle(status: user.status),
        ],
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
