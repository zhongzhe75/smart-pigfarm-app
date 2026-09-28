package com.example.smart_pigfarm_app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class EzvizCameraViewFactory(
    private val messenger: BinaryMessenger,
    private val config: EzvizCameraConfig,
    private val sdkRuntime: EzvizSdkRuntime,
    private val onCreated: (EzvizCameraPlatformView) -> Unit,
    private val onDisposed: (EzvizCameraPlatformView) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return EzvizCameraPlatformView(
            context = context,
            viewId = viewId,
            messenger = messenger,
            config = config,
            sdkRuntime = sdkRuntime,
            onDisposed = onDisposed,
        ).also(onCreated)
    }
}
