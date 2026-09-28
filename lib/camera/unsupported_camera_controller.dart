import 'camera_config.dart';
import 'camera_controller.dart';
import 'camera_state.dart';
import 'camera_status.dart';

class UnsupportedCameraController extends CameraController {
  CameraState _state = const CameraState.initial();

  @override
  CameraState get state => _state;

  @override
  bool get requiresPlatformView => false;

  @override
  Future<void> initialize() async {
    _state = const CameraState(
      status: CameraStatus.unconfigured,
      config: CameraConfig.unsupported(),
    );
    notifyListeners();
  }

  @override
  Future<void> attachPlatformView(int viewId) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> retry() async {}
}
