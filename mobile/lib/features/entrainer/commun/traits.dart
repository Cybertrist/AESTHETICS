import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/theme/theme.dart';

/// Icônes au trait de la maquette qui ne sont pas dans le noyau.
enum Trait {
  plus(22, 1.7),
  plusFort(18, 2),
  signet(22, 1.7),
  chevronDroit(14, 2),
  chevronBas(14, 2),
  retour(18, 2),
  partager(22, 1.7),
  points(18, 0, plein: true),
  crayon(22, 1.7),
  image(22, 1.7),
  dupliquer(22, 1.7),
  deplacer(22, 1.7),
  corbeille(22, 1.7),
  horloge(14, 1.4),
  horlogeGrande(22, 1.7),
  calendrier(22, 1.8),
  lecture(14, 0, plein: true),
  loupe(14, 1.8),
  historique(22, 1.7),
  personne(22, 1.7),
  corps(22, 1.7),
  trier(22, 1.7),
  liste(22, 2),
  grille(22, 1.7),
  pause(22, 1.7),
  lectureCercle(22, 1.7),
  pleinEcran(22, 1.7),
  remplacer(22, 1.7),
  medaille(24, 2),
  appareil(22, 1.7),
  fermer(22, 1.9),
  coche(22, 2),
  lien(22, 1.8),
  lienCoupe(22, 1.8),
  dossier(22, 1.7);

  const Trait(this.cadre, this.epaisseur, {this.plein = false});

  /// Côté du cadre de dessin.
  final double cadre;
  final double epaisseur;
  final bool plein;
}

Path _rond(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
Path _rect(double x, double y, double w, double h, double r) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));

Path _chemin(Trait t) {
  Path p(String d) => parseSvgPathData(d);
  return switch (t) {
    Trait.plus => p('M11 4.5v13M4.5 11h13'),
    Trait.plusFort => p('M9 3.5v11M3.5 9h11'),
    Trait.signet => p('M6.5 3.5h9v15l-4.5-3.5-4.5 3.5z'),
    Trait.chevronDroit => p('M5 2.5L9.5 7 5 11.5'),
    Trait.chevronBas => p('M3 5l4 4 4-4'),
    Trait.retour => p('M11 3.5L5.5 9l5.5 5.5'),
    Trait.partager => p('M12.5 4.5L18.5 10l-6 5.5v-3.3c-4 0-6.8 1-8.5 4 0-4.8 2.5-8.3 8.5-8.5z'),
    Trait.points => _rond(9, 3.8, 1.5)
      ..addPath(_rond(9, 9, 1.5), Offset.zero)
      ..addPath(_rond(9, 14.2, 1.5), Offset.zero),
    Trait.crayon => p('M4 18l1-4L15 4l3 3L8 17zM13 6l3 3'),
    Trait.image => _rect(3.5, 4.5, 15, 13, 2.5)
      ..addPath(_rond(8.5, 9.5, 1.5), Offset.zero)
      ..addPath(p('M4.5 16l4.5-4 3 2.5 2.5-2 3.5 3'), Offset.zero),
    Trait.dupliquer => _rect(7.5, 7.5, 11, 11, 2.5)..addPath(p('M14.5 4.5h-8a2 2 0 0 0-2 2v8'), Offset.zero),
    Trait.deplacer => _rect(3.5, 6.5, 15, 12, 2.5)..addPath(p('M8 12.5h6M11.5 10l2.5 2.5-2.5 2.5M6 3.8h10'), Offset.zero),
    Trait.corbeille => p('M4.5 6.5h13M9 6.5V4.2h4v2.3M6.5 6.5l.8 11.3h7.4l.8-11.3'),
    Trait.horloge => _rond(7, 7, 5.5)..addPath(p('M7 4v3l2 1.2'), Offset.zero),
    Trait.horlogeGrande => _rond(11, 11, 7.5)..addPath(p('M11 7v4l2.5 1.5'), Offset.zero),
    Trait.calendrier => _rect(3.5, 4.5, 15, 14, 2.5)..addPath(p('M3.5 9h15M7.5 2.8v3M14.5 2.8v3'), Offset.zero),
    Trait.lecture => p('M4 2.2v9.6L12 7z'),
    Trait.loupe => _rond(6, 6, 4.2)..addPath(p('M9.3 9.3l3 3'), Offset.zero),
    Trait.historique => p('M4 11a7 7 0 1 0 2.2-5.1M4 4.5v3.5h3.5M11 7.5V11l2.5 1.5'),
    Trait.personne => _rond(11, 7.5, 3.5)..addPath(p('M4 19c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5'), Offset.zero),
    Trait.corps => _rond(11, 5, 2)..addPath(p('M5 9h12M11 9v10M8 19l3-6 3 6'), Offset.zero),
    Trait.trier => p('M7 4v14M4 7l3-3 3 3M15 18V4M12 15l3 3 3-3'),
    Trait.liste => p('M8 6h10M8 11h10M8 16h10M4 6h.2M4 11h.2M4 16h.2'),
    Trait.grille => _rect(4, 4, 5.5, 5.5, 1.5)
      ..addPath(_rect(12.5, 4, 5.5, 5.5, 1.5), Offset.zero)
      ..addPath(_rect(4, 12.5, 5.5, 5.5, 1.5), Offset.zero)
      ..addPath(_rect(12.5, 12.5, 5.5, 5.5, 1.5), Offset.zero),
    Trait.pause => _rond(11, 11, 8)..addPath(p('M9 8v6M13 8v6'), Offset.zero),
    Trait.lectureCercle => _rond(11, 11, 8)..addPath(p('M9.5 7.8v6.4l5-3.2z'), Offset.zero),
    Trait.pleinEcran => p('M4 8V4h4M14 4h4v4M18 14v4h-4M8 18H4v-4'),
    Trait.remplacer => p('M5 9a6.5 6.5 0 0 1 11.5-2.5M17 13a6.5 6.5 0 0 1-11.5 2.5'),
    // Dessinée dans un cadre de 22 sur 24 : on la centre dans le carré de 24.
    Trait.medaille => (p('M5.5 2h4l1.5 3.5L12.5 2h4l-3 7h-5z')..addPath(_rond(11, 15.5, 5.5), Offset.zero)).shift(const Offset(1, 0)),
    Trait.appareil => _rect(3, 5.5, 16, 12.5, 2.5)
      ..addPath(_rond(11, 11.8, 3.2), Offset.zero)
      ..addPath(p('M8 5.5l1.2-2h3.6l1.2 2'), Offset.zero),
    Trait.fermer => p('M5.5 5.5l11 11M16.5 5.5l-11 11'),
    Trait.coche => p('M5 11.5l4 4 8-9'),
    Trait.lien => p('M9.5 12.5a3.6 3.6 0 0 0 5.1 0l2.6-2.6a3.6 3.6 0 0 0-5.1-5.1l-1 1M12.5 9.5a3.6 3.6 0 0 0-5.1 0l-2.6 2.6a3.6 3.6 0 0 0 5.1 5.1l1-1'),
    Trait.lienCoupe => p('M12.1 5.8l1-1a3.6 3.6 0 0 1 5.1 5.1l-1 1M9.9 16.2l-1 1a3.6 3.6 0 0 1-5.1-5.1l1-1M4 4l14 14'),
    Trait.dossier => p('M3.5 6.5A1.5 1.5 0 0 1 5 5h3.6l2 2H17a1.5 1.5 0 0 1 1.5 1.5v8A1.5 1.5 0 0 1 17 18H5a1.5 1.5 0 0 1-1.5-1.5z'),
  };
}

final _cache = <Trait, Path>{};

/// Une icône au trait, à la couleur du thème d'icône courant.
class IconeTrait extends StatelessWidget {
  const IconeTrait(this.trait, {super.key, this.size = 22, this.color, this.epaisseur, this.semanticLabel});

  final Trait trait;
  final double size;
  final Color? color;

  /// Épaisseur dans le cadre de dessin (celle de la maquette par défaut).
  final double? epaisseur;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final couleur = color ?? IconTheme.of(context).color ?? context.colors.text;
    final dessin = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _Peintre(trait, couleur, epaisseur ?? trait.epaisseur)),
    );
    return semanticLabel == null ? ExcludeSemantics(child: dessin) : Semantics(label: semanticLabel, child: dessin);
  }
}

class _Peintre extends CustomPainter {
  _Peintre(this.trait, this.color, this.epaisseur);

  final Trait trait;
  final Color color;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / trait.cadre, size.height / trait.cadre);
    final chemin = _cache.putIfAbsent(trait, () => _chemin(trait));
    final pinceau = Paint()..color = color;
    if (trait.plein) {
      pinceau.style = PaintingStyle.fill;
    } else {
      pinceau
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(chemin, pinceau);
  }

  @override
  bool shouldRepaint(_Peintre old) => old.trait != trait || old.color != color || old.epaisseur != epaisseur;
}
