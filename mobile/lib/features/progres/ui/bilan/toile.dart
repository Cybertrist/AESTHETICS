import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_map.dart';
import '../../../sante/recuperation/recup_calcul.dart';
import '../../logic/bilan_mois.dart';
import 'couleurs.dart';

/// Toile des muscles : un axe par groupe, le personnage au bout de chaque
/// axe, le mois devant et le mois d'avant en gris derrière.
///
/// Cotes de la maquette (boîte de 280 sur 262, centre en 140 ; 131, rayon
/// de 82, personnages à 111 du centre), à l'échelle 1,25.
class ToileMuscles extends StatelessWidget {
  const ToileMuscles({super.key, required this.axes, this.echelle = 1.25});
  final List<AxeToile> axes;
  final double echelle;

  static const _centre = Offset(140, 131);
  static const _rayon = 82.0;
  static const _rayonFigure = 111.0;
  static const _figure = 38.0;

  /// Point d'un axe à la distance [r] du centre (le premier axe en haut,
  /// puis dans le sens des aiguilles).
  static Offset point(int i, int n, double r) {
    final a = -math.pi / 2 + 2 * math.pi * i / n;
    return _centre + Offset(math.cos(a), math.sin(a)) * r;
  }

  /// Largeur utile : du bord gauche de la boîte au bord droit du
  /// personnage le plus à droite (dans la maquette, la boîte de 280 dépasse
  /// de la page, pas les personnages).
  static const _largeurUtile = 268.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => _toile(
          context,
          box.maxWidth.isFinite ? math.min(echelle, box.maxWidth / _largeurUtile) : echelle,
        ),
      );

  Widget _toile(BuildContext context, double k) {
    final n = axes.length;
    final accent = context.colors.accent;
    return SizedBox(
      width: 280 * k,
      height: 262 * k,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _ToilePainter(axes, k))),
          for (final (i, a) in axes.indexed)
            Positioned(
              left: (point(i, n, _rayonFigure).dx - _figure / 2) * k,
              top: (point(i, n, _rayonFigure).dy - _figure / 2) * k,
              child: BodyMap(
                view: Recup.cadrage(a.muscle).$1,
                framing: Recup.cadrage(a.muscle).$2,
                height: _figure * k,
                intensities: {a.muscle: 1},
                highlight: accent,
              ),
            ),
        ],
      ),
    );
  }
}

class _ToilePainter extends CustomPainter {
  _ToilePainter(this.axes, this.k);
  final List<AxeToile> axes;
  final double k;

  Path _polygone(double Function(int i) rayon) {
    final n = axes.length;
    final p = Path();
    for (var i = 0; i < n; i++) {
      final o = ToileMuscles.point(i, n, rayon(i));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(k);
    final n = axes.length;
    if (n < 3) return;
    const r = ToileMuscles._rayon;
    final grille = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = CouleursBilan.toileGrille;
    for (final f in [1.0, 0.66, 0.33]) {
      canvas.drawPath(_polygone((_) => r * f), grille);
    }
    final axe = Paint()
      ..strokeWidth = 1
      ..color = CouleursBilan.toileAxe;
    for (var i = 0; i < n; i++) {
      canvas.drawLine(ToileMuscles._centre, ToileMuscles.point(i, n, r), axe);
    }

    void forme(double Function(AxeToile) valeur, Color couleur, double remplissage, double trait) {
      if (axes.every((a) => valeur(a) <= 0)) return;
      final p = _polygone((i) => r * valeur(axes[i]).clamp(0.0, 1.0));
      canvas.drawPath(p, Paint()..color = couleur.withValues(alpha: remplissage));
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trait
          ..strokeJoin = StrokeJoin.miter
          ..color = couleur,
      );
    }

    forme((a) => a.avant, CouleursBilan.toileAvant, 0.3, 2);
    forme((a) => a.mois, CouleursBilan.toileMois, 0.4, 2.5);
  }

  @override
  bool shouldRepaint(_ToilePainter old) => old.axes != axes || old.k != k;
}
