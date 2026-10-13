import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_store.dart';
import 'models.dart';

class Api {
  static Future<bool>? _refreshing;

  static Future<dynamic> get(String path, {Map<String, String>? query}) => _request('GET', path, query: query);
  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _request('POST', path, body: body ?? {});
  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _request('PUT', path, body: body ?? {});
  static Future<dynamic> delete(String path) => _request('DELETE', path);

  static Future<AppUser> login(String name, String password) async {
    final r = await _request('POST', '/api/auth/login', body: {'name': name, 'password': password}, auth: false);
    await AuthStore.saveTokens(access: r['accessToken'], refresh: r['refreshToken']);
    final u = AppUser.fromJson(Map<String, dynamic>.from(r['user']));
    await AuthStore.saveUser(u);
    await AuthStore.clearExpired();
    return u;
  }

  static Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body, Map<String, String>? query, bool auth = true, bool retried = false}) async {
    final base = await AuthStore.apiBase();
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final headers = {'content-type': 'application/json'};
    if (auth) {
      final t = await AuthStore.access();
      if (t != null) headers['authorization'] = 'Bearer $t';
    }
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw ApiException(0, 'No connection to the server');
    }

    if (res.statusCode == 401 && auth && !retried) {
      // Access token expired (normal after days offline). Trade the refresh token for a new pair.
      final ok = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
      if (ok) return _request(method, path, body: body, query: query, auth: auth, retried: true);
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final msg = (data is Map && data['error'] != null) ? '${data['error']}' : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg);
  }

  /// true = got new tokens. false = refresh token rejected (session really over).
  /// Throws a network ApiException when offline so callers keep the session and retry later.
  static Future<bool> _refresh() async {
    final rt = await AuthStore.refresh();
    if (rt == null) return false;
    final base = await AuthStore.apiBase();
    http.Response res;
    try {
      res = await http
          .post(Uri.parse('$base/api/auth/refresh'), headers: {'content-type': 'application/json'}, body: jsonEncode({'refreshToken': rt}))
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw ApiException(0, 'No connection to the server');
    }
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      await AuthStore.saveTokens(access: j['accessToken'], refresh: j['refreshToken']);
      return true;
    }
    if (res.statusCode == 401) {
      await AuthStore.markExpired();
      return false;
    }
    throw ApiException(res.statusCode, 'Could not refresh session');
  }
}
