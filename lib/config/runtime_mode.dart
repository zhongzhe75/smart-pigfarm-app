import 'package:flutter/foundation.dart';

enum RuntimeMode {
  auto,
  webLocal,
  webLive,
  padLocal,
  padLive;

  static RuntimeMode fromEnvironment() {
    const value = String.fromEnvironment(
      'APP_RUNTIME_MODE',
      defaultValue: 'auto',
    );
    return RuntimeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => RuntimeMode.auto,
    );
  }

  RuntimeMode resolve({
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    if (this != RuntimeMode.auto) return this;
    if (isWeb) return RuntimeMode.webLocal;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.android
        ? RuntimeMode.padLive
        : RuntimeMode.padLocal;
  }

  bool get usesLiveCamera =>
      this == RuntimeMode.webLive || this == RuntimeMode.padLive;

  bool get usesWebLiveCamera => this == RuntimeMode.webLive;

  bool get usesLocalVideo =>
      this == RuntimeMode.webLocal || this == RuntimeMode.padLocal;
}

abstract final class RuntimeConfig {
  static final RuntimeMode requested = RuntimeMode.fromEnvironment();
  static final RuntimeMode current = requested.resolve();
}
