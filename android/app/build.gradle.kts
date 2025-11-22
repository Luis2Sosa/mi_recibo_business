import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mi_recibo"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.mi_recibo"
        minSdk = 29
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // =====================================================
    //   CARGAR key.properties
    // =====================================================
    val keystoreProperties = Properties()
    val keystoreFile = rootProject.file("key.properties")

    if (keystoreFile.exists()) {
        keystoreProperties.load(FileInputStream(keystoreFile))
    }

    // =====================================================
    //         FIRMA RELEASE
    // =====================================================
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] ?: "")
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // 🔥 SOLUCIÓN FINAL AL ERROR
            isMinifyEnabled = true
            isShrinkResources = false
        }

        debug { }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}
