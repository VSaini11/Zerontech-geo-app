import 'package:flutter_test/flutter_test.dart';
import 'package:geo_app/core/geo_math.dart';
import 'package:geo_app/core/ids.dart';
import 'package:geo_app/data/models.dart';

void main() {
  test('event ids are unique v4 uuids', () {
    final a = newEventId(), b = newEventId();
    expect(a, isNot(b));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(a), true);
  });
  test('queued event survives a json round trip unchanged (same id => server dedupes)', () {
    final e = QueuedEvent(type: 'ENTER', locationId: 'x', occurredAt: 1700000000000);
    final r = QueuedEvent.fromJson(e.toJson());
    expect(r.eventId, e.eventId);
    expect(r.occurredAt, e.occurredAt);
  });
  test('haversine ~111 km per degree latitude', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 300));
  });
}
