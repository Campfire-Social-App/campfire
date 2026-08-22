package com.campfire.campfire

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The one thing Dart cannot do for itself: hold the foreground service
        // a call needs to keep the microphone and to capture the screen at all.
        // See CallService.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sharingScreen = call.argument<Boolean>("screenShare") ?: false
                        CallService.start(applicationContext, sharingScreen)
                        result.success(null)
                    }
                    "stop" -> {
                        CallService.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CALL_SERVICE_CHANNEL = "campfire/call_service"
    }
}
