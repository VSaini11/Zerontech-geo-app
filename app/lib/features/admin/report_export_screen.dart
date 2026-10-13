import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/time.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

// Web download helper using conditional dart:js_interop / url trick
import 'export_web_helper.dart' if (dart.library.io) 'export_io_helper.dart' as exporter;

class ReportExportScreen extends StatefulWidget {
  final String? initialUser;
  final List<String> employeeNames;
  const ReportExportScreen({super.key, this.initialUser, this.employeeNames = const []});

  @override
  State<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends State<ReportExportScreen> {
  late String? _selectedUser = widget.initialUser;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _records = [];
  bool _hasFetched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1); // Start of current month
    _endDate = now;
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fromStr = ymd(_startDate);
      final toStr = ymd(_endDate);
      final query = <String, String>{
        'from': fromStr,
        'to': toStr,
        if (_selectedUser != null && _selectedUser!.isNotEmpty) 'user': _selectedUser!,
      };

      final res = await Api.get('/api/admin/report', query: query);
      final list = (res['records'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      setState(() {
        _records = list;
        _hasFetched = true;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exportCSV() {
    if (_records.isEmpty) {
      toast(context, 'No records to export');
      return;
    }

    final buf = StringBuffer();
    // CSV Header compatible with MS Excel
    buf.writeln('Employee Name,Date,Status,Worked Hours,Minutes,Visits Count,First In,Last Out,Sites Visited,Needs Review');

    for (final r in _records) {
      final name = '"${(r['userName'] ?? '').toString().replaceAll('"', '""')}"';
      final date = r['date'] ?? '';
      final status = (r['status'] ?? 'absent').toString().toUpperCase();
      final hours = r['workedHours'] ?? '0.00';
      final minutes = r['totalMinutes'] ?? 0;
      final visits = r['checkInCount'] ?? 0;

      final firstIn = r['firstIn'] != null ? fmtTime((r['firstIn'] as num).toInt()) : '-';
      final lastOut = r['lastOut'] != null ? fmtTime((r['lastOut'] as num).toInt()) : '-';
      final sites = '"${(r['sites'] ?? '-').toString().replaceAll('"', '""')}"';
      final review = (r['needsReview'] == true) ? 'YES' : 'NO';

      buf.writeln('$name,$date,$status,$hours,$minutes,$visits,$firstIn,$lastOut,$sites,$review');
    }

    final csvString = buf.toString();
    final fileName = 'attendance_report_${ymd(_startDate)}_to_${ymd(_endDate)}.csv';

    exporter.saveOrDownload(csvString, fileName);
    toast(context, 'Report exported: $fileName');
  }

  void _copyToClipboard() {
    if (_records.isEmpty) return;
    final buf = StringBuffer();
    buf.writeln('Employee\tDate\tStatus\tHours\tFirst In\tLast Out\tSites');
    for (final r in _records) {
      final name = r['userName'] ?? '';
      final date = r['date'] ?? '';
      final status = r['status'] ?? '';
      final hours = '${r['workedHours']}h';
      final firstIn = r['firstIn'] != null ? fmtTime((r['firstIn'] as num).toInt()) : '-';
      final lastOut = r['lastOut'] != null ? fmtTime((r['lastOut'] as num).toInt()) : '-';
      final sites = r['sites'] ?? '-';
      buf.writeln('$name\t$date\t$status\t$hours\t$firstIn\t$lastOut\t$sites');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    toast(context, 'Report table copied to clipboard');
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: kBrand, onPrimary: Colors.white, surface: Colors.white, onSurface: kSlateDark),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalHours = _records.fold<double>(0.0, (acc, r) => acc + (double.tryParse('${r['workedHours']}') ?? 0.0));
    final presentCount = _records.where((r) => r['status'] == 'present').length;
    final halfCount = _records.where((r) => r['status'] == 'partial').length;
    final absentCount = _records.where((r) => r['status'] == 'absent').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports & Export', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_records.isNotEmpty) ...[
            IconButton(
              tooltip: 'Copy to Clipboard',
              icon: const Icon(Icons.copy_all, color: kSlate),
              onPressed: _copyToClipboard,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 38),
                  backgroundColor: kGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _exportCSV,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filter Controls Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18, color: kBrand),
                      const SizedBox(width: 8),
                      const Text('Report Parameters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const Spacer(),
                      // Preset buttons
                      TextButton(
                        onPressed: () {
                          final today = DateTime.now();
                          setState(() {
                            _startDate = today;
                            _endDate = today;
                          });
                          _fetchReport();
                        },
                        child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, 1);
                            _endDate = now;
                          });
                          _fetchReport();
                        },
                        child: const Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      final employeeField = DropdownButtonFormField<String?>(
                        value: _selectedUser,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Employee',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Employees (Company-wide)', overflow: TextOverflow.ellipsis)),
                          for (final name in widget.employeeNames)
                            DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _selectedUser = v),
                      );

                      final dateField = OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.calendar_today, size: 18, color: kBrand),
                        label: Text(
                          '${ymd(_startDate)}  to  ${ymd(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kSlateDark),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            employeeField,
                            const SizedBox(height: 10),
                            dateField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: employeeField),
                          const SizedBox(width: 12),
                          Expanded(child: dateField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _fetchReport,
                    icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                    label: const Text('Generate Report'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null)
            Card(
              color: kRedLight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w600)),
              ),
            ),

          // Overview KPI stats when records exist
          if (_hasFetched && _records.isNotEmpty) ...[
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = [
                  MetricCard(label: 'Total Records', value: '${_records.length}', color: kBrand, icon: Icons.format_list_bulleted),
                  MetricCard(label: 'Total Hours', value: '${totalHours.toStringAsFixed(1)}h', color: kSlateDark, icon: Icons.schedule),
                  MetricCard(label: 'Present', value: '$presentCount', color: kGreen, icon: Icons.check_circle_outline),
                  MetricCard(label: 'Half-Day', value: '$halfCount', color: kAmber, icon: Icons.timelapse),
                  MetricCard(label: 'Absent', value: '$absentCount', color: kRed, icon: Icons.cancel_outlined),
                ];

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(children: [cards[0], cards[1]]),
                      const SizedBox(height: 6),
                      Row(children: [cards[2], cards[3], cards[4]]),
                    ],
                  );
                }

                return Row(children: cards);
              },
            ),
            const SizedBox(height: 12),
            sectionTitle('Report Data (${_records.length} records)'),
            Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Hours Worked', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('First In', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Last Out', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Work Sites', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataColumn(label: Text('Visits', style: TextStyle(fontWeight: FontWeight.w800))),
                    ],
                    rows: [
                      for (final r in _records)
                        DataRow(
                          cells: [
                            DataCell(Text(r['userName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(r['date'] ?? '', style: const TextStyle(color: kSlate))),
                            DataCell(AttendanceBadge(r['status'] ?? 'absent')),
                            DataCell(Text('${r['workedHours']} hrs (${fmtHm(r['totalMinutes'] ?? 0)})', style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(r['firstIn'] != null ? fmtTime((r['firstIn'] as num).toInt()) : '-', style: const TextStyle(color: kSlate))),
                            DataCell(Text(r['lastOut'] != null ? fmtTime((r['lastOut'] as num).toInt()) : '-', style: const TextStyle(color: kSlate))),
                            DataCell(Text(r['sites'] ?? '-', style: const TextStyle(color: kSlateDark))),
                            DataCell(Text('${r['checkInCount'] ?? 0}')),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_hasFetched && _records.isEmpty) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: kSlate),
                      SizedBox(height: 12),
                      Text('No records found for the selected criteria.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kSlate)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
