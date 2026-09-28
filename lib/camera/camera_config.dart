class CameraConfig {
  const CameraConfig({
    required this.platformSupported,
    required this.configured,
    this.missingKeys = const [],
    this.sdkVersion,
    this.cameraNo = 1,
  });

  const CameraConfig.unsupported()
      : platformSupported = false,
        configured = false,
        missingKeys = const [],
        sdkVersion = null,
        cameraNo = 1;

  final bool platformSupported;
  final bool configured;
  final List<String> missingKeys;
  final String? sdkVersion;
  final int cameraNo;

  factory CameraConfig.fromMap(Map<Object?, Object?> map) {
    return CameraConfig(
      platformSupported: map['platformSupported'] == true,
      configured: map['configured'] == true,
      missingKeys: (map['missingKeys'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      sdkVersion: map['sdkVersion'] as String?,
      cameraNo: map['cameraNo'] as int? ?? 1,
    );
  }

  String get developmentStatus {
    if (!platformSupported) {
      return '当前平台不加载 Android 萤石 SDK';
    }
    if (configured) {
      return '本机配置已加载 · cameraNo=$cameraNo'
          '${sdkVersion == null ? '' : ' · SDK $sdkVersion'}';
    }
    if (missingKeys.isEmpty) return '本机摄像头配置不可用';
    return '缺少本机配置：${missingKeys.join(', ')}';
  }
}
