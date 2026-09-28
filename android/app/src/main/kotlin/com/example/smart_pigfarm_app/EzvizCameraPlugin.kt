package com.example.smart_pigfarm_app

import android.app.Activity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.videogo.openapi.EZOpenSDK
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewRegistry

internal class EzvizCameraPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
    registry: PlatformViewRegistry,
) : DefaultLifecycleObserver, MethodChannel.MethodCallHandler {
    private val config = EzvizCameraConfig.fromBuildConfig()
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val views = linkedSetOf<EzvizCameraPlatformView>()
    private val sdkRuntime = EzvizSdkRuntime(activity, config)

    init {
        channel.setMethodCallHandler(this)
        registry.registerViewFactory(
            VIEW_TYPE,
            EzvizCameraViewFactory(
                messenger = messenger,
                config = config,
                sdkRuntime = sdkRuntime,
                onCreated = views::add,
                onDisposed = views::remove,
            ),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getConfiguration" -> result.success(
                mapOf(
                    "platformSupported" to true,
                    "configured" to config.isConfigured,
                    "missingKeys" to config.missingKeys,
                    "sdkVersion" to SDK_VERSION,
                    "cameraNo" to config.cameraNo,
                ),
            )
            else -> result.notImplemented()
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        views.toList().forEach(EzvizCameraPlatformView::onHostResume)
    }

    override fun onStop(owner: LifecycleOwner) {
        views.toList().forEach(EzvizCameraPlatformView::onHostPause)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        views.toList().forEach(EzvizCameraPlatformView::release)
        views.clear()
    }

    companion object {
        const val CHANNEL_NAME = "com.example.smart_pigfarm_app/ezviz_camera"
        const val VIEW_TYPE = "com.example.smart_pigfarm_app/ezviz_camera_view"
        const val SDK_VERSION = "5.32"
    }
}

internal class EzvizSdkRuntime(
    private val activity: Activity,
    private val config: EzvizCameraConfig,
) {
    @Volatile
    private var initialized = false

    @Synchronized
    fun ensureInitialized(): Boolean {
        if (!config.isConfigured) return false
        if (!initialized) {
            EZOpenSDK.showSDKLog(false)
            EZOpenSDK.initLib(activity.application, config.appKey)
            initialized = true
        }
        EZOpenSDK.getInstance().setAccessToken(config.accessToken)
        return true
    }
}
