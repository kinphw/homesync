import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 정보 로드. 비밀번호는 프로젝트 루트의 .env (KEYSTORE_PW) 에서 읽는다.
// 경로/별칭은 비밀이 아니므로 기본값을 두되, .env 로 덮어쓸 수 있다.
val envProperties = Properties()
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    envFile.inputStream().use { envProperties.load(it) }
}
val keystorePw: String? = (envProperties["KEYSTORE_PW"] as String?)?.trim()
val keystorePath: String =
    (envProperties["KEYSTORE_FILE"] as String?)?.trim()
        ?: "C:/projects/lawquery-twa/android.keystore"
val keystoreAlias: String =
    (envProperties["KEY_ALIAS"] as String?)?.trim() ?: "android"
val hasReleaseKey = !keystorePw.isNullOrEmpty()

android {
    namespace = "com.sncmlife.homesync"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sncmlife.homesync"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth/Firestore 요구사항에 맞춰 최소 23으로 고정
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // .env 에 KEYSTORE_PW 가 있을 때만 release 서명 구성을 만든다.
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = keystorePw
                keyAlias = keystoreAlias
                keyPassword = keystorePw
            }
        }
    }

    buildTypes {
        release {
            // .env 에 키 정보가 있으면 release 키로, 없으면 debug 키로 서명.
            signingConfig = if (hasReleaseKey)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
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
