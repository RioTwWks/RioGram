(function () {
  'use strict';

  let tdClient = null;
  let onUpdateCallback = null;
  let onTransportStateCallback = null;

  /** UMD webpack export: library name "tdweb", default export = TdClient */
  function getTdClientClass() {
    const lib = window.tdweb;
    if (!lib) {
      return undefined;
    }
    return lib.default || lib;
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

      onUpdateCallback = options.onUpdate;
      tdClient = new TdClient({
        instanceName: options.instanceName || 'riogram',
        jsLogVerbosityLevel: options.jsLogVerbosityLevel || 'warning',
        logVerbosityLevel: options.logVerbosityLevel || 2,
        useDatabase: options.useDatabase !== false,
        onUpdate: function (update) {
          if (onUpdateCallback) {
            onUpdateCallback(update);
          }
        },
      });
      return true;
    },

    send: function (query) {
      if (!tdClient) {
        throw new Error('RioGramTdlib: клиент не создан');
      }
      return tdClient.send(query);
    },

    close: function () {
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
