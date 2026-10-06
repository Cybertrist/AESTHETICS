import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import 'program_plan.dart';

/// Ce que la progression change pour un exercice, en clair.
class Ajustement {
  const Ajustement(this.exerciseId, this.texte);
  final String exerciseId;
  final String texte;
}

/// Routine réellement prévue pour la séance du programme : charges et
/// répétitions ajustées selon le plan et la dernière performance.
class RoutineDuJour {
  const RoutineDuJour(this.routine, this.ajustements, {this.decharge = false, this.phase});
  final Routine routine;
  final List<Ajustement> ajustements;
  final bool decharge;

  /// Lourd, moyen ou léger (progression ondulée).
  final String? phase;
}

/// Phase de la semaine en progression ondulée : (nom, reps, RPE visé).
({String nom, int reps, double rpe}) phaseOndulee(int semaine) => switch (semaine % 3) {
      0 => (nom: 'Semaine lourde', reps: 5, rpe: 8.5),
      1 => (nom: 'Semaine moyenne', reps: 8, rpe: 8),
      _ => (nom: 'Semaine légère', reps: 12, rpe: 7),
    };

/// Applique le plan d'un programme à une routine.
RoutineDuJour appliquerProgression({
  required Routine routine,
  required ProgramPlan plan,
  required int semaine,
  required SessionRepo sessions,
  required Exercise? Function(String) lookup,
}) {
  final decharge = plan.estDecharge(semaine);
  final pas = plan.incrementKg <= 0 ? 2.5 : plan.incrementKg;
  final ajustements = <Ajustement>[];
  final ondule = plan.progression == ProgressionType.ondulee ? phaseOndulee(semaine) : null;

  final exercices = <RoutineExercise>[];
  for (final re in routine.exercices) {
    final ex = lookup(re.exerciseId);
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    final dernier = sessions.lastFor(re.exerciseId);
    final faites = dernier?.seriesFaites.where((s) => s.type.counts).toList() ?? const <WorkoutSet>[];
    var series = [...re.series];
    String? note;
    // Aux haltères, on ne charge pas un pas de disques : on prend l'haltère
    // suivant du râtelier, et tout arrondi tombe sur un haltère qui existe.
    final halteres = ex?.auxHalteres ?? false;
    double plus(double? base) => halteres && base != null ? Strength.haltereSuivant(base) - base : pas;
    double arrondi(double kg) => halteres ? Strength.arrondirHaltere(kg) : Strength.arrondir(kg, pas);
    final hausse = halteres ? 'haltère suivant' : '+${Fmt.n(pas)} kg';

    if (suivi.usesWeight && plan.progression != ProgressionType.aucune && faites.isNotEmpty) {
      switch (plan.progression) {
        case ProgressionType.charge:
          final reussi = _toutReussi(re.series, faites, (p) => p.reps);
          series = [
            for (var i = 0; i < series.length; i++)
              series[i].type.counts ? _avecPoids(series[i], _poidsBase(series[i], i, faites), reussi ? plus(_poidsBase(series[i], i, faites)) : 0) : series[i],
          ];
          note = reussi ? 'Réussi la dernière fois : $hausse' : 'Même charge, objectif : toutes les répétitions';
        case ProgressionType.doubleProgression:
          final haut = _toutReussi(re.series, faites, (p) => p.repsMax ?? p.reps);
          series = [
            for (var i = 0; i < series.length; i++)
              if (!series[i].type.counts)
                series[i]
              else if (haut)
                _avecPoids(series[i], _poidsBase(series[i], i, faites), plus(_poidsBase(series[i], i, faites))).copyWith(reps: series[i].reps)
              else
                _avecPoids(series[i], _poidsBase(series[i], i, faites), 0).copyWith(
                  reps: _repsCible(series[i], i < faites.length ? faites[i].reps : faites.last.reps),
                ),
          ];
          note = haut ? 'Haut de fourchette atteint : $hausse' : 'Une répétition de plus que la dernière fois';
        case ProgressionType.ondulee:
          final unRm = faites.map((s) => s.poids == null || s.reps == null ? 0.0 : Strength.oneRepMax(s.poids!, s.reps!)).fold(0.0, (a, b) => a > b ? a : b);
          if (unRm > 0) {
            final kg = arrondi(Strength.poidsPourReps(unRm, ondule!.reps) * 0.92);
            series = [
              for (final s in series)
                s.type.counts ? PlannedSet(type: s.type, poids: kg, reps: ondule.reps, rpe: ondule.rpe, dureeSec: s.dureeSec, distanceM: s.distanceM) : s,
            ];
            note = '${ondule.nom} : ${ondule.reps} reps à ${Fmt.n(kg)} kg';
          }
        case ProgressionType.aucune:
          break;
      }
    } else if (ondule != null) {
      series = [for (final s in series) s.type.counts && suivi.usesReps ? s.copyWith(reps: ondule.reps, rpe: ondule.rpe) : s];
    }

    if (decharge) {
      final travail = series.where((s) => s.type.counts).toList();
      final garder = (travail.length / 2).ceil().clamp(1, 99);
      var vus = 0;
      series = [
        for (final s in series)
          if (!s.type.counts)
            s
          else if (vus++ < garder)
            PlannedSet(
              type: s.type == SetType.echec ? SetType.normale : s.type,
              poids: s.poids == null ? null : arrondi(s.poids! * 0.9),
              reps: s.reps,
              repsMax: s.repsMax,
              dureeSec: s.dureeSec,
              distanceM: s.distanceM,
              rpe: s.rpe == null ? null : (s.rpe! - 2).clamp(5, 10).toDouble(),
            ),
      ];
      note = 'Décharge : moitié des séries, charge à 90 %';
    }

    if (note != null) ajustements.add(Ajustement(re.exerciseId, note));
    exercices.add(re.copyWith(series: series));
  }

  return RoutineDuJour(
    routine.copyWith(exercices: exercices),
    ajustements,
    decharge: decharge,
    phase: ondule?.nom,
  );
}

double? _poidsBase(PlannedSet s, int i, List<WorkoutSet> faites) {
  final prev = (i < faites.length ? faites[i] : faites.last).poids;
  if (prev == null) return s.poids;
  if (s.poids != null && s.poids! > prev) return s.poids;
  return prev;
}

PlannedSet _avecPoids(PlannedSet s, double? base, double plus) =>
    base == null ? s : PlannedSet(type: s.type, poids: base + plus, reps: s.reps, repsMax: s.repsMax, dureeSec: s.dureeSec, distanceM: s.distanceM, rpe: s.rpe);

int? _repsCible(PlannedSet s, int? derniere) {
  if (s.reps == null) return null;
  final max = s.repsMax ?? s.reps!;
  if (derniere == null) return s.reps;
  return (derniere + 1).clamp(s.reps!, max);
}

/// Vrai si chaque série de travail a atteint la cible la dernière fois.
bool _toutReussi(List<PlannedSet> prevues, List<WorkoutSet> faites, int? Function(PlannedSet) cible) {
  final travail = prevues.where((s) => s.type.counts).toList();
  if (travail.isEmpty || faites.length < travail.length) return false;
  for (var i = 0; i < travail.length; i++) {
    final c = cible(travail[i]);
    if (c == null) continue;
    if ((faites[i].reps ?? 0) < c) return false;
  }
  return true;
}
