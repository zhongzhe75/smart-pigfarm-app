import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_controller.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.expand();
    }
    return AndroidView(
      key: const Key('ezviz-android-camera-view'),
      viewType: 'com.example.smart_pigfarm_app/ezviz_camera_view',
      onPlatformViewCreated: controller.attachPlatformView,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
