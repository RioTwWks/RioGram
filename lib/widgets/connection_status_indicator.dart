import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/proxy/proxy_manager.dart';
import '../core/proxy/web_proxy_manager.dart';
import 'proxy_status_indicator.dart';
import 'web_proxy_status_indicator.dart';

/// Индикатор прокси: MTProto (native) или WSS (web).
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final webProxy = context.watch<WebProxyManager?>();
    if (webProxy != null) {
      return WebProxyStatusIndicator(manager: webProxy);
    }

    final proxy = context.watch<ProxyManager?>();
    if (proxy != null) {
      return ProxyStatusIndicator(
        status: proxy.status,
        proxyName: proxy.activeProxyName,
      );
    }

    return const SizedBox.shrink();
  }
}
