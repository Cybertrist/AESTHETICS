import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../seance_paths.dart';
import '../widgets/habillage.dart';

/// Résumé d'une routine avant de la lancer.
class ApercuRoutine {
  const ApercuRoutine({
    required this.nbExercices,
    required this.nbSeries,
    required this.dureeMin,
    required this.intensites,
    this.dernierVolume,
    this.position,
  });

  final int nbExercices;
  final int nbSeries;
  final int dureeMin;

  /// Volume de la dernière séance faite avec cette routine, s'il y en a une.
  final double? dernierVolume;

  /// « Semaine 7 sur 12 · jour 4 » quand la routine vient d'un programme.
  final String? position;

  /// Muscles visés : principaux à 1, secondaires atténués.
  final Map<Muscle, double> intensites;

  static ApercuRoutine calculer(Routine r, {required ExerciseRepo exos, required SessionRepo sessions, Program? programme}) {
    final intens = <Muscle, double>{};
    for (final re in r.exercices) {
      final e = exos.byId(re.exerciseId);
      if (e == null) continue;
      for (final m in e.musclesSecondaires) {
        intens[m] = (intens[m] ?? 0) < 0.55 ? 0.55 : intens[m]!;
      }
      for (final m in e.musclesPrincipaux) {
        intens[m] = 1;
      }
    }
    String? position;
    if (programme != null && programme.routineIds.isNotEmpty) {
      final jour = programme.routineIds.indexOf(r.id);
      position = [
        'Semaine ${programme.semaineCourante + 1} sur ${programme.dureeSemaines}',
        if (jour >= 0) 'jour ${jour + 1}',
      ].join(' · ');
    }
    return ApercuRoutine(
      nbExercices: r.exercices.length,
      nbSeries: r.nbSeries,
      dureeMin: r.dureeEstimeeMin,
      dernierVolume: sessions.lastForRoutine(r.id)?.volume,
      position: position,
      intensites: intens,
    );
  }
}

/// « 4 × 8 · 80 kg » : les séries de travail prévues pour un exercice.
String resumePlan(RoutineExercise re, UnitePoids u) {
  final travail = re.series.where((s) => s.type.counts).toList();
  final l = travail.isEmpty ? re.series : travail;
  if (l.isEmpty) return '';
  final p = l.first;
  final reps = p.reps == null
      ? (p.dureeSec == null ? '' : ' × ${Fmt.chrono(Duration(seconds: p.dureeSec!))}')
      : ' × ${p.repsMax != null && p.repsMax != p.reps ? '${p.reps}-${p.repsMax}' : '${p.reps}'}';
  final charge = p.poids == null || p.poids == 0 ? '' : ' · ${Fmt.poids(p.poids, u)}';
  return '${l.length}$reps$charge';
}

/// Maquette « Lancer la séance » : les muscles visés, la durée, les exercices
/// prévus et le rappel de la dernière fois, puis « Commencer la séance ».
class ApercuPage extends StatelessWidget {
  const ApercuPage({super.key, required this.routineId, this.programId});

  final String routineId;
  final String? programId;

  /// Nombre d'exercices listés avant « et N autres exercices ».
  static const visibles = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    final sessions = context.watch<SessionRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final r = context.watch<RoutineRepo>().byId(routineId);
    if (r == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              const EnTeteSeance(titre: 'Séance'),
              Expanded(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Routine introuvable',
                  message: 'Elle a peut-être été supprimée.',
                  actionLabel: 'Retour',
                  onAction: () => context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final programmes = context.watch<ProgramRepo>();
    final actif = programmes.active;
    // Le programme demandé, sinon le programme en cours s'il contient la routine.
    final programme = programId != null
        ? programmes.programs.where((p) => p.id == programId).firstOrNull
        : (actif != null && actif.routineIds.contains(r.id) ? actif : null);
    final a = ApercuRoutine.calculer(r, exos: exos, sessions: sessions, programme: programme);
    final reste = r.exercices.length - visibles;
    final montres = reste == 1 ? r.exercices : r.exercices.take(visibles).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                EnTeteSeance(
                  titre: r.nom,
                  sousTitre: a.position,
                  onRetour: () => context.canPop() ? context.pop() : context.go('/'),
                  fin: a.dureeMin > 0 ? Pastille('${a.dureeMin} min') : null,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(k(10), k(12), k(10), k(8)),
                          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(18))),
                          alignment: Alignment.center,
                          child: BodyMapDual(intensities: a.intensites, highlight: c.accent, height: k(168), spacing: k(26)),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                        child: TroisChiffres(valeurs: [
                          (Text('${a.nbExercices}'), a.nbExercices > 1 ? 'exercices' : 'exercice'),
                          (Text('${a.nbSeries}'), a.nbSeries > 1 ? 'séries' : 'série'),
                          if (a.dernierVolume != null && a.dernierVolume! > 0)
                            (Text(volumeSeance(a.dernierVolume!, unite)), 'dernier volume')
                          else
                            (Text('${a.dureeMin} min'), 'durée estimée'),
                        ]),
                      ),
                      if (r.exercices.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: k(12)),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
                            child: Column(
                              children: [
                                for (var i = 0; i < montres.length; i++)
                                  _LigneExercice(
                                    exercise: exos.byId(montres[i].exerciseId),
                                    nom: exos.nameOf(montres[i].exerciseId),
                                    detail: resumePlan(montres[i], unite),
                                    filet: i < montres.length - 1 || montres.length < r.exercices.length,
                                    onTap: () => ouvrirFicheExercice(context, montres[i].exerciseId),
                                  ),
                                if (montres.length < r.exercices.length)
                                  Container(
                                    height: k(44),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'et $reste autres exercices',
                                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), fontWeight: FontWeight.w500, color: c.text2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                          child: Text(
                            'Cette routine est vide : la séance démarrera sans exercice.',
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), color: c.text2),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(18)),
                  child: BoutonSeance(
                    label: 'Commencer la séance',
                    fond: c.bouton,
                    encre: c.onBouton,
                    onTap: () => context.pushReplacement(SeancePaths.routine(r.id, programId: programme?.id)),
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

/// Ligne d'un exercice prévu (`.mini`) : vignette, nom, « 4 × 8 · 80 kg ».
class _LigneExercice extends StatelessWidget {
  const _LigneExercice({required this.exercise, required this.nom, required this.detail, required this.filet, required this.onTap});

  final Exercise? exercise;
  final String nom;
  final String detail;
  final bool filet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: k(44),
        decoration: BoxDecoration(border: filet ? Border(bottom: BorderSide(color: c.line)) : null),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(k(8)),
              child: ColoredBox(color: c.surface2, child: ExerciseThumb(exercise, size: k(34))),
            ),
            SizedBox(width: k(10)),
            Expanded(
              child: Text(
                nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), fontWeight: FontWeight.w600, color: c.text),
              ),
            ),
            SizedBox(width: k(10)),
            Text(
              detail,
              maxLines: 1,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11.5), color: c.text2, fontFeatures: AppTokens.tabular),
            ),
          ],
        ),
      ),
    );
  }
}
