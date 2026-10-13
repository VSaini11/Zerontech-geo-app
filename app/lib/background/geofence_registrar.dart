import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';
import '../data/auth_store.dart';
import '../data/models.dart';
import 'geofence_callback.dart';

class GeofenceRegistrar {
  static const double minRadius = 100;

  /// Make the OS geofences match the assigned sites. Cheap to call often: it only touches what
  /// differs, and it re-creates any geofence the OS lost (reboot, app data trim, plugin reset).
  static Future<bool> reconcile(List<Site> sites, {bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      final mgr = NativeGeofenceManager.instance;
      await mgr.initialize();
      final registered = (await mgr.getRegisteredGeofenceIds()).toSet();
      final want = sites.map((s) => s.id).toSet();
      final sig = sites.map((s) => '${s.id}|${s.latitude}|${s.longitude}|${max(s.radiusMeters, minRadius)}').join(';');
      final changed = (await AuthStore.sitesSignature()) != sig;

      for (final id in registered.difference(want)) {
        await mgr.removeGeofenceById(id);
      }
      for (final s in sites) {
        final exists = registered.contains(s.id);
        if (exists && !changed && !force) continue;
        if (exists) await mgr.removeGeofenceById(s.id);
        await mgr.createGeofence(
          Geofence(
            id: s.id,
            location: Location(latitude: s.latitude, longitude: s.longitude),
            radiusMeters: max(s.radiusMeters, minRadius),
            triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
            iosSettings: IosGeofenceSettings(initialTrigger: true),
            // initialTriggers: if the phone is already inside when we register, report ENTER now.
            androidSettings: AndroidGeofenceSettings(initialTriggers: {GeofenceEvent.enter}, notificationResponsiveness: const Duration(minutes: 1)),
          ),
          geofenceTriggered,
        );
      }
      await AuthStore.setSitesSignature(sig);
      return true;
    } catch (_) {
      return false; // usually missing "Allow all the time" permission; the UI shows a fix button
    }
  }

  static Future<void> removeAll() async {
    if (kIsWeb) return;
    try {
      await NativeGeofenceManager.instance.initialize();
      await NativeGeofenceManager.instance.removeAllGeofences();
    } catch (_) {}
  }
}
