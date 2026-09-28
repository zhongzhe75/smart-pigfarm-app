import 'dart:async';

import 'package:flutter/services.dart';

import 'camera_config_loader.dart';
import 'camera_controller.dart';
import 'camera_runtime_status.dart';
import 'camera_state.dart';
import 'camera_status.dart';

class EzvizCameraController extends CameraController {
  EzvizCameraController({CameraConfigLoader? configLoader})
      : _configLoader = configLoader ?? const CameraConfigLoader();

  final CameraConfigLoader _configLoader;
  CameraState _state = const CameraState.initial();
  MethodChannel? _viewChannel;
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
      status: config.platformSupported && config.configured
          ? CameraStatus.initializing
          : CameraStatus.unconfigured,
      config: config,
    ));
  }

  @override
  Future<void> attachPlatformView(int viewId) async {
    if (_released || !requiresPlatformView) return;
    final channel = MethodChannel(
      'com.example.smart_pigfarm_app/ezviz_camera/view/$viewId',
    );
    _viewChannel = channel;
    channel.setMethodCallHandler(_handleNativeCall);
    try {
      final current = await channel.invokeMapMethod<Object?, Object?>(
        'getState',
      );
      if (current != null) _applyNativeState(current);
      _update(_state.copyWith(
        status: CameraStatus.connecting,
        clearError: true,
      ));
      await channel.invokeMethod<void>('start');
    } on PlatformException catch (error) {
      _setBridgeError(error.code);
    } on MissingPluginException {
      _setBridgeError('missing_plugin');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'status' || _released) return;
    final arguments = call.arguments;
    if (arguments is Map<Object?, Object?>) {
      _applyNativeState(arguments);
    }
  }

  void _applyNativeState(Map<Object?, Object?> value) {
    final statusName = value['status'] as String?;
    final status = CameraStatus.values.cast<CameraStatus?>().firstWhere(
              (item) => item?.name == statusName,
              orElse: () => CameraStatus.error,
            ) ??
        CameraStatus.error;
    _update(CameraState(
      status: status,
      config: _state.config,
      errorCode: value['errorCode'] as int?,
      lastError: value['lastError'] as String?,
    ));
  }

  void _setBridgeError(String code) {
    _update(CameraState(
      status: CameraStatus.error,
      config: _state.config,
      lastError: 'Android 摄像头桥接不可用（$code）',
    ));
  }

  @override
  Future<void> retry() async {
    if (_released || !requiresPlatformView) return;
    _update(_state.copyWith(
      status: CameraStatus.connecting,
      clearError: true,
    ));
    try {
      await _viewChannel?.invokeMethod<void>('retry');
    } on PlatformException catch (error) {
      _setBridgeError(error.code);
    }
  }

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
    try {
      await _viewChannel?.invokeMethod<void>('pause');
    } on PlatformException {
      // Native lifecycle also stops the player; a pause failure is non-fatal.
    }
  }

  @override
  Future<void> resume() async {
    if (_released || !_resumeAfterPause) return;
    _resumeAfterPause = false;
    _update(_state.copyWith(
      status: CameraStatus.connecting,
      clearError: true,
    ));
    try {
      await _viewChannel?.invokeMethod<void>('resume');
    } on PlatformException catch (error) {
      _setBridgeError(error.code);
    }
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    final channel = _viewChannel;
    _viewChannel = null;
    channel?.setMethodCallHandler(null);
    try {
      await channel?.invokeMethod<void>('release');
    } on PlatformException {
      // PlatformView disposal is the final native-side release guard.
    }
  }

  void _update(CameraState value) {
    if (_released) return;
    _state = value;
    CameraRuntimeStatus.publish(value.status);
    notifyListeners();
  }
}
