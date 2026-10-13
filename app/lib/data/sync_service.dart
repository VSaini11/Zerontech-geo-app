import '../background/scheduler.dart';
import 'api.dart';
import 'auth_store.dart';
import 'event_queue.dart';
import 'models.dart';

class FlushResult {
  final bool ok;
  final int sent;
  final LiveState? state;
  final String? error;
  FlushResult({required this.ok, this.sent = 0, this.state, this.error});
}

class SyncService {
  static bool _busy = false;

  /// Send everything in the outbox. Safe to call from any isolate at any time, any number of
  /// times: the server de-duplicates on eventId, so a retry after a half-finished send is harmless.
  static Future<FlushResult> flush() async {
    if (_busy) return FlushResult(ok: true);
    if (!await AuthStore.hasSession()) return FlushResult(ok: true, error: 'signed out');
    _busy = true;
    try {
      LiveState? state;
      var sent = 0;
      while (true) {
        final items = await EventQueue.list(limit: 100);
        if (items.isEmpty) break;
        try {
          final r = await Api.post('/api/geo/events', {
            'deviceSentAt': DateTime.now().millisecondsSinceEpoch, // lets the server correct a wrong phone clock
            'events': items.map((e) => e.toJson()).toList(),
          });
          await EventQueue.remove(items);
          sent += items.length;
          if (r['state'] != null) state = LiveState.fromJson(Map<String, dynamic>.from(r['state']));
        } on ApiException catch (e) {
          if (e.isNetwork || e.status >= 500 || e.status == 408 || e.status == 429) rethrow;
          if (e.status == 401) rethrow;
          await EventQueue.remove(items); // 4xx other than 401 will never succeed; do not block the queue
        }
        if (items.length < 100) break;
      }
      if (state != null) await AuthStore.saveState(state);
      return FlushResult(ok: true, sent: sent, state: state);
    } on ApiException catch (e) {
      if (e.isNetwork || e.status >= 500) await Scheduler.scheduleFlushWhenOnline();
      return FlushResult(ok: false, error: e.message);
    } finally {
      _busy = false;
    }
  }
}
