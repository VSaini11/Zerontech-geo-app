import 'package:workmanager/workmanager.dart';
import '../data/api.dart';
import '../data/auth_store.dart';
import '../data/event_queue.dart';
import '../data/models.dart';
import '../data/sync_service.dart';
import 'geofence_registrar.dart';
import 'notifier.dart';
import 'position_probe.dart';

/// Work that runs about every 15 minutes with the app closed. It is the safety net behind the
/// OS geofences: it re-registers them, proves where the phone is, and empties the outbox.
class Heartbeat {
  static Future<void> run({String source = 'heartbeat'}) async {
    if (!await AuthStore.hasSession()) return;
    await AuthStore.markHeartbeat();

    // 1. Pick up site changes made by the admin, then make the OS geofences match.
    try {
      final cfg = await Api.get('/api/me/config');
      final sites = (cfg['locations'] as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
      await AuthStore.saveSites(sites);
    } catch (_) {}
    await GeofenceRegistrar.reconcile(await AuthStore.sites());

    // 2. Record where the phone is right now.
    final ping = await PositionProbe.sample(source: source);
    if (ping != null) {
      await EventQueue.add(ping);
      await AuthStore.setPermLostNotified(false);
    } else if (!await PositionUsable.ok() && !await AuthStore.permLostNotified()) {
      await AuthStore.setPermLostNotified(true);
      await Notifier.show(2001, 'Location is off', 'Attendance cannot be recorded. Turn on location and choose "Allow all the time".');
    }

    // 3. Send everything that is waiting.
    await SyncService.flush();
  }
}

class PositionUsable {
  static Future<bool> ok() => PositionProbe.locationUsable();
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      if (task == 'flush') {
        await SyncService.flush();
      } else {
        await Heartbeat.run();
      }
    } catch (_) {}
    // Always report success. Returning false would trigger exponential backoff and starve the next run.
    return true;
  });
}
