plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Añadir el plugin de Google Services
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.ventas_b2b"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // Actualizado a la versión requerida por los plugins

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        // Añadido freeCompilerArgs para mejorar la compatibilidad
        freeCompilerArgs = listOf("-Xskip-metadata-version-check")
    }

    defaultConfig {
        applicationId = "com.gtronic.ventas_b2b"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Añadido para mejor compatibilidad con las bibliotecas de terceros
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Añadido para resolver conflictos de dependencias
    configurations.all {
        resolutionStrategy {
            force("org.jetbrains.kotlin:kotlin-stdlib:1.8.22")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.22")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Añadir dependencia específica de Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.22")
    
    // Importar el BoM de Firebase - versión compatible
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))

    // Añadir los productos de Firebase que necesitas
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    
    // Añadir soporte para multidex
    implementation("androidx.multidex:multidex:2.0.1")
}
