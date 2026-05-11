import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 카메라 JPEG bytes를 백엔드 전송용으로 압축
///
/// - 긴 변을 1280px 이하로 리사이즈
/// - JPEG quality 70으로 재인코딩
/// - 백그라운드 isolate에서 실행되어 UI 블로킹 없음
///
/// 실패 시 null 반환.
Future<Uint8List?> compressFrameForUpload(Uint8List jpegBytes) async {
  if (jpegBytes.isEmpty) return null;
  try {
    return await compute(_compressInIsolate, jpegBytes);
  } catch (_) {
    return null;
  }
}

/// 1280px 이하면 리사이즈 생략, 1280 초과면 긴 변 기준 리사이즈
const int _kMaxDimension = 1280;

/// JPEG 인코딩 quality
const int _kJpegQuality = 70;

/// isolate에서 실행되는 실제 압축 로직
Uint8List? _compressInIsolate(Uint8List input) {
  try {
    final decoded = img.decodeJpg(input);
    if (decoded == null) return null;

    final w = decoded.width;
    final h = decoded.height;

    img.Image processed = decoded;

    // 긴 변이 max를 초과하면 비율 유지하며 리사이즈
    final longSide = w > h ? w : h;
    if (longSide > _kMaxDimension) {
      if (w >= h) {
        processed = img.copyResize(
          decoded,
          width: _kMaxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        processed = img.copyResize(
          decoded,
          height: _kMaxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    final encoded = img.encodeJpg(processed, quality: _kJpegQuality);
    return Uint8List.fromList(encoded);
  } catch (_) {
    return null;
  }
}
