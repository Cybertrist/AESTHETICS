import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Petite courbe sans axes, remplissage en dégradé et point final.
class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.values,
    this.height = 40,
    this.width,
    this.color,
    this.fill = true,
    this.strokeWidth = 2,
    this.showLastDot = true,
  });

  final List<double> values;
  final double height;
  final double? width;
  final Color? color;
  final bool fill;
  final double strokeWidth;
  final bool showLastDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: color ?? context.colors.accent,
          fill: fill,
          strokeWidth: strokeWidth,
          dot: showLastDot,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, required this.fill, required this.strokeWidth, required this.dot});

  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;
  final bool dot;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final pad = strokeWidth + (dot ? 2 : 0);
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    Offset pt(int i) => Offset(
          pad + (values.length == 1 ? w / 2 : w * i / (values.length - 1)),
          pad + h - (values[i] - minV) / span * h,
        );

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }

    if (fill && values.length > 1) {
      final area = Path.from(path)
        ..lineTo(pt(values.length - 1).dx, size.height)
        ..lineTo(pt(0).dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (dot) {
      final last = pt(values.length - 1);
      canvas.drawCircle(last, strokeWidth + 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}
