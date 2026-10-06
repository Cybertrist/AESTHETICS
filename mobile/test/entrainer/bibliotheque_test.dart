import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/erreurs_frequentes.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_index.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/formats.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/records.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_detail_page.dart' show exerciceEnTexte, remplacerDansRoutines;
import 'package:aesthetic/features/entrainer/bibliotheque/pages/fiche/tab_apropos.dart' show exercicesAlternatifs;
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'outils.dart';

WorkoutSession _seance(String id, DateTime d, List<(double, int)> series, {String exercice = 'developpe-couche'}) => WorkoutSession(
      id: id,
      nom: 'Push',
      debut: d,
      fin: d.add(const Duration(hours: 1)),
      exercices: [
        SessionExercise(id: 'e$id', exerciseId: exercice, series: [
          WorkoutSet(id: 'w$id', type: SetType.echauffement, poids: 40, reps: 10, fait: true),
          for (var i = 0; i < series.length; i++) WorkoutSet(id: 's$id$i', poids: series[i].$1, reps: series[i].$2, fait: true),
        ]),
      ],
    );

ExerciseStats _stats(List<WorkoutSession> seances) => ExerciseStats([for (final s in seances) (session: s, exercise: s.exercices.first)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('index de recherche et filtres', () {
    final catalogue = [
      const Exercise(id: 'developpe-couche', nom: 'Développé couché', nomEn: 'Barbell Bench Press', alias: ['DC', 'Bench Press (Barbell)'], musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.triceps], equipement: 'barre', categorie: 'pectoraux'),
      const Exercise(id: 'squat', nom: 'Squat', nomEn: 'Barbell Full Squat', musclesPrincipaux: [Muscle.quadriceps], equipement: 'barre', categorie: 'jambes'),
      const Exercise(id: 'curl', nom: 'Curl haltères', musclesPrincipaux: [Muscle.biceps], equipement: 'halteres', categorie: 'biceps'),
      const Exercise(id: 'extension', nom: 'Extension triceps poulie', musclesPrincipaux: [Muscle.triceps], equipement: 'poulie', categorie: 'triceps'),
    ];
    const perso = [Exercise(id: 'perso-1', nom: 'Mon curl', musclesPrincipaux: [Muscle.biceps], perso: true)];
    final index = ExerciseIndex();
    List<String> f(LibraryFilters filtres, {Set<String> favoris = const {}, List<String> recents = const [], Map<String, int> freq = const {}, List<Exercise> persos = const []}) => index
        .filtrer(catalogue: catalogue, perso: persos, filtres: filtres, favoris: favoris, recents: recents, frequences: freq)
        .map((e) => e.id)
        .toList();

    test('nom français sans accents, anglais, alias', () {
      expect(f(const LibraryFilters(query: 'developpe')).first, 'developpe-couche');
      expect(f(const LibraryFilters(query: 'bench press')), ['developpe-couche']);
      expect(f(const LibraryFilters(query: 'full squat')), ['squat']);
      expect(f(const LibraryFilters(query: 'zzz')), isEmpty);
    });

    test('muscles principaux ou secondaires, matériel, catégorie', () {
      expect(f(const LibraryFilters(muscles: {Muscle.triceps})), containsAll(['developpe-couche', 'extension']));
      expect(f(const LibraryFilters(muscles: {Muscle.triceps}, principauxSeulement: true)), ['extension']);
      expect(f(const LibraryFilters(equipements: {'barre'})), ['developpe-couche', 'squat']);
      expect(f(const LibraryFilters(categories: {'biceps'})), ['curl']);
    });

    test('favoris, récents dans l\'ordre, mes exercices, tris', () {
      expect(f(const LibraryFilters(scope: LibraryScope.favoris), favoris: {'curl'}), ['curl']);
      expect(f(const LibraryFilters(scope: LibraryScope.recents), recents: ['squat', 'curl']), ['squat', 'curl']);
      expect(f(const LibraryFilters()), ['curl', 'developpe-couche', 'extension', 'squat']);
      expect(f(const LibraryFilters(scope: LibraryScope.perso), persos: perso), ['perso-1']);
      expect(f(const LibraryFilters(sort: LibrarySort.frequence), freq: {'squat': 5, 'extension': 2}).take(2), ['squat', 'extension']);
      expect(f(const LibraryFilters(sort: LibrarySort.recent), recents: ['extension', 'curl']).take(2), ['extension', 'curl']);
    });

    test('effectués : seulement les exercices de l\'historique, les perso aussi, et les autres filtres par-dessus', () {
      const faits = {'squat': 5, 'curl': 1, 'perso-1': 2, 'extension': 0};
      expect(f(const LibraryFilters(scope: LibraryScope.effectues), freq: faits, persos: perso), ['squat', 'perso-1', 'curl']);
      expect(f(const LibraryFilters(scope: LibraryScope.effectues, muscles: {Muscle.biceps}), freq: faits, persos: perso), ['perso-1', 'curl']);
      expect(f(const LibraryFilters(scope: LibraryScope.effectues)), isEmpty);
    });

    test('les raccourcis par muscle couvrent des muscles distincts', () {
      final vus = <Muscle>{};
      for (final g in MuscleGroup.all) {
        expect(g.muscles, isNotEmpty);
        expect(vus.intersection(g.muscles), isEmpty, reason: g.label);
        vus.addAll(g.muscles);
      }
      expect(MuscleGroup.all.take(5).map((g) => g.label), ['Pecs', 'Abdos', 'Biceps', 'Dos', 'Épaules']);
    });

    test('erreurs fréquentes toujours présentes', () {
      for (final e in catalogue) {
        expect(ErreursFrequentes.pour(e), isNotEmpty);
      }
    });

    test('exercices alternatifs : même muscle principal, jamais soi-même', () {
      final alt = exercicesAlternatifs(catalogue[2], [...catalogue, ...perso]);
      expect(alt.map((e) => e.id), ['perso-1']);
      expect(exercicesAlternatifs(const Exercise(id: 'x', nom: 'Sans muscle'), catalogue), isEmpty);
    });
  });

  test('statistiques d\'un exercice', () {
    final stats = _stats([
      _seance('a', DateTime(2026, 8, 1), [(80, 8), (80, 8)]),
      _seance('b', DateTime(2026, 9, 1), [(100, 3), (90, 6)]),
      _seance('c', DateTime(2026, 9, 20), [(70, 12)]),
    ]);
    expect(stats.nbSeances, 3);
    expect(stats.nbSeries, 5, reason: 'les échauffements ne comptent pas');
    expect(stats.points.first.session.id, 'a');
    expect(stats.nRm(5)!.valeur, 90);
    expect(stats.chargeMax!.valeur, 100);
    expect(stats.volumeSeance!.valeur, 1280);
    expect(stats.dans(StatPeriod.mois1, now: DateTime(2026, 9, 25)).length, 2);
    expect(StatMetric.pour(ExerciseTracking.duree), [StatMetric.dureeMax]);
  });

  group('records de la fiche', () {
    // Les séances de la maquette : élévations latérales, 18 et 25 septembre.
    final stats = _stats([
      _seance('s18', DateTime(2026, 9, 18, 19, 5), [(10, 15), (10, 13), (10, 12)], exercice: 'elevations-laterales'),
      _seance('s25', DateTime(2026, 9, 25, 18, 42), [(12, 12), (10, 15), (10, 14), (10, 12)], exercice: 'elevations-laterales'),
    ]);
    const suivi = ExerciseTracking.poidsReps;

    test('les cinq records, leur date et leur série', () {
      final r = {for (final x in recordsDe(stats, suivi)) x.type: x};
      expect(r.keys, TypeRecord.pour(suivi));
      expect(r[TypeRecord.unRm]!.valeurTexte(UnitePoids.kg), '17 kg');
      expect(r[TypeRecord.unRm]!.detail(suivi, UnitePoids.kg), '12 kg × 12');
      expect(r[TypeRecord.poidsMax]!.valeurTexte(UnitePoids.kg), '12 kg');
      expect(r[TypeRecord.poidsMax]!.sessionId, 's25');
      expect(r[TypeRecord.repsMax]!.valeurTexte(UnitePoids.kg), '15');
      expect(r[TypeRecord.repsMax]!.sessionId, 's18', reason: 'égalé le 25, établi le 18');
      expect(r[TypeRecord.volumeSeance]!.valeurTexte(UnitePoids.kg), '554 kg');
      expect(r[TypeRecord.volumeSeance]!.detail(suivi, UnitePoids.kg), '4 séries');
      expect(r[TypeRecord.volumeSerie]!.valeurTexte(UnitePoids.kg), '150 kg');
      expect(r[TypeRecord.volumeSerie]!.detail(suivi, UnitePoids.kg), '10 kg × 15');
      expect(ExFmt.dateAbregee(r[TypeRecord.unRm]!.date), '25 sept. 2026');
      expect(ExFmt.dateEtHeure(DateTime(2026, 9, 25, 18, 42)), '25 septembre 2026 à 18:42');
    });

    test('historique d\'un record : chaque fois qu\'il a été battu', () {
      final poids = progressionRecord(stats, TypeRecord.poidsMax);
      expect(poids.map((r) => r.valeur), [10, 12]);
      expect(progressionRecord(stats, TypeRecord.repsMax), hasLength(1));
      expect(progressionRecord(ExerciseStats(const []), TypeRecord.unRm), isEmpty);
    });

    test('médaille : la meilleure série de la séance, dorée si elle tient le record', () {
      final p18 = stats.points.first, p25 = stats.points.last;
      expect(meilleureDeSeance(p25, suivi)!.serie.poids, 12);
      expect(meilleureDeSeance(p25, suivi)!.label, 'Poids');
      expect(meilleureDeSeance(p18, suivi)!.serie.reps, 15, reason: 'à charge égale, la série la plus longue');
      expect(tientLeRecord(stats, p25, suivi), isTrue);
      expect(tientLeRecord(stats, p18, suivi), isFalse);
    });

    test('exercice au poids du corps : seules les répétitions comptent', () {
      expect(TypeRecord.pour(ExerciseTracking.repsSeules), [TypeRecord.repsMax]);
      final s = _stats([_seance('p', DateTime(2026, 9, 1), [(0, 12), (0, 10)], exercice: 'pompes')]);
      final r = recordsDe(s, ExerciseTracking.repsSeules);
      expect(r.single.valeurTexte(UnitePoids.kg), '12');
      expect(r.single.detail(ExerciseTracking.repsSeules, UnitePoids.kg), '12 réps');
      expect(meilleureDeSeance(s.points.first, ExerciseTracking.repsSeules)!.label, 'Réps');
    });
  });

  test('remplacer un exercice dans les routines, partage en texte', () {
    Routine r(String id, List<String> ex) =>
        Routine(id: id, nom: id, creeLe: DateTime(2026), exercices: [for (final e in ex) RoutineExercise(id: '$id-$e', exerciseId: e)]);
    final change = remplacerDansRoutines([r('a', ['squat', 'curl']), r('b', ['curl']), r('c', ['squat'])], 'curl', 'curl-marteau');
    expect(change.map((x) => x.id), ['a', 'b']);
    expect(change.first.exercices.map((e) => e.exerciseId), ['squat', 'curl-marteau']);
    const e = Exercise(id: 'x', nom: 'Curl', musclesPrincipaux: [Muscle.biceps], instructions: ['Monte.', 'Descends.'], equipement: 'halteres');
    final texte = exerciceEnTexte(e);
    expect(texte, contains('CURL'));
    expect(texte, contains('Principal : Biceps'));
    expect(texte, contains('2. Descends.'));
  });

  test('chiffres d\'un muscle : séries de la semaine, dernier travail, récupération', () {
    const curl = Exercise(id: 'curl', nom: 'Curl', musclesPrincipaux: [Muscle.biceps], musclesSecondaires: [Muscle.avantBras]);
    Exercise? lookup(String id) => id == 'curl' ? curl : null;
    final mercredi = DateTime(2026, 9, 30, 20);
    final seances = [
      _seance('m', DateTime(2026, 9, 29, 18), [(14, 12), (14, 12), (14, 10)], exercice: 'curl'),
      _seance('v', DateTime(2026, 9, 18, 18), [(14, 12)], exercice: 'curl'),
    ];
    final biceps = chiffresDuMuscle(Muscle.biceps, seances: seances, lookup: lookup, maintenant: mercredi);
    expect(biceps.seriesSemaine, 3, reason: 'la séance du 18 est d\'une autre semaine');
    expect(biceps.dernier, DateTime(2026, 9, 29, 18));
    expect(biceps.recuperation, inInclusiveRange(1, 99));
    final avantBras = chiffresDuMuscle(Muscle.avantBras, seances: seances, lookup: lookup, maintenant: mercredi);
    expect(avantBras.seriesSemaine, 1.5, reason: 'un muscle secondaire compte pour moitié');
    expect(avantBras.dernier, isNull, reason: 'jamais travaillé en muscle principal');
    final mollets = chiffresDuMuscle(Muscle.mollets, seances: seances, lookup: lookup, maintenant: mercredi);
    expect(mollets.seriesSemaine, 0);
    expect(mollets.recuperation, 100);
  });

  testWidgets('sélecteur multiple : ordre de sélection rendu', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer');
    List<String>? resultat;
    final ctx = t.element(find.text('Entraînement').first);
    pickExercises(ctx).then((r) => resultat = r);
    await attendre(t);
    expect(find.text('Choisis des exercices'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'squat');
    await attendre(t, 2);
    await t.tap(find.byType(CarteExercice).first);
    await t.pump();
    await t.enterText(find.byType(TextField).first, 'developpe couche');
    await attendre(t, 2);
    await t.tap(find.byType(CarteExercice).first);
    await t.pump();
    expect(find.text('Ajouter (2)'), findsOneWidget);
    await capturer(t, 'bibliotheque', 'selecteur');
    await t.tap(find.text('Ajouter (2)'));
    await attendre(t, 2);
    expect(resultat, hasLength(2));
    expect(resultat!.last, 'developpe-couche');
  });

  testWidgets('bibliothèque en page pleine, filtre par l\'adresse, création', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer/exercices?muscle=biceps');
    expect(find.text('Exercices'), findsOneWidget);
    final cartes = t.widgetList<CarteExercice>(find.byType(CarteExercice));
    expect(cartes, isNotEmpty);
    expect(cartes.every((c) => c.exercise.musclesPrincipaux.contains(Muscle.biceps)), isTrue);
    await capturer(t, 'bibliotheque', 'page-pleine-biceps');
    routeur(t).go('/entrainer/exercices/nouveau');
    await attendre(t);
    expect(find.text('Nouvel exercice'), findsOneWidget);
    await capturer(t, 'bibliotheque', 'creation');
  });
}
