import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

class EmployeesTab extends StatefulWidget {
  const EmployeesTab({super.key});
  @override
  State<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<EmployeesTab> {
  List<Employee> _list = [];
  List<Site> _sites = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _list = ((await Api.get('/api/employees')) as List).map((e) => Employee.fromJson(Map<String, dynamic>.from(e))).toList();
      _sites = ((await Api.get('/api/locations')) as List).map((e) => Site.fromJson(Map<String, dynamic>.from(e))).toList();
      _err = null;
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final pw = TextEditingController();
    final chosen = <String>{};
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add employee'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Username'), autocorrect: false),
              const SizedBox(height: 8),
              TextField(controller: pw, decoration: const InputDecoration(labelText: 'Temporary password (6+ characters)')),
              const SizedBox(height: 8),
              const Text('Sites'),
              Wrap(spacing: 6, children: [for (final s in _sites) FilterChip(label: Text(s.name), selected: chosen.contains(s.id), onSelected: (v) => set(() => v ? chosen.add(s.id) : chosen.remove(s.id)))]),
              if (err != null) Text(err!, style: const TextStyle(color: kRed)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.post('/api/employees', {'name': name.text, 'password': pw.text, 'locationIds': chosen.toList()});
                  if (ctx.mounted) Navigator.pop(ctx);
                } on ApiException catch (e) {
                  set(() => err = e.message);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  Future<void> _sitesDialog(Employee e) async {
    final chosen = {for (final s in e.sites) s['id']!};
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Sites for ${e.name}'),
          content: Wrap(spacing: 6, children: [for (final s in _sites) FilterChip(label: Text(s.name), selected: chosen.contains(s.id), onSelected: (v) => set(() => v ? chosen.add(s.id) : chosen.remove(s.id)))]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await Api.put('/api/employees/${e.id}/sites', {'locationIds': chosen.toList()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  Future<void> _reset(Employee e) async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password for ${e.name}'),
        content: TextField(controller: pw, decoration: const InputDecoration(labelText: 'New password (6+ characters)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset'))],
      ),
    );
    if (ok != true) return;
    try {
      await Api.put('/api/employees/${e.id}/password', {'password': pw.text});
      if (mounted) toast(context, 'Password changed. ${e.name} will be signed out.');
    } on ApiException catch (x) {
      if (mounted) toast(context, x.message);
    }
  }

  Future<void> _delete(Employee e) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Delete ${e.name}?'), content: const Text('The account is removed. Past attendance records stay in the database.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (ok != true) return;
    try {
      await Api.delete('/api/employees/${e.id}');
    } on ApiException catch (x) {
      if (mounted) toast(context, x.message);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Add')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_loading) const LinearProgressIndicator(),
          if (_err != null) Text(_err!, style: const TextStyle(color: kRed)),
          for (final e in _list)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(e.name.isEmpty ? '?' : e.name[0].toUpperCase())),
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${e.role} · ${e.sites.isEmpty ? 'no sites' : e.sites.map((s) => s['name']).join(', ')}'),
                trailing: e.role == 'admin'
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) => {'sites': _sitesDialog, 'pw': _reset, 'del': _delete}[v]!(e),
                        itemBuilder: (_) => const [PopupMenuItem(value: 'sites', child: Text('Assign sites')), PopupMenuItem(value: 'pw', child: Text('Reset password')), PopupMenuItem(value: 'del', child: Text('Delete'))],
                      ),
              ),
            ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
