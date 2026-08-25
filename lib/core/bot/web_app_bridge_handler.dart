import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Состояние кнопок Mini App, управляемых из JavaScript.
@immutable
class WebAppUiState {
  const WebAppUiState({
    this.mainButtonText = 'CONTINUE',
    this.mainButtonVisible = false,
    this.mainButtonActive = true,
    this.mainButtonProgress = false,
    this.mainButtonColor,
    this.mainButtonTextColor,
    this.backButtonVisible = false,
    this.isExpanded = false,
    this.headerColor,
    this.backgroundColor,
    this.closingConfirmation = false,
  });

  final String mainButtonText;
  final bool mainButtonVisible;
  final bool mainButtonActive;
  final bool mainButtonProgress;
  final String? mainButtonColor;
  final String? mainButtonTextColor;
  final bool backButtonVisible;
  final bool isExpanded;
  final String? headerColor;
  final String? backgroundColor;
  final bool closingConfirmation;

  WebAppUiState copyWith({
    String? mainButtonText,
    bool? mainButtonVisible,
    bool? mainButtonActive,
    bool? mainButtonProgress,
    String? mainButtonColor,
    String? mainButtonTextColor,
    bool? backButtonVisible,
    bool? isExpanded,
    String? headerColor,
    String? backgroundColor,
    bool? closingConfirmation,
  }) {
    return WebAppUiState(
      mainButtonText: mainButtonText ?? this.mainButtonText,
      mainButtonVisible: mainButtonVisible ?? this.mainButtonVisible,
      mainButtonActive: mainButtonActive ?? this.mainButtonActive,
      mainButtonProgress: mainButtonProgress ?? this.mainButtonProgress,
      mainButtonColor: mainButtonColor ?? this.mainButtonColor,
      mainButtonTextColor: mainButtonTextColor ?? this.mainButtonTextColor,
      backButtonVisible: backButtonVisible ?? this.backButtonVisible,
      isExpanded: isExpanded ?? this.isExpanded,
      headerColor: headerColor ?? this.headerColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      closingConfirmation: closingConfirmation ?? this.closingConfirmation,
    );
  }
}

/// События, которые Mini App отправляет в нативный клиент.
sealed class WebAppBridgeEvent {
  const WebAppBridgeEvent();
}

final class WebAppReadyEvent extends WebAppBridgeEvent {
  const WebAppReadyEvent();
}

final class WebAppExpandEvent extends WebAppBridgeEvent {
  const WebAppExpandEvent();
}

final class WebAppCloseEvent extends WebAppBridgeEvent {
  const WebAppCloseEvent();
}

final class WebAppSendDataEvent extends WebAppBridgeEvent {
  const WebAppSendDataEvent(this.data);

  final String data;
}

final class WebAppOpenLinkEvent extends WebAppBridgeEvent {
  const WebAppOpenLinkEvent({
    required this.url,
    this.tryInstantView = false,
  });

  final String url;
  final bool tryInstantView;
}

final class WebAppOpenTelegramLinkEvent extends WebAppBridgeEvent {
  const WebAppOpenTelegramLinkEvent(this.url);

  final String url;
}

final class WebAppCustomMethodEvent extends WebAppBridgeEvent {
  const WebAppCustomMethodEvent({
    required this.requestId,
    required this.method,
    required this.parameters,
  });

  final String requestId;
  final String method;
  final String parameters;
}

final class WebAppUiChangedEvent extends WebAppBridgeEvent {
  const WebAppUiChangedEvent(this.state);

  final WebAppUiState state;
}

/// Парсер сообщений из JavaScript bridge.
abstract final class WebAppBridgeHandler {
  static WebAppBridgeEvent? parseMessage(
    String raw, {
    required WebAppUiState currentState,
  }) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    final event = decoded['event'] as String?;
    if (event == null) {
      return null;
    }

    return switch (event) {
      'ready' => const WebAppReadyEvent(),
      'expand' => const WebAppExpandEvent(),
      'close' => const WebAppCloseEvent(),
      'sendData' => WebAppSendDataEvent(decoded['data'] as String? ?? ''),
      'openLink' => WebAppOpenLinkEvent(
          url: decoded['url'] as String? ?? '',
          tryInstantView: decoded['try_instant_view'] as bool? ?? false,
        ),
      'openTelegramLink' => WebAppOpenTelegramLinkEvent(
          decoded['url'] as String? ?? '',
        ),
      'invokeCustomMethod' => WebAppCustomMethodEvent(
          requestId: decoded['request_id'] as String? ?? '',
          method: decoded['method'] as String? ?? '',
          parameters: decoded['params'] as String? ?? '{}',
        ),
      'mainButtonSetParams' => WebAppUiChangedEvent(
          currentState.copyWith(
            mainButtonText: decoded['text'] as String? ?? currentState.mainButtonText,
            mainButtonVisible:
                decoded['is_visible'] as bool? ?? currentState.mainButtonVisible,
            mainButtonActive:
                decoded['is_active'] as bool? ?? currentState.mainButtonActive,
            mainButtonProgress: decoded['is_progress_visible'] as bool? ??
                currentState.mainButtonProgress,
            mainButtonColor:
                decoded['color'] as String? ?? currentState.mainButtonColor,
            mainButtonTextColor: decoded['text_color'] as String? ??
                currentState.mainButtonTextColor,
          ),
        ),
      'backButtonSetParams' => WebAppUiChangedEvent(
          currentState.copyWith(
            backButtonVisible:
                decoded['is_visible'] as bool? ?? currentState.backButtonVisible,
          ),
        ),
      'setHeaderColor' => WebAppUiChangedEvent(
          currentState.copyWith(
            headerColor: decoded['color'] as String?,
          ),
        ),
      'setBackgroundColor' => WebAppUiChangedEvent(
          currentState.copyWith(
            backgroundColor: decoded['color'] as String?,
          ),
        ),
      'enableClosingConfirmation' => WebAppUiChangedEvent(
          currentState.copyWith(closingConfirmation: true),
        ),
      'disableClosingConfirmation' => WebAppUiChangedEvent(
          currentState.copyWith(closingConfirmation: false),
        ),
      _ => null,
    };
  }
}
