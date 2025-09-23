buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // No declares AGP aquí (evita conflicto con el que maneja Flutter)
        classpath("com.google.gms:google-services:4.4.2") // ✅ Firebase/Google Services
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
    // Mueve los builds de subproyectos a ../../build/<modulo>
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Asegura que :app se evalúe primero
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}