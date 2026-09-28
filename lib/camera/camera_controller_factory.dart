import 'camera_controller.dart';
import 'camera_controller_factory_stub.dart'
    if (dart.library.io) 'camera_controller_factory_io.dart'
    if (dart.library.html) 'camera_controller_factory_web.dart' as platform;

CameraController createCameraController() => platform.createCameraController();
