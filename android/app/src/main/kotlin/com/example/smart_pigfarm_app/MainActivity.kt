package com.example.smart_pigfarm_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var ezvizCameraPlugin: EzvizCameraPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ezvizCameraPlugin = EzvizCameraPlugin(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            registry = flutterEngine.platformViewsController.registry,
        ).also(lifecycle::addObserver)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ezvizCameraPlugin?.let {
            lifecycle.removeObserver(it)
            it.dispose()
        }
        ezvizCameraPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
