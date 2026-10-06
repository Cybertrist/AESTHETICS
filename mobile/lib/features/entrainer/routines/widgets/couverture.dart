import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_images.dart';
import '../../bibliotheque/widgets/exercise_media.dart';
import '../../commun/corps_colore.dart';
import '../../commun/elements.dart';
import '../../commun/palette.dart';
import '../logic/idees.dart';

/// Couverture carrée d'une idée de programme. Deux zones qui ne se
/// touchent jamais : le personnage aux muscles allumés (ou une pose
/// d'exercice) en haut, le titre et son bandeau en bas. Le titre rétrécit
/// plutôt que de déborder.
class CouvertureIdee extends StatelessWidget {
  const CouvertureIdee(this.idee, {super.key, this.cote = 172});

  final IdeeProgramme idee;
  final double cote;

  /// Part de la hauteur réservée au titre et au bandeau.
  static const partTitre = 0.36;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = cote / 172;
    Widget image;
    if (idee.auPersonnage) {
      image = LayoutBuilder(
        builder: (context, zone) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CorpsColore(view: BodyView.front, height: zone.maxHeight, couleurs: allumer(idee.face)),
            SizedBox(width: 12.5 * k),
            CorpsColore(view: BodyView.back, height: zone.maxHeight, couleurs: allumer(idee.dos)),
          ],
        ),
      );
    } else {
      final repo = context.watch<ExerciseRepo>();
      String? src;
      for (final id in idee.poses) {
        src = poseDe(repo.byId(id));
        if (src != null) break;
      }
      image = src == null ? const SizedBox.shrink() : SizedBox.expand(child: mediaImage(src, cacheWidth: 540));
    }
    return SizedBox.square(
      dimension: cote,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20 * k),
        child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 0.8,
          colors: [PaletteEntrainer.couvertureClair, PaletteEntrainer.couvertureSombre],
          stops: [0, 0.7],
        ),
      ),
      // La couverture est une image : son texte suit la taille de la
      // couverture, pas la taille de police du téléphone.
      child: MediaQuery.withNoTextScaling(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10 * k, 11 * k, 10 * k, 5 * k),
                child: image,
              ),
            ),
            SizedBox(
              height: cote * partTitre,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10 * k, 0, 10 * k, 6 * k),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        idee.gros.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTokens.fontUi,
                          fontSize: 19 * k,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (idee.bandeau != null) ...[
                      SizedBox(height: 6 * k),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          color: c.bouton,
                          padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 4 * k),
                          child: Text(
                            idee.bandeau!.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTokens.fontUi,
                              fontSize: 11.25 * k,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: c.onBouton,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      ),
    );
  }
}

/// Couverture d'un programme : son nom court et un gros signe, sur une
/// tuile grise au reflet léger.
class CouvertureProgramme extends StatelessWidget {
  const CouvertureProgramme(this.nom, {super.key, this.cote = 165});

  final String nom;
  final double cote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = couvertureProgramme(nom);
    return Container(
      width: cote,
      height: cote,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17.5),
        gradient: LinearGradient(
          begin: const Alignment(-0.7, -1),
          end: const Alignment(0.7, 1),
          colors: [c.text.withValues(alpha: 0.2), c.text.withValues(alpha: 0), c.bg.withValues(alpha: 0.3)],
          stops: const [0, 0.48, 1],
        ),
      ),
      decoration: BoxDecoration(
        color: PaletteEntrainer.tuileCouverture,
        borderRadius: BorderRadius.circular(17.5),
        boxShadow: [BoxShadow(color: c.bg.withValues(alpha: 0.5), blurRadius: 36, offset: const Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.haut.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                t.haut,
                maxLines: 1,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 24, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c.text),
              ),
            ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.gros,
              maxLines: 1,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 57.5, height: 1, fontWeight: FontWeight.w800, color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile d'un programme dans une liste : son sigle (« V3 »).
class TuileProgramme extends StatelessWidget {
  const TuileProgramme(this.nom, {super.key});
  final String nom;

  @override
  Widget build(BuildContext context) => Tuile(
        child: Text(
          sigleProgramme(nom),
          maxLines: 1,
          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: context.colors.text),
        ),
      );
}
