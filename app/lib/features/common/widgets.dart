import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/models.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const MetricCard({super.key, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: kSlate), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String status; // inside | outside | unconfirmed
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'inside' => ('Inside', kGreen),
      'unconfirmed' => ('No signal', kAmber),
      _ => ('Outside', kRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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
    final color = v.open ? (v.stale ? kAmber : kGreen) : (v.needsReview ? kAmber : kSlate);
    return ListTile(
      onLongPress: onLongPress,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(v.open ? Icons.timelapse : Icons.check, color: color, size: 20)),
      title: Text(v.locationName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${fmtTime(v.start)} – ${v.open ? (v.stale ? 'last seen ${fmtTime(v.end)}' : 'now') : fmtTime(v.end)} · ${reasonLabel(v.reason)}${v.needsReview ? '\nNeeds admin review' : ''}${v.note.isNotEmpty ? '\n${v.note}' : ''}'),
      isThreeLine: v.needsReview || v.note.isNotEmpty,
      trailing: Text(fmtHm(v.minutes), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Month grid used by both roles. Colours: green present, amber partial, grey absent.
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
    final cells = <Widget>[
      for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Center(child: Text(d, style: const TextStyle(color: kSlate, fontWeight: FontWeight.w700))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++) _cell(d),
    ];
    return GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.95, children: cells);
  }

  Widget _cell(int d) {
    final key = '${month.year}-${two(month.month)}-${two(d)}';
    final info = days[key];
    final status = info?['status'] as String?;
    final color = status == 'present' ? kGreen : status == 'partial' ? kAmber : Colors.transparent;
    final isSel = selected == key;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onSelect(key),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: isSel ? kBrand : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$d', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (info != null && (info['totalMinutes'] as int) > 0) Text(fmtHm(info['totalMinutes'] as int).replaceAll(' ', ''), style: const TextStyle(fontSize: 9, color: kSlate)),
        ]),
      ),
    );
  }
}

Widget sectionTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)));

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
