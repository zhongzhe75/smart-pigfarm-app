import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use(::load)
    }
}

fun localPropertyAsBuildConfigString(name: String): String {
    val value = localProperties.getProperty(name, "").trim()
    val escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
    return "\"$escaped\""
}

android {
    namespace = "com.example.smart_pigfarm_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.smart_pigfarm_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField(
            "String",
            "EZVIZ_APP_KEY",
            localPropertyAsBuildConfigString("EZVIZ_APP_KEY"),
        )
        buildConfigField(
            "String",
            "EZVIZ_ACCESS_TOKEN",
            localPropertyAsBuildConfigString("EZVIZ_ACCESS_TOKEN"),
        )
        buildConfigField(
            "String",
            "EZVIZ_DEVICE_SERIAL",
            localPropertyAsBuildConfigString("EZVIZ_DEVICE_SERIAL"),
        )
        buildConfigField(
            "String",
            "EZVIZ_VERIFY_CODE",
            localPropertyAsBuildConfigString("EZVIZ_VERIFY_CODE"),
        )
        buildConfigField("int", "EZVIZ_CAMERA_NO", "1")

        // EZVIZ SDK 5.32 ships native libraries for ARM only. Restrict the APK
        // to the ABIs that contain the complete player runtime.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("io.github.ezviz-open:ezviz-sdk:5.32")
    implementation("com.squareup.okhttp3:okhttp:3.12.13")
    implementation("com.google.code.gson:gson:2.11.0")
}
