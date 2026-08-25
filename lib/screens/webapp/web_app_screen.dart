import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/bot/bot_manager.dart';

/// Экран Telegram Mini App (WebView).
class WebAppScreen extends StatefulWidget {
  const WebAppScreen({
    super.key,
    required this.url,
    required this.launchId,
    this.title = 'Mini App',
  });

  final String url;
  final int launchId;
  final String title;

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  late final WebViewController _controller;
  late final BotManager _botManager;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _botManager = context.read<BotManager>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _botManager.closeWebApp(webAppLaunchId: widget.launchId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
