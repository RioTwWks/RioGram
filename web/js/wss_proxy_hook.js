(function () {
  'use strict';

  const CONFIG_KEY = 'riogram_wss_proxy_config';
  const TELEGRAM_WS_RE =
    /^wss:\/\/([a-z0-9.-]+\.(?:web\.)?telegram\.org)(\/.*)?$/i;

  const transportState = {
    state: 'idle',
    activeUrl: null,
    lastError: null,
    reconnectAttempt: 0,
  };

  function defaultConfig() {
    return {
      enabled: false,
      url: '',
      autoReconnect: true,
      maxReconnectAttempts: 5,
      reconnectDelayMs: 2000,
    };
  }

  function readConfig() {
    try {
      const raw = localStorage.getItem(CONFIG_KEY);
      if (!raw) {
        return defaultConfig();
      }
      return Object.assign(defaultConfig(), JSON.parse(raw));
    } catch (_) {
      return defaultConfig();
    }
  }

  function normalizeProxyBase(raw) {
    if (!raw || !String(raw).trim()) {
      return null;
    }
    let value = String(raw).trim();
    if (value.startsWith('https://')) {
      value = 'wss://' + value.slice('https://'.length);
    } else if (value.startsWith('http://')) {
      value = 'ws://' + value.slice('http://'.length);
    } else if (!value.startsWith('wss://') && !value.startsWith('ws://')) {
      value = 'wss://' + value;
    }
    while (value.endsWith('/')) {
      value = value.slice(0, -1);
    }
    return value;
  }

  function rewriteUrl(originalUrl, config) {
    const cfg = config || readConfig();
    if (!cfg.enabled || !cfg.url) {
      return originalUrl;
    }
    const proxyBase = normalizeProxyBase(cfg.url);
    if (!proxyBase) {
      return originalUrl;
    }
    const match = String(originalUrl).match(TELEGRAM_WS_RE);
    if (!match) {
      return originalUrl;
    }
    const host = match[1];
    const path = match[2] || '/apiws';
    return proxyBase + '/' + host + path;
  }

  function notifyTransportState() {
    if (
      window.RioGramTdlib &&
      typeof window.RioGramTdlib._onTransportState === 'function'
    ) {
      window.RioGramTdlib._onTransportState(Object.assign({}, transportState));
    }
  }

  function setTransportState(partial) {
    Object.assign(transportState, partial);
    notifyTransportState();
  }

  function installWebSocketHook(globalScope, getConfig, trackTelegram) {
    const OriginalWebSocket = globalScope.WebSocket;
    if (!OriginalWebSocket) {
      return;
    }

    function PatchedWebSocket(url, protocols) {
      const targetUrl = rewriteUrl(url, getConfig());
      const isTelegram = TELEGRAM_WS_RE.test(String(url));
      const ws =
        protocols === undefined
          ? new OriginalWebSocket(targetUrl)
          : new OriginalWebSocket(targetUrl, protocols);

      if (trackTelegram && isTelegram) {
        setTransportState({
          state: 'connecting',
          activeUrl: targetUrl,
          lastError: null,
        });

        ws.addEventListener('open', function () {
          setTransportState({
            state: 'connected',
            activeUrl: targetUrl,
            lastError: null,
            reconnectAttempt: 0,
          });
        });

        ws.addEventListener('error', function () {
          setTransportState({
            state: 'failed',
            lastError: 'WebSocket error',
          });
        });

        ws.addEventListener('close', function (event) {
          setTransportState({
            state: 'failed',
            lastError:
              event.reason || 'WebSocket closed (code ' + event.code + ')',
          });
        });
      }

      return ws;
    }

    PatchedWebSocket.prototype = OriginalWebSocket.prototype;
    PatchedWebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
    PatchedWebSocket.OPEN = OriginalWebSocket.OPEN;
    PatchedWebSocket.CLOSING = OriginalWebSocket.CLOSING;
    PatchedWebSocket.CLOSED = OriginalWebSocket.CLOSED;

    globalScope.WebSocket = PatchedWebSocket;
  }

  // Main thread: patch window.WebSocket before tdweb spawns workers.
  installWebSocketHook(window, readConfig, true);

  window.RioGramWssProxy = {
    readConfig: readConfig,
    writeConfig: function (config) {
      const merged = Object.assign(defaultConfig(), config || {});
      localStorage.setItem(CONFIG_KEY, JSON.stringify(merged));
      return merged;
    },
    rewriteUrl: function (url) {
      return rewriteUrl(url);
    },
    getTransportStatus: function () {
      return Object.assign({}, transportState);
    },
  };
})();
