package com.choborunner.chobo_runner_frontend

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

/**
 * YUV420 → NV21 → 회전 → JPEG 인코딩 유틸.
 *
 * FrameEncoderHandler(MethodChannel용)와 Camera2RecordingController(네이티브 캡처용)
 * 모두에서 공유한다.
 */
object FrameEncoderUtil {

    /**
     * CameraImage(android.media.Image) 또는 동등한 plane 데이터를 받아
     * sensor orientation으로 회전 적용된 JPEG 바이트 배열로 반환.
     */
    fun encode(
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
     * android.media.Image (YUV_420_888) 한 장을 바로 JPEG로 인코딩.
     * Camera2 ImageReader 콜백에서 사용.
     */
    fun encodeFromImage(image: Image, rotation: Int, quality: Int): ByteArray {
        require(image.format == ImageFormat.YUV_420_888) {
            "expected YUV_420_888, got ${image.format}"
        }
        val planes = image.planes
        val y = bufferToByteArray(planes[0].buffer)
        val u = bufferToByteArray(planes[1].buffer)
        val v = bufferToByteArray(planes[2].buffer)
        return encode(
            y = y,
            u = u,
            v = v,
            width = image.width,
            height = image.height,
            yRowStride = planes[0].rowStride,
            uvRowStride = planes[1].rowStride,
            uvPixelStride = planes[1].pixelStride,
            rotation = rotation,
            quality = quality,
        )
    }

    private fun bufferToByteArray(buffer: ByteBuffer): ByteArray {
        buffer.rewind()
        val arr = ByteArray(buffer.remaining())
        buffer.get(arr)
        return arr
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
     * NV21 시계방향 90도 회전. 출력 크기: (height, width)
     */
    private fun rotateNv21Cw90(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        var dst = 0
        for (x in 0 until w) {
            for (y in h - 1 downTo 0) {
                out[dst++] = src[y * w + x]
            }
        }

        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (x in 0 until uvW) {
            for (y in uvH - 1 downTo 0) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]
                out[dst++] = src[srcIdx + 1]
            }
        }
        return out
    }

    private fun rotateNv21Cw180(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        var dst = 0
        for (y in h - 1 downTo 0) {
            for (x in w - 1 downTo 0) {
                out[dst++] = src[y * w + x]
            }
        }

        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (y in uvH - 1 downTo 0) {
            for (x in uvW - 1 downTo 0) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]
                out[dst++] = src[srcIdx + 1]
            }
        }
        return out
    }

    private fun rotateNv21Cw270(src: ByteArray, w: Int, h: Int): ByteArray {
        val ySize = w * h
        val out = ByteArray(src.size)

        var dst = 0
        for (x in w - 1 downTo 0) {
            for (y in 0 until h) {
                out[dst++] = src[y * w + x]
            }
        }

        val uvW = w / 2
        val uvH = h / 2
        dst = ySize
        for (x in uvW - 1 downTo 0) {
            for (y in 0 until uvH) {
                val srcIdx = ySize + y * w + x * 2
                out[dst++] = src[srcIdx]
                out[dst++] = src[srcIdx + 1]
            }
        }
        return out
    }
}
