plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (SEC-020). Release builds are NEVER signed with the debug
// key. Signing comes from android/key.properties (git-ignored), e.g.:
//   storeFile=/absolute/path/to/upload-keystore.jks   (or relative to android/app)
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// Without key.properties a release build fails with an explicit message,
// unless -Pkabso.allowUnsignedRelease=true is passed (CI artifacts that are
// signed later); then the release output is left unsigned.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    java.util.Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }
val hasReleaseSigning = keystorePropertiesFile.exists()
val allowUnsignedRelease =
    (findProperty("kabso.allowUnsignedRelease") as String?)?.toBoolean() == true

fun requiredSigningProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "android/key.properties is missing '$name' (needed to sign release builds).",
        )

android {
    namespace = "com.kabso.kabso_live"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Placeholder application id; the final id is blocker B7 (docs/KNOWN_LIMITATIONS.md).
        applicationId = "com.kabso.kabso_live"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 11 requires API 24+.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Upload key from key.properties, or unsigned. Never the debug key.
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release") else null
        }
    }
}

// Fail every release build early and clearly when no release key is
// configured (instead of producing an unsigned or debug-signed artifact).
val verifyReleaseSigning by tasks.registering {
    doFirst {
        if (!hasReleaseSigning && !allowUnsignedRelease) {
            throw GradleException(
                "Release signing is not configured: create android/key.properties " +
                    "(storeFile, storePassword, keyAlias, keyPassword) or pass " +
                    "-Pkabso.allowUnsignedRelease=true to build an unsigned release. " +
                    "Release builds are never signed with the debug key (SEC-020).",
            )
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(verifyReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
