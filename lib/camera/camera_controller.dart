import 'package:flutter/foundation.dart';

import 'camera_state.dart';

abstract class CameraController extends ChangeNotifier {
  CameraState get state;

  bool get requiresPlatformView;

  Future<void> initialize();

  Future<void> attachPlatformView(int viewId);

  Future<void> retry();

  Future<void> pause();

  Future<void> resume();

  Future<void> release();
}

typedef CameraControllerFactory = CameraController Function();
