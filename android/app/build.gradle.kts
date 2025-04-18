plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Añadir el plugin de Google Services
    id("com.google.gms.google-services")
}

repositories {
    google()
    mavenCentral()
}

android {
    // Corregir para que coincida con applicationId
    namespace = "com.gtronic.ventas_b2b"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Versión requerida por los plugins

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
        // Mejorar la compatibilidad con opciones avanzadas
        freeCompilerArgs = listOf(
            "-Xskip-metadata-version-check",
            "-Xjvm-default=all",
            "-Xopt-in=kotlin.RequiresOptIn"
        )
    }

    defaultConfig {
        applicationId = "com.gtronic.ventas_b2b"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Añadir soporte para vectores
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
        }

        getByName("release") {
            isMinifyEnabled = true
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Usando la forma moderna de lint
    lint {
        disable += listOf(
            "InvalidPackage",
            "GradleDependency",
            "ObsoleteSdkInt",
            "NamespaceDeclaration",
            "FirebaseStorageLocation"
        )
        warningsAsErrors = false
        checkReleaseBuilds = false
    }

    // Usando la forma moderna de packaging
    packaging {
        resources {
            excludes += listOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/DEPENDENCIES",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/proguard/**",
                "META-INF/*.kotlin_module",
                "META-INF/*.version"
            )
        }
    }

    // Resolución de dependencias mejorada
    configurations.all {
        resolutionStrategy {
            // Kotlin
            force("org.jetbrains.kotlin:kotlin-stdlib:1.8.10")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.10")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.10")
            force("org.jetbrains.kotlin:kotlin-stdlib-common:1.8.10")
            force("org.jetbrains.kotlin:kotlin-bom:1.8.10")

            // AndroidX
            force("androidx.core:core-ktx:1.10.1")
            force("androidx.activity:activity:1.7.2")
            force("androidx.annotation:annotation:1.5.0")
            force("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")
            force("androidx.multidex:multidex:2.0.1")

            // Evitar conflictos de versiones
            failOnVersionConflict()

            // Cacheo para mejorar la compilación
            cacheDynamicVersionsFor(10, "minutes")
            cacheChangingModulesFor(24, "hours")
        }
    }

    // Configuración de la característica buildConfig
    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring para compatibilidad con versiones antiguas de Android
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.10")
    implementation("org.jetbrains.kotlin:kotlin-reflect:1.8.10")

    // AndroidX
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")

    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("com.google.firebase:firebase-performance")

    // Google Play Services
    implementation("com.google.android.gms:play-services-auth:20.7.0")

    // Multidex para soporte en API 19+
    implementation("androidx.multidex:multidex:2.0.1")

    // Soporte de ventanas para Flutter
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}