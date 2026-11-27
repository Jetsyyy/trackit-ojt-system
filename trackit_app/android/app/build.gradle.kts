import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter hands its --dart-define values to Gradle base64-encoded.
// TRACKIT_PORTAL=staff builds the "TrackIT Staff" app for instructors and
// the admin; anything else builds the student "TrackIT" app.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            val pair = String(Base64.getDecoder().decode(encoded)).split("=", limit = 2)
            if (pair.size == 2) pair[0] to pair[1] else null
        }
        ?.toMap()
        ?: emptyMap()
val isStaffApp = dartDefines["TRACKIT_PORTAL"] == "staff"

android {
    namespace = "com.example.trackit_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (isStaffApp) "com.example.trackit_app.staff" else "com.example.trackit_app"
        manifestPlaceholders["appLabel"] = if (isStaffApp) "TrackIT Staff" else "TrackIT"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
