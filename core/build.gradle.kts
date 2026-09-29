import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Logique de comptabilité pure Kotlin : aucune dépendance Android,
// testable avec `./gradlew :core:test`.
plugins {
    alias(libs.plugins.kotlin.jvm)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    testImplementation(libs.kotlin.test)
}
