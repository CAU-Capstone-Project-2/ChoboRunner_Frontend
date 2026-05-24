package com.choborunner.chobo_runner_frontend

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
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
            val quality = call.argument<Int>("quality") ?: 85

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

        val (rotatedNv21, outW, outH) = when (rotation.mod(360)) {
            0 -> Triple(nv21, width, height)
            90 -> Triple(rotateNv21Cw90(nv21, width, height), height, width)
            180 -> Triple(rotateNv21Cw180(nv21, width, height), width, height)
            270 -> Triple(rotateNv21Cw270(nv21, width, height), height, width)
            else -> Triple(nv21, width, height)
        }

        val yuvImage = YuvImage(rotatedNv21, ImageFormat.NV21, outW, outH, null)
        val baos = ByteArrayOutputStream(outW * outH / 2)
        yuvImage.compressToJpeg(Rect(0, 0, outW, outH), quality, baos)
        return baos.toByteArray()
    }

    /**
     * CameraImage(YUV_420_888) 3 planes → NV21 단일 버퍼.
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

    /**
     * NV21 시계방향 90도 회전.
     *
     * 출력 크기: (outW, outH) = (height, width)
     * Y plane은 픽셀 단위, VU plane은 2x2 블록 단위로 회전.
     */
    private fun rotateNv21Cw90(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        // Y plane: dst(x', y') = src(y, h-1-x), 여기서 x' = h-1-x, y' = ...
        // 시계방향 90도: dst[i*h + (h-1-j)] = src[j*w + i]
        var dst = 0
        for (x in 0 until w) {
            for (y in h - 1 downTo 0) {
                out[dst++] = src[y * w + x]
            }
        }

        // VU plane: 2x2 블록 단위. 입력 (w/2, h/2)을 회전해 (h/2, w/2)로.
        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (x in 0 until uvW) {
            for (y in uvH - 1 downTo 0) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]     // V
                out[dst++] = src[srcIdx + 1] // U
            }
        }
        return out
    }

    /**
     * NV21 180도 회전.
     * 크기 유지. (outW, outH) = (w, h)
     */
    private fun rotateNv21Cw180(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        // Y plane: dst[j*w + i] = src[(h-1-j)*w + (w-1-i)]
        var dst = 0
        for (y in h - 1 downTo 0) {
            for (x in w - 1 downTo 0) {
                out[dst++] = src[y * w + x]
            }
        }

        // VU plane
        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (y in uvH - 1 downTo 0) {
            for (x in uvW - 1 downTo 0) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]     // V
                out[dst++] = src[srcIdx + 1] // U
            }
        }
        return out
    }

    /**
     * NV21 시계방향 270도(= 반시계 90도) 회전.
     * 출력 크기: (outW, outH) = (height, width)
     */
    private fun rotateNv21Cw270(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        // Y plane: dst[(w-1-i)*h + j] = src[j*w + i]
        var dst = 0
        for (x in w - 1 downTo 0) {
            for (y in 0 until h) {
                out[dst++] = src[y * w + x]
            }
        }

        // VU plane
        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (x in uvW - 1 downTo 0) {
            for (y in 0 until uvH) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]     // V
                out[dst++] = src[srcIdx + 1] // U
            }
        }
        return out
    }
}
