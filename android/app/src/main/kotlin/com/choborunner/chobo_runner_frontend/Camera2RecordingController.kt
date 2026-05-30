package com.choborunner.chobo_runner_frontend

import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.ImageReader
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.util.Size
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import java.io.File

/**
 * 네이티브 Camera2로 후면 카메라를 열어 ImageReader(YUV) + MediaRecorder(MP4) 2-surface
 * 캡처 세션을 구성한다.
 *
 * Flutter `camera` 플러그인은 Preview surface까지 묶어 3-surface를 강제하므로
 * 일부 OEM(예: S24)에서 ImageAnalysis가 조용히 드롭되는 문제가 있다. 측정 화면 미리보기는
 * Method D(JPEG `Image.memory`)로 처리하므로 Preview surface가 필요 없다 → 2-surface만으로
 * 모든 폰에서 동작.
 *
 * 사용 흐름:
 *  1. [start] 호출 (outputPath 지정) → 카메라 open → 세션 구성 → MediaRecorder.start
 *  2. ImageReader 콜백마다 JPEG 인코딩해서 [frameSink]로 push
 *  3. [stop] 호출 → MediaRecorder.stop → 카메라 close → outputPath 반환
 *
 * Threading:
 *  - 카메라/이미지 콜백은 background HandlerThread에서 수신
 *  - EventChannel sink 호출은 main thread로 post (Flutter 요구)
 */
class Camera2RecordingController(private val context: Context) {

    companion object {
        private const val TAG = "Camera2Rec"
        private const val TARGET_W = 1280
        private const val TARGET_H = 720
        private const val FRAME_INTERVAL_MS = 33L // ~30fps throttle
        private const val JPEG_QUALITY = 85
        private const val VIDEO_BITRATE = 4_000_000
        private const val VIDEO_FPS = 30
    }

    var frameSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var mediaRecorder: MediaRecorder? = null
    private var recorderSurface: Surface? = null
    private var sensorOrientation: Int = 0
    private var outputPath: String? = null
    private var lastFrameNanos: Long = 0L
    private var isRunning = false

    /**
     * 녹화 + 프레임 캡처 시작. 동기 메서드처럼 보이지만 카메라 open은 async라
     * 실제 시작 완료까지 1초 이내 걸린다.
     *
     * mp4 출력 경로는 네이티브가 자동 생성(context.cacheDir/chobo_rec_<ts>.mp4).
     *
     * @return 성공 여부. 실패 시 자원 정리됨.
     */
    fun start(): Boolean {
        Log.i(TAG, "start() called")
        if (isRunning) {
            Log.w(TAG, "already running")
            return false
        }
        outputPath = generateOutputPath()
        lastFrameNanos = 0L

        return try {
            startCameraThread()
            val cameraId = pickBackCameraId() ?: run {
                Log.e(TAG, "no back camera")
                cleanup()
                return false
            }
            val (cameraId2, characteristics) = cameraId
            sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
            Log.i(TAG, "cameraId=$cameraId2 sensorOrientation=$sensorOrientation")

            setupImageReader()
            setupMediaRecorder(outputPath!!)

            openCamera(cameraId2)
            isRunning = true
            true
        } catch (t: Throwable) {
            Log.e(TAG, "start failed", t)
            cleanup()
            false
        }
    }

    /**
     * 녹화 + 캡처 중지. MediaRecorder.stop 후 mp4 경로 반환.
     */
    fun stop(): String? {
        if (!isRunning) return null
        isRunning = false

        val path = outputPath

        // capture session 먼저 중단해야 MediaRecorder.stop이 안전
        try {
            captureSession?.stopRepeating()
            captureSession?.abortCaptures()
        } catch (_: Throwable) {}

        try {
            mediaRecorder?.stop()
        } catch (t: Throwable) {
            Log.w(TAG, "MediaRecorder.stop failed (probably no frames written)", t)
        }

        cleanup()
        return path
    }

    private fun cleanup() {
        try { captureSession?.close() } catch (_: Throwable) {}
        captureSession = null

        try { cameraDevice?.close() } catch (_: Throwable) {}
        cameraDevice = null

        try { imageReader?.close() } catch (_: Throwable) {}
        imageReader = null

        try { mediaRecorder?.reset() } catch (_: Throwable) {}
        try { mediaRecorder?.release() } catch (_: Throwable) {}
        mediaRecorder = null

        try { recorderSurface?.release() } catch (_: Throwable) {}
        recorderSurface = null

        stopCameraThread()
    }

    private fun startCameraThread() {
        cameraThread = HandlerThread("Camera2RecThread").also { it.start() }
        cameraHandler = Handler(cameraThread!!.looper)
    }

    private fun stopCameraThread() {
        cameraThread?.quitSafely()
        try { cameraThread?.join(500) } catch (_: InterruptedException) {}
        cameraThread = null
        cameraHandler = null
    }

    private fun pickBackCameraId(): Pair<String, CameraCharacteristics>? {
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        for (id in mgr.cameraIdList) {
            val ch = mgr.getCameraCharacteristics(id)
            if (ch.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK) {
                return id to ch
            }
        }
        // fallback: 첫 번째 카메라
        val first = mgr.cameraIdList.firstOrNull() ?: return null
        return first to mgr.getCameraCharacteristics(first)
    }

    private fun setupImageReader() {
        val reader = ImageReader.newInstance(TARGET_W, TARGET_H, ImageFormat.YUV_420_888, 2)
        reader.setOnImageAvailableListener({ r ->
            val image = try { r.acquireLatestImage() } catch (_: Throwable) { null } ?: return@setOnImageAvailableListener
            try {
                val nowNs = System.nanoTime()
                val elapsedMs = (nowNs - lastFrameNanos) / 1_000_000L
                if (lastFrameNanos != 0L && elapsedMs < FRAME_INTERVAL_MS) {
                    return@setOnImageAvailableListener
                }
                lastFrameNanos = nowNs

                // landscape 전송 정책: 센서 원본 그대로(rotation=0) 인코딩.
                // 화면 표시는 Flutter 측에서 RotatedBox로 회전해 portrait-fit으로 보여줌.
                val jpeg = FrameEncoderUtil.encodeFromImage(image, 0, JPEG_QUALITY)
                postFrame(jpeg)
            } catch (t: Throwable) {
                Log.w(TAG, "frame encode failed", t)
            } finally {
                try { image.close() } catch (_: Throwable) {}
            }
        }, cameraHandler)
        imageReader = reader
        Log.i(TAG, "ImageReader set up $TARGET_W x $TARGET_H")
    }

    private fun setupMediaRecorder(path: String) {
        // 부모 디렉터리 생성
        val file = File(path)
        file.parentFile?.mkdirs()
        if (file.exists()) file.delete()

        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        rec.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        rec.setOutputFile(path)
        rec.setVideoEncodingBitRate(VIDEO_BITRATE)
        rec.setVideoFrameRate(VIDEO_FPS)
        rec.setVideoSize(TARGET_W, TARGET_H)
        rec.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        // landscape 정책: MP4도 센서 원본 그대로 저장 (rotation hint=0).
        rec.setOrientationHint(0)
        rec.prepare()
        recorderSurface = rec.surface
        mediaRecorder = rec
    }

    private fun openCamera(cameraId: String) {
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        // 권한 체크는 Flutter 측 permission_handler가 이미 통과 보장
        try {
            mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    createSession(device)
                }
                override fun onDisconnected(device: CameraDevice) {
                    Log.w(TAG, "camera disconnected")
                    try { device.close() } catch (_: Throwable) {}
                }
                override fun onError(device: CameraDevice, error: Int) {
                    Log.e(TAG, "camera error: $error")
                    try { device.close() } catch (_: Throwable) {}
                }
            }, cameraHandler)
        } catch (se: SecurityException) {
            Log.e(TAG, "camera permission missing", se)
            cleanup()
        }
    }

    private fun createSession(device: CameraDevice) {
        val ir = imageReader ?: return
        val recSurface = recorderSurface ?: return

        val surfaces = listOf(ir.surface, recSurface)
        Log.i(TAG, "createCaptureSession with ${surfaces.size} surfaces")
        device.createCaptureSession(
            surfaces,
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    Log.i(TAG, "session.onConfigured — starting repeating")
                    captureSession = session
                    startRepeating(session, surfaces)
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "session configure FAILED")
                }
            },
            cameraHandler,
        )
    }

    private fun startRepeating(session: CameraCaptureSession, surfaces: List<Surface>) {
        try {
            val device = cameraDevice ?: return
            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
            for (s in surfaces) builder.addTarget(s)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            session.setRepeatingRequest(builder.build(), null, cameraHandler)
            Log.i(TAG, "setRepeatingRequest issued")
            try {
                mediaRecorder?.start()
                Log.i(TAG, "MediaRecorder.start succeeded")
            } catch (t: Throwable) {
                Log.e(TAG, "MediaRecorder.start failed", t)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startRepeating failed", t)
        }
    }

    private fun generateOutputPath(): String {
        val dir = context.cacheDir
        return File(dir, "chobo_rec_${System.currentTimeMillis()}.mp4").absolutePath
    }

    private fun postFrame(jpeg: ByteArray) {
        val sink = frameSink ?: return
        mainHandler.post {
            try {
                sink.success(jpeg)
            } catch (_: Throwable) {}
        }
    }
}
