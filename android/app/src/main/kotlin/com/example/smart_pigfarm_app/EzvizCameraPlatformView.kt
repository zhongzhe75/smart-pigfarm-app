package com.example.smart_pigfarm_app

import android.content.Context
import android.graphics.SurfaceTexture
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.Log
import android.view.TextureView
import android.view.View
import com.videogo.errorlayer.ErrorInfo
import com.videogo.openapi.EZConstants
import com.videogo.openapi.EZOpenSDK
import com.videogo.openapi.EZPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class EzvizCameraPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val config: EzvizCameraConfig,
    private val sdkRuntime: EzvizSdkRuntime,
    private val onDisposed: (EzvizCameraPlatformView) -> Unit,
) : PlatformView, MethodChannel.MethodCallHandler, TextureView.SurfaceTextureListener {
    private val textureView = TextureView(context).apply {
        surfaceTextureListener = this@EzvizCameraPlatformView
    }
    private val channel = MethodChannel(
        messenger,
        "${EzvizCameraPlugin.CHANNEL_NAME}/view/$viewId",
    )
    private val playerHandler = Handler(Looper.getMainLooper(), ::handlePlayerMessage)

    private var player: EZPlayer? = null
    private var surfaceTexture: SurfaceTexture? = null
    private var boundSurfaceTexture: SurfaceTexture? = null
    private var surfaceReady = false
    private var startRequested = false
    private var pausedByHost = false
    private var released = false
    private var currentStatus = "initializing"
    private var lastErrorCode: Int? = null
    private var lastError: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun getView(): View = textureView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(statePayload())
            "start", "retry" -> {
                startRequested = true
                pausedByHost = false
                startIfReady()
                result.success(null)
            }
            "pause" -> {
                pausedByHost = true
                stopPlayer()
                result.success(null)
            }
            "resume" -> {
                if (startRequested) {
                    pausedByHost = false
                    startIfReady()
                }
                result.success(null)
            }
            "release" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        Log.i(TAG, "surface lifecycle=available width=$width height=$height")
        surfaceTexture = surface
        surfaceReady = true
        startIfReady()
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
        Log.i(TAG, "surface lifecycle=sizeChanged width=$width height=$height")
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        Log.i(TAG, "surface lifecycle=destroyed width=${textureView.width} height=${textureView.height}")
        surfaceReady = false
        surfaceTexture = null
        boundSurfaceTexture = null
        stopPlayer()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    fun onHostPause() {
        if (startRequested) {
            pausedByHost = true
            stopPlayer()
        }
    }

    fun onHostResume() {
        if (startRequested && !released) {
            pausedByHost = false
            startIfReady()
        }
    }

    private fun startIfReady() {
        if (released || pausedByHost || !startRequested || !surfaceReady) return
        if (!config.isConfigured) {
            emitStatus("unconfigured")
            return
        }
        if (!sdkRuntime.ensureInitialized()) {
            emitStatus("error", -1, "萤石 SDK 初始化失败")
            return
        }

        val activeSurface = surfaceTexture ?: return
        val activePlayer = player ?: EZOpenSDK.getInstance()
            .createPlayer(config.deviceSerial, config.cameraNo)
            .also {
                player = it
                it.setHandler(playerHandler)
                it.setPlayVerifyCode(config.verifyCode)
            }

        activePlayer.stopRealPlay()
        val reusingBoundSurface = boundSurfaceTexture === activeSurface
        val surfaceBound = reusingBoundSurface || activePlayer.setSurfaceEx(activeSurface)
        if (surfaceBound) {
            boundSurfaceTexture = activeSurface
        }
        Log.i(
            TAG,
            "setSurfaceEx result=$surfaceBound reused=$reusingBoundSurface " +
                "width=${textureView.width} height=${textureView.height}",
        )
        if (!surfaceBound) {
            emitStatus("error", SURFACE_BIND_FAILED, "视频显示 Surface 绑定失败")
            return
        }
        emitStatus("connecting")
        val started = activePlayer.startRealPlay()
        Log.i(TAG, "EZPlayer state=startRealPlay result=$started")
        if (!started) {
            emitStatus("error", -2, "播放器未能启动实时预览")
        }
    }

    private fun stopPlayer() {
        val stopped = player?.stopRealPlay()
        Log.i(TAG, "EZPlayer state=stopRealPlay result=${stopped ?: false}")
        textureView.keepScreenOn = false
    }

    private fun handlePlayerMessage(message: Message): Boolean {
        if (released) return true
        when (message.what) {
            EZConstants.EZRealPlayConstants.MSG_REALPLAY_CONNECTION_START,
            EZConstants.EZRealPlayConstants.MSG_REALPLAY_CONNECTION_SUCCESS,
            EZConstants.EZRealPlayConstants.MSG_REALPLAY_PLAY_START,
            -> {
                Log.i(TAG, "EZPlayer state=${message.what}")
                emitStatus("connecting")
            }

            EZConstants.EZRealPlayConstants.MSG_REALPLAY_PLAY_SUCCESS -> {
                player?.closeSound()
                textureView.keepScreenOn = true
                Log.i(TAG, "EZPlayer state=playSuccess decoderType=${player?.decodeType ?: -1}")
                emitStatus("playing")
            }

            EZConstants.EZRealPlayConstants.MSG_REALPLAY_PLAY_FAIL -> {
                val errorCode = (message.obj as? ErrorInfo)?.errorCode ?: message.arg1
                Log.e(TAG, "EZPlayer state=playFail errorCode=$errorCode")
                emitPlayerError(errorCode)
            }

            EZConstants.EZRealPlayConstants.MSG_REALPLAY_PASSWORD_ERROR,
            EZConstants.EZRealPlayConstants.MSG_REALPLAY_ENCRYPT_PASSWORD_ERROR,
            -> {
                Log.e(TAG, "EZPlayer state=passwordError errorCode=$VERIFY_CODE_INCORRECT")
                emitStatus(
                    "verifyCodeRequired",
                    VERIFY_CODE_INCORRECT,
                    errorMeaning(VERIFY_CODE_INCORRECT),
                )
            }
        }
        return true
    }

    private fun emitPlayerError(errorCode: Int) {
        val status = when (errorCode) {
            110002, 110003, 110018 -> "tokenExpired"
            120006, 120007, 120008, 395452, 395544 -> "offline"
            120010, 400035, 400036, 400041 -> "verifyCodeRequired"
            else -> "error"
        }
        emitStatus(status, errorCode, errorMeaning(errorCode))
    }

    private fun errorMeaning(errorCode: Int): String = when (errorCode) {
        110002 -> "AccessToken 无效"
        110003 -> "AccessToken 已过期"
        110018 -> "AccessToken 与 AppKey 不匹配"
        120006 -> "设备网络异常"
        120007 -> "设备离线"
        120008 -> "设备响应超时"
        120010 -> "设备验证码错误"
        395452 -> "连接视频流服务器失败"
        395544 -> "设备无视频源"
        400035 -> "需要设备视频验证码"
        400036 -> "设备视频验证码不匹配"
        400041 -> "视频解码超时，请检查设备验证码"
        -1 -> "萤石 SDK 初始化失败"
        -2 -> "播放器未能启动实时预览"
        else -> "萤石播放器错误"
    }

    private fun emitStatus(status: String, errorCode: Int? = null, error: String? = null) {
        currentStatus = status
        lastErrorCode = errorCode
        lastError = errorCode?.let { "SDK 错误 $it：${error ?: errorMeaning(it)}" }
        channel.invokeMethod("status", statePayload())
    }

    private fun statePayload(): Map<String, Any?> = mapOf(
        "status" to currentStatus,
        "errorCode" to lastErrorCode,
        "lastError" to lastError,
    )

    override fun dispose() {
        release()
    }

    fun release() {
        if (released) return
        released = true
        startRequested = false
        textureView.surfaceTextureListener = null
        textureView.keepScreenOn = false
        surfaceReady = false
        surfaceTexture = null
        boundSurfaceTexture = null
        player?.let {
            it.stopRealPlay()
            it.setHandler(null)
            it.release()
        }
        player = null
        playerHandler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
        onDisposed(this)
    }

    companion object {
        private const val TAG = "EzvizVideo"
        private const val VERIFY_CODE_INCORRECT = 400036
        private const val SURFACE_BIND_FAILED = -3
    }
}
