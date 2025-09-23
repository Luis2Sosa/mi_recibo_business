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
    compileSdk = 36                      // ✅ requerido por google_sign_in_android
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 👇 ESTE applicationId debe ser IGUAL al que uses en Firebase / Google Play
        applicationId = "com.example.mi_recibo"
        minSdk = 29            // ✅ Android 10 (recomendado para MediaStore)
        targetSdk = 36         // ✅ parejo con compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ⚠️ Más adelante agrega tu propia firma para release
            signingConfig = signingConfigs.getByName("debug")
            // Puedes activar minify si firmas con tu keystore:
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            // Opcional: ajustes de debug si los necesitas
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
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}