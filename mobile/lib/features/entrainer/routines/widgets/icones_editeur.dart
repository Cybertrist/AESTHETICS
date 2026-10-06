import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../../core/theme/theme.dart';

/// Icônes au trait des éditeurs (objectifs, progression, réglages),
/// dessinées dans un cadre de 24.
enum Picto {
  muscle,
  force,
  seche,
  fondamentaux,
  condition,
  sport,
  stable,
  monte,
  paliers,
  vague,
  disque,
  lune,
  poignee,
}

Path _rond(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
Path _rect(double x, double y, double w, double h, double r) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));

Path _chemin(Picto p) {
  Path d(String s) => parseSvgPathData(s);
  return switch (p) {
    // Bras fléchi : avant-bras levé, poing fermé, biceps bombé.
    Picto.muscle => d('M21 11.5c-1.2-2.3-3.2-3.5-5.6-3.5-2 0-3.6.9-4.7 2.6l.9-3.6c.3-1.2-.4-2.4-1.6-2.7l-1.9-.5c-1.2-.3-2.4.4-2.7 1.6L3.2 14.5c-.7 2.8 1.2 5.2 4 5.2h9.6c2.4 0 4.2-1.9 4.2-4.2z'
        'M4.9 7.4l6.2 1.6M10.7 10.6c-.5 1.5-.3 2.8.5 3.9'),
    // Barre chargée, deux disques de chaque côté.
    Picto.force => (_rect(5.2, 6, 3.2, 12, 1.3)
      ..addPath(_rect(15.6, 6, 3.2, 12, 1.3), Offset.zero)
      ..addPath(_rect(2, 8.6, 3.2, 6.8, 1.3), Offset.zero)
      ..addPath(_rect(18.8, 8.6, 3.2, 6.8, 1.3), Offset.zero)
      ..addPath(d('M8.4 12h7.2'), Offset.zero)),
    // Flamme et son cœur.
    Picto.seche => d('M12.4 3c.6 3.2-1.4 4.8-3 6.7C8 11.3 7 13 7 14.8c0 3.2 2.2 5.7 5 5.7s5-2.5 5-5.7'
        'c0-1.9-.7-3.5-1.7-4.8-.4 1-1 1.7-1.9 2.1.5-3.1-.2-6.3-1-9.1z'
        'M12 20.5c-1.3 0-2.2-1.1-2.2-2.4 0-1.2.8-2 2.2-3.5 1.4 1.5 2.2 2.3 2.2 3.5 0 1.3-.9 2.4-2.2 2.4z'),
    // Trois couches posées l'une sur l'autre : les bases.
    Picto.fondamentaux => d('M12 3.5l8.5 4.3L12 12.1 3.5 7.8zM3.5 12l8.5 4.3 8.5-4.3M3.5 16.2l8.5 4.3 8.5-4.3'),
    // Cœur traversé par un battement.
    Picto.condition => d('M12 20.2S4.3 15.6 4.3 9.9C4.3 7.1 6.3 5 8.7 5c1.3 0 2.6.7 3.3 1.9C12.7 5.7 14 5 15.3 5'
        'c2.4 0 4.4 2.1 4.4 4.9 0 5.7-7.7 10.3-7.7 10.3z'
        'M7.3 12.2h2.3l1.3-2.6 2.2 5 1.3-2.4h2.3'),
    // Ballon.
    Picto.sport => _rond(12, 12, 8.6)..addPath(d('M3.4 12h17.2M12 3.4v17.2M6 5.9c2.7 2.6 2.7 9.6 0 12.2M18 5.9c-2.7 2.6-2.7 9.6 0 12.2'), Offset.zero),
    Picto.stable => d('M5 9.3h14M5 14.7h14'),
    Picto.monte => d('M3.5 17l5.6-5.6 3.4 3.4 7.2-7.6M15 7.2h4.7v4.7'),
    Picto.paliers => d('M3.5 19.5h4.4V15h4.4v-4.5h4.4V6h3.8'),
    Picto.vague => d('M2.8 12c1.5-4 3-6 4.6-6s3.1 2 4.6 6 3 6 4.6 6 3.1-2 4.6-6'),
    Picto.disque => _rond(12, 12, 8.6)
      ..addPath(_rond(12, 12, 2.4), Offset.zero)
      ..addPath(d('M12 5.8v1.6M12 16.6v1.6M5.8 12h1.6M16.6 12h1.6'), Offset.zero),
    Picto.lune => d('M19.5 14.4A7.8 7.8 0 0 1 9.6 4.5a7.8 7.8 0 1 0 9.9 9.9z'),
    Picto.poignee => d('M5 9h14M5 15h14'),
  };
}

final _cache = <Picto, Path>{};

/// Une icône au trait des éditeurs.
class IconePicto extends StatelessWidget {
  const IconePicto(this.picto, {super.key, this.size = 24, this.color, this.epaisseur = 1.7});

  final Picto picto;
  final double size;
  final Color? color;

  /// Épaisseur du trait à l'écran.
  final double epaisseur;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _PeintrePicto(picto, color ?? IconTheme.of(context).color ?? context.colors.text, epaisseur)),
        ),
      );
}

class _PeintrePicto extends CustomPainter {
  _PeintrePicto(this.picto, this.color, this.epaisseur);

  final Picto picto;
  final Color color;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k, k);
    canvas.drawPath(
      _cache.putIfAbsent(picto, () => _chemin(picto)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur / k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PeintrePicto old) => old.picto != picto || old.color != color || old.epaisseur != epaisseur;
}

/// Trois barres qui se remplissent avec le niveau (1 à 3).
class IconeNiveau extends StatelessWidget {
  const IconeNiveau(this.rang, {super.key, this.size = 26, this.color});

  final int rang;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _PeintreNiveau(rang, color ?? context.colors.text)),
        ),
      );
}

class _PeintreNiveau extends CustomPainter {
  _PeintreNiveau(this.rang, this.color);

  final int rang;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k, k);
    const largeur = 5.4;
    const hauteurs = [8.0, 13.5, 19.0];
    for (var i = 0; i < 3; i++) {
      final plein = i < rang;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(2.2 + i * 7.1, 21.5 - hauteurs[i], largeur, hauteurs[i]).deflate(plein ? 0 : 0.7),
        const Radius.circular(1.3),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = color
          ..style = plein ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_PeintreNiveau old) => old.rang != rang || old.color != color;
}
