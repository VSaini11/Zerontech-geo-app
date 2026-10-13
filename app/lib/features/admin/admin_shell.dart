import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../common/calendar_tab.dart';
import '../common/widgets.dart';
import 'employee_detail.dart';
import 'employees_tab.dart';
import 'locations_tab.dart';

class AdminShell extends StatefulWidget {
  final AppController controller;
  const AdminShell({super.key, required this.controller});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    const titles = ['Status', 'Locations', 'Employees', 'Calendar', 'Profile'];
    final body = switch (_tab) {
      0 => const _StatusTab(),
      1 => const LocationsTab(),
      2 => const EmployeesTab(),
      3 => const _AdminCalendar(),
      _ => _AdminProfile(c: widget.controller),
    };
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Locations'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Employees'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatusTab extends StatefulWidget {
  const _StatusTab();
  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  List<OverviewEntry> _all = [];
  int _review = 0;
  bool _loading = true;
  String? _err;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await Api.get('/api/admin/status');
      _all = (o['employees'] as List).map((e) => OverviewEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      final r = await Api.get('/api/admin/review');
      _review = (r['items'] as List).length;
      _err = null;
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = _all.where((e) => e.name.toLowerCase().contains(_q.toLowerCase())).toList();
    final inside = _all.where((e) => e.status == 'inside').length;
    final unc = _all.where((e) => e.status == 'unconfirmed').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_loading) const LinearProgressIndicator(),
        if (_err != null) Text(_err!, style: const TextStyle(color: kRed)),
        Row(children: [
          MetricCard(label: 'Employees', value: '${_all.length}', color: kBrand),
          MetricCard(label: 'Inside', value: '$inside', color: kGreen),
          MetricCard(label: 'Outside', value: '${_all.length - inside - unc}', color: kRed),
          MetricCard(label: 'No signal', value: '$unc', color: kAmber),
        ]),
        if (_review > 0)
          Card(color: const Color(0xFFFFFBEB), child: ListTile(leading: const Icon(Icons.flag, color: kAmber), title: Text('$_review visit${_review == 1 ? '' : 's'} need review'), subtitle: const Text('Exit was not recorded (phone off or no signal). Open the employee to correct it.'))),
        const SizedBox(height: 8),
        TextField(decoration: const InputDecoration(hintText: 'Search employee', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 8),
        for (final e in list)
          Card(
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetail(name: e.name))).then((_) => _load()),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${e.site ?? 'Not at a site'} · today ${e.todayMinutes ~/ 60}h ${(e.todayMinutes % 60).toString().padLeft(2, '0')}m'),
              trailing: StatusChip(e.status),
            ),
          ),
        if (!_loading && list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No employees found.', style: TextStyle(color: kSlate)))),
      ]),
    );
  }
}

class _AdminCalendar extends StatefulWidget {
  const _AdminCalendar();
  @override
  State<_AdminCalendar> createState() => _AdminCalendarState();
}

class _AdminCalendarState extends State<_AdminCalendar> {
  List<String> _names = [];
  String? _sel;

  @override
  void initState() {
    super.initState();
    Api.get('/api/employees').then((r) {
      final n = (r as List).where((e) => e['role'] != 'admin').map((e) => '${e['name']}').toList();
      if (mounted) setState(() {
        _names = n;
        _sel = n.isEmpty ? null : n.first;
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_sel == null) return const Center(child: Text('No employees yet.', style: TextStyle(color: kSlate)));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: DropdownButtonFormField<String>(value: _sel, items: [for (final n in _names) DropdownMenuItem(value: n, child: Text(n))], onChanged: (v) => setState(() => _sel = v), decoration: const InputDecoration(labelText: 'Employee')),
      ),
      Expanded(child: CalendarTab(key: ValueKey(_sel), userName: _sel)),
    ]);
  }
}

class _AdminProfile extends StatelessWidget {
  final AppController c;
  const _AdminProfile({required this.c});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)), title: Text(c.user!.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Administrator'))),
      sectionTitle('System diagnostics'),
      Card(
        child: FutureBuilder<String>(
          future: AuthStore.apiBase(),
          builder: (_, s) => Column(children: [
            ListTile(leading: const Icon(Icons.dns), title: const Text('Server'), subtitle: Text(s.data ?? '…')),
            ListTile(leading: Icon(c.online ? Icons.cloud_done : Icons.cloud_off, color: c.online ? kGreen : kRed), title: const Text('Connection'), subtitle: Text(c.online ? 'Online' : 'Offline')),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: c.logout, icon: const Icon(Icons.logout), label: const Text('Sign out')),
    ]);
  }
}
