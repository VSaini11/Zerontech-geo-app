import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

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
    final center = pos ?? (_sites.isNotEmpty ? LatLng(_sites.first.latitude, _sites.first.longitude) : const LatLng(20.5937, 78.9629));
    return Scaffold(
      appBar: AppBar(title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addManual, icon: const Icon(Icons.add), label: const Text('Add time')),
      body: d == null
          ? Center(child: _err == null ? const CircularProgressIndicator() : Text(_err!, style: const TextStyle(color: kRed)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                SizedBox(
                  height: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(initialCenter: center, initialZoom: 15),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: kPackageForMapTiles),
                        CircleLayer(circles: [for (final s in _sites) CircleMarker(point: LatLng(s.latitude, s.longitude), radius: s.radiusMeters, useRadiusInMeter: true, color: kBrand.withValues(alpha: 0.15), borderColor: kBrand, borderStrokeWidth: 2)]),
                        if (pos != null) MarkerLayer(markers: [Marker(point: pos, width: 40, height: 40, child: const Icon(Icons.person_pin_circle, color: kRed, size: 40))]),
                        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                      ],
                    ),
                  ),
                ),
                if (k != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Last position ${fmtTime((k['updatedAt'] as num).toInt())} · ±${((k['accuracy'] ?? 0) as num).round()} m', style: const TextStyle(color: kSlate, fontSize: 12))),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(fmtHm(today!.totalMinutes), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('${today.checkInCount} visits · ${today.status}', style: const TextStyle(color: kSlate)),
                    ]),
                  ),
                ),
                sectionTitle("Today's visits (long-press to remove)"),
                if (today.sessions.isEmpty) const Text('Nothing recorded.', style: TextStyle(color: kSlate)),
                for (final s in today.sessions) VisitTile(s, onLongPress: s.open ? null : () => _adjust('void', s.start, s.end, locationId: s.locationId)),
              ]),
            ),
    );
  }
}
