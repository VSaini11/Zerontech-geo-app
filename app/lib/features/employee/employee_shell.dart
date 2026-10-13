import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../state/app_controller.dart';
import '../common/calendar_tab.dart';
import '../common/permission_card.dart';
import '../common/widgets.dart';
import 'radar.dart';

class EmployeeShell extends StatefulWidget {
  final AppController controller;
  const EmployeeShell({super.key, required this.controller});
  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final titles = ['Status', 'Calendar', 'Profile'];
    // Not an IndexedStack: only the visible tab is built, so hidden tabs never get zero-size layout.
    final body = switch (_tab) {
      0 => _StatusTab(c: widget.controller),
      1 => const CalendarTab(),
      _ => _ProfileTab(c: widget.controller),
    };
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final AppController c;
  const _StatusTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final live = c.live;
        final open = live?.open;
        final near = c.nearest();
        final h = DateTime.now().hour;
        final lunch = h >= 13 && h < 14;
        var minutes = live?.todayMinutes ?? 0;
        if (live != null && open != null && !open.stale) minutes += ((c.serverNow() - live.serverTime) / 60000).floor().clamp(0, 600);
        return RefreshIndicator(
          onRefresh: c.refreshAll,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (!c.online || c.pending > 0)
              Card(
                color: const Color(0xFFFFF7ED),
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: kAmber),
                  title: Text(c.online ? '${c.pending} update${c.pending == 1 ? '' : 's'} waiting to sync' : 'Offline'),
                  subtitle: const Text('Your check-ins are saved on this phone and will upload automatically.'),
                ),
              ),
            Card(
              color: open != null ? (open.stale ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  if (open != null) ...[
                    Text(open.stale ? 'Signal lost at ${open.locationName}' : 'Checked in at ${open.locationName}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: open.stale ? kAmber : kGreen)),
                    const SizedBox(height: 6),
                    if (!open.stale) LiveTimer(sinceServerMs: open.since, serverNow: c.serverNow, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                    Text('Since ${fmtTime(open.since)}', style: const TextStyle(color: kSlate)),
                    if (open.stale) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Open the app near the site or check your location settings. Time is counted only up to your last signal.', textAlign: TextAlign.center, style: TextStyle(color: kSlate))),
                  ] else ...[
                    const Text('Outside geofence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate)),
                    const SizedBox(height: 4),
                    Text(c.sites.isEmpty ? 'No work site is assigned to you yet.' : 'You will be checked in automatically when you arrive.', textAlign: TextAlign.center, style: const TextStyle(color: kSlate)),
                  ],
                  const Divider(height: 28),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Worked today', style: TextStyle(color: kSlate)),
                    Text(fmtHm(minutes), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              ),
            ),
            if (lunch)
              const Card(color: Color(0xFFFFFBEB), child: ListTile(leading: Icon(Icons.restaurant, color: kAmber), title: Text('Lunch time'), subtitle: Text('1:00 PM – 2:00 PM'))),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Radar(inside: open != null && !open.stale, meters: near?.meters, accuracy: c.position?.accuracy, siteName: near?.site.name),
              ),
            ),
            if (!c.perms.allGood) PermissionCard(c: c),
            sectionTitle("Today's activity"),
            if (c.today == null || c.today!.sessions.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nothing recorded yet today.', style: TextStyle(color: kSlate))),
            if (c.today != null) for (final s in c.today!.sessions) VisitTile(s),
          ]),
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final AppController c;
  const _ProfileTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(c.user!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Employee · ${c.sites.length} assigned site${c.sites.length == 1 ? '' : 's'}'),
          ),
        ),
        const SizedBox(height: 8),
        PermissionCard(c: c),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.sync), title: const Text('Sync now'), subtitle: Text(c.pending == 0 ? 'Everything is uploaded' : '${c.pending} waiting'), onTap: () async {
              await c.refreshAll();
              if (context.mounted) toast(context, c.online ? 'Synced' : 'No connection. Will retry automatically.');
            }),
            for (final s in c.sites) ListTile(leading: const Icon(Icons.business), title: Text(s.name), subtitle: Text('Radius ${s.radiusMeters.round()} m')),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Sign out?'), content: const Text('Automatic check-in stops until you sign in again.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out'))]));
            if (ok == true) await c.logout();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Geo Attendance 1.0', style: TextStyle(color: kSlate, fontSize: 12))),
      ]),
    );
  }
}
