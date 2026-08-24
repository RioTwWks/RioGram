package com.riotwwks.riogram

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CallPlatformPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: android.content.Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "riogram/call_platform")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startActiveCall" -> {
                val title = call.argument<String>("title") ?: "RioGram"
                CallForegroundService.start(appContext, title)
                result.success(null)
            }
            "stopActiveCall", "endActiveCall" -> {
                CallForegroundService.stop(appContext)
                result.success(null)
            }
            "reportIncomingCall", "setCallConnected" -> {
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
