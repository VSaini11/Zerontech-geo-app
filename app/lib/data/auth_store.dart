import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'models.dart';

/// Everything the background isolates need lives here. SharedPreferencesAsync reads straight from
/// disk on every call, so an isolate started while the app is closed never sees stale values.
class AuthStore {
  static final SharedPreferencesAsync _p = SharedPreferencesAsync();

  static Future<String> apiBase() async => (await _p.getString('api_base')) ?? kDefaultApiBase;
  static Future<void> setApiBase(String v) => _p.setString('api_base', v.trim().replaceAll(RegExp(r'/+$'), ''));

  static Future<String?> access() => _p.getString('access');
  static Future<String?> refresh() => _p.getString('refresh');
  static Future<bool> hasSession() async => (await refresh()) != null;

  static Future<void> saveTokens({required String access, required String refresh}) async {
    await _p.setString('access', access);
    await _p.setString('refresh', refresh);
  }

  static Future<void> saveUser(AppUser u) => _p.setString('user', jsonEncode(u.toJson()));
  static Future<AppUser?> user() async {
    final s = await _p.getString('user');
    if (s == null) return null;
    try {
      return AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    for (final k in ['access', 'refresh', 'user', 'sites', 'last_state', 'sites_sig', 'session_expired', 'perm_lost']) {
      await _p.remove(k);
    }
  }

  // Session lost for good (password reset by admin, account deleted). UI shows the login screen.
  static Future<void> markExpired() => _p.setBool('session_expired', true);
  static Future<bool> expired() async => (await _p.getBool('session_expired')) ?? false;
  static Future<void> clearExpired() => _p.remove('session_expired');

  static Future<void> saveSites(List<Site> s) => _p.setString('sites', jsonEncode(s.map((e) => e.toJson()).toList()));
  static Future<List<Site>> sites() async {
    final s = await _p.getString('sites');
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveState(LiveState s) => _p.setString('last_state', jsonEncode(s.toJson()));
  static Future<LiveState?> lastState() async {
    final s = await _p.getString('last_state');
    if (s == null) return null;
    try {
      return LiveState.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> sitesSignature() => _p.getString('sites_sig');
  static Future<void> setSitesSignature(String v) => _p.setString('sites_sig', v);

  // Milliseconds epoch of the last time background code proved it could run (heartbeat health).
  static Future<void> markHeartbeat() => _p.setInt('last_heartbeat', DateTime.now().millisecondsSinceEpoch);
  static Future<int?> lastHeartbeat() => _p.getInt('last_heartbeat');

  static Future<void> setPermLostNotified(bool v) => _p.setBool('perm_lost', v);
  static Future<bool> permLostNotified() async => (await _p.getBool('perm_lost')) ?? false;
}
