import '../core/ids.dart';

class ApiException implements Exception {
  final int status; // 0 = no network / timeout
  final String message;
  ApiException(this.status, this.message);
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

class AppUser {
  final String id;
  final String name;
  final String role;
  AppUser(this.id, this.name, this.role);
  bool get isAdmin => role == 'admin';
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser('${j['id']}', '${j['name']}', '${j['role']}');
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}

class Site {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final List<String> assigned;
  Site({required this.id, required this.name, required this.latitude, required this.longitude, required this.radiusMeters, this.assigned = const []});
  factory Site.fromJson(Map<String, dynamic> j) => Site(
        id: '${j['id']}',
        name: '${j['name']}',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusMeters: ((j['radiusMeters'] ?? 100) as num).toDouble(),
        assigned: ((j['assignedEmployees'] ?? const []) as List).map((e) => '$e').toList(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'latitude': latitude, 'longitude': longitude, 'radiusMeters': radiusMeters, 'assignedEmployees': assigned};
}

class OpenVisit {
  final String locationId;
  final String locationName;
  final int since; // server epoch ms
  final bool stale;
  OpenVisit(this.locationId, this.locationName, this.since, this.stale);
  factory OpenVisit.fromJson(Map<String, dynamic> j) => OpenVisit('${j['locationId']}', '${j['locationName']}', (j['since'] as num).toInt(), j['stale'] == true);
  Map<String, dynamic> toJson() => {'locationId': locationId, 'locationName': locationName, 'since': since, 'stale': stale};
}

class LiveState {
  final int serverTime;
  final OpenVisit? open;
  final int todayMinutes;
  final String todayStatus;
  LiveState(this.serverTime, this.open, this.todayMinutes, this.todayStatus);
  factory LiveState.fromJson(Map<String, dynamic> j) => LiveState(
        (j['serverTime'] as num).toInt(),
        j['open'] == null ? null : OpenVisit.fromJson(Map<String, dynamic>.from(j['open'])),
        ((j['todayMinutes'] ?? 0) as num).toInt(),
        '${j['todayStatus'] ?? 'absent'}',
      );
  Map<String, dynamic> toJson() => {'serverTime': serverTime, 'open': open?.toJson(), 'todayMinutes': todayMinutes, 'todayStatus': todayStatus};
}

class VisitView {
  final String? locationId;
  final String locationName;
  final int start;
  final int end;
  final bool open;
  final bool stale;
  final String? reason;
  final List<String> flags;
  final bool needsReview;
  final int minutes;
  final String note;
  VisitView({this.locationId, required this.locationName, required this.start, required this.end, required this.open, required this.stale, this.reason, required this.flags, required this.needsReview, required this.minutes, this.note = ''});
  factory VisitView.fromJson(Map<String, dynamic> j) => VisitView(
        locationId: j['locationId'] == null ? null : '${j['locationId']}',
        locationName: '${j['locationName'] ?? 'Site'}',
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        open: j['open'] == true,
        stale: j['stale'] == true,
        reason: j['reason'] as String?,
        flags: ((j['flags'] ?? const []) as List).map((e) => '$e').toList(),
        needsReview: j['needsReview'] == true,
        minutes: ((j['minutes'] ?? ((j['end'] - j['start']) / 60000).round()) as num).toInt(),
        note: '${j['note'] ?? ''}',
      );
}

class DayView {
  final String date;
  final int totalMinutes;
  final String status;
  final int checkInCount;
  final bool needsReview;
  final List<VisitView> sessions;
  DayView(this.date, this.totalMinutes, this.status, this.checkInCount, this.needsReview, this.sessions);
  factory DayView.fromJson(Map<String, dynamic> j) => DayView(
        '${j['date']}',
        ((j['totalMinutes'] ?? 0) as num).toInt(),
        '${j['status'] ?? 'absent'}',
        ((j['checkInCount'] ?? 0) as num).toInt(),
        j['needsReview'] == true,
        ((j['sessions'] ?? const []) as List).map((e) => VisitView.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

class OverviewEntry {
  final String id;
  final String name;
  final String status; // inside | outside | unconfirmed
  final String? site;
  final int? since;
  final int todayMinutes;
  final double? lat;
  final double? lng;
  final int? seenAt;
  OverviewEntry({required this.id, required this.name, required this.status, this.site, this.since, required this.todayMinutes, this.lat, this.lng, this.seenAt});
  factory OverviewEntry.fromJson(Map<String, dynamic> j) {
    final k = j['lastKnownLocation'] as Map?;
    return OverviewEntry(
      id: '${j['id']}',
      name: '${j['name']}',
      status: '${j['status']}',
      site: j['site'] as String?,
      since: (j['since'] as num?)?.toInt(),
      todayMinutes: ((j['todayMinutes'] ?? 0) as num).toInt(),
      lat: (k?['latitude'] as num?)?.toDouble(),
      lng: (k?['longitude'] as num?)?.toDouble(),
      seenAt: (k?['updatedAt'] as num?)?.toInt(),
    );
  }
}

class Employee {
  final String id;
  final String name;
  final String role;
  final List<Map<String, String>> sites;
  Employee(this.id, this.name, this.role, this.sites);
  factory Employee.fromJson(Map<String, dynamic> j) => Employee('${j['id']}', '${j['name']}', '${j['role']}',
      ((j['sites'] ?? const []) as List).map((e) => {'id': '${e['id']}', 'name': '${e['name']}'}).toList());
}

/// One fact the phone reports. Immutable, uniquely identified, safe to send any number of times.
class QueuedEvent {
  final String eventId;
  final String type; // ENTER | EXIT | PING
  final String? locationId;
  final int occurredAt;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final bool mock;
  final String source;
  QueuedEvent({String? eventId, required this.type, this.locationId, int? occurredAt, this.lat, this.lng, this.accuracy, this.mock = false, this.source = 'app'})
      : eventId = eventId ?? newEventId(),
        occurredAt = occurredAt ?? DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'type': type,
        if (locationId != null) 'locationId': locationId,
        'occurredAt': occurredAt,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (mock) 'mock': true,
        'source': source,
      };
  factory QueuedEvent.fromJson(Map<String, dynamic> j) => QueuedEvent(
        eventId: '${j['eventId']}',
        type: '${j['type']}',
        locationId: j['locationId'] as String?,
        occurredAt: (j['occurredAt'] as num).toInt(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        mock: j['mock'] == true,
        source: '${j['source'] ?? 'app'}',
      );
}
