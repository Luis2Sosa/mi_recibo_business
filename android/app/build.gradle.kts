import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "lab.sosatech.mi_recibo_business"
    compileSdk = 36       // ← OBLIGATORIO POR LOS PLUGINS
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "lab.sosatech.mi_recibo_business"
        minSdk = flutter.minSdkVersion
        targetSdk = 36    // ← MATCH CON compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystoreProperties = Properties()
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        keystoreProperties.load(FileInputStream(keystoreFile))
    }

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
            isMinifyEnabled = false
            isShrinkResources = false
        }

        debug {
            // firma debug automática
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
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
