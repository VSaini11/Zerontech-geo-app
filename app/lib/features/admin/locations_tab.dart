import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});
  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> {
  List<Site> _sites = [];
  List<String> _emps = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _sites = ((await Api.get('/api/locations')) as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
      _emps = ((await Api.get('/api/employees')) as List).where((e) => e['role'] != 'admin').map((e) => '${e['name']}').toList();
      _err = null;
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Site? s]) async {
    final saved = await showModalBottomSheet<bool>(isScrollControlled: true, context: context, builder: (_) => _SiteForm(site: s, employees: _emps));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final center = _sites.isNotEmpty ? LatLng(_sites.first.latitude, _sites.first.longitude) : const LatLng(20.5937, 78.9629);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_location_alt), label: const Text('Add site')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_loading) const LinearProgressIndicator(),
        if (_err != null) Text(_err!, style: const TextStyle(color: kRed)),
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: _sites.isEmpty ? 4 : 13),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: kPackageForMapTiles),
                CircleLayer(circles: [for (final s in _sites) CircleMarker(point: LatLng(s.latitude, s.longitude), radius: s.radiusMeters, useRadiusInMeter: true, color: kBrand.withValues(alpha: 0.18), borderColor: kBrand, borderStrokeWidth: 2)]),
                MarkerLayer(markers: [for (final s in _sites) Marker(point: LatLng(s.latitude, s.longitude), width: 36, height: 36, child: const Icon(Icons.location_on, color: kBrand, size: 36))]),
                const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in _sites)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              onTap: () => _edit(s),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: kBrandLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.apartment_rounded, color: kBrand, size: 22),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text('Radius: ${s.radiusMeters.round()}m', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSlateDark)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.assigned.isEmpty ? 'No staff assigned' : '${s.assigned.length} assigned (${s.assigned.join(', ')})',
                        style: const TextStyle(fontSize: 12, color: kSlate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Delete ${s.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
                  if (ok == true) {
                    await Api.delete('/api/locations/${s.id}');
                    _load();
                  }
                },
              ),
            ),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _SiteForm extends StatefulWidget {
  final Site? site;
  final List<String> employees;
  const _SiteForm({this.site, required this.employees});
  @override
  State<_SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends State<_SiteForm> {
  late final _name = TextEditingController(text: widget.site?.name ?? '');
  late LatLng _pos = widget.site == null ? const LatLng(28.6139, 77.209) : LatLng(widget.site!.latitude, widget.site!.longitude);
  late double _radius = widget.site?.radiusMeters ?? 150;
  late final Set<String> _assigned = {...?widget.site?.assigned};
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final body = {'name': _name.text, 'latitude': _pos.latitude, 'longitude': _pos.longitude, 'radiusMeters': _radius.round(), 'assignedEmployees': _assigned.toList()};
      if (widget.site == null) {
        await Api.post('/api/locations', body);
      } else {
        await Api.put('/api/locations/${widget.site!.id}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.site == null ? 'New site' : 'Edit site', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Site name')),
          const SizedBox(height: 12),
          const Text('Tap the map to place the site', style: TextStyle(color: kSlate)),
          const SizedBox(height: 6),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: _pos, initialZoom: 15, onTap: (_, p) => setState(() => _pos = p)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: kPackageForMapTiles),
                  CircleLayer(circles: [CircleMarker(point: _pos, radius: _radius, useRadiusInMeter: true, color: kBrand.withValues(alpha: 0.2), borderColor: kBrand, borderStrokeWidth: 2)]),
                  MarkerLayer(markers: [Marker(point: _pos, width: 36, height: 36, child: const Icon(Icons.location_on, color: kBrand, size: 36))]),
                ],
              ),
            ),
          ),
          Text('${_pos.latitude.toStringAsFixed(5)}, ${_pos.longitude.toStringAsFixed(5)}', style: const TextStyle(color: kSlate, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Radius: ${_radius.round()} m', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _radius.clamp(100, 1000), min: 100, max: 1000, divisions: 18, onChanged: (v) => setState(() => _radius = v)),
          const Text('Assigned employees', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final n in widget.employees) FilterChip(label: Text(n), selected: _assigned.contains(n), onSelected: (v) => setState(() => v ? _assigned.add(n) : _assigned.remove(n))),
          ]),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: kRed))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}
