import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

import 'report_export_screen.dart';

class EmployeeDetail extends StatefulWidget {
  final String name;
  const EmployeeDetail({super.key, required this.name});
  @override
  State<EmployeeDetail> createState() => _EmployeeDetailState();
}

class _EmployeeDetailState extends State<EmployeeDetail> {
  Map<String, dynamic>? _data;
  List<Site> _sites = [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _data = Map<String, dynamic>.from(await Api.get('/api/admin/employee/${Uri.encodeComponent(widget.name)}'));
      _sites = ((await Api.get('/api/locations')) as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
      _err = null;
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _adjust(String action, int start, int end, {String? locationId}) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'void' ? 'Remove this time?' : 'Add time'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${fmtTime(start)} – ${fmtTime(end)} for ${widget.name}'),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Reason (kept in the audit log)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('/api/admin/adjust', {'userName': widget.name, 'action': action, 'start': start, 'end': end, 'locationId': locationId, 'note': note.text});
      await _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _addManual() async {
    final now = DateTime.now();
    final t1 = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0), helpText: 'Start time (today)');
    if (t1 == null || !mounted) return;
    final t2 = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0), helpText: 'End time (today)');
    if (t2 == null) return;
    final s = DateTime(now.year, now.month, now.day, t1.hour, t1.minute).millisecondsSinceEpoch;
    final e = DateTime(now.year, now.month, now.day, t2.hour, t2.minute).millisecondsSinceEpoch;
    if (e <= s) {
      if (mounted) toast(context, 'End must be after start');
      return;
    }
    await _adjust('add', s, e, locationId: _sites.isNotEmpty ? _sites.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final today = d == null ? null : DayView.fromJson(Map<String, dynamic>.from(d['today']));
    final k = d?['user']?['lastKnownLocation'] as Map?;
    final pos = k == null ? null : LatLng((k['latitude'] as num).toDouble(), (k['longitude'] as num).toDouble());
    final accuracy = k == null ? null : (k['accuracy'] as num?)?.toDouble() ?? 15.0;
    final updatedAt = k == null ? null : (k['updatedAt'] as num?)?.toInt();
    final center = pos ?? (_sites.isNotEmpty ? LatLng(_sites.first.latitude, _sites.first.longitude) : const LatLng(20.5937, 78.9629));

    // Determine if signal is active or last-synced fallback
    final now = DateTime.now().millisecondsSinceEpoch;
    final isRecent = updatedAt != null && (now - updatedAt) < 45 * 60 * 1000; // <45 mins

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Export Employee Attendance',
            icon: const Icon(Icons.file_download, color: kBrand),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportExportScreen(
                    initialUser: widget.name,
                    employeeNames: [widget.name],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addManual, icon: const Icon(Icons.add), label: const Text('Add time')),
      body: d == null
          ? Center(child: _err == null ? const CircularProgressIndicator() : Text(_err!, style: const TextStyle(color: kRed)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                // Map Container with clear Pin, GPS Accuracy radius and status badge
                Card(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 280,
                          child: Stack(
                            children: [
                              FlutterMap(
                                options: MapOptions(initialCenter: center, initialZoom: pos != null ? 16 : 14),
                                children: [
                                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: kPackageForMapTiles),
                                  // Geofence Work Sites
                                  CircleLayer(circles: [
                                    for (final s in _sites)
                                      CircleMarker(
                                        point: LatLng(s.latitude, s.longitude),
                                        radius: s.radiusMeters,
                                        useRadiusInMeter: true,
                                        color: kBrand.withValues(alpha: 0.12),
                                        borderColor: kBrand,
                                        borderStrokeWidth: 2,
                                      ),
                                    // GPS accuracy circle around employee's exact pin
                                    if (pos != null && accuracy != null)
                                      CircleMarker(
                                        point: pos,
                                        radius: accuracy,
                                        useRadiusInMeter: true,
                                        color: (isRecent ? kGreen : kAmber).withValues(alpha: 0.18),
                                        borderColor: isRecent ? kGreen : kAmber,
                                        borderStrokeWidth: 1.5,
                                      ),
                                  ]),
                                  // Work Site Markers & Employee Pin
                                  MarkerLayer(markers: [
                                    for (final s in _sites)
                                      Marker(
                                        point: LatLng(s.latitude, s.longitude),
                                        width: 36,
                                        height: 36,
                                        child: const Icon(Icons.apartment_rounded, color: kBrand, size: 30),
                                      ),
                                    if (pos != null)
                                      Marker(
                                        point: pos,
                                        width: 50,
                                        height: 50,
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: isRecent ? kGreen : kAmber,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3)),
                                                ],
                                              ),
                                              child: const Icon(Icons.person, color: Colors.white, size: 20),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ]),
                                  const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                                ],
                              ),
                              // Floating Status Pill on Map
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        pos != null
                                            ? (isRecent ? Icons.my_location : Icons.location_history)
                                            : Icons.location_disabled,
                                        size: 15,
                                        color: pos != null ? (isRecent ? kGreen : kAmber) : kRed,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        pos != null
                                            ? (isRecent ? 'Live Location' : 'Last Synced Location')
                                            : 'No Location Data',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: pos != null ? (isRecent ? kGreen : kAmber) : kRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Location details footer
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: kSlate),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pos != null
                                      ? (isRecent
                                          ? 'Device synced at ${fmtTime(updatedAt!)} (GPS ±${accuracy?.round()}m precision)'
                                          : 'Signal paused. Showing last known synced position from ${fmtTime(updatedAt!)} (±${accuracy?.round()}m)')
                                      : 'No position recorded yet. Employee needs to open app and allow location.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRecent ? kSlate : kAmber,
                                    fontWeight: isRecent ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Today\'s Worked Hours', style: TextStyle(fontSize: 12, color: kSlate, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(fmtHm(today!.totalMinutes), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kSlateDark)),
                          ],
                        ),
                        AttendanceBadge(today.status),
                      ],
                    ),
                  ),
                ),
                sectionTitle("Today's visits (long-press to remove)"),
                if (today.sessions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No attendance punches recorded yet today.', style: TextStyle(color: kSlate))),
                    ),
                  ),
                for (final s in today.sessions) VisitTile(s, onLongPress: s.open ? null : () => _adjust('void', s.start, s.end, locationId: s.locationId)),
                const SizedBox(height: 60),
              ]),
            ),
    );
  }
}
