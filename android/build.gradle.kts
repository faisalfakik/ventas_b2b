import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile // Necesario importar JavaCompile

// android/build.gradle.kts (Archivo de Nivel de Proyecto - VERSIÓN COMPLETA Y CORREGIDA)

buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // --- Plugins Esenciales para la Construcción ---
        // classpath("com.android.tools.build:gradle:8.6.0") // <-- LÍNEA ELIMINADA
        // classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0") // <-- LÍNEA ELIMINADA
        classpath("com.google.gms:google-services:4.4.2")            // Mantenida
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2") // Mantenida
        //classpath("com.google.firebase:firebase-perf-plugin:1.4.1")
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }

    // --- ESTE BLOQUE DEBE ESTAR AQUÍ DENTRO ---
    // Aplica opciones de compilación Java/Kotlin a todos los subproyectos (plugins)
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_17.toString()
        }
    }
    // --- FIN DEL BLOQUE ---
}

// Tarea 'clean' estándar de Gradle
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
