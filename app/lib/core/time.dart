String two(int n) => n.toString().padLeft(2, '0');

String fmtHm(int minutes) {
  if (minutes < 0) minutes = 0;
  return '${minutes ~/ 60}h ${two(minutes % 60)}m';
}

String fmtClock(Duration d) {
  if (d.isNegative) d = Duration.zero;
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String monthName(int m) => _months[m - 1];
String fmtDate(DateTime d) => '${d.day} ${monthName(d.month)} ${d.year}';
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String ym(DateTime d) => '${d.year}-${two(d.month)}';

String reasonLabel(String? r) {
  switch (r) {
    case 'outside_radius':
      return 'Exited geofence radius';
    case 'inferred_exit':
      return 'Estimated exit (Signal lost / phone off)';
    case 'auto_close':
      return 'Auto-closed after 16h limit';
    case 'manual':
      return 'Admin manual adjustment';
    case 'perm_lost':
      return 'Location / GPS turned off';
    default:
      return 'Active session';
  }
}
