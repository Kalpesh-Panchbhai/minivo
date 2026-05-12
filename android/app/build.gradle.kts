plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
