# Gradle changes (android/app/build.gradle.kts)

1. Inside `android { compileOptions { ... } }`:
   ```kotlin
   isCoreLibraryDesugaringEnabled = true
   sourceCompatibility = JavaVersion.VERSION_17
   targetCompatibility = JavaVersion.VERSION_17
   ```
   and `kotlinOptions { jvmTarget = "17" }` (or `compilerOptions` on newer templates).
2. In `defaultConfig`: `minSdk = 24`.
3. At the bottom:
   ```kotlin
   dependencies {
       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   }
   ```
If `flutter run` complains about compileSdk or AGP, follow the message: raise `compileSdk` to 36.
