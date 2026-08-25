import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/bot/bot_manager.dart';
import '../../core/bot/web_app_bridge_handler.dart';
import '../../core/bot/web_app_theme.dart';

/// Экран Telegram Mini App с bridge `Telegram.WebApp`.
class WebAppScreen extends StatefulWidget {
  const WebAppScreen({
    super.key,
    required this.url,
    required this.launchId,
    this.title = 'Mini App',
    this.botUserId = 0,
    this.chatId = 0,
    this.buttonText = '',
  });

  final String url;
  final int launchId;
  final String title;
  final int botUserId;
  final int chatId;
  final String buttonText;

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  late final WebViewController _controller;
  late final BotManager _botManager;
  var _isLoading = true;
  var _uiState = const WebAppUiState();
  String? _bridgeScript;

  @override
  void initState() {
    super.initState();
    _botManager = context.read<BotManager>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'RioGramWebApp',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectBridge(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _loadBridgeScript();
  }

  Future<void> _loadBridgeScript() async {
    final script = await rootBundle.loadString(
      'assets/web/telegram_web_app_bridge.js',
    );
    if (!mounted) {
      return;
    }
    setState(() => _bridgeScript = script);
    await _injectBridge();
  }

  Future<void> _injectBridge() async {
    final script = _bridgeScript;
    if (script == null) {
      return;
    }
    final brightness = Theme.of(context).brightness;
    final config = jsonEncode({
      'initData': '',
      'initDataUnsafe': <String, dynamic>{},
      'platform': Theme.of(context).platform.name,
      'colorScheme': brightness == Brightness.dark ? 'dark' : 'light',
      'themeParams': WebAppTheme.themeParamsForJs(brightness),
      'viewportHeight': MediaQuery.sizeOf(context).height,
    });
    await _controller.runJavaScript('$script;'
        'window.Telegram.WebApp._applyHostConfig($config);');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final event = WebAppBridgeHandler.parseMessage(
      message.message,
      currentState: _uiState,
    );
    if (event == null) {
      return;
    }

    switch (event) {
      case WebAppReadyEvent():
        break;
      case WebAppExpandEvent():
        setState(() => _uiState = _uiState.copyWith(isExpanded: true));
      case WebAppCloseEvent():
        _closeScreen();
      case WebAppSendDataEvent(:final data):
        if (widget.botUserId != 0 && data.isNotEmpty) {
          _botManager.sendWebAppData(
            botUserId: widget.botUserId,
            buttonText: widget.buttonText,
            data: data,
          );
        }
        _closeScreen();
      case WebAppOpenLinkEvent(:final url, :final tryInstantView):
        _openExternalUrl(url, tryInstantView: tryInstantView);
      case WebAppOpenTelegramLinkEvent(:final url):
        _openExternalUrl(url);
      case WebAppCustomMethodEvent(
          :final requestId,
          :final method,
          :final parameters,
        ):
        _handleCustomMethod(requestId, method, parameters);
      case WebAppUiChangedEvent(:final state):
        setState(() => _uiState = state);
    }
  }

  Future<void> _handleCustomMethod(
    String requestId,
    String method,
    String parameters,
  ) async {
    if (widget.botUserId == 0 || method.isEmpty) {
      return;
    }
    final result = await _botManager.sendWebAppCustomRequest(
      botUserId: widget.botUserId,
      method: method,
      parameters: parameters,
    );
    final payload = jsonEncode({
      'request_id': requestId,
      'result': result ?? '',
    });
    await _controller.runJavaScript(
      'window.Telegram.WebApp._receiveEvent("customMethodResult", $payload);',
    );
  }

  Future<void> _openExternalUrl(
    String url, {
    bool tryInstantView = false,
  }) async {
    if (url.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _closeScreen() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<bool> _onWillPop() async {
    if (!_uiState.closingConfirmation) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть Mini App?'),
        content: const Text('Несохранённые данные могут быть потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _onMainButtonPressed() {
    _controller.runJavaScript(
      'window.Telegram.WebApp._receiveEvent("mainButtonClicked", {});',
    );
  }

  void _onBackButtonPressed() {
    _controller.runJavaScript(
      'window.Telegram.WebApp._receiveEvent("backButtonClicked", {});',
    );
  }

  Color? _parseHexColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.replaceFirst('#', '');
    if (normalized.length == 6) {
      final parsed = int.tryParse('FF$normalized', radix: 16);
      return parsed == null ? null : Color(parsed);
    }
    if (normalized.length == 8) {
      final parsed = int.tryParse(normalized, radix: 16);
      return parsed == null ? null : Color(parsed);
    }
    return null;
  }

  @override
  void dispose() {
    if (widget.launchId != 0) {
      _botManager.closeWebApp(webAppLaunchId: widget.launchId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = _parseHexColor(_uiState.backgroundColor);
    final header = _parseHexColor(_uiState.headerColor);

    return PopScope(
      canPop: !_uiState.closingConfirmation,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: _uiState.isExpanded
            ? null
            : AppBar(
                backgroundColor: header,
                leading: _uiState.backButtonVisible
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _onBackButtonPressed,
                      )
                    : null,
                title: Text(widget.title),
                actions: [
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: () => _controller.reload(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            if (_uiState.mainButtonVisible)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _uiState.mainButtonActive &&
                              !_uiState.mainButtonProgress
                          ? _onMainButtonPressed
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _parseHexColor(_uiState.mainButtonColor),
                        foregroundColor:
                            _parseHexColor(_uiState.mainButtonTextColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _uiState.mainButtonProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_uiState.mainButtonText),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
