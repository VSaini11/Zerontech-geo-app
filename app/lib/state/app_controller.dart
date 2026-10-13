import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../background/geofence_registrar.dart';
import '../background/position_probe.dart';
import '../background/scheduler.dart';
import '../config.dart';
import '../core/geo_math.dart';
import '../core/time.dart';
import '../data/api.dart';
import '../data/auth_store.dart';
import '../data/event_queue.dart';
import '../data/models.dart';
import '../data/sync_service.dart';

enum Phase { booting, loggedOut, ready }

class PermHealth {
  final bool serviceOn;
  final bool fine;
  final bool always;
  final bool notifications;
  const PermHealth({this.serviceOn = true, this.fine = false, this.always = false, this.notifications = false});
  bool get allGood => serviceOn && always && notifications;
}

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  Phase phase = Phase.booting;
  AppUser? user;
  List<Site> sites = [];
  LiveState? live;
  DayView? today;
  int serverOffsetMs = 0;
  int pending = 0;
  bool online = true;
  bool syncing = false;
  int? lastSyncAt;
  String? banner;
  PermHealth perms = const PermHealth();
  Position? position;
  StreamSubscription<Position>? _posSub;
  int _lastFgPing = 0;
  bool _foreground = true;

  int serverNow() => DateTime.now().millisecondsSinceEpoch + serverOffsetMs;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    user = await AuthStore.user();
    if (user == null || !await AuthStore.hasSession() || await AuthStore.expired()) {
      phase = Phase.loggedOut;
      notifyListeners();
      return;
    }
    sites = await AuthStore.sites();
    live = await AuthStore.lastState();
    phase = Phase.ready;
    notifyListeners();
    unawaited(_afterLogin());
  }

  Future<void> login(String name, String password, {String? apiBase}) async {
    if (apiBase != null && apiBase.trim().isNotEmpty) await AuthStore.setApiBase(apiBase);
    await EventQueue.clear(); // never let one person's leftovers be uploaded under another account
    user = await Api.login(name.trim(), password);
    sites = [];
    live = null;
    today = null;
    phase = Phase.ready;
    notifyListeners();
    unawaited(_afterLogin());
  }

  Future<void> _afterLogin() async {
    await Scheduler.startHeartbeat();
    await checkPermissions();
    await refreshAll();
    _startForegroundStream();
  }

  Future<void> logout() async {
    await _stopForegroundStream();
    try {
      final p = await PositionProbe.sample(source: 'logout');
      if (p != null) await EventQueue.add(p);
      await SyncService.flush();
    } catch (_) {}
    await Scheduler.cancelAll();
    await GeofenceRegistrar.removeAll();
    await EventQueue.clear();
    await AuthStore.clear();
    user = null;
    sites = [];
    live = null;
    today = null;
    phase = Phase.loggedOut;
    notifyListeners();
  }

  /// The single "bring everything back in line" routine. Runs at login, whenever the app comes to
  /// the front, on pull-to-refresh and from the heartbeat. After days of being closed this is what
  /// repairs state: re-register geofences, report the current position, upload the outbox, then
  /// adopt whatever the server derived.
  Future<void> refreshAll({bool probe = true}) async {
    if (phase != Phase.ready || user == null) return;
    syncing = true;
    notifyListeners();
    try {
      if (await AuthStore.expired()) {
        await _sessionOver();
        return;
      }
      try {
        final cfg = await Api.get('/api/me/config');
        sites = (cfg['locations'] as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
        await AuthStore.saveSites(sites);
        online = true;
      } on ApiException catch (e) {
        if (e.isNetwork) online = false;
        if (e.status == 401) {
          await _sessionOver();
          return;
        }
      }
      if (!user!.isAdmin) {
        await GeofenceRegistrar.reconcile(sites);
        if (probe) {
          final p = await PositionProbe.sample(source: 'resume');
          if (p != null) await EventQueue.add(p);
        }
        final r = await SyncService.flush();
        if (r.ok) {
          online = true;
          lastSyncAt = DateTime.now().millisecondsSinceEpoch;
        } else {
          online = false;
        }
        if (r.state != null) _adopt(r.state!);
        await loadState();
        await loadToday();
      }
    } finally {
      pending = await EventQueue.count();
      syncing = false;
      if (await AuthStore.expired()) await _sessionOver();
      notifyListeners();
    }
  }

  Future<void> _sessionOver() async {
    await Scheduler.cancelAll();
    await GeofenceRegistrar.removeAll();
    user = null;
    phase = Phase.loggedOut;
    banner = 'Your session ended. Please sign in again.';
    notifyListeners();
  }

  void _adopt(LiveState s) {
    live = s;
    serverOffsetMs = s.serverTime - DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> loadState() async {
    try {
      final j = await Api.get('/api/geo/state');
      _adopt(LiveState.fromJson(Map<String, dynamic>.from(j)));
      await AuthStore.saveState(live!);
      online = true;
    } on ApiException catch (e) {
      if (e.isNetwork) online = false;
    }
  }

  Future<void> loadToday() async {
    try {
      today = DayView.fromJson(Map<String, dynamic>.from(await Api.get('/api/geo/day')));
    } on ApiException catch (_) {}
  }

  // ---------- permissions ----------
  Future<void> checkPermissions() async {
    if (kIsWeb) {
      perms = const PermHealth(serviceOn: true, fine: true, always: true, notifications: true);
      notifyListeners();
      return;
    }
    final on = await Geolocator.isLocationServiceEnabled();
    final fine = await Permission.locationWhenInUse.isGranted;
    final always = await Permission.locationAlways.isGranted;
    final notif = await Permission.notification.isGranted;
    perms = PermHealth(serviceOn: on, fine: fine, always: always, notifications: notif);
    notifyListeners();
  }

  Future<void> requestForeground() async {
    await Permission.locationWhenInUse.request();
    await checkPermissions();
  }

  /// Android 11+ sends the user to Settings for "Allow all the time"; there is no in-app dialog.
  Future<void> requestAlways() async {
    await Permission.locationAlways.request();
    await checkPermissions();
    if (perms.always) {
      await GeofenceRegistrar.reconcile(sites, force: true);
      unawaited(refreshAll());
    }
  }

  Future<void> requestNotifications() async {
    await Permission.notification.request();
    await checkPermissions();
  }

  // ---------- foreground live position ----------
  void _startForegroundStream() {
    if (kIsWeb || user == null || user!.isAdmin || _posSub != null || !perms.fine) return;
    _posSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20)).listen((p) async {
      position = p;
      notifyListeners();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastFgPing >= kForegroundPingSeconds * 1000) {
        _lastFgPing = now;
        await EventQueue.add(QueuedEvent(type: 'PING', lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, mock: p.isMocked, occurredAt: p.timestamp.millisecondsSinceEpoch, source: 'foreground'));
        final r = await SyncService.flush();
        online = r.ok;
        if (r.state != null) _adopt(r.state!);
        pending = await EventQueue.count();
        notifyListeners();
      }
    }, onError: (_) {});
  }

  Future<void> _stopForegroundStream() async {
    await _posSub?.cancel();
    _posSub = null;
  }

  /// Nearest assigned site with distance, for the radar card.
  ({Site site, double meters})? nearest() {
    final p = position;
    if (p == null || sites.isEmpty) return null;
    Site? best;
    var bd = double.infinity;
    for (final s in sites) {
      final d = distanceMeters(p.latitude, p.longitude, s.latitude, s.longitude);
      if (d < bd) {
        bd = d;
        best = s;
      }
    }
    return best == null ? null : (site: best, meters: bd);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (phase == Phase.ready) {
        unawaited(() async {
          await checkPermissions();
          await refreshAll();
          _startForegroundStream();
        }());
      }
    } else if (state == AppLifecycleState.paused) {
      _foreground = false;
      unawaited(_stopForegroundStream());
    }
  }

  bool get isForeground => _foreground;
}
