import 'package:flutter/foundation.dart';

import 'camera_status.dart';

class CameraRuntimeStatus {
  CameraRuntimeStatus._();

  static final ValueNotifier<CameraStatus?> current = ValueNotifier(null);

  static void publish(CameraStatus status) {
    current.value = status;
  }
}
