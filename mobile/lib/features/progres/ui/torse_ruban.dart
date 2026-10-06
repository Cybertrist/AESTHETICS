import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../sante/recuperation/recup_calcul.dart';

/// Le torse du personnage, un mètre ruban passé autour de la taille :
/// l'image de la tuile Mensurations.
class TorseRuban extends StatelessWidget {
  const TorseRuban({super.key, this.cote = 92});
  final double cote;

  @override
  Widget build(BuildContext context) {
    // Même cadrage que la vignette des abdominaux, sans muscle allumé.
    final (vue, cadre) = Recup.cadrage(Muscle.abdominaux);
    final (zoom, centreY) = Recup.zoom(Muscle.abdominaux);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cote * 0.2),
      child: SizedBox.square(
        dimension: cote,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Le ruban fait le tour : sa moitié arrière passe derrière le corps.
            const CustomPaint(painter: RubanPainter(arriere: true)),
            Transform.scale(
              scale: zoom,
              alignment: Alignment(0, centreY),
              child: BodyMap(view: vue, framing: cadre, height: cote, intensities: const {}, highlight: context.colors.text),
            ),
            const CustomPaint(painter: RubanPainter()),
          ],
        ),
      ),
    );
  }
}

/// Le mètre ruban de couturière : un anneau jaune gradué autour de la
/// taille, vu d'un peu au-dessus. [arriere] dessine la moitié qui passe
/// derrière le corps ; sinon la moitié de devant.
class RubanPainter extends CustomPainter {
  const RubanPainter({this.arriere = false});
  final bool arriere;

  static const _clair = Color(0xFFFFDC5E);
  static const _jaune = Color(0xFFF7BE22);
  static const _ombre = Color(0xFFA87300);
  static const _envers = Color(0xFF7A5400);
  static const _encre = Color(0xFF2E2100);

  @override
  void paint(Canvas canvas, Size size) {
    final l = size.width;
    final u = size.height;
    final epaisseur = u * 0.12;
    // L'anneau : une ellipse serrée sur la taille.
    final centre = Offset(l * 0.507, u * 0.565);
    final rx = l * 0.288;
    final ry = u * 0.058;
    Offset point(double angle) => centre + Offset(rx * math.cos(angle), ry * math.sin(angle));

    // Une moitié de l'anneau : le bord haut suit l'ellipse, le bord bas est
    // le même, plus bas de l'épaisseur du ruban.
    Path moitie(double de, double a) {
      const pas = 40;
      final haut = [for (var i = 0; i <= pas; i++) point(de + (a - de) * i / pas)];
      return Path()..addPolygon([...haut, for (final p in haut.reversed) p.translate(0, epaisseur)], true);
    }

    Path arc(double de, double a, double dy) {
      const pas = 40;
      final p = Path();
      for (var i = 0; i <= pas; i++) {
        final o = point(de + (a - de) * i / pas).translate(0, dy);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    if (arriere) {
      // L'envers du ruban, dans l'ombre : on ne le voit qu'entre le torse et les bras.
      final dos = moitie(math.pi, 2 * math.pi);
      final cadre = dos.getBounds();
      canvas.drawPath(
        dos,
        Paint()
          ..shader = ui.Gradient.linear(
            cadre.centerLeft,
            cadre.centerRight,
            const [_ombre, _envers, _envers, _ombre],
            const [0, 0.14, 0.86, 1],
          ),
      );
      return;
    }

    final trait = Paint()
      ..strokeWidth = u * 0.0085
      ..color = _encre.withValues(alpha: 0.82);

    // La moitié de devant, par-dessus le ventre.
    final devant = moitie(0, math.pi);
    final cadre = devant.getBounds();
    canvas.drawPath(
      devant.shift(Offset(0, u * 0.022)),
      Paint()
        ..color = const Color(0x73000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.022),
    );
    // Claire de face, sombre là où elle tourne vers l'arrière.
    canvas.drawPath(
      devant,
      Paint()
        ..shader = ui.Gradient.linear(
          cadre.centerLeft,
          cadre.centerRight,
          const [_ombre, _jaune, _clair, _jaune, _ombre],
          const [0, 0.15, 0.5, 0.85, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(devant);
    // Un reflet sur le bord haut, un liseré sombre sur le bord bas.
    final lisere = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.012;
    canvas.drawPath(arc(0, math.pi, 0), lisere..color = const Color(0x99FFF3B8));
    canvas.drawPath(arc(0, math.pi, epaisseur), lisere..color = const Color(0x80694700));
    // Les graduations : à angle égal, donc plus serrées vers les côtés.
    const traits = 36;
    for (var i = 1; i < traits; i++) {
      final depart = point(math.pi * i / traits);
      final long = epaisseur * (i % 4 == 0 ? 0.56 : (i.isEven ? 0.38 : 0.24));
      canvas.drawLine(depart, depart.translate(0, long), trait);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RubanPainter old) => old.arriere != arriere;
}
