import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Grafico locale, senza dipendenze o chiamate di rete.
/// Ogni vertice proviene dal registro dei punti effettivi.
class MatchPointProgressChart extends StatelessWidget {
  const MatchPointProgressChart({super.key, required this.timeline});
  final List<Map<String, int>> timeline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 205,
      child: CustomPaint(
        painter: _ProgressPainter(timeline),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.timeline);
  final List<Map<String, int>> timeline;
  static const lime = Color(0xFFCCFF00);
  static const cyan = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 35.0, top = 8.0, bottom = 23.0, right = 10.0;
    final width = math.max(1.0, size.width - left - right);
    final height = math.max(1.0, size.height - top - bottom);
    final peak = timeline.fold<int>(0, (maxValue, point) => math.max(maxValue,
        math.max(point['a'] ?? 0, point['b'] ?? 0)));
    final yMax = math.max(1, peak);
    final xMax = math.max(1, timeline.length - 1);
    final origin = Offset(left, top + height);
    final grid = Paint()..color = Colors.white24..strokeWidth = 0.8;
    for (var i = 0; i <= 4; i++) {
      final y = top + height - (height * i / 4);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final label = TextPainter(
        text: TextSpan(text: '${(yMax * i / 4).round()}',
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(math.max(0, left - label.width - 6), y - 6));
    }
    if (timeline.length < 2) return;
    for (final entry in [(key: 'a', color: lime), (key: 'b', color: cyan)]) {
      final path = Path();
      for (var i = 0; i < timeline.length; i++) {
        final value = timeline[i][entry.key] ?? 0;
        final x = origin.dx + width * i / xMax;
        final y = origin.dy - height * value / yMax;
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, Paint()
        ..color = entry.color..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
    final label = TextPainter(text: TextSpan(
      text: '${timeline.length - 1} punti',
      style: const TextStyle(color: Colors.white60, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(math.max(left, left + width - label.width), size.height - 15));
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      !identical(timeline, oldDelegate.timeline);
}
