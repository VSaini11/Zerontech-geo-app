import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models.dart';

class PositionProbe {
  /// One position sample turned into an outbox event. Null if location is off, denied or unavailable.
  static Future<QueuedEvent?> sample({String source = 'heartbeat'}) async {
    if (kIsWeb) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 5) p = last;
      }
      if (p == null) return null;
      return QueuedEvent(type: 'PING', lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, mock: p.isMocked, occurredAt: p.timestamp.millisecondsSinceEpoch, source: source);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> locationUsable() async {
    if (kIsWeb) return true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
