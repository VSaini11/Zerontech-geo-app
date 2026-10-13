import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// Thin wrapper over WorkManager so the rest of the code never touches the plugin directly.
class Scheduler {
  static bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init(Function dispatcher) async {
    if (!_supported) return;
    await Workmanager().initialize(dispatcher);
  }

  /// Runs about every 15 minutes even if the app was swiped away or the phone rebooted.
  static Future<void> startHeartbeat() async {
    if (!_supported) return;
    await Workmanager().registerPeriodicTask(
      'geo-heartbeat',
      'heartbeat',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  /// One-off job that waits for a connection, then sends the outbox.
  static Future<void> scheduleFlushWhenOnline() async {
    if (!_supported) return;
    try {
      await Workmanager().registerOneOffTask(
        'geo-flush',
        'flush',
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_supported) return;
    await Workmanager().cancelAll();
  }
}
