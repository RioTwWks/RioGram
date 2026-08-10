import 'package:flutter/material.dart';

import '../core/proxy/proxy_manager.dart';

class ProxyStatusIndicator extends StatelessWidget {
  const ProxyStatusIndicator({
    super.key,
    required this.status,
    this.proxyName,
  });

  final ProxyStatus status;
  final String? proxyName;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ProxyStatus.active => (Colors.green, proxyName ?? 'Прокси активен'),
      ProxyStatus.switching => (Colors.amber, 'Переключение прокси...'),
      ProxyStatus.error => (Colors.red, 'Прокси недоступен'),
      ProxyStatus.disabled => (Colors.grey, 'Прокси не настроен'),
      ProxyStatus.unknown => (Colors.grey, 'Прокси не настроен'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
