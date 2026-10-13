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
        Row(children: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${monthName(_month.month)} ${_month.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ]),
        Center(child: Text('Total this month: ${fmtHm(_total)}', style: const TextStyle(color: kSlate))),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        if (_err != null) Padding(padding: const EdgeInsets.all(8), child: Text(_err!, style: const TextStyle(color: kRed))),
        MonthGrid(month: _month, days: _days, selected: _sel, onSelect: _loadDay),
        sectionTitle(_sel == null ? 'Day' : _sel!),
        if (_day != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmtHm(_day!.totalMinutes), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${_day!.checkInCount} visit${_day!.checkInCount == 1 ? '' : 's'} · ${_day!.status}', style: const TextStyle(color: kSlate)),
              ]),
            ),
          ),
          if (_day!.sessions.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No attendance recorded.', style: TextStyle(color: kSlate))),
          for (final s in _day!.sessions) VisitTile(s),
        ],
      ]),
    );
  }
}
