package com.example.smart_pigfarm_app

internal data class EzvizCameraConfig(
    val appKey: String,
    val accessToken: String,
    val deviceSerial: String,
    val verifyCode: String,
    val cameraNo: Int,
) {
    val missingKeys: List<String>
        get() = buildList {
            if (appKey.isBlank()) add("EZVIZ_APP_KEY")
            if (accessToken.isBlank()) add("EZVIZ_ACCESS_TOKEN")
            if (deviceSerial.isBlank()) add("EZVIZ_DEVICE_SERIAL")
            if (verifyCode.isBlank()) add("EZVIZ_VERIFY_CODE")
        }

    val isConfigured: Boolean
        get() = missingKeys.isEmpty()

    companion object {
        fun fromBuildConfig() = EzvizCameraConfig(
            appKey = BuildConfig.EZVIZ_APP_KEY,
            accessToken = BuildConfig.EZVIZ_ACCESS_TOKEN,
            deviceSerial = BuildConfig.EZVIZ_DEVICE_SERIAL,
            verifyCode = BuildConfig.EZVIZ_VERIFY_CODE,
            cameraNo = BuildConfig.EZVIZ_CAMERA_NO,
        )
    }
}
