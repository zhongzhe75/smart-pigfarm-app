import 'dart:io';

import 'package:flutter/services.dart';

import 'camera_config.dart';

class CameraConfigLoader {
  const CameraConfigLoader();

  static const _channel =
      MethodChannel('com.example.smart_pigfarm_app/ezviz_camera');

  Future<CameraConfig> load() async {
    if (!Platform.isAndroid) return const CameraConfig.unsupported();
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'getConfiguration',
      );
      return CameraConfig.fromMap(value ?? const {});
    } on MissingPluginException {
      return const CameraConfig.unsupported();
    } on PlatformException {
      return const CameraConfig(
        platformSupported: true,
        configured: false,
      );
    }
  }
}
