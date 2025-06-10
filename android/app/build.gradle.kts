plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zerowaste_app"
    compileSdk = 33 // Or flutter.compileSdkVersion if you have it in flutter config
    defaultConfig {
        applicationId = "com.example.zerowaste_app"
        minSdk = 21 // Or flutter.minSdkVersion
        targetSdk = 33 // Or flutter.targetSdkVersion
        versionCode = 1 // Or flutter.versionCode
        versionName = "1.0" // Or flutter.versionName
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Apply the Google services plugin at the bottom
apply(plugin = "com.google.gms.google-services")
