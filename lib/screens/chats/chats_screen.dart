import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';
import '../../widgets/proxy_status_indicator.dart';
import '../../core/proxy/proxy_manager.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final proxy = context.watch<ProxyManager?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          if (proxy != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ProxyStatusIndicator(
                  status: proxy.status,
                  proxyName: proxy.activeProxyName,
                ),
              ),
            ),
        ],
      ),
      body: auth.chats.isEmpty
          ? const Center(child: Text('Загрузка чатов...'))
          : ListView.separated(
              itemCount: auth.chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chat = auth.chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(chat.title.isNotEmpty ? chat.title[0] : '?'),
                  ),
                  title: Text(chat.title),
                  subtitle: chat.lastMessage != null ? Text(chat.lastMessage!) : null,
                );
              },
            ),
    );
  }
}
