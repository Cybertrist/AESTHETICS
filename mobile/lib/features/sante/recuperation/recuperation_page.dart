import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../progres/progres_paths.dart';
import '../../progres/ui/communs.dart';
import 'recup_calcul.dart';
import 'tous_muscles_page.dart';

/// Récupération musculaire : un anneau global, six vignettes de muscles
/// (vert si prêt, ambre sinon), « Tout afficher » et le groupe conseillé.
class RecuperationPage extends StatelessWidget {
  const RecuperationPage({super.key, this.maintenant});

  /// Date du jour, pour les tests.
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final etats = Recup.etats(sessions, exos.byId, now: maintenant);
    final vignettes = Recup.vignettes(etats);
    final conseil = Recup.conseil(etats, sessions, exos.byId);

    // Sur un téléphone, tout tient sur un écran : les vignettes prennent la
    // place qui reste, et le groupe conseillé se lit sans défiler. Si la
    // place manque vraiment (écran très bas, texte agrandi), la page défile.
    return PageProgres(
      child: LayoutBuilder(
        builder: (context, box) {
          final serre = box.maxHeight < 700;
          final entete = Padding(
            padding: EdgeInsets.fromLTRB(Cotes.marge, serre ? 8 : 12.5, Cotes.marge, serre ? 0 : 12.5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Récupération', style: ts(25, FontWeight.w700, c.text, hauteur: 1.35, espace: -0.25)),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text('Les muscles prêts pour l\'entraînement', style: ts(15, FontWeight.w400, c.text2, hauteur: 1.35)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnneauRecup(pourcentage: Recup.global(etats), taille: serre ? 80 : 95),
              ],
            ),
          );
          Widget grille({required bool souple}) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
                child: GrilleMuscles(
                  vignettes: vignettes,
                  souple: souple,
                  onMuscle: (m) => context.go(ProgresPaths.explorateur(m.name)),
                ),
              );
          final ligne = Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Row(
              children: [
                Expanded(
                  child: Text('${vignettes.length} muscles sur ${etats.length}', style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  // Navigation directe : la page marche dans l'onglet Progrès
                  // comme en plein écran.
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TousLesMusclesPage(maintenant: maintenant))),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: serre ? 10 : 15, horizontal: 2),
                    child: Text('Tout afficher', style: ts(15, FontWeight.w600, c.text, hauteur: 1.35)),
                  ),
                ),
              ],
            ),
          );
          final conseille = Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Carte(
              padding: EdgeInsets.all(serre ? 12.5 : 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SurTitre('Conseillé aujourd\'hui'),
                        const SizedBox(height: 4),
                        Text(Recup.groupeLabel(conseil.groupe), style: ts(17.5, FontWeight.w700, c.text, hauteur: 1.35)),
                        Text(Recup.phrase(conseil), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // L'explorateur de muscles, ouvert sur le muscle conseillé.
                  _BoutonVoir(
                    groupe: Recup.groupeLabel(conseil.groupe),
                    hauteur: serre ? 48 : 55,
                    onTap: () => context.go(ProgresPaths.explorateur(conseil.phare.name)),
                  ),
                ],
              ),
            ),
          );
          final agrandi = MediaQuery.textScalerOf(context).scale(10) > 11.5;
          if (box.maxHeight < 440 || agrandi) {
            return ListView(
              padding: EdgeInsets.only(bottom: basDePage(context)),
              children: [entete, const SizedBox(height: 12), grille(souple: false), const SizedBox(height: 4), ligne, const SizedBox(height: 6), conseille],
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                entete,
                SizedBox(height: serre ? 10 : Cotes.bloc),
                // Jamais plus hautes que leur taille naturelle.
                Flexible(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: GrilleMuscles.hauteurNaturelle(vignettes.length)), child: grille(souple: true))),
                SizedBox(height: serre ? 2 : 12.5),
                ligne,
                SizedBox(height: serre ? 4 : 12.5),
                conseille,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bouton blanc « Voir », à la largeur de son libellé.
class _BoutonVoir extends StatelessWidget {
  const _BoutonVoir({required this.onTap, required this.groupe, this.hauteur = 55});
  final VoidCallback onTap;
  final String groupe;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Voir les exercices conseillés : $groupe',
      excludeSemantics: true,
      child: Material(
        color: c.bouton,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: hauteur,
            padding: const EdgeInsets.symmetric(horizontal: 22.5),
            alignment: Alignment.center,
            child: Text('Voir', style: ts(16, FontWeight.w700, c.onBouton)),
          ),
        ),
      ),
    );
  }
}

/// Grille de vignettes de muscles, trois par ligne.
class GrilleMuscles extends StatelessWidget {
  const GrilleMuscles({super.key, required this.vignettes, required this.onMuscle, this.souple = false});
  final List<(String, EtatRecup)> vignettes;
  final ValueChanged<Muscle> onMuscle;

  /// Les lignes se partagent la hauteur donnée (l'image de chaque vignette
  /// rétrécit) au lieu de prendre leur taille naturelle.
  final bool souple;

  static const parLigne = 3;

  /// Hauteur de la grille quand rien ne la presse.
  static double hauteurNaturelle(int n) {
    final lignes = (n / parLigne).ceil();
    return lignes * 176.0 + (lignes - 1) * Cotes.gouttiere;
  }

  @override
  Widget build(BuildContext context) {
    final lignes = (vignettes.length / parLigne).ceil();
    if (souple) {
      return Column(
        children: [
          for (var l = 0; l < lignes; l++) ...[
            if (l > 0) const SizedBox(height: Cotes.gouttiere),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = l * parLigne; i < (l + 1) * parLigne; i++) ...[
                    if (i > l * parLigne) const SizedBox(width: Cotes.gouttiere),
                    Expanded(
                      child: i < vignettes.length
                          ? VignetteMuscle(label: vignettes[i].$1, etat: vignettes[i].$2, souple: true, onTap: () => onMuscle(vignettes[i].$2.muscle))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var l = 0; l < lignes; l++)
          Padding(
            padding: EdgeInsets.only(top: l == 0 ? 0 : Cotes.gouttiere),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = l * parLigne; i < (l + 1) * parLigne; i++) ...[
                    if (i > l * parLigne) const SizedBox(width: Cotes.gouttiere),
                    Expanded(
                      child: i < vignettes.length
                          ? VignetteMuscle(label: vignettes[i].$1, etat: vignettes[i].$2, onTap: () => onMuscle(vignettes[i].$2.muscle))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un muscle : le buste (ou les jambes) du personnage, le muscle coloré,
/// son nom et son pourcentage. Vert s'il est prêt, ambre sinon.
class VignetteMuscle extends StatelessWidget {
  const VignetteMuscle({super.key, required this.label, required this.etat, this.onTap, this.souple = false});
  final String label;
  final EtatRecup etat;
  final VoidCallback? onTap;

  /// L'image prend la hauteur qui reste dans la vignette (au plus 92).
  final bool souple;

  /// Orange du muscle encore en récupération.
  static const Color ambre = AppTokens.orange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (vue, cadre) = Recup.cadrage(etat.muscle);
    final (zoom, centreY) = Recup.zoom(etat.muscle);
    Widget image(double h) => SizedBox(
          height: h,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Transform.scale(
              scale: zoom,
              alignment: Alignment(0, centreY),
              child: BodyMap(
                view: vue,
                framing: cadre,
                height: h,
                intensities: {etat.muscle: 1},
                highlight: etat.pret ? c.success : ambre,
              ),
            ),
          ),
        );
    return Semantics(
      button: onTap != null,
      label: '$label, récupéré à ${etat.pourcentage} %',
      excludeSemantics: true,
      child: Carte(
        rayon: Cotes.rTuile,
        padding: souple ? const EdgeInsets.fromLTRB(7.5, 10, 7.5, 9) : const EdgeInsets.fromLTRB(7.5, 12.5, 7.5, 11),
        onTap: onTap,
        child: Column(
          children: [
            if (souple)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Align(alignment: Alignment.bottomCenter, child: image(box.maxHeight.clamp(0.0, 92.0))),
                ),
              )
            else
              image(92),
            SizedBox(height: souple ? 6 : 7.5),
            Text(label, maxLines: souple ? 1 : 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w600, c.text, hauteur: 1.35)),
            SizedBox(height: souple ? 6 : 7.5),
            Pastille('${etat.pourcentage} %', ton: etat.pret ? TonPastille.ok : TonPastille.alerte, grande: true),
          ],
        ),
      ),
    );
  }
}
