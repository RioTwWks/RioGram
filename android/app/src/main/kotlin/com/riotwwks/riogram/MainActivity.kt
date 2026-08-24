package com.riotwwks.riogram

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SystemProxyPlugin())
        flutterEngine.plugins.add(CallPlatformPlugin())
    }
}
