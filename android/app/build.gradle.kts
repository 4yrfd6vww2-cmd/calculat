plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Вторая сборка для Android 5.0+: gradle -PoldAndroid=true
val old = project.hasProperty("oldAndroid")

android {
    namespace = "app.neirox"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.neirox"
        minSdk = if (old) 21 else 26
        targetSdk = 34
        versionCode = if (old) 2 else 18
        versionName = if (old) "0.0.2 android 5 build" else "0.10.7 android build"
        buildConfigField("String", "UPDATE_KEY", if (old) "\"android_old\"" else "\"android\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    if (old) {
        lint {
            checkOnly += "NewApi"
            abortOnError = true
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = old
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.03"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("io.getstream:stream-webrtc-android:1.3.8")
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    if (old) coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
