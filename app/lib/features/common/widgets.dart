import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/models.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final String? subtitle;
  const MetricCard({super.key, required this.label, required this.value, required this.color, this.icon, this.subtitle});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (icon != null) Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 11, color: kSlate.withValues(alpha: 0.8))),
                ],
              ],
            ),
          ),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String status; // inside | outside | unconfirmed
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'inside' => ('On-Site', kGreen, kGreenLight),
      'unconfirmed' => ('Signal Lost', kAmber, kAmberLight),
      _ => ('Off-Site', kSlate, const Color(0xFFF1F5F9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }
}

class AttendanceBadge extends StatelessWidget {
  final String status; // present | partial | absent
  final bool compact;
  const AttendanceBadge(this.status, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, textCol, bgCol) = switch (status) {
      'present' => ('Present', kGreen, kGreenLight),
      'partial' => ('Half-Day', kAmber, kAmberLight),
      _ => ('Absent', kRed, kRedLight),
    };

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(color: bgCol, borderRadius: BorderRadius.circular(4), border: Border.all(color: textCol.withValues(alpha: 0.4), width: 0.8)),
        child: Text(label, style: TextStyle(color: textCol, fontWeight: FontWeight.w800, fontSize: 8)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgCol,
        border: Border.all(color: textCol.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: textCol, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

/// Ticks once a second using the *server's* clock offset, so a wrong phone clock cannot make
/// the timer jump.
class LiveTimer extends StatefulWidget {
  final int sinceServerMs;
  final int Function() serverNow;
  final TextStyle? style;
  const LiveTimer({super.key, required this.sinceServerMs, required this.serverNow, this.style});
  @override
  State<LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<LiveTimer> {
  late final Stream<int> _ticks = Stream.periodic(const Duration(seconds: 1), (i) => i);
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
        stream: _ticks,
        builder: (_, __) => Text(fmtClock(Duration(milliseconds: widget.serverNow() - widget.sinceServerMs)), style: widget.style),
      );
}

class VisitTile extends StatelessWidget {
  final VisitView v;
  final VoidCallback? onLongPress;
  const VisitTile(this.v, {super.key, this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final color = v.open ? (v.stale ? kAmber : kGreen) : (v.needsReview ? kAmber : kBrand);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(v.open ? Icons.play_circle_fill : Icons.check_circle, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.locationName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtTime(v.start)} – ${v.open ? (v.stale ? 'last seen ${fmtTime(v.end)}' : 'active now') : fmtTime(v.end)}',
                    style: const TextStyle(color: kSlate, fontSize: 12),
                  ),
                  if (v.needsReview || v.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      v.needsReview ? '⚠ Needs admin review' : v.note,
                      style: TextStyle(color: v.needsReview ? kAmber : kSlate, fontSize: 11, fontWeight: v.needsReview ? FontWeight.w700 : FontWeight.normal),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtHm(v.minutes), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kSlateDark)),
                const SizedBox(height: 2),
                Text(reasonLabel(v.reason), style: const TextStyle(fontSize: 10, color: kSlate)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Month grid showing day number, hours worked, and explicit Present / Half-Day / Absent badge.
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, Map<String, dynamic>> days; // date -> {totalMinutes,status}
  final String? selected;
  final void Function(String date) onSelect;
  const MonthGrid({super.key, required this.month, required this.days, required this.onSelect, this.selected});
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final now = DateTime.now();
    final todayKey = '${now.year}-${two(now.month)}-${two(now.day)}';

    final cells = <Widget>[
      for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'])
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(d, style: const TextStyle(color: kSlate, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++) _cell(d, todayKey),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.82,
          children: cells,
        ),
      ),
    );
  }

  Widget _cell(int d, String todayKey) {
    final key = '${month.year}-${two(month.month)}-${two(d)}';
    final info = days[key];
    final minutes = (info?['totalMinutes'] as num?)?.toInt() ?? 0;
    final rawStatus = info?['status'] as String?;
    final isSunday = DateTime(month.year, month.month, d).weekday == 7;
    final isPastOrToday = key.compareTo(todayKey) <= 0;

    // Derive status: if past or today and minutes == 0 (and not Sunday), it's absent
    final status = rawStatus ?? (isSunday ? 'weekend' : (isPastOrToday ? 'absent' : 'future'));
    final isSel = selected == key;

    final (badgeBg, borderCol) = switch (status) {
      'present' => (kGreenLight, kGreen.withValues(alpha: 0.3)),
      'partial' => (kAmberLight, kAmber.withValues(alpha: 0.3)),
      'absent' => (kRedLight, kRed.withValues(alpha: 0.2)),
      _ => (const Color(0xFFF8FAFC), kBorder),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onSelect(key),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isSel ? kBrandLight : badgeBg,
          border: Border.all(
            color: isSel ? kBrand : borderCol,
            width: isSel ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              '$d',
              style: TextStyle(
                fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
                color: isSel ? kBrand : kSlateDark,
              ),
            ),
            if (minutes > 0)
              Text(
                fmtHm(minutes).replaceAll(' ', ''),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSlateDark),
              )
            else if (status == 'absent')
              const Text('0h', style: TextStyle(fontSize: 9, color: kSlate))
            else
              const SizedBox(height: 12),
            if (status == 'present' || status == 'partial' || status == 'absent')
              AttendanceBadge(status, compact: true)
            else if (isSunday)
              const Text('OFF', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kSlate))
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kSlateDark, letterSpacing: -0.2)),
    );

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    ));

