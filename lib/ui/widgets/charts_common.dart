import 'dart:math' as math;
import 'package:flutter/material.dart';

const _inkDim = Color(0xFF64748B);

class DonutSlice {
  final Color color;
  final int value;
  const DonutSlice({required this.color, required this.value});
}

class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double strokeWidth;
  final double radiusFactor;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.slices,
    this.strokeWidth = 28,
    this.radiusFactor = .42,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(slices: slices, strokeWidth: strokeWidth, radiusFactor: radiusFactor),
      child: Center(child: center),
    );
  }
}

class LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const LegendDot(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _inkDim)),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double strokeWidth;
  final double radiusFactor;

  _DonutPainter({required this.slices, required this.strokeWidth, required this.radiusFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (p, s) => p + s.value);
    if (total == 0) return;

    final center = (Offset.zero & size).center;
    final radius = size.shortestSide * radiusFactor;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = s.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }

    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - (strokeWidth * .64), inner);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.strokeWidth != strokeWidth || old.radiusFactor != radiusFactor;
}
