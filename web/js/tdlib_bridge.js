(function () {
  'use strict';

  let tdClient = null;
  let onUpdateCallback = null;
  let onTransportStateCallback = null;
  let readyResolve = null;
  let readyReject = null;
  let readyTimer = null;

  /** UMD webpack export: library name "tdweb", default export = TdClient */
  function getTdClientClass() {
    const lib = window.tdweb;
    if (!lib) {
      return undefined;
    }
    return lib.default || lib;
  }

  function clearReadyWait() {
    if (readyTimer) {
      clearTimeout(readyTimer);
      readyTimer = null;
    }
    readyResolve = null;
    readyReject = null;
  }

  function notifyReady(update) {
    if (!readyResolve) {
      return;
    }
    const resolve = readyResolve;
    clearReadyWait();
    resolve(update);
  }

  function isAuthorizationUpdate(update) {
    return (
      update &&
      update['@type'] === 'updateAuthorizationState' &&
      update.authorization_state &&
      update.authorization_state['@type']
    );
  }

  function dispatchUpdate(update) {
    if (isAuthorizationUpdate(update)) {
      notifyReady(update);
    }
    if (typeof onUpdateCallback === 'function') {
      onUpdateCallback(update);
    }
  }

  window.RioGramTdlib = {
    isAvailable: function () {
      return typeof getTdClientClass() === 'function';
    },

    isReady: function () {
      return tdClient !== null;
    },

    create: function (options) {
      const TdClient = getTdClientClass();
      if (typeof TdClient !== 'function') {
        throw new Error(
          'tdweb не загружен. Соберите tdweb (см. docs/WEB_TRANSPORT.md) ' +
            'и подключите tdweb/tdweb.js в index.html.',
        );
      }

      options = options || {};
      const instanceName =
        options.instanceName ||
        'riogram_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

      tdClient = new TdClient({
        instanceName: instanceName,
        jsLogVerbosityLevel: options.jsLogVerbosityLevel || 'warning',
        logVerbosityLevel: options.logVerbosityLevel || 2,
        useDatabase: options.useDatabase !== false,
        onUpdate: dispatchUpdate,
      });
      return true;
    },

    setUpdateCallback: function (callback) {
      onUpdateCallback = callback;
    },

    waitForAuthorizationUpdate: function (timeoutMs) {
      clearReadyWait();
      const timeout = typeof timeoutMs === 'number' ? timeoutMs : 120000;
      return new Promise(function (resolve, reject) {
        readyResolve = resolve;
        readyReject = reject;
        readyTimer = setTimeout(function () {
          clearReadyWait();
          reject(
            new Error(
              'TDLib не прислал updateAuthorizationState за ' +
                Math.round(timeout / 1000) +
                ' с (WASM/IndexedDB/tdweb)',
            ),
          );
        }, timeout);
      });
    },

    send: function (query) {
      if (!tdClient) {
        throw new Error('RioGramTdlib: клиент не создан');
      }
      return tdClient.send(query);
    },

    close: function () {
      clearReadyWait();
      if (tdClient && typeof tdClient.close === 'function') {
        tdClient.close();
      }
      tdClient = null;
    },

    _onTransportState: function (status) {
      if (onTransportStateCallback) {
        onTransportStateCallback(status);
      }
    },

    setTransportStateCallback: function (callback) {
      onTransportStateCallback = callback;
    },
  };
})();
