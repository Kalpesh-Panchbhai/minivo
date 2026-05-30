import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// ── Upload-keystore credentials ─────────────────────────────────────────
// Loaded from android/key.properties (gitignored). When the file is
// absent (e.g. CI without secrets), release falls back to debug signing
// so `flutter build` still works locally for inspection.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.puzzloragames.dropzy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.puzzloragames.dropzy"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ── Flavors: `dev` for local runs, `prod` for store uploads ─────────────
    // Same applicationId for both — Firebase credentials and AdMob unit IDs
    // are selected at the Dart level via main_dev.dart / main_prod.dart.
    // The AdMob *App ID* (manifest meta-data) does need a per-flavor value
    // since it's read by the Mobile Ads SDK from the manifest at startup.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            // Google's official test App ID — safe for dev builds.
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["admobAppId"] = "ca-app-pub-6010707433076438~1574283221"
        }
    }
}

flutter {
    source = "../.."
}
