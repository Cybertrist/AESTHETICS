import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Anneau de progression animé, avec un contenu au centre. Piste grise
/// #3A3A3C, bout arrondi, et deux filets fins autour quand [rings] est
/// vrai.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 72,
    this.stroke = 8,
    this.color,
    this.trackColor,
    this.center,
    this.overflowColor,
    this.rings = false,
  });

  /// 0..1 ; au-delà de 1, un second tour s'affiche en [overflowColor].
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? center;
  final Color? overflowColor;

  /// Filets fins dedans et dehors (grands anneaux d'en-tête).
  final bool rings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.isFinite ? math.max(0, value) : 0),
      duration: AppTokens.slow,
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            color: color ?? c.accent,
            track: trackColor ?? c.track,
            overflow: overflowColor ?? c.warning,
            rings: rings,
          ),
          child: Center(child: child),
        ),
      ),
      child: center,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
    required this.overflow,
    required this.rings,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;
  final Color overflow;
  final bool rings;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = rings ? 6.0 : 0.0;
    final inset = stroke / 2 + gap;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    if (rings) {
      final filet = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x0DFFFFFF);
      final c = size.center(Offset.zero);
      canvas.drawCircle(c, rect.width / 2 + stroke / 2 + 5, filet);
      canvas.drawCircle(c, rect.width / 2 - stroke / 2 - 5, filet);
    }
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    const start = -math.pi / 2;
    final first = value.clamp(0.0, 1.0);
    if (first > 0) canvas.drawArc(rect, start, math.pi * 2 * first, false, base..color = color);
    if (value > 1) {
      final extra = (value - 1).clamp(0.0, 1.0);
      canvas.drawArc(rect, start, math.pi * 2 * extra, false, base..color = overflow);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke ||
      old.overflow != overflow ||
      old.rings != rings;
}

/// Barre de progression plate : piste grise #3A3A3C,
/// remplissage de couleur, étiquettes facultatives au-dessus.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
    this.label,
    this.trailing,
  });

  /// 0..1 (bornée).
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = ClipRRect(
      borderRadius: AppTokens.radiusPill,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor ?? c.track),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.isFinite ? value.clamp(0.0, 1.0) : 0),
              duration: AppTokens.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color ?? c.accent, borderRadius: AppTokens.radiusPill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (label == null && trailing == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (label != null)
              Expanded(
                child: Text(label!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, fontWeight: FontWeight.w400, color: c.text)),
              ),
            if (label == null) const Spacer(),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, fontWeight: FontWeight.w400, color: c.text2, fontFeatures: AppTokens.tabular),
              ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
      ],
    );
  }
}

/// Barre coupée en segments colorés arrondis, séparés d'un jour de 3 px
/// (répartition des muscles, des macros). Un segment ne descend pas sous
/// [minFraction] de la barre, pour qu'une petite part reste visible.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({super.key, required this.parts, this.height = 9, this.gap = 3, this.minFraction = 0.025});

  /// Valeur et couleur de chaque segment (les valeurs nulles sont ignorées).
  final List<(double, Color)> parts;
  final double height;
  final double gap;
  final double minFraction;

  @override
  Widget build(BuildContext context) {
    final useful = parts.where((p) => p.$1 > 0).toList();
    if (useful.isEmpty) return ProgressBar(value: 0, height: height);
    final total = useful.fold<double>(0, (s, p) => s + p.$1);
    int flex(double v) => (1000 * math.max(v / total, minFraction)).round();
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < useful.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              flex: flex(useful[i].$1),
              child: DecoratedBox(decoration: BoxDecoration(color: useful[i].$2, borderRadius: AppTokens.radiusPill)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une part de [SegmentRing].
class RingPart {
  const RingPart(this.value, this.color, [this.icon]);

  final double value;
  final Color color;

  /// Icône posée à l'extérieur, au milieu de l'arc.
  final IconData? icon;
}

/// Anneau segmenté : fin, des arcs nets séparés d'un jour,
/// deux filets autour, et l'icône de chaque part posée à l'extérieur dans
/// un petit carré bordé de sa couleur. Contenu libre au centre (un grand
/// chiffre et une étiquette en capitales).
class SegmentRing extends StatelessWidget {
  const SegmentRing({super.key, required this.parts, this.center, this.size = 280, this.stroke = 16, this.minFraction = 0.035});

  final List<RingPart> parts;
  final Widget? center;
  final double size;
  final double stroke;

  /// Part minimale d'un arc, pour qu'une petite part reste visible.
  final double minFraction;

  List<double> _angles() {
    final vals = [for (final p in parts) math.max(p.value, 0.0)];
    final total = vals.fold<double>(0, (s, v) => s + v);
    if (total == 0) return List.filled(vals.length, 0);
    final fr = [for (final v in vals) v / total];
    final small = fr.where((p) => p > 0 && p < minFraction).length;
    final big = fr.where((p) => p >= minFraction).fold<double>(0, (s, p) => s + p);
    final rest = 1 - small * minFraction;
    return [for (final p in fr) p == 0 ? 0 : (p < minFraction ? minFraction : p / big * rest) * 2 * math.pi];
  }

  @override
  Widget build(BuildContext context) {
    final withIcons = parts.any((p) => p.icon != null);
    final radius = withIcons ? size * 0.32 : size / 2 - stroke / 2 - 7;
    final angles = _angles();
    final badges = <Widget>[];
    if (withIcons) {
      var start = -math.pi / 2;
      final r = radius + stroke / 2 + 22;
      final mids = <double>[];
      final shown = <RingPart>[];
      for (var i = 0; i < parts.length; i++) {
        if (angles[i] <= 0) continue;
        mids.add(start + angles[i] / 2);
        shown.add(parts[i]);
        start += angles[i];
      }
      final places = _spread(mids, 34 / r);
      for (var i = 0; i < shown.length; i++) {
        final p = shown[i];
        if (p.icon == null) continue;
        badges.add(Positioned(
          left: size / 2 + math.cos(places[i]) * r - 15,
          top: size / 2 + math.sin(places[i]) * r - 15,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.color.withValues(alpha: 0.4)),
            ),
            child: Icon(p.icon, size: 16, color: p.color),
          ),
        ));
      }
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(size: Size.square(size), painter: _SegmentRingPainter(parts, angles, radius, stroke)),
          ...badges,
          if (center != null) Positioned.fill(child: Center(child: center)),
        ],
      ),
    );
  }

  /// Écarte les icônes voisines trop proches.
  static List<double> _spread(List<double> mids, double minGap) {
    final order = List.generate(mids.length, (i) => i)..sort((a, b) => mids[a].compareTo(mids[b]));
    final a = [for (final i in order) mids[i]];
    for (var pass = 0; pass < 40 && a.length > 1; pass++) {
      var moved = false;
      for (var i = 0; i < a.length; i++) {
        final j = (i + 1) % a.length;
        var d = a[j] - a[i];
        if (j == 0) d += 2 * math.pi;
        if (d < minGap) {
          final push = (minGap - d) / 2;
          a[i] -= push;
          a[j] += push;
          moved = true;
        }
      }
      if (!moved) break;
    }
    final out = List<double>.filled(mids.length, 0);
    for (var k = 0; k < order.length; k++) {
      out[order[k]] = a[k];
    }
    return out;
  }
}

class _SegmentRingPainter extends CustomPainter {
  _SegmentRingPainter(this.parts, this.angles, this.radius, this.stroke);

  final List<RingPart> parts;
  final List<double> angles;
  final double radius;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final filet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x0DFFFFFF);
    canvas.drawCircle(c, radius + stroke / 2 + 5, filet);
    canvas.drawCircle(c, radius - stroke / 2 - 5, filet);
    final rect = Rect.fromCircle(center: c, radius: radius);
    final total = angles.fold<double>(0, (s, a) => s + a);
    if (total == 0) {
      canvas.drawCircle(c, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = AppTokens.surface3);
      return;
    }
    const gap = 3 / 96;
    var start = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      final a = angles[i];
      if (a <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        math.max(a - gap, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = parts[i].color,
      );
      start += a;
    }
  }

  @override
  bool shouldRepaint(_SegmentRingPainter o) => o.parts != parts || o.angles != angles || o.radius != radius;
}

/// Cadran à graduations : un demi-cercle de
/// traits allumés jusqu'à [value], contenu libre dessous.
class TickGauge extends StatelessWidget {
  const TickGauge({super.key, required this.value, this.color, this.width = 126, this.ticks = 25, this.child});

  /// 0..1.
  final double value;
  final Color? color;
  final double width;
  final int ticks;

  /// Sous l'arc (un chiffre, un pourcentage).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final gauge = SizedBox(
      width: width,
      height: width * 0.54,
      child: CustomPaint(painter: _TickPainter(value.clamp(0.0, 1.0), color ?? context.colors.accent, ticks)),
    );
    if (child == null) return gauge;
    return Column(mainAxisSize: MainAxisSize.min, children: [gauge, const SizedBox(height: 6), child!]);
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.value, this.color, this.ticks);

  final double value;
  final Color color;
  final int ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 6);
    final outer = size.width * 0.43;
    final inner = outer - size.width * 0.095;
    for (var i = 0; i < ticks; i++) {
      final a = math.pi + i / (ticks - 1) * math.pi;
      final on = value > 0 && i / (ticks - 1) <= value;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        Paint()
          ..strokeWidth = size.width * 0.025
          ..strokeCap = StrokeCap.round
          ..color = on ? color : AppTokens.track,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter o) => o.value != value || o.color != color || o.ticks != ticks;
}
