import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// YUV420 image stream 프레임을 backend 전송용 JPEG로 변환하기 위한 입력.
///
/// CameraImage 자체는 isolate/플랫폼 채널로 보낼 수 없어 plane bytes/strides만 추려 담음.
@immutable
class FrameEncoderInput {
  const FrameEncoderInput({
    required this.yPlane,
    required this.uPlane,
    required this.vPlane,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    this.jpegQuality = 70,
  });

  final Uint8List yPlane;
  final Uint8List uPlane;
  final Uint8List vPlane;
  final int yRowStride;
  final int uvRowStride;

  /// UV plane이 NV12/NV21로 인터리브되어 있으면 2, 평면 분리면 1.
  final int uvPixelStride;

  final int width;
  final int height;

  /// 0/90/180/270. CameraDescription.sensorOrientation 값을 그대로 넣으면
  /// 디바이스 자연 방향(portrait) 기준 upright 프레임이 생성됨.
  final int rotationDegrees;

  final int jpegQuality;
}

/// YUV420 프레임 → 회전 보정 → JPEG. Android 네이티브(YuvImage)에서 실행.
///
/// 실패 시 null. iOS는 미지원.
Future<Uint8List?> encodeYuv420ToJpeg(FrameEncoderInput input) async {
  try {
    final result = await _channel.invokeMethod<Uint8List>('encode', {
      'y': input.yPlane,
      'u': input.uPlane,
      'v': input.vPlane,
      'width': input.width,
      'height': input.height,
      'yRowStride': input.yRowStride,
      'uvRowStride': input.uvRowStride,
      'uvPixelStride': input.uvPixelStride,
      'rotation': input.rotationDegrees,
      'quality': input.jpegQuality,
    });
    return result;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
}

const MethodChannel _channel = MethodChannel('chobo_runner/frame_encoder');
