enum CameraStatus {
  unconfigured,
  initializing,
  connecting,
  playing,
  offline,
  tokenExpired,
  verifyCodeRequired,
  error,
}

extension CameraStatusText on CameraStatus {
  String get label {
    switch (this) {
      case CameraStatus.unconfigured:
        return '待配置';
      case CameraStatus.initializing:
        return '初始化中';
      case CameraStatus.connecting:
        return '连接中';
      case CameraStatus.playing:
        return '播放中';
      case CameraStatus.offline:
        return '设备离线';
      case CameraStatus.tokenExpired:
        return '授权已过期';
      case CameraStatus.verifyCodeRequired:
        return '视频加密验证失败';
      case CameraStatus.error:
        return '连接异常';
    }
  }
}
