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
    final titles = ['My Attendance', 'My Profile'];
    final body = switch (_tab) {
      0 => _StatusTab(c: widget.controller),
      _ => _ProfileTab(c: widget.controller),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kSlateDark)),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh, color: kSlate),
            onPressed: () => widget.controller.refreshAll(),
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: kBrand,
        unselectedItemColor: kSlate,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar_outlined), activeIcon: Icon(Icons.radar), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
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
        if (live != null && open != null && !open.stale) {
          minutes += ((c.serverNow() - live.serverTime) / 60000).floor().clamp(0, 600);
        }

        final targetMinutes = 8 * 60; // 8-hour benchmark
        final progress = (minutes / targetMinutes).clamp(0.0, 1.0);
        final isCheckedIn = open != null && !open.stale;

        return RefreshIndicator(
          onRefresh: c.refreshAll,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // Connectivity Banner
            if (!c.online || c.pending > 0)
              Card(
                color: const Color(0xFFFFF7ED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFFED7AA))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: kAmber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.online ? '${c.pending} punches saved locally' : 'Offline Mode',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF9A3412)),
                            ),
                            const Text('Punches sync automatically when internet is available.', style: TextStyle(fontSize: 11, color: Color(0xFFC2410C))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Hero Live Status Card
            Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isCheckedIn
                        ? [const Color(0xFFECFDF5), Colors.white]
                        : open != null && open.stale
                            ? [const Color(0xFFFFFBEB), Colors.white]
                            : [const Color(0xFFF8FAFC), Colors.white],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCheckedIn ? kGreen : (open != null ? kAmber : kSlate),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCheckedIn
                                  ? 'ACTIVE SHIFT'
                                  : (open != null && open.stale ? 'SIGNAL PENDING' : 'OUTSIDE SITE'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: isCheckedIn ? kGreen : (open != null ? kAmber : kSlate),
                              ),
                            ),
                          ],
                        ),
                        if (open != null && !open.stale)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Clocked In', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (open != null) ...[
                      Text(
                        open.stale ? 'No recent signal at ${open.locationName}' : open.locationName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kSlateDark),
                      ),
                      const SizedBox(height: 8),
                      if (!open.stale)
                        LiveTimer(
                          sinceServerMs: open.since,
                          serverNow: c.serverNow,
                          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1, color: kBrand, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      Text('Since ${fmtTime(open.since)}', style: const TextStyle(color: kSlate, fontWeight: FontWeight.w600, fontSize: 13)),
                      if (open.stale)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Keep GPS on and open the app near the work site to refresh.', textAlign: TextAlign.center, style: TextStyle(color: kAmber, fontSize: 12)),
                        ),
                    ] else ...[
                      const Icon(Icons.location_off_outlined, size: 40, color: kSlate),
                      const SizedBox(height: 8),
                      const Text('Currently Off-Site', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kSlateDark)),
                      const SizedBox(height: 4),
                      Text(
                        c.sites.isEmpty ? 'No work site assigned yet' : 'Automatic check-in will trigger when you reach your site',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kSlate, fontSize: 13),
                      ),
                    ],
                    const Divider(height: 32, color: kBorder),
                    // Today's worked summary with progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Today\'s Worked Hours', style: TextStyle(fontSize: 12, color: kSlate, fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text('Standard benchmark: 8 hours', style: TextStyle(fontSize: 10, color: kSlate)),
                          ],
                        ),
                        Text(fmtHm(minutes), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kSlateDark)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? kGreen : kBrand),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (lunch)
              Card(
                color: kAmberLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: kAmber.withValues(alpha: 0.3))),
                child: const ListTile(
                  leading: Icon(Icons.restaurant, color: kAmber),
                  title: Text('Scheduled Lunch Period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text('1:00 PM – 2:00 PM (Deducted automatically as per company policy)'),
                ),
              ),

            // Site Distance & Radar widget card
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                child: Column(
                  children: [
                    Radar(
                      inside: open != null && !open.stale,
                      meters: near?.meters,
                      accuracy: c.position?.accuracy,
                      siteName: near?.site.name,
                    ),
                    if (near != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          'Nearest: ${near.site.name} (${near.meters.round()}m away)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kSlateDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (!c.perms.allGood) PermissionCard(c: c),

            sectionTitle("Today's Visits & Timeline"),
            if (c.today == null || c.today!.sessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.schedule, size: 36, color: kSlate),
                        SizedBox(height: 8),
                        Text('No attendance sessions recorded yet today.', style: TextStyle(color: kSlate, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            if (c.today != null)
              for (final s in c.today!.sessions) VisitTile(s),
            const SizedBox(height: 60),
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
      builder: (context, _) {
        try {
          final u = c.user;
          final name = (u != null && u.name.isNotEmpty) ? u.name : 'Employee';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';
          final userId = u != null ? u.id.toString() : '-';

          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: kBrandLight,
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBrand),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 2),
                          Text('Employee · ID #$userId', style: const TextStyle(color: kSlate, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: kGreen.withOpacity(0.3))),
                      child: const Text('Active', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            PermissionCard(c: c),
            const SizedBox(height: 8),
            sectionTitle('Assigned Sites (${c.sites.length})'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                child: Column(
                  children: [
                    if (c.sites.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('No work sites assigned to your account.', style: TextStyle(color: kSlate))),
                      )
                    else
                      for (final s in c.sites)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.apartment_rounded, color: kBrand, size: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kSlateDark)),
                                    const SizedBox(height: 2),
                                    Text('Geofence Radius: ${s.radiusMeters.round()} meters', style: const TextStyle(fontSize: 12, color: kSlate)),
                                  ],
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
            sectionTitle('Account & Synchronization'),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await c.refreshAll();
                  if (context.mounted) {
                    toast(context, c.online ? 'Sync completed successfully' : 'Device is offline. Will retry once reconnected.');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: kBrand, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sync attendance with server', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kSlateDark)),
                            const SizedBox(height: 2),
                            Text(c.pending == 0 ? 'All local events are uploaded' : '${c.pending} records queued for upload', style: const TextStyle(fontSize: 12, color: kSlate)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: kSlate),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                foregroundColor: kRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Automatic attendance and geofence tracking will pause until you sign in again.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: kRed), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                    ],
                  ),
                );
                if (ok == true) await c.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out of account', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('Geo Attendance • Mobile Edition', style: TextStyle(color: kSlate, fontSize: 12))),
            const SizedBox(height: 40),
          ]);
        } catch (e, stack) {
          debugPrint('Error rendering ProfileTab: $e\n$stack');
          return Center(child: Text('Error loading profile: $e'));
        }
      },
    );
  }
}
