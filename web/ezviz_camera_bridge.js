(function (global) {
  'use strict';

  const players = new Map();
  const containers = new Map();
  let nextHandle = 1;

  function registerContainer(viewId, element) {
    containers.set(Number(viewId), element);
  }

  function unregisterContainer(viewId) {
    containers.delete(Number(viewId));
  }

  function mountPlayerHost(record, anchor, containerId) {
    const host = document.createElement('div');
    host.id = containerId;
    host.setAttribute('aria-label', 'H6c 实时监控画面');
    host.style.position = 'fixed';
    host.style.margin = '0';
    host.style.padding = '0';
    host.style.overflow = 'hidden';
    host.style.background = '#050c0a';
    host.style.zIndex = '10';
    document.body.appendChild(host);

    const sync = function () {
      if (record.destroyed || !anchor.isConnected) {
        host.style.display = 'none';
        return;
      }
      const rect = anchor.getBoundingClientRect();
      host.style.display = rect.width > 0 && rect.height > 0 ? 'block' : 'none';
      host.style.left = `${rect.left}px`;
      host.style.top = `${rect.top}px`;
      host.style.width = `${rect.width}px`;
      host.style.height = `${rect.height}px`;
    };
    const observer = new ResizeObserver(sync);
    observer.observe(anchor);
    window.addEventListener('resize', sync);
    window.addEventListener('scroll', sync, true);
    sync();
    requestAnimationFrame(sync);

    record.anchor = anchor;
    record.container = host;
    record.resizeObserver = observer;
    record.syncHost = sync;
    return host;
  }

  function unmountPlayerHost(record) {
    if (record.resizeObserver) record.resizeObserver.disconnect();
    if (record.syncHost) {
      window.removeEventListener('resize', record.syncHost);
      window.removeEventListener('scroll', record.syncHost, true);
    }
    if (record.container) {
      record.container.replaceChildren();
      record.container.remove();
    }
    record.anchor = null;
    record.container = null;
    record.resizeObserver = null;
    record.syncHost = null;
  }

  function toCode(error) {
    const candidates = [
      error && error.data && error.data.nErrorCode,
      error && error.data && error.data.code,
      error && error.nErrorCode,
      error && error.errorCode,
      error && error.code,
    ];
    return candidates.find((value) => value !== undefined && value !== null) ?? '';
  }

  function toMessage(error) {
    const value =
      (error && error.data && (error.data.message || error.data.msg)) ||
      (error && (error.message || error.msg)) ||
      '';
    return typeof value === 'string' ? value : '';
  }

  function safeDiagnostic(error) {
    const redact = (value) => String(value || '')
      .replace(/at\.[A-Za-z0-9-]+/g, '[TOKEN]')
      .replace(/ezopen:\/\/[^\s"']+/gi, '[EZOPEN]');
    return JSON.stringify({
      name: redact(error && error.name),
      type: redact(error && error.type),
      code: redact(toCode(error)),
      message: redact(toMessage(error)),
    });
  }

  function classify(error) {
    const code = String(toCode(error)).toUpperCase();
    const message = toMessage(error);
    const normalized = `${code} ${message}`.toLowerCase();

    if (
      ['UE001', 'EZ001', '10002', '110002', '110003', '310002'].includes(code) ||
      (normalized.includes('token') &&
        (normalized.includes('expire') || normalized.includes('invalid')))
    ) {
      return { status: 'tokenExpired', code, message: '视频授权已过期，请联系管理员更新后重试。' };
    }
    if (
      ['5', 'UE104', 'EZ104', '5002', '120010', '200006', '400035', '400036', '400041'].includes(code) ||
      normalized.includes('verifycode') ||
      normalized.includes('validatecode') ||
      normalized.includes('验证码')
    ) {
      return { status: 'verifyCodeRequired', code, message: '设备视频验证失败，请联系管理员检查配置。' };
    }
    if (
      ['UE102', 'EZ102', '20007', '120007', '120023', '120024', '395404'].includes(code) ||
      normalized.includes('offline') ||
      normalized.includes('设备离线')
    ) {
      return { status: 'offline', code, message: '摄像头当前离线，请检查设备电源和网络。' };
    }
    if (
      ['100006', '100007', '100028'].includes(code) ||
      normalized.includes('network') ||
      normalized.includes('timeout') ||
      normalized.includes('cors')
    ) {
      return { status: 'networkError', code, message: '网络连接异常，请检查网络后重新连接。' };
    }
    return { status: 'error', code, message: '实时视频播放失败，请重新连接。' };
  }

  function emit(record, event) {
    if (record.destroyed) return;
    record.onEvent(event);
  }

  function create(options, onEvent) {
    const handle = nextHandle++;
    const record = {
      destroyed: false,
      onEvent,
      player: null,
      anchor: null,
      container: null,
      containerId: options.containerId,
      resizeObserver: null,
      syncHost: null,
      startedAt: performance.now(),
    };
    players.set(handle, record);

    try {
      if (!global.EZUIKit || typeof global.EZUIKit.EZUIKitPlayer !== 'function') {
        throw new Error('Official player library is unavailable');
      }
      const serial = String(options.deviceSerial || '').trim().toUpperCase();
      const verifyCode = String(options.verifyCode || '').trim();
      const authority = verifyCode ? `${verifyCode}@open.ys7.com` : 'open.ys7.com';
      const url = `ezopen://${authority}/${serial}/${Number(options.cameraNo) || 1}.live`;
      const anchor = containers.get(Number(options.viewId));
      if (!anchor) throw new Error('Video container is not mounted');
      const container = mountPlayerHost(record, anchor, options.containerId);
      const player = new global.EZUIKit.EZUIKitPlayer({
        id: options.containerId,
        container,
        accessToken: options.accessToken,
        url,
        width: '100%',
        height: '100%',
        staticPath: options.staticPath,
        audio: false,
        autoplay: true,
        template: 'simple',
        quality: 0,
        streamInfoCBType: 1,
        loggerOptions: { name: 'web-live', level: 'ERROR', showTime: true },
        handleSuccess: function () {
          emit(record, { status: 'playing', code: '', message: '' });
        },
        handleError: function (error) {
          const event = classify(error);
          console.error(`[Web Live] playback error ${safeDiagnostic(error)}`);
          emit(record, event);
        },
      });
      record.player = player;

      const events = global.EZUIKit.EZUIKitPlayer.EVENTS;
      if (player.eventEmitter && events && events.firstFrameDisplay) {
        player.eventEmitter.on(events.firstFrameDisplay, function () {
          const elapsed = Math.round(performance.now() - record.startedAt);
          console.info(`[Web Live] first frame rendered in ${elapsed} ms`);
          emit(record, { status: 'playing', code: '', message: '' });
        });
      }
      return handle;
    } catch (error) {
      const event = classify(error);
      console.error(`[Web Live] player startup error ${safeDiagnostic(error)}`);
      emit(record, event);
      unmountPlayerHost(record);
      players.delete(handle);
      return 0;
    }
  }

  async function play(handle) {
    const record = players.get(Number(handle));
    if (!record || record.destroyed || !record.player) return;
    record.startedAt = performance.now();
    await Promise.resolve(record.player.play());
  }

  async function stop(handle) {
    const record = players.get(Number(handle));
    if (!record || record.destroyed || !record.player) return;
    await Promise.resolve(record.player.stop());
  }

  async function destroy(handle) {
    const id = Number(handle);
    const record = players.get(id);
    if (!record || record.destroyed) return;
    record.destroyed = true;
    players.delete(id);
    try {
      if (record.player && typeof record.player.stop === 'function') {
        await Promise.resolve(record.player.stop());
      }
    } catch (_) {
      // Destruction continues even when the stream is already closed.
    }
    try {
      if (record.player && typeof record.player.destroy === 'function') {
        await Promise.resolve(record.player.destroy());
      }
    } finally {
      record.player = null;
      unmountPlayerHost(record);
    }
  }

  global.addEventListener('pagehide', function () {
    for (const handle of Array.from(players.keys())) {
      void destroy(handle);
    }
  });

  global.smartPigfarmEzviz = Object.freeze({
    registerContainer,
    unregisterContainer,
    create,
    play,
    stop,
    destroy,
  });
})(globalThis);
