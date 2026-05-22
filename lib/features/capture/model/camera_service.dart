import 'package:camera/camera.dart';

/// 카메라 하드웨어를 감싸는 서비스.
///
/// - 카메라 목록 조회 및 후면 카메라 선택
/// - CameraController 초기화/dispose
/// - image stream(YUV420) 시작/정지 및 최신 프레임 캐시
///
/// 단일 프레임 캡처(takePicture) 방식은 제거됨. CaptureLoopController가
/// 33ms 주기로 takeLatest()를 호출해 최신 캐시 프레임을 사용한다.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = const [];
  CameraDescription? _selectedCamera;
  bool _streaming = false;

  /// 외부에서 프리뷰 위젯이 사용할 컨트롤러 (초기화 후 non-null)
  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// 선택된 카메라의 sensor orientation (degrees). 회전 보정 시 사용.
  int? get sensorOrientation => _selectedCamera?.sensorOrientation;

  /// 사용 가능한 카메라 목록 로드
  Future<List<CameraDescription>> loadAvailableCameras() async {
    _availableCameras = await availableCameras();
    return _availableCameras;
  }

  /// 후면 카메라 선택 (없으면 첫 번째 카메라)
  CameraDescription? _pickBackCamera() {
    if (_availableCameras.isEmpty) return null;
    return _availableCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _availableCameras.first,
    );
  }

  /// 카메라 초기화
  ///
  /// 권한이 이미 허용된 상태에서 호출되어야 함.
  /// 권한 처리는 ViewModel 책임.
  Future<void> initialize() async {
    if (_availableCameras.isEmpty) {
      await loadAvailableCameras();
    }

    final camera = _pickBackCamera();
    if (camera == null) {
      throw StateError('사용 가능한 카메라가 없습니다');
    }
    _selectedCamera = camera;

    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.high, // 1280x720 정도. 백엔드 권장 720p.
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  /// image stream 시작.
  ///
  /// 스트림 콜백 안에서는 최신 프레임만 캐시한다 (덮어쓰기).
  /// 소비 측은 takeLatest()로 가장 최근 프레임을 가져간다.
  Future<void> startStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('카메라가 초기화되지 않았습니다');
    }
    if (_streaming) return;

    await controller.startImageStream((image) {
      _latestImage = image;
    });
    _streaming = true;
  }

  /// image stream 정지. 캐시도 비움.
  Future<void> stopStream() async {
    if (!_streaming) return;
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // 이미 멈춰있어도 무시
      }
    }
    _streaming = false;
    _latestImage = null;
  }

  bool get isStreaming => _streaming;

  CameraImage? _latestImage;

  /// 가장 최근에 들어온 프레임 캐시. 없으면 null.
  /// 호출 후 캐시를 비우지 않으므로 같은 프레임을 두 번 가져갈 수 있다.
  CameraImage? takeLatest() => _latestImage;

  /// 리소스 정리
  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    _selectedCamera = null;
  }
}
