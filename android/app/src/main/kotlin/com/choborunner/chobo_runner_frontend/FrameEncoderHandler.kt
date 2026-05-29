package com.choborunner.chobo_runner_frontend

import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Dart에서 CameraImage plane 데이터를 보내 JPEG으로 인코딩 받기 위한 MethodChannel.
 * 실제 인코딩은 [FrameEncoderUtil]에 위임.
 */
class FrameEncoderHandler : MethodCallHandler {

    companion object {
        const val CHANNEL = "chobo_runner/frame_encoder"
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (call.method != "encode") {
            result.notImplemented()
            return
        }

        try {
            val y = call.argument<ByteArray>("y")
            val u = call.argument<ByteArray>("u")
            val v = call.argument<ByteArray>("v")
            val width = call.argument<Int>("width")
            val height = call.argument<Int>("height")
            val yRowStride = call.argument<Int>("yRowStride")
            val uvRowStride = call.argument<Int>("uvRowStride")
            val uvPixelStride = call.argument<Int>("uvPixelStride")
            val rotation = call.argument<Int>("rotation") ?: 0
            val quality = call.argument<Int>("quality") ?: 85

            if (y == null || u == null || v == null ||
                width == null || height == null ||
                yRowStride == null || uvRowStride == null || uvPixelStride == null
            ) {
                result.error("BAD_ARGS", "missing required arg", null)
                return
            }

            val jpeg = FrameEncoderUtil.encode(
                y = y,
                u = u,
                v = v,
                width = width,
                height = height,
                yRowStride = yRowStride,
                uvRowStride = uvRowStride,
                uvPixelStride = uvPixelStride,
                rotation = rotation,
                quality = quality,
            )
            result.success(jpeg)
        } catch (t: Throwable) {
            result.error("ENCODE_FAIL", t.message, null)
        }
    }
}
