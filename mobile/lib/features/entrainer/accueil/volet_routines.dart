import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../seance/seance_paths.dart';
import '../commun/elements.dart';
import '../commun/traits.dart';
import '../routines/logic/suggestion.dart';
import '../routines/logic/vignettes.dart';
import '../routines/widgets/ligne_routine.dart';

/// Volet Routines : la suggestion du jour quand l'appli est sûre d'elle,
/// « Nouvel entraînement », puis toutes les routines.
class VoletRoutines extends StatelessWidget {
  const VoletRoutines({super.key, this.maintenant});

  /// Date de référence (les tests figent le jour).
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final routines = context.watch<RoutineRepo>();
    final sessions = context.watch<SessionRepo>();
    final programmes = context.watch<ProgramRepo>();
    final prefs = RoutinePrefs.of(context.read<Store>());
    final liste = routines.routines;
    final jour = maintenant ?? DateTime.now();

    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final seances = [...sessions.sessions, ?sessions.active];
        final ids = [for (final r in liste) r.id];
        // La première proposition n'apparaît que si l'appli est sûre d'elle.
        // « Une autre » fait ensuite avancer la file des routines plausibles.
        final sure = suggererRoutine(maintenant: jour, seances: seances, routinesConnues: ids.toSet());
        final autre = prefs.suggestionEcartee(jour);
        final ecartees = {...prefs.ecarteesLe(jour), if (autre && prefs.ecarteesLe(jour).isEmpty) ?sure?.routineId};
        final suggestion = !autre
            ? sure
            : suggestionsRoutines(
                maintenant: jour,
                seances: seances,
                routines: ids,
                cycle: programmes.active?.routineIds ?? const [],
              ).where((s) => !ecartees.contains(s.routineId)).firstOrNull;
        final suggeree = suggestion == null ? null : routines.byId(suggestion.routineId);
        return ListView(
          padding: const EdgeInsets.only(top: 12.5, bottom: 28),
          children: [
            if (suggestion != null && suggeree != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 10),
                child: Surtitre(titreSuggestion(suggestion.jour)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 25),
                child: _Suggestion(
                  routine: suggeree,
                  suggestion: suggestion,
                  programme: programmes.programs.where((p) => p.routineIds.contains(suggeree.id)).sorted((a, b) => a.actif == b.actif ? 0 : (a.actif ? -1 : 1)).firstOrNull,
                  onAutre: () => prefs.ecarterSuggestion(jour, suggeree.id),
                ),
              ),
            ] else if (autre && liste.isNotEmpty)
              // Plus rien à proposer : on le dit, plutôt que de retirer le bloc sans un mot.
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 1.5), child: IconeTrait(Trait.calendrier, size: 17.5, color: c.text2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(plusDeSuggestion, style: TexteEntrainer.detail(context).copyWith(fontSize: 13.8))),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 25),
              child: Carte(
                onTap: () => context.push(SeancePaths.vide),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle),
                      child: Padding(padding: const EdgeInsets.only(left: 1.5), child: IconeTrait(Trait.lecture, size: 16, color: c.onBouton)),
                    ),
                    const SizedBox(width: 17.5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nouvel entraînement', style: TexteEntrainer.ligneForte(context)),
                          Text('Ajoute des exercices et commence le suivi', style: TexteEntrainer.detail(context).copyWith(fontSize: 13.8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 17.5),
                    IconeTrait(Trait.chevronDroit, size: 17.5, color: c.text3),
                  ],
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 12.5), child: Surtitre('Tes routines')),
            if (liste.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 12.5),
                child: Text(
                  'Une routine garde tes exercices et tes séries, prêts à lancer. Crée la première, ou pars d’une idée de programme.',
                  style: TexteEntrainer.detail(context),
                ),
              ),
            for (final (i, r) in liste.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 12.5),
                child: LigneRoutine(routine: r, rang: rangDansProgramme(programmes.programs)[r.id] ?? i),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: margeEcran),
              child: InkWell(
                onTap: () => context.push('/entrainer/routines/nouvelle'),
                borderRadius: BorderRadius.circular(15),
                child: Row(
                  children: [
                    const Tuile(taille: 68, rayon: 15, child: IconeTrait(Trait.plus, size: 25)),
                    const SizedBox(width: 15),
                    Expanded(child: Text('Créer une routine', style: TexteEntrainer.ligne(context))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Carte de la suggestion : la carte du jour, la routine, la raison écrite,
/// puis Commencer et Une autre.
class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.routine, required this.suggestion, required this.programme, required this.onAutre});

  final Routine routine;
  final SuggestionRoutine suggestion;
  final Program? programme;
  final VoidCallback onAutre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final detail = [
      Fmt.pluriel(routine.exercices.length, 'exercice'),
      Fmt.duree(Duration(minutes: routine.dureeEstimeeMin)),
    ].join(' · ');
    final gris = TexteEntrainer.detail(context).copyWith(fontSize: 13.8);
    return Carte(
      rayon: 22.5,
      cadre: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              VignetteRoutineVue(routine: routine, rang: 0, jour: suggestion.jour, fond: c.surface),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 20, height: 1.3, fontWeight: FontWeight.w800, color: c.text),
                    ),
                    // Deux lignes entières, sans point de liaison en fin de
                    // ligne : le programme (coupé s'il est long), puis le
                    // nombre d'exercices et la durée.
                    if (programme != null) Text(programme!.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1.5), child: IconeTrait(Trait.calendrier, size: 17.5, color: c.text2)),
              const SizedBox(width: 10),
              Expanded(child: Text(raisonSuggestion(suggestion), style: gris)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: BoutonPrincipal(
                  label: 'Commencer',
                  onPressed: () => lancerRoutine(context, routine, programId: programme?.id),
                ),
              ),
              const SizedBox(width: 10),
              IntrinsicWidth(child: BoutonSecondaire(label: 'Une autre', onPressed: onAutre)),
            ],
          ),
        ],
      ),
    );
  }
}

/// La place de chaque routine dans son programme (l'actif d'abord) : sa
/// carte de jour reste la même ici que sur la page du programme, où la
/// première routine est « Lun », la deuxième « Mar »...
Map<String, int> rangDansProgramme(List<Program> programmes) {
  final rangs = <String, int>{};
  for (final p in [...programmes.where((p) => p.actif), ...programmes.where((p) => !p.actif)]) {
    for (final (i, id) in p.routineIds.indexed) {
      rangs.putIfAbsent(id, () => i);
    }
  }
  return rangs;
}
