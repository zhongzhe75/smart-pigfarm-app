import 'camera_config.dart';
import 'camera_status.dart';

class CameraState {
  const CameraState({
    required this.status,
    this.config = const CameraConfig.unsupported(),
    this.lastError,
    this.errorCode,
  });

  const CameraState.initial()
      : status = CameraStatus.initializing,
        config = const CameraConfig.unsupported(),
        lastError = null,
        errorCode = null;

  final CameraStatus status;
  final CameraConfig config;
  final String? lastError;
  final int? errorCode;

  CameraState copyWith({
    CameraStatus? status,
    CameraConfig? config,
    String? lastError,
    int? errorCode,
    bool clearError = false,
  }) {
    return CameraState(
      status: status ?? this.status,
      config: config ?? this.config,
      lastError: clearError ? null : lastError ?? this.lastError,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}
