import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import 'widgets.dart';

/// Month view with day detail. Used for the employee's own history and, with [userName], for any
/// employee in the admin calendar.
class CalendarTab extends StatefulWidget {
  final String? userName;
  const CalendarTab({super.key, this.userName});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map<String, dynamic>> _days = {};
  int _total = 0;
  String? _sel;
  DayView? _day;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _sel = ymd(DateTime.now());
    _load();
  }

  @override
  void didUpdateWidget(CalendarTab old) {
    super.didUpdateWidget(old);
    if (old.userName != widget.userName) _load();
  }

  Map<String, String> get _q => {if (widget.userName != null) 'user': widget.userName!};

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final m = await Api.get('/api/geo/month', query: {..._q, 'month': ym(_month)});
      _days = {for (final d in (m['days'] as List)) '${d['date']}': Map<String, dynamic>.from(d)};
      _total = (m['totalMinutes'] as num).toInt();
      await _loadDay(_sel!);
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDay(String date) async {
    _sel = date;
    try {
      _day = DayView.fromJson(Map<String, dynamic>.from(await Api.get('/api/geo/day', query: {..._q, 'date': date})));
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  void _shift(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    _sel = ymd(DateTime(_month.year, _month.month, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${monthName(_month.month)} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kSlateDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Worked: ${fmtHm(_total)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBrand),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        if (_err != null) Padding(padding: const EdgeInsets.all(8), child: Text(_err!, style: const TextStyle(color: kRed))),
        MonthGrid(month: _month, days: _days, selected: _sel, onSelect: _loadDay),
        sectionTitle(_sel == null ? 'Day Summary' : 'Day Summary ($_sel)'),
        if (_day != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Hours', style: TextStyle(fontSize: 12, color: kSlate, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(fmtHm(_day!.totalMinutes), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kSlateDark)),
                        ],
                      ),
                      AttendanceBadge(_day!.status),
                    ],
                  ),
                  const Divider(height: 24, color: kBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DayStat(label: 'Visits', value: '${_day!.checkInCount}'),
                      _DayStat(label: 'Status', value: _day!.status.toUpperCase()),
                      _DayStat(label: 'Issues', value: _day!.needsReview ? 'Needs Review' : 'Clean', isWarn: _day!.needsReview),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_day!.sessions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 36, color: kSlate),
                      SizedBox(height: 8),
                      Text('No visits recorded on this date.', style: TextStyle(color: kSlate, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          for (final s in _day!.sessions) VisitTile(s),
        ],
      ]),
    );
  }
}

class _DayStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarn;
  const _DayStat({required this.label, required this.value, this.isWarn = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isWarn ? kAmber : kSlateDark)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: kSlate, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
