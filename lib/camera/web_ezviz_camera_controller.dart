import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'camera_config_loader.dart';
import 'camera_controller.dart';
import 'camera_runtime_status.dart';
import 'camera_state.dart';
import 'camera_status.dart';

@JS('smartPigfarmEzviz.create')
external JSNumber _createWebPlayer(
  _WebPlayerOptions options,
  JSFunction onEvent,
);

@JS('smartPigfarmEzviz.play')
external JSPromise<JSAny?> _playWebPlayer(JSNumber handle);

@JS('smartPigfarmEzviz.stop')
external JSPromise<JSAny?> _stopWebPlayer(JSNumber handle);

@JS('smartPigfarmEzviz.destroy')
external JSPromise<JSAny?> _destroyWebPlayer(JSNumber handle);

@JS()
@anonymous
extension type _WebPlayerOptions._(JSObject _) implements JSObject {
  external factory _WebPlayerOptions({
    required String containerId,
    required String accessToken,
    required String deviceSerial,
    required String verifyCode,
    required int cameraNo,
    required int viewId,
    required String staticPath,
  });
}

@JS()
extension type _WebPlayerEvent(JSObject _) implements JSObject {
  external String get status;
  external String get message;
  external JSAny? get code;
}

class WebEzvizCameraController extends CameraController {
  WebEzvizCameraController({CameraConfigLoader? configLoader})
      : _configLoader = configLoader ?? const CameraConfigLoader();

  static const _accessToken = String.fromEnvironment('EZVIZ_ACCESS_TOKEN');
  static const _deviceSerial = String.fromEnvironment('EZVIZ_DEVICE_SERIAL');
  static const _verifyCode = String.fromEnvironment('EZVIZ_VERIFY_CODE');

  final CameraConfigLoader _configLoader;
  CameraState _state = const CameraState.initial();
  JSNumber? _playerHandle;
  JSFunction? _eventCallback;
  int? _viewId;
  int _generation = 0;
  bool _released = false;
  bool _resumeAfterPause = false;

  @override
  CameraState get state => _state;

  @override
  bool get requiresPlatformView =>
      _state.config.platformSupported && _state.config.configured;

  @override
  Future<void> initialize() async {
    if (_released) return;
    _update(_state.copyWith(
      status: CameraStatus.initializing,
      clearError: true,
    ));
    final config = await _configLoader.load();
    if (_released) return;
    _update(CameraState(
      status: config.configured
          ? CameraStatus.initializing
          : CameraStatus.unconfigured,
      config: config,
    ));
  }

  @override
  Future<void> attachPlatformView(int viewId) async {
    if (_released || !requiresPlatformView) return;
    _viewId = viewId;
    await _replacePlayer();
  }

  Future<void> _replacePlayer() async {
    final viewId = _viewId;
    if (_released || viewId == null || !requiresPlatformView) return;
    await _disposePlayer();
    if (_released) return;

    final generation = ++_generation;
    _update(_state.copyWith(
      status: CameraStatus.connecting,
      clearError: true,
    ));
    final callback = ((JSObject value) {
      if (_released || generation != _generation) return;
      _handleWebEvent(_WebPlayerEvent(value));
    }).toJS;
    _eventCallback = callback;

    try {
      final handle = _createWebPlayer(
        _WebPlayerOptions(
          containerId: 'smart-pigfarm-ezviz-player-$viewId',
          accessToken: _accessToken,
          deviceSerial: _deviceSerial,
          verifyCode: _verifyCode,
          cameraNo: 1,
          viewId: viewId,
          staticPath: 'ezuikit/ezuikit_static',
        ),
        callback,
      );
      if (handle.toDartInt <= 0) {
        _setError(CameraStatus.error, '播放器暂时无法启动，请重新连接。');
        return;
      }
      _playerHandle = handle;
    } catch (error) {
      debugPrint('[Web Live] player creation failed: ${error.runtimeType}');
      _setError(CameraStatus.error, '播放器暂时无法启动，请重新连接。');
    }
  }

  void _handleWebEvent(_WebPlayerEvent event) {
    final status = switch (event.status) {
      'playing' => CameraStatus.playing,
      'offline' => CameraStatus.offline,
      'tokenExpired' => CameraStatus.tokenExpired,
      'verifyCodeRequired' => CameraStatus.verifyCodeRequired,
      'networkError' => CameraStatus.error,
      _ => CameraStatus.error,
    };
    final codeValue = event.code?.dartify();
    final errorCode = switch (codeValue) {
      int value => value,
      double value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    _update(CameraState(
      status: status,
      config: _state.config,
      errorCode: errorCode,
      lastError: status == CameraStatus.playing ? null : event.message,
    ));
  }

  void _setError(CameraStatus status, String message) {
    _update(CameraState(
      status: status,
      config: _state.config,
      lastError: message,
    ));
  }

  @override
  Future<void> retry() => _replacePlayer();

  @override
  Future<void> pause() async {
    if (_released) return;
    _resumeAfterPause = switch (_state.status) {
      CameraStatus.initializing ||
      CameraStatus.connecting ||
      CameraStatus.playing =>
        true,
      _ => false,
    };
    final handle = _playerHandle;
    if (handle == null) return;
    try {
      await _stopWebPlayer(handle).toDart;
    } catch (error) {
      debugPrint('[Web Live] player stop failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> resume() async {
    if (_released || !_resumeAfterPause) return;
    _resumeAfterPause = false;
    final handle = _playerHandle;
    if (handle == null) {
      await _replacePlayer();
      return;
    }
    _update(_state.copyWith(
      status: CameraStatus.connecting,
      clearError: true,
    ));
    try {
      await _playWebPlayer(handle).toDart;
    } catch (error) {
      debugPrint('[Web Live] player resume failed: ${error.runtimeType}');
      _setError(CameraStatus.error, '实时视频恢复失败，请重新连接。');
    }
  }

  Future<void> _disposePlayer() async {
    _generation++;
    final handle = _playerHandle;
    _playerHandle = null;
    if (_eventCallback != null) _eventCallback = null;
    if (handle == null) return;
    try {
      await _destroyWebPlayer(handle).toDart;
    } catch (error) {
      debugPrint('[Web Live] player release failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _disposePlayer();
  }

  void _update(CameraState value) {
    if (_released) return;
    _state = value;
    CameraRuntimeStatus.publish(value.status);
    notifyListeners();
  }
}
