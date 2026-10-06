import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_templates.dart';
import 'package:aesthetic/features/entrainer/routines/logic/progression.dart';
import 'package:aesthetic/features/entrainer/routines/logic/routine_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr_FR'));

  const bench = Exercise(id: 'dc', nom: 'Développé couché', musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.triceps], equipement: 'barre');
  Exercise? lookup(String id) => id == 'dc' ? bench : null;

  Routine routine({int? repsMax}) => Routine(
        id: 'r1',
        nom: 'Push',
        creeLe: DateTime(2026),
        exercices: [
          RoutineExercise(id: 'a', exerciseId: 'dc', series: [
            const PlannedSet(type: SetType.echauffement, reps: 10),
            PlannedSet(reps: 8, repsMax: repsMax),
            PlannedSet(reps: 8, repsMax: repsMax),
          ]),
        ],
      );

  Future<SessionRepo> sessionsAvec(List<int> reps, double kg) async {
    final repo = SessionRepo(Store.memory());
    await repo.load();
    await repo.save(WorkoutSession(
      id: 's1',
      nom: 'Push',
      debut: DateTime.now().subtract(const Duration(days: 2)),
      fin: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
      exercices: [
        SessionExercise(id: 'x', exerciseId: 'dc', series: [
          for (var i = 0; i < reps.length; i++) WorkoutSet(id: 'w$i', poids: kg, reps: reps[i], fait: true),
        ]),
      ],
    ));
    return repo;
  }

  test('séries par muscle et intensités', () {
    final s = seriesParMuscle(routine().exercices, lookup);
    expect(s[Muscle.pectoraux], 2);
    expect(s[Muscle.triceps], 1);
    final i = intensitesPour(s);
    expect(i[Muscle.pectoraux], 1);
    expect(i[Muscle.triceps]! < 1, isTrue);
  });

  test('supersets orphelins retirés, lettres attribuées', () {
    final list = normaliserSupersets(const [
      RoutineExercise(id: 'a', exerciseId: 'dc', supersetId: 'x'),
      RoutineExercise(id: 'b', exerciseId: 'dc', supersetId: 'x'),
      RoutineExercise(id: 'c', exerciseId: 'dc', supersetId: 'y'),
    ]);
    expect(list[2].supersetId, isNull);
    expect(supersetsDe(list)['x']!.lettre, 'A');
  });

  test('charge progressive : +incrément si tout est réussi', () async {
    final sessions = await sessionsAvec([8, 8], 60);
    final r = appliquerProgression(routine: routine(), plan: const ProgramPlan(programId: 'p'), semaine: 0, sessions: sessions, lookup: lookup);
    final travail = r.routine.exercices.first.series.where((s) => s.type.counts);
    expect(travail.every((s) => s.poids == 62.5), isTrue);
    expect(r.ajustements, hasLength(1));
  });

  test('charge progressive : même charge en cas d\'échec', () async {
    final sessions = await sessionsAvec([8, 6], 60);
    final r = appliquerProgression(routine: routine(), plan: const ProgramPlan(programId: 'p'), semaine: 0, sessions: sessions, lookup: lookup);
    expect(r.routine.exercices.first.series[1].poids, 60);
  });

  test('double progression : une répétition de plus, puis la charge', () async {
    const plan = ProgramPlan(programId: 'p', progression: ProgressionType.doubleProgression);
    final bas = await sessionsAvec([9, 9], 60);
    final r1 = appliquerProgression(routine: routine(repsMax: 12), plan: plan, semaine: 0, sessions: bas, lookup: lookup);
    expect(r1.routine.exercices.first.series[1].reps, 10);
    expect(r1.routine.exercices.first.series[1].poids, 60);
    final haut = await sessionsAvec([12, 12], 60);
    final r2 = appliquerProgression(routine: routine(repsMax: 12), plan: plan, semaine: 0, sessions: haut, lookup: lookup);
    expect(r2.routine.exercices.first.series[1].poids, 62.5);
    expect(r2.routine.exercices.first.series[1].reps, 8);
  });

  test('décharge : moitié des séries de travail à 90 %', () async {
    final sessions = await sessionsAvec([8, 8], 100);
    const plan = ProgramPlan(programId: 'p', progression: ProgressionType.aucune, dechargeToutesLes: 4);
    expect(plan.estDecharge(3), isTrue);
    final r = appliquerProgression(
      routine: routine().copyWith(exercices: [routine().exercices.first.copyWith(series: const [PlannedSet(reps: 5, poids: 100), PlannedSet(reps: 5, poids: 100)])]),
      plan: plan,
      semaine: 3,
      sessions: sessions,
      lookup: lookup,
    );
    expect(r.decharge, isTrue);
    expect(r.routine.exercices.first.series, hasLength(1));
    expect(r.routine.exercices.first.series.first.poids, 90);
  });

  test('plan : aller-retour JSON', () {
    const p = ProgramPlan(programId: 'p', progression: ProgressionType.ondulee, incrementKg: 5, dechargeToutesLes: 6, jours: [1, 3, 5]);
    final back = ProgramPlan.fromJson(p.toJson());
    expect(back.progression, ProgressionType.ondulee);
    expect(back.jours, [1, 3, 5]);
    expect(back.incrementKg, 5);
  });

  test('tous les modèles se créent avec le vrai catalogue', () async {
    final data = AppData(Store.memory());
    await data.loadAll();
    expect(modelesProgrammes.length, greaterThanOrEqualTo(95));
    expect(modelesProgrammes.map((m) => m.id).toSet(), hasLength(modelesProgrammes.length), reason: 'identifiants uniques');
    final plans = ProgramPlanRepo.of(data.store);
    for (final m in modelesProgrammes) {
      expect(exercicesManquants(m, data.exercises), isEmpty, reason: m.nom);
      final prog = await creerProgrammeDepuisModele(
        modele: m,
        exercices: data.exercises,
        routines: data.routines,
        programmes: data.programs,
        plans: plans,
      );
      expect(prog.routineIds, hasLength(m.cycle.length));
      for (final id in prog.routineIds) {
        expect(data.routines.byId(id)!.exercices, isNotEmpty);
      }
    }
    expect(data.programs.active?.nom, modelesProgrammes.last.nom);
    expect(data.routines.folders, isEmpty, reason: 'plus de dossier : le programme range ses routines');
  });
}
