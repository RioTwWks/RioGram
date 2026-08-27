(function () {
  'use strict';

  let tdClient = null;
  let onUpdateCallback = null;
  let onTransportStateCallback = null;
  let readyResolve = null;
  let readyReject = null;
  let readyTimer = null;
  let lastAuthorizationUpdate = null;
  let forceStartTimer = null;

  function clearForceStartTimer() {
    if (forceStartTimer) {
      clearTimeout(forceStartTimer);
      forceStartTimer = null;
    }
  }

  function scheduleForceStart() {
    clearForceStartTimer();
    forceStartTimer = setTimeout(function () {
      forceStartTimer = null;
      if (lastAuthorizationUpdate || !tdClient) {
        return;
      }
      try {
        if (typeof tdClient.sendStart === 'function') {
          tdClient.sendStart();
        } else if (typeof tdClient.doSendStart === 'function') {
          tdClient.wantSendStart = true;
          tdClient.doSendStart();
        }
      } catch (error) {
        console.warn('RioGramTdlib: forceStart failed', error);
      }
    }, 8000);
  }

  function patchTdClientCloseOtherClients(TdClient) {
    if (!TdClient || TdClient.__riogramClosePatched) {
      return;
    }
    const proto = TdClient.prototype;
    if (!proto || typeof proto.closeOtherClients !== 'function') {
      return;
    }
    const original = proto.closeOtherClients;
    proto.closeOtherClients = async function patchedCloseOtherClients(options) {
      let finished = false;
      await Promise.race([
        original.call(this, options).then(function () {
          finished = true;
        }),
        new Promise(function (resolve) {
          setTimeout(resolve, 6000);
        }),
      ]);
      if (!finished && typeof this.sendStart === 'function') {
        this.sendStart();
      }
    };
    TdClient.__riogramClosePatched = true;
  }

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
    lastAuthorizationUpdate = update;
    clearForceStartTimer();
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

  function cloneJsonObject(value) {
    try {
      return JSON.parse(JSON.stringify(value));
    } catch (error) {
      return value;
    }
  }

  function dispatchUpdate(update) {
    const plain = cloneJsonObject(update);
    if (isAuthorizationUpdate(plain)) {
      notifyReady(plain);
    }
    if (typeof onUpdateCallback === 'function') {
      onUpdateCallback(plain);
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
      patchTdClientCloseOtherClients(TdClient);

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
      scheduleForceStart();
      return true;
    },

    setUpdateCallback: function (callback) {
      onUpdateCallback = callback;
    },

    waitForAuthorizationUpdate: function (timeoutMs) {
      if (lastAuthorizationUpdate) {
        return Promise.resolve(lastAuthorizationUpdate);
      }
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

    consumeLastAuthorizationUpdate: function () {
      const update = lastAuthorizationUpdate;
      lastAuthorizationUpdate = null;
      return update;
    },

    send: function (query) {
      if (!tdClient) {
        throw new Error('RioGramTdlib: клиент не создан');
      }
      return tdClient.send(query);
    },

    close: function () {
      clearReadyWait();
      clearForceStartTimer();
      lastAuthorizationUpdate = null;
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
