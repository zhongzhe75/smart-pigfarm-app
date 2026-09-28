import 'camera_config.dart';

class CameraConfigLoader {
  const CameraConfigLoader();

  Future<CameraConfig> load() async => const CameraConfig.unsupported();
}
