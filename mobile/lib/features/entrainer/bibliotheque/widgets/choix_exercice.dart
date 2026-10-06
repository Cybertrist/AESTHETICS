import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_map.dart';
import '../../../../core/ui/ui.dart';
import '../../../sante/recuperation/recup_calcul.dart';
import '../../commun/corps_colore.dart';
import '../pages/exercise_browser.dart' show CategorieRaccourci, MuscleGroup, famillesMateriel;
import 'exercise_media.dart';

/// Les panneaux du bas de l'éditeur d'exercice : type, partie du corps,
/// matériel, muscles. Chacun est une liste, une image à gauche de chaque
/// ligne et une case à droite.

TextStyle _t(double taille, FontWeight poids, Color couleur, {double hauteur = 1.3}) =>
    TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, fontWeight: poids, color: couleur, height: hauteur);

/// Ligne « Détails » de l'éditeur : un libellé, la valeur choisie à droite
/// (en couleur d'accent), ou ce qu'il reste à faire en gris.
class LigneDetail extends StatelessWidget {
  const LigneDetail({super.key, required this.label, required this.valeur, required this.vide, required this.onTap, this.erreur});
  final String label;

  /// Valeur choisie, ou null si rien ne l'est.
  final String? valeur;

  /// Ce qui s'écrit sans valeur (« Facultatif », « À choisir »).
  final String vide;
  final VoidCallback onTap;

  /// Message rouge sous la ligne.
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = erreur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '$label, ${valeur ?? vide}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppTokens.radius12,
              side: BorderSide(color: e != null ? c.error : AppTokens.frame, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(label, style: _t(16, FontWeight.w500, c.text)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          valeur ?? vide,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(15, valeur == null ? FontWeight.w400 : FontWeight.w600, valeur == null ? c.text2 : AccentChoice.bleu.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (e != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(e, style: _t(13.5, FontWeight.w600, c.error)),
          ),
      ],
    );
  }
}

/// Le personnage resserré sur un muscle, dans un rond.
class RondMuscle extends StatelessWidget {
  const RondMuscle({super.key, required this.muscles, required this.vue, required this.cadre, this.zoom = 1, this.centreY = 0, this.teinte = Teinte.principal, this.taille = 58});

  /// Le rond d'un seul muscle, cadré comme dans la récupération.
  factory RondMuscle.de(Muscle m, {Teinte teinte = Teinte.principal, double taille = 58}) {
    final (vue, cadre) = Recup.cadrage(m);
    final (zoom, centreY) = m == Muscle.cou ? (1.7, -1.0) : Recup.zoom(m);
    return RondMuscle(muscles: {m}, vue: vue, cadre: cadre, zoom: zoom, centreY: centreY, teinte: teinte, taille: taille);
  }

  /// Le rond d'un groupe de la rangée des exercices (Pecs, Dos, Cuisses...).
  factory RondMuscle.groupe(MuscleGroup g, {double taille = 58}) =>
      RondMuscle(muscles: g.muscles, vue: g.view, cadre: g.framing, zoom: g.zoom, centreY: g.centreY, taille: taille);

  final Set<Muscle> muscles;
  final BodyView vue;
  final BodyFraming cadre;
  final double zoom;
  final double centreY;
  final Teinte teinte;
  final double taille;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: context.colors.surface3, shape: BoxShape.circle),
        child: IgnorePointer(
          child: Transform.scale(
            scale: zoom,
            alignment: Alignment(0, centreY),
            child: CorpsColore(view: vue, framing: cadre, couleurs: {for (final m in muscles) m: teinte}),
          ),
        ),
      );
}

/// Case à cocher carrée, à droite des lignes.
class _Case extends StatelessWidget {
  const _Case(this.cochee);
  final bool cochee;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppTokens.fast,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: cochee ? c.text : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cochee ? c.text : c.text3, width: 1.6),
      ),
      child: cochee ? Icon(Icons.check_rounded, size: 18, color: c.bg) : null,
    );
  }
}

/// Une ligne de panneau : image, libellé, case.
class _Ligne extends StatelessWidget {
  const _Ligne({required this.image, required this.label, required this.cochee, required this.onTap});
  final Widget image;
  final String label;
  final bool cochee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      checked: cochee,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 58, height: 58, child: Center(child: image)),
              const SizedBox(width: 16),
              Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(16.5, FontWeight.w600, c.text))),
              const SizedBox(width: 12),
              _Case(cochee),
            ],
          ),
        ),
      ),
    );
  }
}

/// La coque commune : poignée, titre, filet, liste qui défile, et un bouton
/// « Valider » quand on peut cocher plusieurs lignes.
class _Coque extends StatelessWidget {
  const _Coque({required this.titre, required this.children, this.onValider});
  final String titre;
  final List<Widget> children;
  final VoidCallback? onValider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.88, maxWidth: 640),
      child: Material(
        color: c.surface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(width: 44, height: 5, decoration: const BoxDecoration(color: AppTokens.poignee, borderRadius: AppTokens.radiusPill)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Text(titre, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(17, FontWeight.w700, c.text)),
              ),
              const Divider(height: 1, thickness: 1, color: PanneauBas.filet),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: children,
                ),
              ),
              if (onValider != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: BoutonPrincipal(label: 'Valider', onPressed: onValider),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> _ouvrir<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: builder,
    );

/// Les muscles, rangés par partie du corps.
const _parties = <(String, List<Muscle>)>[
  ('Poitrine', [Muscle.pectoraux]),
  ('Épaules', [Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.deltoidesPosterieurs]),
  ('Bras', [Muscle.biceps, Muscle.triceps, Muscle.avantBras]),
  ('Dos', [Muscle.trapezes, Muscle.rhomboides, Muscle.grandDorsal, Muscle.lombaires]),
  ('Abdos', [Muscle.abdominaux, Muscle.obliques]),
  ('Jambes', [Muscle.quadriceps, Muscle.ischios, Muscle.fessiers, Muscle.adducteurs, Muscle.abducteurs, Muscle.mollets]),
  ('Cou', [Muscle.cou]),
];

/// « Sélectionner les muscles principaux » (ou secondaires) : chaque muscle
/// sur le personnage, sous le titre de sa partie du corps. Rend la liste
/// cochée, dans l'ordre du panneau, ou null si le panneau est fermé.
Future<List<Muscle>?> choisirMuscles(BuildContext context, {required String titre, required List<Muscle> choisis, Teinte teinte = Teinte.principal}) {
  final sel = {...choisis};
  return _ouvrir<List<Muscle>>(
    context,
    (context) => StatefulBuilder(
      builder: (context, setState) => _Coque(
        titre: titre,
        onValider: () => Navigator.pop(context, [
          for (final (_, muscles) in _parties)
            for (final m in muscles)
              if (sel.contains(m)) m,
        ]),
        children: [
          for (final (partie, muscles) in _parties) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(partie.toUpperCase(), style: _t(12.5, FontWeight.w700, context.colors.text2).copyWith(letterSpacing: 1.1)),
            ),
            for (final m in muscles)
              _Ligne(
                image: RondMuscle.de(m, teinte: teinte),
                label: m.label,
                cochee: sel.contains(m),
                onTap: () => setState(() => sel.contains(m) ? sel.remove(m) : sel.add(m)),
              ),
          ],
        ],
      ),
    ),
  );
}

/// Le groupe du personnage qui illustre une catégorie de la bibliothèque.
const _groupeDe = <String, String>{
  'pectoraux': 'Pecs',
  'dos': 'Dos',
  'epaules': 'Épaules',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'avantBras': 'Avant-bras',
  'jambes': 'Cuisses',
  'ischios': 'Ischios',
  'fessiers': 'Fessiers',
  'mollets': 'Mollets',
  'abdos': 'Abdos',
};

Widget _imageCategorie(BuildContext context, String cle) {
  final c = context.colors;
  final groupe = _groupeDe[cle];
  if (groupe != null) return RondMuscle.groupe(MuscleGroup.all.firstWhere((g) => g.label == groupe));
  if (cle == 'cou') return RondMuscle.de(Muscle.cou);
  if (cle == 'completCorps') {
    return RondMuscle(
      muscles: {Muscle.pectoraux, Muscle.abdominaux, Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.biceps, Muscle.quadriceps},
      vue: BodyView.front,
      cadre: BodyFraming.corps,
    );
  }
  final pose = CategorieRaccourci.all.where((r) => r.categorie == cle).firstOrNull?.pose;
  Widget secours() => TraitIcone(AppIcone.haltere, size: 26, color: c.text3);
  return Container(
    width: 58,
    height: 58,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle),
    child: pose == null ? Center(child: secours()) : mediaImage(pose, cacheWidth: 240, error: (_) => Center(child: secours())),
  );
}

/// « Sélectionner une partie du corps » : où l'exercice se range dans la
/// bibliothèque. Un seul choix, le panneau se ferme dessus.
Future<String?> choisirPartie(BuildContext context, {required String choisie}) => _ouvrir<String>(
      context,
      (context) => _Coque(
        titre: 'Sélectionner une partie du corps',
        children: [
          for (final e in Categories.labels.entries)
            _Ligne(
              image: _imageCategorie(context, e.key),
              label: e.value,
              cochee: e.key == choisie,
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      ),
    );

/// « Sélectionner l'équipement » : le matériel en images. Un seul choix.
Future<String?> choisirEquipement(BuildContext context, {required String choisi}) {
  final images = {for (final (cle, image) in famillesMateriel) cle: image, 'cardio': 'assets/exercises/materiel/cardio.webp', 'autre': 'assets/exercises/materiel/autre.webp'};
  return _ouvrir<String>(
    context,
    (context) {
      final c = context.colors;
      Widget secours() => TraitIcone(AppIcone.haltere, size: 26, color: c.text3);
      return _Coque(
        titre: 'Sélectionner l’équipement',
        children: [
          for (final e in Equipements.labels.entries)
            _Ligne(
              image: images[e.key] == null
                  ? secours()
                  : Image.asset(images[e.key]!, width: 52, height: 52, fit: BoxFit.contain, cacheWidth: 240, errorBuilder: (_, _, _) => secours()),
              label: e.value,
              cochee: e.key == choisi,
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      );
    },
  );
}

/// Un exemple et ce qu'on saisit à chaque série, pour chaque type.
(String, List<String>) _detailType(ExerciseTracking t) => switch (t) {
      ExerciseTracking.poidsReps => ('Développé couché, squat, soulevé de terre', ['KG', 'RÉPS']),
      ExerciseTracking.repsSeules => ('Pompes, relevés de jambes', ['RÉPS']),
      ExerciseTracking.poidsDuCorpsLeste => ('Tractions, dips', ['+KG', 'RÉPS']),
      ExerciseTracking.poidsDuCorpsAssiste => ('Tractions assistées, dips assistés', ['-KG', 'RÉPS']),
      ExerciseTracking.duree => ('Planche, chaise', ['TEMPS']),
      ExerciseTracking.distanceDuree => ('Course, vélo, rameur', ['KM', 'TEMPS']),
      ExerciseTracking.poidsDuree => ('Marche du fermier, planche lestée', ['KG', 'TEMPS']),
    };

/// « Sélectionner le type d'exercice » : ce qu'on note à chaque série.
Future<ExerciseTracking?> choisirType(BuildContext context, {required ExerciseTracking choisi}) => _ouvrir<ExerciseTracking>(
      context,
      (context) {
        final c = context.colors;
        return _Coque(
          titre: 'Sélectionner le type d’exercice',
          children: [
            for (final t in ExerciseTracking.values)
              Semantics(
                button: true,
                selected: t == choisi,
                label: t.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.pop(context, t),
                  child: Container(
                    color: t == choisi ? AccentChoice.bleu.color.withValues(alpha: 0.14) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label, style: _t(17, FontWeight.w700, c.text)),
                        const SizedBox(height: 3),
                        Text('Exemple : ${_detailType(t).$1}', style: _t(14.5, FontWeight.w400, c.text2, hauteur: 1.35)),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (final b in _detailType(t).$2)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(8)),
                                child: Text(b, style: _t(12.5, FontWeight.w800, c.bg, hauteur: 1.1)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
