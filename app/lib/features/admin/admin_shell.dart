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

import 'report_export_screen.dart';

class AdminShell extends StatefulWidget {
  final AppController controller;
  const AdminShell({super.key, required this.controller});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  List<String> _employeeNames = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployeeNames();
  }

  Future<void> _fetchEmployeeNames() async {
    try {
      final r = await Api.get('/api/employees');
      final names = (r as List).where((e) => e['role'] != 'admin').map((e) => '${e['name']}').toList();
      if (mounted) setState(() => _employeeNames = names);
    } catch (_) {}
  }

  void _openReports([String? employeeName]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportExportScreen(
          initialUser: employeeName,
          employeeNames: _employeeNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Live Attendance', 'Locations & Geofences', 'Employees Directory', 'Attendance Calendar', 'Admin Settings'];
    final body = switch (_tab) {
      0 => _StatusTab(onExportReports: () => _openReports()),
      1 => const LocationsTab(),
      2 => const EmployeesTab(),
      3 => _AdminCalendar(employeeNames: _employeeNames, onExport: (name) => _openReports(name)),
      _ => _AdminProfile(c: widget.controller),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kSlateDark)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: kBrandLight,
                foregroundColor: kBrand,
              ),
              onPressed: () => _openReports(),
              icon: const Icon(Icons.file_download, size: 18, color: kBrand),
              label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Locations'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Employees'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatusTab extends StatefulWidget {
  final VoidCallback onExportReports;
  const _StatusTab({required this.onExportReports});
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
    final outside = _all.length - inside - unc;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_loading) const LinearProgressIndicator(),
        if (_err != null) Text(_err!, style: const TextStyle(color: kRed)),
        Row(children: [
          MetricCard(label: 'Total Staff', value: '${_all.length}', color: kBrand, icon: Icons.badge_outlined),
          MetricCard(label: 'On-Site', value: '$inside', color: kGreen, icon: Icons.place, subtitle: 'Active shifts'),
          MetricCard(label: 'Off-Site', value: '$outside', color: kSlate, icon: Icons.logout, subtitle: 'Not clocked in'),
          MetricCard(label: 'Signal Lost', value: '$unc', color: kAmber, icon: Icons.wifi_off, subtitle: 'Phone asleep'),
        ]),
        const SizedBox(height: 12),
        if (_review > 0)
          Card(
            color: kAmberLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: kAmber.withValues(alpha: 0.3))),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: kAmber, size: 28),
              title: Text('$_review visit${_review == 1 ? '' : 's'} require review', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              subtitle: const Text('Exit punches were missing due to dead battery or airplane mode.', style: TextStyle(fontSize: 12)),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search employee name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Refresh attendance',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        sectionTitle('Employees Overview (${list.length})'),
        for (final e in list)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetail(name: e.name))).then((_) => _load()),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: kBrandLight,
                      child: Text(
                        e.name.isNotEmpty ? e.name.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: kBrand),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(width: 8),
                              StatusChip(e.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: kSlate),
                              const SizedBox(width: 4),
                              Text(e.site ?? 'Off-duty', style: const TextStyle(fontSize: 12, color: kSlate, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${e.todayMinutes ~/ 60}h ${(e.todayMinutes % 60).toString().padLeft(2, '0')}m',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kSlateDark),
                        ),
                        const SizedBox(height: 2),
                        const Text('worked today', style: TextStyle(fontSize: 11, color: kSlate)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: kSlate, size: 20),
                  ],
                ),
              ),
            ),
          ),
        if (!_loading && list.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No employees found.', style: TextStyle(color: kSlate, fontWeight: FontWeight.w600)))),
        const SizedBox(height: 60),
      ]),
    );
  }
}

class _AdminCalendar extends StatefulWidget {
  final List<String> employeeNames;
  final void Function(String? employeeName) onExport;
  const _AdminCalendar({required this.employeeNames, required this.onExport});
  @override
  State<_AdminCalendar> createState() => _AdminCalendarState();
}

class _AdminCalendarState extends State<_AdminCalendar> {
  String? _sel;

  @override
  void initState() {
    super.initState();
    if (widget.employeeNames.isNotEmpty) {
      _sel = widget.employeeNames.first;
    }
  }

  @override
  void didUpdateWidget(_AdminCalendar old) {
    super.didUpdateWidget(old);
    if (_sel == null && widget.employeeNames.isNotEmpty) {
      setState(() => _sel = widget.employeeNames.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.employeeNames.isEmpty) return const Center(child: Text('No employees found.', style: TextStyle(color: kSlate)));
    final active = _sel ?? widget.employeeNames.first;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: active,
                items: [for (final n in widget.employeeNames) DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700)))],
                onChanged: (v) => setState(() => _sel = v),
                decoration: const InputDecoration(
                  labelText: 'Select Employee',
                  prefixIcon: Icon(Icons.person, color: kBrand, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 50),
                backgroundColor: kGreen,
              ),
              onPressed: () => widget.onExport(active),
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('Export Excel'),
            ),
          ],
        ),
      ),
      Expanded(child: CalendarTab(key: ValueKey(active), userName: active)),
    ]);
  }
}

class _AdminProfile extends StatelessWidget {
  final AppController c;
  const _AdminProfile({required this.c});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)), title: Text(c.user?.name ?? 'Administrator', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Administrator'))),
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
