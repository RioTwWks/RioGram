package com.riotwwks.riogram

import android.content.Context
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SystemProxyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.riotwwks.riogram/system_proxy")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSystemProxy" -> result.success(readSystemProxy())
            else -> result.notImplemented()
        }
    }

    private fun readSystemProxy(): Map<String, Any?>? {
        val host = System.getProperty("http.proxyHost")?.trim().orEmpty()
        val portValue = System.getProperty("http.proxyPort")?.trim().orEmpty()
        var port = portValue.toIntOrNull() ?: 0

        if (host.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val globalHost = Settings.Global.getString(context.contentResolver, "http_proxy")
            if (!globalHost.isNullOrBlank() && globalHost.contains(":")) {
                val parts = globalHost.split(":")
                if (parts.size >= 2) {
                    return mapOf(
                        "host" to parts[0],
                        "port" to parts[1].toIntOrNull(),
                        "type" to "http",
                        "username" to "",
                        "password" to "",
                    )
                }
            }
        }

        if (host.isEmpty() || port <= 0) {
            return null
        }

        return mapOf(
            "host" to host,
            "port" to port,
            "type" to "http",
            "username" to "",
            "password" to "",
        )
    }
}
