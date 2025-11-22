buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin necesario para Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {

    // =========================================================
    // 🔥 SOLUCIÓN DEFINITIVA:
    // Desactivar TODO lo relacionado a "shrink" en el proyecto
    // =========================================================
    tasks.configureEach {
        if (name.contains("shrink", ignoreCase = true)) {
            enabled = false
        }
    }

    // =========================================================
    // Mantener el sistema de carpetas que ya tenías
    // =========================================================
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Asegurar que el módulo APP se evalúe primero
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
