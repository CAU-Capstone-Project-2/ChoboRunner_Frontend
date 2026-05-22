package com.choborunner.chobo_runner_frontend

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.graphics.ImageFormat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.ByteArrayOutputStream

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
            val quality = call.argument<Int>("quality") ?: 70

            if (y == null || u == null || v == null ||
                width == null || height == null ||
                yRowStride == null || uvRowStride == null || uvPixelStride == null
            ) {
                result.error("BAD_ARGS", "missing required arg", null)
                return
            }

            val jpeg = encode(
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

    private fun encode(
        y: ByteArray,
        u: ByteArray,
        v: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
        rotation: Int,
        quality: Int,
    ): ByteArray {
        val nv21 = yuv420ToNv21(
            y = y,
            u = u,
            v = v,
            width = width,
            height = height,
            yRowStride = yRowStride,
            uvRowStride = uvRowStride,
            uvPixelStride = uvPixelStride,
        )

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val baos = ByteArrayOutputStream(width * height / 2)
        yuvImage.compressToJpeg(Rect(0, 0, width, height), quality, baos)
        val raw = baos.toByteArray()

        if (rotation % 360 == 0) {
            return raw
        }

        // 회전이 필요한 경우만 비트맵 디코드→회전→재인코드.
        val bmp = BitmapFactory.decodeByteArray(raw, 0, raw.size)
            ?: return raw
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(
            bmp, 0, 0, bmp.width, bmp.height, matrix, false
        )
        val out = ByteArrayOutputStream(raw.size)
        rotated.compress(Bitmap.CompressFormat.JPEG, quality, out)
        bmp.recycle()
        if (rotated !== bmp) rotated.recycle()
        return out.toByteArray()
    }

    /**
     * CameraImage(YUV_420_888) 3 planes → NV21 단일 버퍼.
     *
     * NV21 레이아웃: [Y 평면][VU 인터리브 평면]
     */
    private fun yuv420ToNv21(
        y: ByteArray,
        u: ByteArray,
        v: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): ByteArray {
        val ySize = width * height
        val uvSize = width * height / 2
        val out = ByteArray(ySize + uvSize)

        // Y plane: rowStride == width이면 단순 복사, 아니면 row별 복사.
        if (yRowStride == width) {
            System.arraycopy(y, 0, out, 0, ySize)
        } else {
            var dst = 0
            var src = 0
            for (row in 0 until height) {
                System.arraycopy(y, src, out, dst, width)
                src += yRowStride
                dst += width
            }
        }

        // VU 인터리브 채우기. NV21은 V가 먼저, 그 다음 U.
        val uvHeight = height / 2
        val uvWidth = width / 2
        var dst = ySize
        for (row in 0 until uvHeight) {
            var uIdx = row * uvRowStride
            var vIdx = row * uvRowStride
            for (col in 0 until uvWidth) {
                out[dst++] = v[vIdx]
                out[dst++] = u[uIdx]
                uIdx += uvPixelStride
                vIdx += uvPixelStride
            }
        }
        return out
    }
}
