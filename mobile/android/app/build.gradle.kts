import java.util.Properties

plugins {
    id("com.android.application")
    // Le plugin Flutter doit venir après les plugins Android et Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// La clé de publication vit hors du dépôt : android/key.properties (ignoré
// par git) dit où la trouver. Sans lui, la publication est signée avec la
// clé de débogage, ce qui suffit pour essayer.
val proprietesCle = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}
val clePresente = proprietesCle.containsKey("storeFile")

android {
    namespace = "fr.cybertrist.aesthetic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Notifications locales planifiées : java.time sur les anciens Android.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "fr.cybertrist.aesthetic"
        // Health Connect demande Android 8 au minimum.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (clePresente) {
            create("publication") {
                storeFile = file(proprietesCle.getProperty("storeFile"))
                storePassword = proprietesCle.getProperty("storePassword")
                keyAlias = proprietesCle.getProperty("keyAlias")
                keyPassword = proprietesCle.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (clePresente) "publication" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
