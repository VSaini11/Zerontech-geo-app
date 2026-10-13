import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Durable outbox. One small file per event, written atomically (tmp + rename), so an event is
/// never lost if the process is killed mid-write and two isolates never overwrite each other.
class EventQueue {
  static final List<QueuedEvent> _mem = []; // web preview only

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/geo_queue');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<void> add(QueuedEvent e) async {
    if (kIsWeb) {
      _mem.add(e);
      return;
    }
    final d = await _dir();
    final name = '${e.occurredAt.toString().padLeft(15, '0')}_${e.eventId}';
    final tmp = File('${d.path}/$name.tmp');
    await tmp.writeAsString(jsonEncode(e.toJson()), flush: true);
    await tmp.rename('${d.path}/$name.json');
  }

  static Future<List<QueuedEvent>> list({int limit = 100}) async {
    if (kIsWeb) return _mem.take(limit).toList();
    final d = await _dir();
    final files = (await d.list().toList()).whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final out = <QueuedEvent>[];
    for (final f in files.take(limit)) {
      try {
        out.add(QueuedEvent.fromJson(Map<String, dynamic>.from(jsonDecode(await f.readAsString()))));
      } catch (_) {
        try {
          await f.delete(); // unreadable file can never be sent; do not block the queue
        } catch (_) {}
      }
    }
    return out;
  }

  static Future<void> remove(Iterable<QueuedEvent> events) async {
    if (kIsWeb) {
      _mem.removeWhere((m) => events.any((e) => e.eventId == m.eventId));
      return;
    }
    final d = await _dir();
    for (final e in events) {
      final f = File('${d.path}/${e.occurredAt.toString().padLeft(15, '0')}_${e.eventId}.json');
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  static Future<int> count() async {
    if (kIsWeb) return _mem.length;
    final d = await _dir();
    return (await d.list().toList()).where((f) => f.path.endsWith('.json')).length;
  }

  static Future<void> clear() async {
    if (kIsWeb) {
      _mem.clear();
      return;
    }
    final d = await _dir();
    await for (final f in d.list()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
