// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Actualizar a la versión más reciente estable de Google Services
        classpath("com.google.gms:google-services:4.4.0")
        // Añadir classpath para crashlytics si lo usas
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Añadir repositorio de jitpack si usas algunas bibliotecas específicas
        maven { url = uri("https://jitpack.io") }
    }
}

// Configuración de directorios de compilación personalizada
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Configuración común para todos los subproyectos
    afterEvaluate {
        if (project.hasProperty("android")) {
            // Configuraciones comunes para proyectos Android
            project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileSdkVersion(34)

                defaultConfig {
                    // Usar propiedades en lugar de métodos deprecados
                    minSdk = 23
                    targetSdk = 34
                }
                
                // Habilitar buildConfig explícitamente
                buildFeatures.apply {
                    buildConfig = true
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
