(function () {
  'use strict';

  if (self.__RIOGRAM_WSS_HOOK__) {
    return;
  }
  self.__RIOGRAM_WSS_HOOK__ = true;

  try {
    importScripts('/js/wss_proxy_worker_config.js');
  } catch (_) {
    try {
      importScripts('js/wss_proxy_worker_config.js');
    } catch (_2) {}
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

  function sameOriginProxyBase() {
    try {
      var loc = self.location;
      if (!loc || !loc.host) {
        return null;
      }
      var href = String(loc.href || '');
      if (loc.protocol === 'https:' || loc.protocol === 'wss:' || href.indexOf('https://') === 0) {
        return 'wss://' + loc.host;
      }
      if (loc.protocol === 'http:' || loc.protocol === 'ws:' || href.indexOf('http://') === 0) {
        return 'ws://' + loc.host;
      }
    } catch (_) {}
    return null;
  }

  function proxyBase() {
    var config = self.RIOGRAM_WSS_CONFIG;
    if (config && config.enabled === false) {
      return null;
    }
    if (config && config.url) {
      var fromConfig = normalizeProxyBase(config.url);
      if (fromConfig) {
        return fromConfig;
      }
    }
    return sameOriginProxyBase();
  }

  function rewriteUrl(url) {
    var match = String(url).match(TELEGRAM_WS_RE);
    if (!match) {
      return url;
    }
    var base = proxyBase();
    if (!base) {
      return url;
    }
    return base + '/' + match[1] + (match[2] || '/apiws');
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
