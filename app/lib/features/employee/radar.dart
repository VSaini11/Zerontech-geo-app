import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class Radar extends StatefulWidget {
  final bool inside;
  final double? meters;
  final double? accuracy;
  final String? siteName;
  const Radar({super.key, required this.inside, this.meters, this.accuracy, this.siteName});
  @override
  State<Radar> createState() => _RadarState();
}

class _RadarState extends State<Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.inside ? kGreen : kBrand;
    final m = widget.meters;
    final label = m == null ? 'Locating…' : (m < 1000 ? '${m.round()} m away' : '${(m / 1000).toStringAsFixed(1)} km away');
    return SizedBox(
      height: 220,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(size: const Size(220, 220), painter: _RadarPainter(_c.value, color))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.inside ? Icons.location_on : Icons.near_me, color: color, size: 30),
          const SizedBox(height: 4),
          Text(widget.inside ? 'Inside site' : label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          if (widget.siteName != null) Text(widget.siteName!, style: const TextStyle(color: kSlate, fontSize: 12)),
          if (widget.accuracy != null) Text('GPS ±${widget.accuracy!.round()} m', style: const TextStyle(color: kSlate, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  _RadarPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      canvas.drawCircle(c, maxR * p, Paint()
        ..color = color.withValues(alpha: (1 - p) * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    canvas.drawCircle(c, maxR * 0.42, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawCircle(c, maxR * 0.42, Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    final a = t * 2 * pi;
    canvas.drawLine(c, c + Offset(cos(a), sin(a)) * maxR * 0.42, Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
