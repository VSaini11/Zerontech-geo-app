# Play Store checklist

- **Background location declaration (Play Console → App content → Sensitive permissions).**
  Core feature: automatic attendance at assigned work sites. Describe it exactly like that, and
  attach a short screen recording showing the in-app disclosure dialog, then the system prompt
  ("Allow all the time"), then a check-in. The disclosure text is already in the app
  (`permission_card.dart`) and appears before the system prompt, as Google requires.
- **Data safety form:** collects precise location (collected, not sold, used for app
  functionality), name/username, shared with the employer only. Data is encrypted in transit
  (HTTPS). Account deletion: provide an employer-contact route or a web page URL.
- **Privacy policy URL** required. It must mention background location and worked-hours records.
- **No battery-optimization exemption request** is used (that permission is restricted by
  Google). The app links to its own settings page instead.
- **Foreground service type:** the geofence plugin's service is only used briefly when an OS
  geofence fires. If Play Console asks, declare "location".
- **Target API:** the Flutter template targets current API levels. Notification permission
  (Android 13+) is requested at runtime.
- **Signing:** `flutter build appbundle --release --dart-define=API_BASE=https://YOUR-APP.catalystappsail.in`
  and upload the `.aab`. Use Play App Signing. Replace the default debug signing in `build.gradle.kts`
  with your keystore first.
- **Internal testing track first.** Background-location apps get a manual review; allow several days.
- Change the package id (`com.gnc.geo_app`) before first upload if you want a different one; it
  cannot change afterwards. Also update it in `permission_card.dart`.
