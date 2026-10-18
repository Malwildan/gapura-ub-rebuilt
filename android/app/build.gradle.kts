plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.ac.ub.gapura_ub"
    compileSdk = 36
    // Reuse the installed NDK; the original application's NDK pin is unknown.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.ac.ub.gapura_rebuilt"
        manifestPlaceholders.putAll(mapOf("appAuthRedirectScheme" to "ub.gapura.app"))
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(28, flutter.minSdkVersion)
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Flutter 3.35.3 defaults each build type to all supported ABIs even when
    // --target-platform selects one engine. Filter transitive JNI libraries to
    // that same selection so an ARMv7 APK cannot advertise an absent ARM64 engine.
    // Keep split builds under Flutter's own ABI-split configuration.
    if (project.findProperty("split-per-abi") != "true") {
        val abiForPlatform = mapOf(
            "android-arm" to "armeabi-v7a",
            "android-arm64" to "arm64-v8a",
            "android-x64" to "x86_64",
        )
        val requestedPlatforms = (project.findProperty("target-platform") as? String)
            ?.split(",") ?: abiForPlatform.keys.toList()
        val requestedAbis = requestedPlatforms.map { platform ->
            requireNotNull(abiForPlatform[platform]) { "Unsupported Flutter target: $platform" }
        }
        buildTypes.configureEach {
            ndk.abiFilters.clear()
            ndk.abiFilters.addAll(requestedAbis)
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    constraints {
        // Versions declared in the shipped Gapura 3.3.38 APK, applied only to
        // modules observed in this app's releaseRuntimeClasspath. Constraints
        // do not add dependencies, and higher consumer requirements still win.
        // See NATIVE-DEPENDENCY-ALIGNMENT.md for graph/artifact validation.
        val originalNativeVersions = mapOf(
            // Remote Config now brings this real consumer through Firebase ABT.
            "com.google.firebase:firebase-measurement-connector" to "19.0.0",
            "androidx.annotation:annotation-experimental" to "1.4.1",
            "androidx.appcompat:appcompat" to "1.6.1",
            "androidx.appcompat:appcompat-resources" to "1.6.1",
            "androidx.core:core" to "1.16.0",
            "androidx.core:core-ktx" to "1.16.0",
            "androidx.customview:customview" to "1.1.0",
            "androidx.drawerlayout:drawerlayout" to "1.1.1",
            "androidx.lifecycle:lifecycle-livedata-core-ktx" to "2.8.7",
            "androidx.lifecycle:lifecycle-livedata-core" to "2.8.7",
            "androidx.lifecycle:lifecycle-livedata" to "2.8.7",
            "androidx.lifecycle:lifecycle-process" to "2.8.7",
            "androidx.lifecycle:lifecycle-runtime" to "2.8.7",
            "androidx.lifecycle:lifecycle-viewmodel-savedstate" to "2.8.7",
            "androidx.lifecycle:lifecycle-viewmodel" to "2.8.7",
            "org.jetbrains.kotlinx:kotlinx-coroutines-android" to "1.9.0",
            "org.jetbrains.kotlinx:kotlinx-coroutines-core" to "1.9.0",
        )
        originalNativeVersions.forEach { (module, originalVersion) ->
            add("implementation", "$module:$originalVersion") {
                because("Align an already used native module with the original APK version declaration")
            }
        }
        // These existing modules have no separate original APK version entry.
        // Keep their versions consistent with their published family metadata.
        listOf("lifecycle-common", "lifecycle-common-java8").forEach { module ->
            add("implementation", "androidx.lifecycle:$module:2.8.7") {
                because("Align existing Lifecycle family transitives with Lifecycle 2.8.7")
            }
        }
        listOf("kotlinx-coroutines-core-jvm", "kotlinx-coroutines-bom").forEach { module ->
            add("implementation", "org.jetbrains.kotlinx:$module:1.9.0") {
                because("Align existing Coroutines JVM implementation and BOM with Coroutines 1.9.0")
            }
        }
    }
}
