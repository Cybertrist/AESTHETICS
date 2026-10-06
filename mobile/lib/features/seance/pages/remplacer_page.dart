import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../logic/alternatives.dart';
import '../widgets/habillage.dart';

/// Ouvre « Remplacer un exercice » et rend l'identifiant de l'exercice choisi
/// (null si on referme). [session] : pour écarter les exercices déjà présents.
Future<String?> choisirRemplacant(BuildContext context, SessionExercise se, {WorkoutSession? session}) {
  final actuel = context.read<ExerciseRepo>().byId(se.exerciseId);
  // Exercice inconnu du catalogue : pas d'alternative à calculer, on cherche.
  if (actuel == null) return pickExercise(context, titre: "Remplacer l'exercice", remplace: se.exerciseId);
  return Navigator.of(context, rootNavigator: true).push<String>(MaterialPageRoute(
    builder: (_) => RemplacerPage(
      actuel: actuel,
      exclus: {for (final e in session?.exercices ?? const <SessionExercise>[]) e.exerciseId},
    ),
  ));
}

/// Maquette « Remplacer un exercice » : l'exercice actuel, une alternative
/// mise en avant, les autres en liste.
class RemplacerPage extends StatelessWidget {
  const RemplacerPage({super.key, required this.actuel, this.exclus = const {}});

  final Exercise actuel;
  final Set<String> exclus;

  static String _muscle(Exercise e) => e.musclesPrincipaux.isEmpty ? '' : e.musclesPrincipaux.first.label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    final alts = alternativesPour(actuel, exos.all, exclus: exclus);
    final conseillee = alts.firstOrNull;
    final autres = alts.skip(1).take(4).toList();
    final memeSchema = conseillee != null && actuel.mecanique != null && conseillee.exercise.mecanique == actuel.mecanique;

    Future<void> chercher() async {
      final id = await pickExercise(context, titre: "Remplacer l'exercice", remplace: actuel.id);
      if (id != null && context.mounted) Navigator.of(context).pop(id);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(18)),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Surtitre('Besoin d\'une autre option ?'),
                          SizedBox(height: k(2)),
                          Text(
                            'Remplacer ${actuel.nom}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(20), height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.text),
                          ),
                        ],
                      ),
                    ),
                    BoutonRond(
                      label: 'Fermer',
                      nu: true,
                      onTap: () => Navigator.of(context).pop(),
                      child: Trait(IconeSeance.croix, size: k(18), epaisseur: 2),
                    ),
                  ],
                ),
                SizedBox(height: k(18)),
                _Carte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Surtitre('Exercice actuel')),
                          if (libelleNiveau(actuel.niveau) != null) Pastille(libelleNiveau(actuel.niveau)!),
                        ],
                      ),
                      SizedBox(height: k(10)),
                      _Fiche(exercise: actuel, detail: [Equipements.label(actuel.equipement), _muscle(actuel)].where((t) => t.isNotEmpty).join(' · ')),
                    ],
                  ),
                ),
                if (conseillee == null) ...[
                  SizedBox(height: k(18)),
                  Text(
                    'Aucun exercice proche dans la bibliothèque.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), color: c.text2),
                  ),
                  SizedBox(height: k(12)),
                  BoutonSecondaire(label: 'Chercher dans la bibliothèque', onPressed: chercher),
                ] else ...[
                  SizedBox(height: k(8)),
                  Row(
                    children: [
                      Expanded(child: Divider(height: 1, thickness: 1, color: c.line)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: k(8)),
                        child: Text(
                          memeSchema ? 'Même schéma de mouvement' : 'Mêmes muscles visés',
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10.5), fontWeight: FontWeight.w600, color: c.accent),
                        ),
                      ),
                      Expanded(child: Divider(height: 1, thickness: 1, color: c.line)),
                    ],
                  ),
                  SizedBox(height: k(8)),
                  _Carte(
                    cadre: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Surtitre('Alternative conseillée', accent: true),
                        SizedBox(height: k(10)),
                        _Fiche(
                          exercise: conseillee.exercise,
                          detail: [Equipements.label(conseillee.exercise.equipement), ?libelleNiveau(conseillee.exercise.niveau)].join(' · '),
                        ),
                        SizedBox(height: k(10)),
                        Wrap(spacing: k(5), runSpacing: k(5), children: [for (final r in conseillee.raisons) Pastille(r)]),
                        SizedBox(height: k(10)),
                        BoutonSeance(
                          label: 'Utiliser cet exercice',
                          fond: c.bouton,
                          encre: c.onBouton,
                          hauteur: k(40),
                          onTap: () => Navigator.of(context).pop(conseillee.exercise.id),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: k(8)),
                  _Carte(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Surtitre('Autres exercices proches'),
                        SizedBox(height: k(2)),
                        for (final a in autres)
                          _Ligne(
                            nom: a.exercise.nom,
                            fin: Pastille(Equipements.label(a.exercise.equipement)),
                            onTap: () => Navigator.of(context).pop(a.exercise.id),
                          ),
                        _Ligne(
                          nom: 'Chercher dans la bibliothèque',
                          fin: Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                          onTap: chercher,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child, this.cadre = false});
  final Widget child;
  final bool cadre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.all(k(12)),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(k(16)),
        border: cadre ? Border.all(color: c.text3, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside) : null,
      ),
      child: child,
    );
  }
}

/// Grande vignette, nom et détail gris.
class _Fiche extends StatelessWidget {
  const _Fiche({required this.exercise, required this.detail});
  final Exercise exercise;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(k(11)),
          child: ColoredBox(color: c.surface2, child: ExerciseThumb(exercise, size: k(68))),
        ),
        SizedBox(width: k(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.nom,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13.5), height: 1.3, fontWeight: FontWeight.w700, color: c.text),
              ),
              SizedBox(height: k(2)),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), color: c.text2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.nom, required this.fin, required this.onTap});
  final String nom;
  final Widget fin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.radius8,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: k(34)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w600, color: c.text),
              ),
            ),
            SizedBox(width: k(8)),
            fin,
          ],
        ),
      ),
    );
  }
}
