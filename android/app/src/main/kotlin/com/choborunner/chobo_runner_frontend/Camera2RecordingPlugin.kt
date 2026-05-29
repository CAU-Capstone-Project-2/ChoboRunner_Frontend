package com.choborunner.chobo_runner_frontend

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Camera2 네이티브 캡처를 Flutter에 노출하는 Plugin.
 *
 *  - MethodChannel `chobo_runner/camera2_recording`
 *    - `start({outputPath: String})` → Boolean (성공 여부)
 *    - `stop()` → String? (저장된 mp4 경로 또는 null)
 *  - EventChannel `chobo_runner/camera2_frames`
 *    - 매 프레임 ByteArray(JPEG) 전송
 */
class Camera2RecordingPlugin(context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "chobo_runner/camera2_recording"
        const val EVENT_CHANNEL = "chobo_runner/camera2_frames"
    }

    private val controller = Camera2RecordingController(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val ok = controller.start()
                result.success(ok)
            }
            "stop" -> {
                val path = controller.stop()
                result.success(path)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        controller.frameSink = events
    }

    override fun onCancel(arguments: Any?) {
        controller.frameSink = null
    }
}
