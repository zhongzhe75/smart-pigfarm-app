import 'camera_config.dart';
import '../config/runtime_mode.dart';

class CameraConfigLoader {
  const CameraConfigLoader();

  static const _accessToken = String.fromEnvironment('EZVIZ_ACCESS_TOKEN');
  static const _deviceSerial = String.fromEnvironment('EZVIZ_DEVICE_SERIAL');
  static const _verifyCode = String.fromEnvironment('EZVIZ_VERIFY_CODE');

  Future<CameraConfig> load() async {
    if (RuntimeConfig.current != RuntimeMode.webLive) {
      return const CameraConfig.unsupported();
    }
    final missingKeys = <String>[
      if (_accessToken.trim().isEmpty) 'EZVIZ_ACCESS_TOKEN',
      if (_deviceSerial.trim().isEmpty) 'EZVIZ_DEVICE_SERIAL',
      if (_verifyCode.trim().isEmpty) 'EZVIZ_VERIFY_CODE',
    ];
    return CameraConfig(
      platformSupported: true,
      configured: missingKeys.isEmpty,
      missingKeys: missingKeys,
      sdkVersion: '9.0.15',
      cameraNo: 1,
    );
  }
}
