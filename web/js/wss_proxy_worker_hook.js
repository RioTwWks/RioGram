(function () {
  'use strict';

  if (self.__RIOGRAM_WSS_HOOK__) {
    return;
  }
  self.__RIOGRAM_WSS_HOOK__ = true;

  // Replaced at build/patch time from WEB_WSS_PROXY_URL (.env).
  var __RIOGRAM_BAKED_PROXY__ = '__RIOGRAM_BAKED_PROXY_URL__';

  // Emscripten/tdweb often passes :443 explicitly; Chrome omits it in error text.
  var TELEGRAM_WS_RE =
    /^wss?:\/\/([a-z0-9.-]+\.(?:web\.)?telegram\.org)(?::\d+)?(\/.*)?$/i;

  function normalizeUrlInput(url) {
    if (url == null) {
      return '';
    }
    if (typeof url === 'object' && typeof url.href === 'string') {
      return url.href;
    }
    return String(url)
      .replace(/\0/g, '')
      .replace(/\r/g, '')
      .trim();
  }

  function normalizeProxyBase(raw) {
    if (!raw || !String(raw).trim()) {
      return null;
    }
    var value = String(raw).trim();
    if (value.indexOf('__RIOGRAM_BAKED_PROXY_URL__') !== -1) {
      return null;
    }
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
      if (!loc) {
        return null;
      }
      var href = String(loc.href || '');
      var host = loc.host || '';
      if (!host && href) {
        var hostMatch = href.match(/^https?:\/\/([^/]+)/i);
        if (hostMatch) {
          host = hostMatch[1];
        }
      }
      if (!host) {
        return null;
      }
      if (
        loc.protocol === 'https:' ||
        loc.protocol === 'wss:' ||
        href.indexOf('https://') === 0
      ) {
        return 'wss://' + host;
      }
      if (
        loc.protocol === 'http:' ||
        loc.protocol === 'ws:' ||
        href.indexOf('http://') === 0
      ) {
        return 'ws://' + host;
      }
    } catch (_) {}
    return null;
  }

  function proxyBase() {
    if (__RIOGRAM_BAKED_PROXY__) {
      var baked = normalizeProxyBase(__RIOGRAM_BAKED_PROXY__);
      if (baked) {
        return baked;
      }
    }
    var config = self.RIOGRAM_WSS_CONFIG;
    if (config && config.enabled !== false && config.url) {
      var fromConfig = normalizeProxyBase(config.url);
      if (fromConfig) {
        return fromConfig;
      }
    }
    return sameOriginProxyBase();
  }

  function rewriteUrl(url) {
    var raw = normalizeUrlInput(url);
    if (!raw) {
      return url;
    }
    var match = raw.match(TELEGRAM_WS_RE);
    if (!match) {
      return url;
    }
    var base = proxyBase();
    if (!base) {
      return url;
    }
    return base + '/' + match[1] + (match[2] || '/apiws');
  }

  function debugRewrite(url, targetUrl) {
    try {
      if (
        self.location &&
        self.location.search.indexOf('riogram_wss_debug=1') !== -1
      ) {
        console.log('[RioGram WSS worker]', url, '->', targetUrl);
      }
    } catch (_) {}
  }

  var OriginalWebSocket = self.WebSocket;
  function PatchedWebSocket(url, protocols) {
    var targetUrl = rewriteUrl(url);
    debugRewrite(url, targetUrl);
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
