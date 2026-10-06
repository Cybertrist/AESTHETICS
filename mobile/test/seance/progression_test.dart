import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_index.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/logic/progression.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:flutter_test/flutter_test.dart';

/// La proposition « la prochaine fois », la comparaison d'une séance
/// écourtée, et les séries gauche, droite d'un exercice unilatéral.
void main() {
  // Le catalogue se lit dans les fichiers de l'appli.
  TestWidgetsFlutterBinding.ensureInitialized();
  const dc = 'developpe-couche';
  var n = 0;
  WorkoutSession seance(DateTime debut, List<(double, int)> series, {String exo = dc}) => WorkoutSession(
        id: 's${n++}',
        nom: 'Push',
        debut: debut,
        fin: debut.add(const Duration(hours: 1)),
        routineId: 'r',
        exercices: [
          SessionExercise(id: 'e${n++}', exerciseId: exo, series: [
            for (final (p, r) in series) WorkoutSet(id: 'w${n++}', poids: p, reps: r, fait: true),
          ]),
        ],
      );
  DateTime jour(int j) => DateTime(2026, 9, j, 18);

  late AppData data;
  setUp(() async {
    data = AppData(Store.memory());
    await data.exercises.load();
  });
  Suggestion proposer(WorkoutSession s, List<WorkoutSession> avant, {Routine? routine}) =>
      Surcharge.calculer(s, exos: data.exercises, avant: avant, routine: routine).single;

  group('la prochaine fois', () {
    test('30 kg × 5 puis 30 kg × 6 : on propose 30 kg × 7, pas une charge plus lourde', () {
      final avant = seance(jour(1), [(30, 5), (30, 5), (30, 5)]);
      final p = proposer(seance(jour(8), [(30, 6), (30, 6), (30, 6)]), [avant]);
      expect((p.poids, p.reps), (30.0, 7));
      expect(p.titre, '30 kg × 7');
      expect(p.raison, contains("30 kg × 5 la dernière fois, × 6 aujourd'hui"));
      expect(p.raison, contains('la charge montera à 8'));
    });

    test('un nombre fixe dans la routine n’est pas un plafond', () {
      // La routine a repris « 30 kg × 5 » de la séance d'avant : 6 répétitions ne font pas monter la charge.
      final routine = Routine(id: 'r', nom: 'Push', creeLe: DateTime(2026), exercices: const [
        RoutineExercise(id: 're', exerciseId: dc, series: [PlannedSet(poids: 30, reps: 5), PlannedSet(poids: 30, reps: 5)]),
      ]);
      final p = proposer(seance(jour(8), [(30, 6), (30, 6)]), [seance(jour(1), [(30, 5), (30, 5)])], routine: routine);
      expect((p.poids, p.reps), (30.0, 7));
    });

    test('le haut de la fourchette partout : la charge monte et l’on repart du bas', () {
      final p = proposer(seance(jour(8), [(30, 8), (30, 8), (30, 8)]), [seance(jour(1), [(30, 7), (30, 7), (30, 7)])]);
      expect((p.poids, p.reps), (32.5, 5));
      // Sans passé à cette charge, 8 est le bas de « 8 à 12 » : on gagne d'abord des répétitions.
      final neuf = proposer(seance(jour(8), [(30, 8), (30, 8), (30, 8)]), const []);
      expect((neuf.poids, neuf.reps), (30.0, 9));
      expect(p.raison, contains('8 répétitions sur toutes tes séries'));
    });

    test('la fourchette de la routine passe devant', () {
      final routine = Routine(id: 'r', nom: 'Push', creeLe: DateTime(2026), exercices: const [
        RoutineExercise(id: 're', exerciseId: dc, series: [PlannedSet(reps: 6, repsMax: 10)]),
      ]);
      expect(proposer(seance(jour(8), [(60, 8), (60, 8)]), const [], routine: routine).reps, 9);
      final haut = proposer(seance(jour(8), [(60, 10), (60, 10)]), const [], routine: routine);
      expect((haut.poids, haut.reps), (62.5, 6));
    });

    test('séries inégales : d’abord toutes au niveau de la meilleure', () {
      final p = proposer(seance(jour(8), [(30, 7), (30, 6), (30, 5)]), const []);
      expect((p.poids, p.reps), (30.0, 7));
      expect(p.raison, contains('Amène toutes tes séries à 7'));
    });

    test('une seule série à la charge la plus lourde : elle n’est pas acquise', () {
      final p = proposer(seance(jour(8), [(72.5, 8), (70, 6), (70, 6)]), const []);
      expect((p.poids, p.reps), (72.5, 8));
      expect(p.raison, contains("n'a tenu que sur 1 série"));
    });

    test('trois séances au même point : une répétition de plus sur la première série', () {
      final avant = [seance(jour(1), [(30, 6), (30, 6)]), seance(jour(4), [(30, 6), (30, 6)])];
      final p = proposer(seance(jour(8), [(30, 6), (30, 6)]), avant);
      expect((p.poids, p.reps), (30.0, 7));
      expect(p.raison, contains('3 séances au même point'));
    });

    test('un recul se dit, et la charge reste', () {
      final p = proposer(seance(jour(8), [(30, 6), (30, 6)]), [seance(jour(1), [(30, 7), (30, 7)])]);
      expect(p.poids, 30);
      expect(p.raison, contains('1 répétition de moins que la dernière fois'));
    });

    test('un pas trop gros pour la charge : deux répétitions de plus avant de monter', () {
      // 2,5 kg sur 10 kg, c'est un quart de plus : parti de 10 répétitions, on va jusqu'à 14 au lieu de 12.
      final debut = [seance(jour(1), [(10, 10), (10, 10)])];
      final p = proposer(seance(jour(8), [(10, 12), (10, 12)]), debut);
      expect((p.poids, p.reps), (10.0, 13));
      expect(p.raison, contains('le pas de 2,5 kg étant gros pour cette charge'));
      expect(proposer(seance(jour(8), [(10, 14), (10, 14)]), debut).poids, 12.5);
    });
  });

  test('aux haltères, la charge monte à l’haltère suivant : 1 kg jusqu’à 10, puis 2 kg', () {
    expect([for (final kg in [3.0, 9.0, 10.0, 12.0, 16.0, 22.0]) Surcharge.haltereSuivant(kg)], [4.0, 10.0, 12.0, 14.0, 18.0, 24.0]);
    const curl = 'curl-marteau';
    expect(data.exercises.byId(curl)!.equipement, 'halteres');
    // De 16 à 18 kg, le saut dépasse 10 % : il se gagne à 14 répétitions, pas à 12.
    final debut = [seance(jour(1), [(16, 8), (16, 8)], exo: curl)];
    expect(proposer(seance(jour(8), [(16, 12), (16, 12)], exo: curl), debut).titre, '16 kg × 13');
    // À 14 partout, on prend les 18, pas des « 18,5 ».
    final p = proposer(seance(jour(8), [(16, 14), (16, 14)], exo: curl), debut);
    expect((p.poids, p.reps), (18.0, 8));
    expect(p.titre, '18 kg × 8');
  });

  group('comparaison', () {
    test('une séance écourtée se compare série pour série, pas en bloc', () {
      final complete = seance(jour(1), [(70, 7), (70, 6), (70, 5), (70, 5)]);
      final courte = seance(jour(8), [(72.5, 8), (70, 6)]);
      // En bloc : 1 000 kg contre 1 610 kg, soit -38 %. Série pour série : 1 000 contre 910.
      final c = comparerAuPrecedent(courte, [complete, courte])!;
      expect(c.aSeriesEgales, isTrue);
      expect(c.texte, '+10 %');
      expect(c.legende, 'vs dernier Push, à séries égales');
    });

    test('autant de séries ou plus : le volume entier, comme avant', () {
      final avant = seance(jour(1), [(70, 8), (70, 8)]);
      final s = seance(jour(8), [(70, 8), (70, 8), (70, 8)]);
      final c = comparerAuPrecedent(s, [avant, s])!;
      expect(c.aSeriesEgales, isFalse);
      expect(c.texte, '+50 %');
      expect(c.legende, 'vs dernier Push');
    });

    test('aucun exercice en commun : rien à comparer', () {
      final avant = seance(jour(1), [(70, 8), (70, 8)]);
      final s = seance(jour(8), [(20, 8)], exo: 'curl-marteau');
      expect(comparerAuPrecedent(s, [avant, s]), isNull);
    });
  });

  test('une série finie en échec ne revient pas en échec la fois suivante', () async {
    const elev = 'elevations-laterales';
    final s = WorkoutSession(id: 'x', nom: 'Épaules', debut: jour(1), fin: jour(1).add(const Duration(hours: 1)), exercices: const [
      SessionExercise(id: 'e', exerciseId: elev, series: [
        WorkoutSet(id: 'a', type: SetType.echauffement, poids: 2, reps: 15, fait: true),
        WorkoutSet(id: 'b', type: SetType.echec, poids: 3.3, reps: 15, fait: true),
        WorkoutSet(id: 'c', type: SetType.echec, poids: 3.3, reps: 12, fait: true),
      ]),
    ]);
    await data.sessions.save(s);
    // La routine tirée de la séance, puis la séance lancée avec elle : l'échauffement reste, l'échec non.
    final routine = routineDepuisSeance(s, 'Épaules');
    expect([for (final p in routine.exercices.single.series) p.type], [SetType.echauffement, SetType.normale, SetType.normale]);
    final suivante = await data.sessions.startFromRoutine(routine);
    expect([for (final x in suivante.exercices.single.series) x.type], [SetType.echauffement, SetType.normale, SetType.normale]);
    expect(suivante.exercices.single.series.last.poids, 3.3);
  });

  test('une routine qui prévoit une série en échec la garde ; un échec de séance ne change pas la routine', () async {
    const elev = 'elevations-laterales';
    final routine = Routine(id: 'r', nom: 'Épaules', creeLe: DateTime(2026), exercices: const [
      RoutineExercise(id: 'a', exerciseId: elev, series: [PlannedSet(poids: 8, reps: 12), PlannedSet(type: SetType.echec, poids: 8, reps: 12)]),
    ]);
    // Prévue dans la routine, la série en échec revient à chaque séance.
    final lancee = await data.sessions.startFromRoutine(routine);
    expect([for (final x in lancee.exercices.single.series) x.type], [SetType.normale, SetType.echec]);
    // En séance, la première série finit elle aussi en échec : la routine, mise à jour, garde son plan.
    final faite = lancee.copyWith(exercices: [
      lancee.exercices.single.copyWith(series: [
        for (final x in lancee.exercices.single.series) x.copyWith(type: SetType.echec, fait: true),
      ]),
    ]);
    final apres = MajRoutine.appliquer(routine, faite);
    expect([for (final p in apres.exercices.single.series) p.type], [SetType.normale, SetType.echec]);
  });

  test('matériel : un exercice apparaît sous chaque matériel qu’il demande', () {
    final dcHalteres = data.exercises.byId('developpe-couche-halteres')!;
    expect(dcHalteres.materiels, {'halteres', 'banc'});
    expect(dcHalteres.auxHalteres, isTrue);
    expect(data.exercises.byId('squat')!.materiels, {'barre'});
    final index = ExerciseIndex();
    List<String> filtre(Set<String> materiels) => index
        .filtrer(catalogue: data.exercises.catalogue, perso: const [], filtres: LibraryFilters(equipements: materiels), favoris: const {}, recents: const [], frequences: const {})
        .map((e) => e.id)
        .toList();
    expect(filtre({'banc'}), containsAll(['developpe-couche-halteres', 'developpe-couche', 'curl-incline']));
    expect(filtre({'halteres'}), contains('developpe-couche-halteres'));
    expect(filtre({'banc'}), isNot(contains('squat')));
    // Un exercice personnel, hors de la table, garde sa seule famille.
    expect(const Exercise(id: 'perso', nom: 'Mon truc', equipement: 'poulie', perso: true).materiels, {'poulie'});
  });

  test('fiches relues : les erreurs à éviter parlent du bon matériel, les corrections s’appliquent', () {
    final dc = data.exercises.byId('developpe-couche-halteres')!;
    final erreurs = ExercicesPlus.erreurs(dc.id)!;
    expect(erreurs.length, inInclusiveRange(2, 4));
    expect(erreurs.any((x) => x.toLowerCase().contains('barre')), isFalse, reason: 'aux haltères, pas de barre');
    expect(erreurs.any((x) => x.contains('Haltères')), isTrue);
    // Chaque exercice du catalogue a sa liste, et aucune fiche sans barre n'en parle.
    for (final e in data.exercises.catalogue) {
      final l = ExercicesPlus.erreurs(e.id);
      expect(l, isNotNull, reason: e.id);
      if (e.materiels.every((m) => const {'halteres', 'banc', 'kettlebell', 'poids du corps', 'elastique', 'mini-bande', 'ballon'}.contains(m))) {
        expect(l!.any((x) => RegExp(r'\bbarre\b', caseSensitive: false).hasMatch(x)), isFalse, reason: '${e.id} : $l');
      }
    }
    // Des corrections de fiche : des étapes réécrites, des muscles, un suivi, un nom.
    expect(data.exercises.byId('decline-bench-press')!.instructions.join(' ').toLowerCase(), isNot(contains('barre')));
    expect(data.exercises.byId('hip-thrust')!.musclesPrincipaux, [Muscle.fessiers]);
    expect(data.exercises.byId('assisted-dips')!.suivi, ExerciseTracking.poidsDuCorpsAssiste);
    expect(data.exercises.byId('curl-a-l-elastique')!.nom, "Leg curl debout à l'élastique");
  });

  test('une gauche et une droite comptent pour une série', () {
    const g = SetType.gauche, d = SetType.droite;
    expect(compterSeries([g, d, g, d, g, d]), 3);
    expect(compterSeries([SetType.echauffement, SetType.normale, SetType.echec]), 2);
    expect(compterSeries([g]), 1, reason: 'un côté fait sans l’autre compte déjà pour une série');
    expect(poidsDesSeries([g, d, g]), 1.5);
    // Trois paires au squat bulgare : trois séries dans la séance, et trois pour les quadriceps.
    final s = WorkoutSession(id: 'u', nom: 'Jambes', debut: jour(1), fin: jour(1).add(const Duration(hours: 1)), exercices: [
      SessionExercise(id: 'e', exerciseId: 'squat-bulgare', series: [
        for (var i = 0; i < 6; i++) WorkoutSet(id: 'w$i', type: i.isEven ? g : d, poids: 20, reps: 10, fait: true),
      ]),
    ]);
    expect(s.nbSeriesFaites, 3);
    expect(Strength.setsParMuscle([s], data.exercises.byId)[Muscle.quadriceps], 3);
    // Le volume, lui, reste tout ce qui a été soulevé, des deux côtés.
    expect(s.volume, 6 * 20 * 10);
  });

  test('programme aux haltères : la charge monte à l’haltère suivant, et la décharge tombe sur un haltère', () async {
    const curl = 'curl-marteau';
    final routine = Routine(id: 'r', nom: 'Bras', creeLe: DateTime(2026), exercices: const [
      RoutineExercise(id: 'a', exerciseId: curl, series: [PlannedSet(poids: 16, reps: 10), PlannedSet(poids: 16, reps: 10)]),
    ]);
    await data.sessions.save(seance(jour(1), [(16, 10), (16, 10)], exo: curl));
    final monte = appliquerProgression(routine: routine, plan: const ProgramPlan(programId: 'p'), semaine: 0, sessions: data.sessions, lookup: data.exercises.byId);
    expect([for (final p in monte.routine.exercices.single.series) p.poids], [18.0, 18.0], reason: 'de 16 à 18 kg, pas 18,5');
    expect(monte.ajustements.single.texte, contains('haltère suivant'));
    // Une semaine de décharge : 90 % de 16 kg font 14,4 kg, soit l'haltère de 14.
    final decharge = appliquerProgression(
      routine: routine,
      plan: const ProgramPlan(programId: 'p', progression: ProgressionType.aucune, dechargeToutesLes: 1),
      semaine: 0,
      sessions: data.sessions,
      lookup: data.exercises.byId,
    );
    expect(decharge.decharge, isTrue);
    expect(decharge.routine.exercices.single.series.first.poids, 14);
    expect([for (final kg in [7.4, 10.4, 11.2, 14.4, 17.1]) Strength.arrondirHaltere(kg)], [7.0, 10.0, 12.0, 14.0, 18.0]);
  });

  group('unilatéral', () {
    test('le catalogue : un bras ou une jambe à la fois, jamais un exercice chronométré', () {
      bool uni(String id) {
        final e = data.exercises.byId(id);
        expect(e, isNotNull, reason: '$id absent du catalogue');
        return e!.unilateral;
      }
      for (final id in ['rowing-haltere-unilateral', 'curl-concentre', 'squat-bulgare', 'single-leg-press', 'one-arm-lat-pulldown', 'pistol-squat', 'step-up', 'elevations-laterales-a-la-poulie']) {
        expect(uni(id), isTrue, reason: id);
      }
      for (final id in ['developpe-couche', 'squat', 'curl-marteau', 'fentes-marchees', 'single-leg-glute-bridge-hold', 'bench-bulgarian-split-stretch']) {
        expect(uni(id), isFalse, reason: id);
      }
    });

    test('trois séries prévues en donnent six : gauche, droite, gauche, droite', () async {
      const g = SetType.gauche, d = SetType.droite;
      final routine = Routine(id: 'r', nom: 'Dos', creeLe: DateTime(2026), exercices: const [
        RoutineExercise(id: 'a', exerciseId: 'rowing-haltere-unilateral', series: [
          PlannedSet(type: SetType.echauffement, poids: 10, reps: 12),
          PlannedSet(poids: 24, reps: 10),
          PlannedSet(poids: 24, reps: 10),
          PlannedSet(poids: 24, reps: 10),
        ]),
        RoutineExercise(id: 'b', exerciseId: dc, series: [PlannedSet(poids: 60, reps: 8), PlannedSet(poids: 60, reps: 8)]),
      ]);
      final s = await data.sessions.startFromRoutine(routine);
      expect([for (final x in s.exercices.first.series) x.type], [SetType.echauffement, g, d, g, d, g, d]);
      expect(s.exercices.first.series.skip(1).every((x) => x.poids == 24 && x.reps == 10), isTrue);
      expect([for (final x in s.exercices.last.series) x.type], [SetType.normale, SetType.normale], reason: 'un exercice des deux côtés à la fois ne change pas');

      // Des côtés déjà notés dans la routine : rien n'est doublé.
      expect(Unilateral.prevues(const [PlannedSet(type: g, reps: 10), PlannedSet(type: d, reps: 10)]).length, 2);
    });

    test('ajouté en séance : trois paires gauche, droite', () {
      final series = Unilateral.series([for (var i = 0; i < 3; i++) WorkoutSet(id: 'w$i')], newId);
      expect([for (final x in series) x.type], [for (var i = 0; i < 3; i++) ...const [SetType.gauche, SetType.droite]]);
      expect({for (final x in series) x.id}.length, 6);
    });
  });
}
