import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties().also { properties ->
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        propertiesFile.inputStream().use(properties::load)
    }
}

fun signingValue(propertyName: String, environmentName: String): String =
    signingProperties.getProperty(propertyName)?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentName)?.takeIf(String::isNotBlank)
        ?: throw GradleException(
            "Missing release signing value. Set $propertyName in android/key.properties " +
                "or $environmentName in the build environment."
        )

val releaseStoreFile = rootProject.file(
    signingProperties.getProperty("storeFile")?.takeIf(String::isNotBlank)
        ?: System.getenv("NIGOH_RELEASE_STORE_FILE")
        ?: "keystore/nigoh-family-release.p12"
)

if (!releaseStoreFile.isFile) {
    throw GradleException("Production release keystore was not found: ${releaseStoreFile.absolutePath}")
}

android {
    namespace = "tj.nigoh.nigoh_family_parent"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "tj.nigoh.nigoh_family_parent"
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

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = signingValue("storePassword", "NIGOH_RELEASE_STORE_PASSWORD")
            keyAlias = signingValue("keyAlias", "NIGOH_RELEASE_KEY_ALIAS")
            keyPassword = signingValue("keyPassword", "NIGOH_RELEASE_KEY_PASSWORD")
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
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
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
    // Санҷишҳои JVM барои мантиқи тозаи Kotlin (масалан WebFilterDns).
    testImplementation("junit:junit:4.13.2")
}
