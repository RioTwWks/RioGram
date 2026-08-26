(function () {
  'use strict';

  try {
    importScripts('js/wss_proxy_worker_config.js');
  } catch (_) {
    // Optional override; same-origin fallback below.
  }

  var TELEGRAM_WS_RE =
    /^wss:\/\/([a-z0-9.-]+\.(?:web\.)?telegram\.org)(\/.*)?$/i;

  function normalizeProxyBase(raw) {
    if (!raw || !String(raw).trim()) {
      return null;
    }
    var value = String(raw).trim();
    if (value.indexOf('https://') === 0) {
      value = 'wss://' + value.slice(8);
    } else if (value.indexOf('http://') === 0) {
      value = 'ws://' + value.slice(7);
    } else if (value.indexOf('wss://') !== 0 && value.indexOf('ws://') !== 0) {
      value = 'wss://' + value;
    }
    while (value.charAt(value.length - 1) === '/') {
      value = value.slice(0, -1);
    }
    return value;
  }

  function resolveConfig() {
    var config = self.RIOGRAM_WSS_CONFIG;
    if (config && config.enabled && config.url) {
      return config;
    }
    if (
      typeof self.location !== 'undefined' &&
      self.location.host &&
      self.location.protocol === 'https:'
    ) {
      return { enabled: true, url: 'wss://' + self.location.host };
    }
    return { enabled: false, url: '' };
  }

  function rewriteUrl(url) {
    var config = resolveConfig();
    if (!config.enabled || !config.url) {
      return url;
    }
    var proxyBase = normalizeProxyBase(config.url);
    if (!proxyBase) {
      return url;
    }
    var match = String(url).match(TELEGRAM_WS_RE);
    if (!match) {
      return url;
    }
    return proxyBase + '/' + match[1] + (match[2] || '/apiws');
  }

  var OriginalWebSocket = self.WebSocket;
  function PatchedWebSocket(url, protocols) {
    var targetUrl = rewriteUrl(url);
    return protocols === undefined
      ? new OriginalWebSocket(targetUrl)
      : new OriginalWebSocket(targetUrl, protocols);
  }
  PatchedWebSocket.prototype = OriginalWebSocket.prototype;
  PatchedWebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
  PatchedWebSocket.OPEN = OriginalWebSocket.OPEN;
  PatchedWebSocket.CLOSING = OriginalWebSocket.CLOSING;
  PatchedWebSocket.CLOSED = OriginalWebSocket.CLOSED;
  self.WebSocket = PatchedWebSocket;
})();
