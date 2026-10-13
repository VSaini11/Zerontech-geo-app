/// Base URL of the AppSail server. Override at build time:
///   flutter build appbundle --dart-define=API_BASE=https://your-app.catalystappsail.in
const String kDefaultApiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:9000');

const String kPackageForMapTiles = 'com.gnc.geo_app';
const int kHeartbeatMinutes = 15; // Android WorkManager minimum for periodic work
const int kForegroundPingSeconds = 120;
