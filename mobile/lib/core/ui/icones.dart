import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../models/workout.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Icônes au trait de la maquette (grille de 22, bouts ronds). Elles se
/// dessinent avec [TraitIcone] : `TraitIcone(AppIcone.haltere, size: 24)`.
enum AppIcone {
  /// Onglet Accueil : la maison.
  accueil,

  /// Musculation et onglet Entraîner : l'haltère en diagonale.
  haltere,

  /// Onglet Progrès : le bloc-notes à pince, trois barres dessus.
  progres,

  /// Onglet Profil : la silhouette.
  profil,

  /// Cardio : le cœur.
  coeur,

  /// HIIT : la flamme.
  flamme,

  /// Hybride : les deux flèches en boucle.
  boucle,

  /// Cross-training : l'éclair.
  eclair,

  /// Aviron : le rameur.
  aviron,

  /// Coche d'un choix retenu.
  coche,
}

/// Tracés SVG repris tels quels de la maquette (viewBox 0 0 22 22).
const _traces = <AppIcone, String>{
  AppIcone.accueil: 'M3.5 10.2L11 4l7.5 6.2V18a1 1 0 0 1-1 1h-4v-5.5h-5V19h-4a1 1 0 0 1-1-1z',
  AppIcone.progres: 'M8 5H6.5a2 2 0 0 0-2 2v10.5a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2H14M8 6.5v-2a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2zM8 16v-2.5M11 16v-5.5M14 16v-4',
  AppIcone.profil: 'M4 19c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5',
  AppIcone.coeur: 'M11 18s-6.5-3.8-6.5-8.5A3.5 3.5 0 0 1 11 7.7a3.5 3.5 0 0 1 6.5 1.8C17.5 14.2 11 18 11 18z',
  AppIcone.flamme: 'M11 3c.5 3 4.5 4.5 4.5 9a4.5 4.5 0 0 1-9 0c0-1.8.8-3 2-4 .2 1.2.8 2 1.5 2.2C9.5 7.5 10 5 11 3z',
  AppIcone.boucle: 'M5 9a6.5 6.5 0 0 1 11.5-2.5M17 13a6.5 6.5 0 0 1-11.5 2.5M16.5 3.5v3h-3M5.5 18.5v-3h3',
  AppIcone.eclair: 'M12 2.5L5 12.5h5.2L9.5 19.5l7.5-10h-5.4z',
  AppIcone.aviron: 'M4 18.5h14M6 15.5l3.5-4 3 2.500h3.5M9.5 11.5l5-3',
  AppIcone.coche: 'M5 11.5l4 4 8-9',
};

final _chemins = <AppIcone, Path>{};

Path _chemin(AppIcone icone) => _chemins.putIfAbsent(icone, () {
      if (icone == AppIcone.haltere) {
        // Haltère horizontal, penché ensuite de 45 degrés autour du centre.
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1.8, 8.6, 3, 4.8), const Radius.circular(1.3)))
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4.8, 6, 3.4, 10), const Radius.circular(1.5)))
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(13.8, 6, 3.4, 10), const Radius.circular(1.5)))
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(17.2, 8.6, 3, 4.8), const Radius.circular(1.3)))
          ..moveTo(8.2, 11)
          ..lineTo(13.8, 11);
        final m = Matrix4.identity()
          ..translateByDouble(11, 11, 0, 1)
          ..rotateZ(-math.pi / 4)
          ..translateByDouble(-11, -11, 0, 1);
        return p.transform(m.storage);
      }
      final p = parseSvgPathData(_traces[icone]!);
      if (icone == AppIcone.profil) p.addOval(Rect.fromCircle(center: const Offset(11, 7.5), radius: 3.5));
      if (icone == AppIcone.aviron) p.addOval(Rect.fromCircle(center: const Offset(8, 5.5), radius: 1.8));
      return p;
    });

/// Une icône au trait de la maquette. [epaisseur] est donnée dans la grille
/// de 22 (1,7 dans la barre d'onglets et les listes, 2 dans les pastilles).
class TraitIcone extends StatelessWidget {
  const TraitIcone(this.icone, {super.key, this.size = 24, this.color, this.epaisseur = 1.7, this.semanticLabel});

  final AppIcone icone;
  final double size;

  /// Couleur du trait, par défaut celle de l'`IconTheme`.
  final Color? color;
  final double epaisseur;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final couleur = color ?? IconTheme.of(context).color ?? context.colors.text;
    final dessin = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TraitPainter(icone, couleur, epaisseur)),
    );
    return semanticLabel == null ? ExcludeSemantics(child: dessin) : Semantics(label: semanticLabel, child: dessin);
  }
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.icone, this.color, this.epaisseur);

  final AppIcone icone;
  final Color color;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    canvas.drawPath(
      _chemin(icone),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TraitPainter old) => old.icone != icone || old.color != color || old.epaisseur != epaisseur;
}

/// L'haltère en diagonale (musculation, onglet Entraîner).
class IconeHaltere extends TraitIcone {
  const IconeHaltere({super.key, super.size, super.color, super.epaisseur}) : super(AppIcone.haltere);
}

/// Le cœur du cardio.
class IconeCoeur extends TraitIcone {
  const IconeCoeur({super.key, super.size, super.color, super.epaisseur}) : super(AppIcone.coeur);
}

/// Icône de chaque type de séance.
extension TypeSeanceIcone on TypeSeance {
  AppIcone get icone => switch (this) {
        TypeSeance.musculation => AppIcone.haltere,
        TypeSeance.cardio => AppIcone.coeur,
        TypeSeance.hiit => AppIcone.flamme,
        TypeSeance.hybride => AppIcone.boucle,
        TypeSeance.crossTraining => AppIcone.eclair,
        TypeSeance.aviron => AppIcone.aviron,
      };
}

/// Icône du type d'une séance : haltère pour la musculation, cœur pour le
/// cardio, etc. À poser dans une liste, un panneau ou une pastille.
class IconeTypeSeance extends StatelessWidget {
  const IconeTypeSeance(this.type, {super.key, this.size = 22, this.color, this.epaisseur = 1.7});

  final TypeSeance type;
  final double size;
  final Color? color;
  final double epaisseur;

  @override
  Widget build(BuildContext context) =>
      TraitIcone(type.icone, size: size, color: color, epaisseur: epaisseur, semanticLabel: type.label);
}

/// Le rond d'en-tête d'une carte de séance : cercle gris au contour blanc
/// avec l'icône du type (la même pastille que dans la semaine).
class PastilleTypeSeance extends StatelessWidget {
  const PastilleTypeSeance(this.type, {super.key, this.taille = 44});

  final TypeSeance type;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface2,
        border: Border.all(color: AppTokens.text, width: 1.5),
      ),
      child: IconeTypeSeance(type, size: taille / 2, color: c.text, epaisseur: 2),
    );
  }
}
