import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../state/app_controller.dart';

/// Checklist of the four things Android needs for automatic attendance. Shown on the Status tab
/// until everything is green and always available on Profile.
class PermissionCard extends StatelessWidget {
  final AppController c;
  const PermissionCard({super.key, required this.c});

  Future<void> _always(BuildContext context) async {
    // Google Play requires a clear disclosure *before* asking for background location.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location in the background'),
        content: const Text('This app collects your location even when it is closed or not in use. It is used only to mark check-in when you arrive at an assigned work site, check-out when you leave, and to calculate your worked hours. It is never used for ads and is only shared with your employer.\n\nOn the next screen choose "Allow all the time".'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue'))],
      ),
    );
    if (ok == true) await c.requestAlways();
  }

  Future<void> _battery() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await const AndroidIntent(action: 'android.settings.APPLICATION_DETAILS_SETTINGS', data: 'package:com.gnc.geo_app').launch();
  }

  Future<void> _openLocationSettings() async {
    if (!kIsWeb) {
      await Geolocator.openLocationSettings();
      await c.checkPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = c.perms;
    Widget row(bool ok, String title, String sub, String action, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? kGreen : kAmber, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kSlateDark)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 11, color: kSlate)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!ok)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(60, 32),
                  ),
                  onPressed: onTap,
                  child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Make attendance automatic', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kSlateDark)),
            const SizedBox(height: 8),
            row(p.serviceOn, 'Location is on', 'Turn on GPS in your phone settings.', 'Turn On', _openLocationSettings),
            const Divider(height: 1, color: kBorder),
            row(p.fine, 'Location while using the app', 'Needed to show your distance to the site.', 'Allow', c.requestForeground),
            const Divider(height: 1, color: kBorder),
            row(p.always, 'Allow all the time', 'Lets check-in work when the app is closed.', 'Allow', () => _always(context)),
            const Divider(height: 1, color: kBorder),
            row(p.notifications, 'Notifications', 'Get a message when you check in or out.', 'Allow', c.requestNotifications),
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.battery_saver, color: kSlate, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Battery: set to Unrestricted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kSlateDark)),
                        SizedBox(height: 2),
                        Text('Prevents phone from stopping tracking in background.', style: TextStyle(fontSize: 11, color: kSlate)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(60, 32),
                    ),
                    onPressed: _battery,
                    child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
