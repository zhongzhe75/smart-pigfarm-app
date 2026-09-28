import 'package:flutter/widgets.dart';

import 'camera_controller.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
