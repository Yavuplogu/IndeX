plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Une release ne doit jamais être signée silencieusement avec la clé debug.
val releaseKeys = listOf("INDEX_ANDROID_KEYSTORE", "INDEX_ANDROID_STORE_PASSWORD",
    "INDEX_ANDROID_KEY_ALIAS", "INDEX_ANDROID_KEY_PASSWORD")
val releaseSigning = releaseKeys.associateWith { System.getenv(it).orEmpty() }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested && releaseSigning.values.any { it.isBlank() }) {
    throw GradleException("Signature release absente : configurer les variables INDEX_ANDROID_* (guide Lot 6D).")
}

android {
    namespace = "fr.index.index_windows"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.index.index_windows"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigning.values.all { it.isNotBlank() }) {
        signingConfigs.create("distribution") {
            storeFile = file(releaseSigning.getValue("INDEX_ANDROID_KEYSTORE"))
            storePassword = releaseSigning.getValue("INDEX_ANDROID_STORE_PASSWORD")
            keyAlias = releaseSigning.getValue("INDEX_ANDROID_KEY_ALIAS")
            keyPassword = releaseSigning.getValue("INDEX_ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("distribution")
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
