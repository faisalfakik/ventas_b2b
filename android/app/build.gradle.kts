// NO es necesario importar JavaCompileOptions aquí

// build.gradle.kts (android/app level) - CORREGIDO OTRA VEZ

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    //id("com.google.firebase.firebase-perf")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gtronic.ventas_b2b"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Correcto

    // Bloque toolchain NO está aquí (Correcto)

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Línea "(options as JavaCompileOptions)..." ELIMINADA
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.gtronic.ventas_b2b"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    signingConfigs {
        getByName("debug") {}
        // TODO: Crear configuración 'release'
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug") // ¡¡Temporal!!
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += listOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/DEPENDENCIES*",
                "META-INF/maven/**",
                "META-INF/proguard/**",
                "META-INF/*.kotlin_module",
                "META-INF/*.version"
            )
        }
    }

    // Configura la ubicación de salida para que coincida con lo que Flutter espera
    buildDir = file("${rootProject.buildDir}/../build/app")

    // Asegura nombres de archivo predecibles para los APKs
    applicationVariants.all {
        val variant = this
        outputs.all {
            if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
                outputFileName = "app-${variant.name}.apk"
            }
        }
    }

    // Configurar la ubicación de salida específicamente para debug
    applicationVariants.all {
        val variant = this
        if (variant.name == "debug") {
            variant.outputs.all {
                if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
                    // Forzar nombre de archivo específico
                    outputFileName = "app-debug.apk"
                    
                    // Agregar una tarea para imprimir información de diagnóstico
                    val taskName = "print${variant.name.capitalize()}OutputPath"
                    project.tasks.register(taskName) {
                        doLast {
                            println("=========== RUTA DE SALIDA DEL APK ===========")
                            println("APK será generado en: ${outputFile.absolutePath}")
                            println("================================================")
                        }
                    }
                    
                    // Hacer que esta tarea se ejecute antes de assembleDebug
                    project.tasks.named("assemble${variant.name.capitalize()}") {
                        dependsOn(taskName)
                    }
                    
                    // Copiar APK a la ruta que Flutter espera
                    val copyTask = "copy${variant.name.capitalize()}ApkToFlutterPath"
                    project.tasks.register(copyTask, Copy::class) {
                        from(outputFile)
                        into("${project.rootDir.parentFile}/build/app/outputs/flutter-apk/")
                        rename { _ -> "app-debug.apk" }
                        
                        doLast {
                            println("=========== APK COPIADO ===========")
                            println("APK copiado a: ${project.rootDir.parentFile}/build/app/outputs/flutter-apk/app-debug.apk")
                            println("====================================")
                        }
                    }
                    
                    // Hacer que la tarea de copia se ejecute después de assembleDebug
                    variant.assembleProvider.get().finalizedBy(copyTask)
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4") // Si lo usas
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")

    implementation(platform("com.google.firebase:firebase-bom:33.1.1"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    //implementation("com.google.firebase:firebase-performance-ktx")
    implementation("com.google.firebase:firebase-functions-ktx")

    implementation("com.google.android.gms:play-services-auth:21.2.0")

    implementation("androidx.multidex:multidex:2.0.1")
}