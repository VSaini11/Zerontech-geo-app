import 'package:native_geofence/native_geofence.dart';
import '../data/auth_store.dart';
import '../data/event_queue.dart';
import '../data/models.dart';
import '../data/sync_service.dart';
import 'notifier.dart';

/// Entry point the Android OS calls when the phone crosses a geofence, even when the app was
/// swiped away. It does the minimum that cannot be redone later: write the fact to disk.
/// Sending it is a separate, retryable step, so a missing network can never lose a check-in.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  try {
    final enter = params.event == GeofenceEvent.enter;
    final exit = params.event == GeofenceEvent.exit;
    if (!enter && !exit) return;
    if (!await AuthStore.hasSession()) return;
    final sites = await AuthStore.sites();
    final loc = params.location;
    for (final g in params.geofences) {
      await EventQueue.add(QueuedEvent(type: enter ? 'ENTER' : 'EXIT', locationId: g.id, lat: loc?.latitude, lng: loc?.longitude, source: 'os_geofence'));
      var name = 'the site';
      for (final s in sites) {
        if (s.id == g.id) name = s.name;
      }
      await Notifier.show(enter ? 1001 : 1002, enter ? 'Checked in' : 'Checked out', enter ? 'You arrived at $name.' : 'You left $name.');
    }
    await SyncService.flush();
  } catch (_) {
    // Nothing useful to do in a headless isolate; the next heartbeat will reconcile.
  }
}
