import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = c.perms;
    Widget row(bool ok, String title, String sub, String action, VoidCallback onTap) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? kGreen : kAmber),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: ok ? null : TextButton(onPressed: onTap, child: Text(action)),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Make attendance automatic', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          row(p.serviceOn, 'Location is on', 'Turn on GPS in your phone settings.', 'Check', () => c.checkPermissions()),
          row(p.fine, 'Location while using the app', 'Needed to show your distance to the site.', 'Allow', c.requestForeground),
          row(p.always, 'Allow all the time', 'Lets check-in work when the app is closed.', 'Allow', () => _always(context)),
          row(p.notifications, 'Notifications', 'Get a message when you check in or out.', 'Allow', c.requestNotifications),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.battery_saver, color: kSlate),
            title: const Text('Battery: set to Unrestricted', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Some phones (Xiaomi, Oppo, Vivo, Samsung) stop background apps. App info → Battery → Unrestricted.'),
            trailing: TextButton(onPressed: _battery, child: const Text('Open')),
          ),
        ]),
      ),
    );
  }
}
