package com.choborunner.chobo_runner_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // YUV→JPEG 인코딩용 단발성 채널 (Dart에서 plane 전달 시)
        MethodChannel(messenger, FrameEncoderHandler.CHANNEL)
            .setMethodCallHandler(FrameEncoderHandler())

        // Camera2 네이티브 녹화 + JPEG 스트림
        val camera2Plugin = Camera2RecordingPlugin(applicationContext)
        MethodChannel(messenger, Camera2RecordingPlugin.METHOD_CHANNEL)
            .setMethodCallHandler(camera2Plugin)
        EventChannel(messenger, Camera2RecordingPlugin.EVENT_CHANNEL)
            .setStreamHandler(camera2Plugin)
    }
}
