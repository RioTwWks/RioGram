(function () {
  if (window.Telegram && window.Telegram.WebApp && window.Telegram.WebApp.__riogram) {
    return;
  }

  const handlers = {};

  function post(payload) {
    const channel = window.RioGramWebApp;
    if (channel && typeof channel.postMessage === 'function') {
      channel.postMessage(JSON.stringify(payload));
    }
  }

  function emit(eventType, data) {
    const list = handlers[eventType] || [];
    for (const callback of list) {
      try {
        callback(data);
      } catch (error) {
        console.error('Telegram.WebApp event handler failed', error);
      }
    }
  }

  const MainButton = {
    text: 'CONTINUE',
    color: '#3390ec',
    textColor: '#ffffff',
    isVisible: false,
    isActive: true,
    isProgressVisible: false,
    _callback: null,
    setText(text) {
      this.text = text || '';
      post({ event: 'mainButtonSetParams', text: this.text });
      return this;
    },
    onClick(callback) {
      this._callback = callback;
      return this;
    },
    offClick(callback) {
      if (!callback || this._callback === callback) {
        this._callback = null;
      }
      return this;
    },
    show() {
      this.isVisible = true;
      post({ event: 'mainButtonSetParams', is_visible: true });
      return this;
    },
    hide() {
      this.isVisible = false;
      post({ event: 'mainButtonSetParams', is_visible: false });
      return this;
    },
    enable() {
      this.isActive = true;
      post({ event: 'mainButtonSetParams', is_active: true });
      return this;
    },
    disable() {
      this.isActive = false;
      post({ event: 'mainButtonSetParams', is_active: false });
      return this;
    },
    showProgress(leaveActive) {
      this.isProgressVisible = true;
      if (!leaveActive) {
        this.isActive = false;
      }
      post({ event: 'mainButtonSetParams', is_progress_visible: true, is_active: this.isActive });
      return this;
    },
    hideProgress() {
      this.isProgressVisible = false;
      post({ event: 'mainButtonSetParams', is_progress_visible: false });
      return this;
    },
    setParams(params) {
      if (params.text != null) this.text = params.text;
      if (params.color != null) this.color = params.color;
      if (params.text_color != null) this.textColor = params.text_color;
      if (params.is_active != null) this.isActive = params.is_active;
      if (params.is_visible != null) this.isVisible = params.is_visible;
      post({ event: 'mainButtonSetParams', ...params });
      return this;
    },
    click() {
      if (this._callback) {
        this._callback();
      }
    },
  };

  const BackButton = {
    isVisible: false,
    _callback: null,
    onClick(callback) {
      this._callback = callback;
      return this;
    },
    offClick(callback) {
      if (!callback || this._callback === callback) {
        this._callback = null;
      }
      return this;
    },
    show() {
      this.isVisible = true;
      post({ event: 'backButtonSetParams', is_visible: true });
      return this;
    },
    hide() {
      this.isVisible = false;
      post({ event: 'backButtonSetParams', is_visible: false });
      return this;
    },
    click() {
      if (this._callback) {
        this._callback();
      }
    },
  };

  const WebApp = {
    __riogram: true,
    initData: '',
    initDataUnsafe: {},
    version: '6.9',
    platform: 'unknown',
    colorScheme: 'light',
    themeParams: {},
    isExpanded: false,
    viewportHeight: window.innerHeight,
    viewportStableHeight: window.innerHeight,
    headerColor: '#ffffff',
    backgroundColor: '#ffffff',
    MainButton,
    BackButton,
    ready() {
      post({ event: 'ready' });
      emit('viewportChanged', { isStateStable: true });
      return this;
    },
    expand() {
      this.isExpanded = true;
      post({ event: 'expand' });
      emit('viewportChanged', { isStateStable: true });
      return this;
    },
    close() {
      post({ event: 'close' });
      return this;
    },
    sendData(data) {
      post({ event: 'sendData', data: String(data ?? '') });
      return this;
    },
    openLink(url, options) {
      post({
        event: 'openLink',
        url: String(url ?? ''),
        try_instant_view: Boolean(options && options.try_instant_view),
      });
      return this;
    },
    openTelegramLink(url) {
      post({ event: 'openTelegramLink', url: String(url ?? '') });
      return this;
    },
    invokeCustomMethod(method, params, callback) {
      const requestId = String(Date.now()) + Math.random().toString(16).slice(2);
      if (typeof callback === 'function') {
        handlers['customMethod:' + requestId] = [callback];
      }
      post({
        event: 'invokeCustomMethod',
        request_id: requestId,
        method: String(method ?? ''),
        params: params == null ? '{}' : JSON.stringify(params),
      });
      return this;
    },
    onEvent(eventType, callback) {
      if (!handlers[eventType]) {
        handlers[eventType] = [];
      }
      handlers[eventType].push(callback);
      return this;
    },
    offEvent(eventType, callback) {
      const list = handlers[eventType];
      if (!list) {
        return this;
      }
      handlers[eventType] = list.filter((item) => item !== callback);
      return this;
    },
    setHeaderColor(color) {
      this.headerColor = color;
      post({ event: 'setHeaderColor', color });
      return this;
    },
    setBackgroundColor(color) {
      this.backgroundColor = color;
      post({ event: 'setBackgroundColor', color });
      return this;
    },
    enableClosingConfirmation() {
      post({ event: 'enableClosingConfirmation' });
      return this;
    },
    disableClosingConfirmation() {
      post({ event: 'disableClosingConfirmation' });
      return this;
    },
    _receiveEvent(eventType, data) {
      if (eventType === 'mainButtonClicked') {
        MainButton.click();
        return;
      }
      if (eventType === 'backButtonClicked') {
        BackButton.click();
        return;
      }
      if (eventType === 'customMethodResult') {
        const requestId = data && data.request_id;
        const key = 'customMethod:' + requestId;
        const callbacks = handlers[key] || [];
        delete handlers[key];
        for (const callback of callbacks) {
          callback(data && data.result);
        }
        return;
      }
      emit(eventType, data);
    },
    _applyHostConfig(config) {
      if (!config) {
        return;
      }
      if (config.initData != null) this.initData = config.initData;
      if (config.initDataUnsafe != null) this.initDataUnsafe = config.initDataUnsafe;
      if (config.platform != null) this.platform = config.platform;
      if (config.colorScheme != null) this.colorScheme = config.colorScheme;
      if (config.themeParams != null) this.themeParams = config.themeParams;
      if (config.viewportHeight != null) {
        this.viewportHeight = config.viewportHeight;
        this.viewportStableHeight = config.viewportHeight;
      }
    },
  };

  window.Telegram = { WebApp };
})();
