import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'camera_controller.dart';

@JS('smartPigfarmEzviz.registerContainer')
external void _registerContainer(int viewId, web.HTMLElement element);

@JS('smartPigfarmEzviz.unregisterContainer')
external void _unregisterContainer(int viewId);

class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.controller});

  final CameraController controller;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static int _nextViewType = 0;
  late final String _viewType;
  int? _viewId;

  @override
  void initState() {
    super.initState();
    _viewType = 'smart-pigfarm-ezviz-${_nextViewType++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final element = web.HTMLDivElement()
          ..id = 'smart-pigfarm-ezviz-player-$viewId'
          ..setAttribute('aria-label', 'H6c 实时监控画面')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#050c0a'
          ..style.overflow = 'hidden';
        _registerContainer(viewId, element);
        return element;
      },
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    widget.controller.attachPlatformView(viewId);
  }

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) _unregisterContainer(viewId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(
        key: const Key('ezviz-web-camera-view'),
        viewType: _viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
      );
}
