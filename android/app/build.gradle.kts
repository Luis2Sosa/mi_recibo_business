plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-kapt") // Procesadores de anotaciones
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase Services
}

android {
    namespace = "com.example.mi_recibo" // 👈 cámbialo si en Firebase usas otro nombre de paquete
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 👈 ESTE applicationId debe ser IGUAL al que pongas en Firebase
        applicationId = "com.example.mi_recibo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ⚠️ Más adelante agrega tu propia firma para release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BOM para manejar versiones
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // Firebase básicos
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.2.0") // 👈 YA AGREGADO
}
