import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/camera_service.dart';
import 'camera_provider.dart';

/// 카메라 권한 상태
enum CameraPermissionStatus {
  idle,
  granted,
  denied,
  permanentlyDenied,
}

/// 카메라 초기화 상태
enum CameraReadyStatus {
  idle,
  initializing,
  ready,
  error,
}

class CameraState {
  final CameraPermissionStatus permission;
  final CameraReadyStatus ready;
  final String? errorMessage;

  const CameraState({
    this.permission = CameraPermissionStatus.idle,
    this.ready = CameraReadyStatus.idle,
    this.errorMessage,
  });

  CameraState copyWith({
    CameraPermissionStatus? permission,
    CameraReadyStatus? ready,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CameraState(
      permission: permission ?? this.permission,
      ready: ready ?? this.ready,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isReady => ready == CameraReadyStatus.ready;
  bool get isInitializing => ready == CameraReadyStatus.initializing;
}

class CameraViewModel extends Notifier<CameraState> {
  late final CameraService _service;

  @override
  CameraState build() {
    _service = ref.read(cameraServiceProvider);
    return const CameraState();
  }

  /// 카메라 서비스 인스턴스 (화면이 controller에 접근할 때 사용)
  CameraService get service => _service;

  // ─────────── 액션 ───────────

  /// 권한 요청 + 카메라 초기화를 한 번에 수행
  Future<void> requestPermissionAndInitialize() async {
    state = state.copyWith(
      ready: CameraReadyStatus.initializing,
      clearError: true,
    );

    // 권한 요청
    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      state = state.copyWith(
        permission: CameraPermissionStatus.permanentlyDenied,
        ready: CameraReadyStatus.error,
        errorMessage: '카메라 권한이 영구 거부되었습니다. 설정에서 허용해주세요.',
      );
      return;
    }

    if (!status.isGranted) {
      state = state.copyWith(
        permission: CameraPermissionStatus.denied,
        ready: CameraReadyStatus.error,
        errorMessage: '카메라 권한이 거부되었습니다.',
      );
      return;
    }

    state = state.copyWith(permission: CameraPermissionStatus.granted);

    // 카메라 초기화
    try {
      await _service.initialize();
      state = state.copyWith(
        ready: CameraReadyStatus.ready,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        ready: CameraReadyStatus.error,
        errorMessage: '카메라 초기화 실패: $e',
      );
    }
  }

  /// 단일 프레임 캡처
  Future<Uint8List?> captureFrame() async {
    if (!state.isReady) return null;
    return _service.captureFrameBytes();
  }
}

/// 카메라 ViewModel Provider
final cameraViewModelProvider =
    NotifierProvider<CameraViewModel, CameraState>(
  CameraViewModel.new,
);
