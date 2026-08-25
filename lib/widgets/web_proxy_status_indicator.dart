import 'package:flutter/material.dart';

import '../core/proxy/web_proxy_manager.dart';

class WebProxyStatusIndicator extends StatelessWidget {
  const WebProxyStatusIndicator({
    super.key,
    required this.manager,
  });

  final WebProxyManager manager;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (manager.status) {
      WebProxyStatus.active => (
        Colors.green,
        manager.activeProxyUrl ?? 'WSS активен',
      ),
      WebProxyStatus.reconnecting => (Colors.amber, 'Переподключение WSS...'),
      WebProxyStatus.error => (Colors.red, 'WSS недоступен'),
      WebProxyStatus.disabled => (Colors.grey, 'WSS выключен'),
      WebProxyStatus.unknown => (Colors.grey, 'WSS не настроен'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
