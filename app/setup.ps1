# Run from the geo-app\app folder in PowerShell:  .\setup.ps1
$ErrorActionPreference = "Stop"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Write-Error "Flutter not found on PATH"; exit 1 }

# 1. Generate the android/ios folders (keeps existing lib/ and pubspec.yaml)
flutter create --org com.gnc --project-name geo_app --platforms=android,ios .
flutter pub get

# 2. Patch the Android manifest
$mf = "android\app\src\main\AndroidManifest.xml"
$x = Get-Content $mf -Raw
if ($x -notmatch "NativeGeofenceBroadcastReceiver") {
  $perms = @'
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
'@
  $comps = @'
        <receiver android:name="com.chunkytofustudios.native_geofence.receivers.NativeGeofenceBroadcastReceiver" android:enabled="true" android:exported="true" />
        <receiver android:name="com.chunkytofustudios.native_geofence.receivers.NativeGeofenceRebootBroadcastReceiver" android:enabled="true" android:exported="true">
            <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED" /></intent-filter>
        </receiver>
        <service android:name="com.chunkytofustudios.native_geofence.NativeGeofenceForegroundService" android:enabled="true" android:exported="true" android:permission="android.permission.BIND_JOB_SERVICE" />
'@
  $x = $x -replace "(<manifest[^>]*>)", "`$1`n$perms"
  $x = $x -replace "(</application>)", "$comps`$1"
  $x = $x -replace 'android:label="[^"]*"', 'android:label="Geo Attendance"'
  Set-Content $mf $x -Encoding UTF8
  Write-Host "Manifest patched."
}

# 3. Patch Gradle (Kotlin DSL)
$g = "android\app\build.gradle.kts"
if (Test-Path $g) {
  $s = Get-Content $g -Raw
  if ($s -notmatch "coreLibraryDesugaring") {
    $s = $s -replace "(compileOptions\s*\{)", "`$1`n        isCoreLibraryDesugaringEnabled = true"
    $s = $s -replace "minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24"
    $s += "`ndependencies {`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs:2.1.4`")`n}`n"
    Set-Content $g $s -Encoding UTF8
    Write-Host "Gradle patched."
  }
} else { Write-Warning "build.gradle.kts not found; apply platform_setup\gradle_changes.md by hand." }

Write-Host "Done. Set your server address: flutter run --dart-define=API_BASE=https://YOUR-APP.catalystappsail.in"
