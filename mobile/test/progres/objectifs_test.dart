import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/carte_routine.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/widgets/ecusson.dart';
import 'package:aesthetic/features/progres/logic/objectifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../profil/test_profil_banc.dart';

WorkoutSession _s(String id, DateTime debut, {double poids = 80, String exo = 'bench'}) => WorkoutSession(
      id: id,
      nom: 'S',
      debut: debut,
      fin: debut.add(const Duration(hours: 1)),
      exercices: [
        SessionExercise(id: '$id-e', exerciseId: exo, series: [WorkoutSet(id: 'a', poids: poids, reps: 5, fait: true)]),
      ],
    );

BodyMeasurement _m(String id, DateTime d, {double? poids, Map<TourCorps, double> tours = const {}}) => BodyMeasurement(id: id, date: d, poidsKg: poids, tours: tours, source: 'manuel');

void main() {
  group('objectifs, calcul', () {
    test('poids à la baisse : la jauge part du poids de départ, atteint dès que la cible est passée', () {
      final o = ObjectifPerso(id: 'o', type: TypeObjectif.poids, cible: 105, depart: 115, creeLe: DateTime(2026, 10, 1));
      expect(o.enBaisse, isTrue);
      double? v(double kg) => Objectifs.valeur(o, sessions: const [], mesures: [_m('a', DateTime(2026, 10, 2), poids: kg)]);
      expect(Objectifs.part(o, v(115)), 0);
      expect(Objectifs.part(o, v(110)), closeTo(0.5, 1e-9));
      expect(Objectifs.atteint(o, v(110)), isFalse);
      expect(Objectifs.atteint(o, v(105)), isTrue);
      expect(Objectifs.atteint(o, v(104.2)), isTrue);
      expect(Objectifs.atteint(o, null), isFalse);
    });

    test('charge : le record de charge de l\'exercice, à la hausse', () {
      final o = ObjectifPerso(id: 'o', type: TypeObjectif.charge, cible: 100, depart: 80, exerciseId: 'bench', creeLe: DateTime(2026, 10, 1));
      final s = [_s('a', DateTime(2026, 10, 2), poids: 90), _s('b', DateTime(2026, 10, 4), poids: 60, exo: 'squat')];
      final v = Objectifs.valeur(o, sessions: s, mesures: const []);
      expect(v, 90);
      expect(Objectifs.part(o, v), closeTo(0.5, 1e-9));
      expect(Objectifs.atteint(o, v), isFalse);
      expect(Objectifs.atteint(o, Objectifs.valeur(o, sessions: [...s, _s('c', DateTime(2026, 10, 6), poids: 100)], mesures: const [])), isTrue);
    });

    test('séances par semaine : celles de la semaine en cours seulement', () {
      final o = ObjectifPerso(id: 'o', type: TypeObjectif.seances, cible: 3, creeLe: DateTime(2026, 10, 1));
      final s = [_s('a', DateTime(2026, 9, 30, 18)), _s('b', DateTime(2026, 10, 1, 18)), _s('c', DateTime(2026, 9, 20, 18))];
      // Le samedi 3 octobre 2026 : la semaine va du lundi 28 septembre au dimanche 4.
      final v = Objectifs.valeur(o, sessions: s, mesures: const [], now: DateTime(2026, 10, 3, 12));
      expect(v, 2);
      expect(Objectifs.part(o, v), closeTo(2 / 3, 1e-9));
    });

    test('mensuration, secrets, et aller-retour sur le disque', () async {
      final o = ObjectifPerso(id: 'o', type: TypeObjectif.mensuration, cible: 40, depart: 38, zone: ZoneMesure.biceps, creeLe: DateTime(2026, 10, 1));
      final v = Objectifs.valeur(o, sessions: const [], mesures: [_m('a', DateTime(2026, 10, 2), tours: const {TourCorps.brasGauche: 39, TourCorps.brasDroit: 39})]);
      expect(v, 39);
      final store = Store.memory();
      ObjectifsRepo.reset();
      final repo = await ObjectifsRepo.ensure(store);
      await repo.ajouter(o);
      await repo.remplacer(o.avecAtteinte(DateTime(2026, 11, 14)));
      ObjectifsRepo.reset();
      final relu = await ObjectifsRepo.ensure(store);
      expect(relu.liste.single.zone, ZoneMesure.biceps);
      expect(relu.liste.single.atteint, isTrue);
      expect(Objectifs.atteintsParType(relu.liste), {TypeObjectif.charge: 0, TypeObjectif.poids: 0, TypeObjectif.seances: 0, TypeObjectif.mensuration: 1});

      final s = [_s('a', DateTime(2026, 1, 5, 8)), _s('b', DateTime(2026, 1, 5, 19)), _s('c', DateTime(2026, 3, 1, 18)), _s('d', DateTime(2026, 3, 3, 18))];
      expect(Objectifs.joursDoubles(s), 1);
      expect(Objectifs.retours(s), 1);
      ObjectifsRepo.reset();
    });
  });

  group('objectifs, écrans', () {
    testWidgets('grades : six secrets, cachés tant qu\'ils ne sont pas gagnés', (t) async {
      await polices(t);
      ecran(t, hauteur: 1500);
      ObjectifsRepo.reset();
      final data = await donnees(t);
      await t.runAsync(() async {
        await data.sessions.save(_s('a', DateTime(2026, 1, 5, 8)));
        await data.sessions.save(_s('b', DateTime(2026, 1, 5, 19)));
      });
      await monter(t, data, '/profil/grades');
      await attendre(t);
      expect(find.text('Secrets'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(5));
      expect(find.text('Doublé'), findsOneWidget);
      expect(find.text('1 sur 6'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'grades-secrets'));
      // Un appui dit comment le badge a été gagné ; verrouillé, seulement un indice.
      await t.tap(find.text('Doublé'));
      await attendre(t);
      expect(find.textContaining('Deux séances le même jour'), findsOneWidget);
      await t.runAsync(() => photo(t, 'grades-secret-detail'));
      Navigator.of(t.element(find.textContaining('Deux séances le même jour'))).pop();
      await attendre(t);
      await t.tap(find.text('???').first);
      await attendre(t);
      expect(find.textContaining('Indice :'), findsOneWidget);
      expect(find.text('Badge secret'), findsOneWidget);
      ObjectifsRepo.reset();
    });

    testWidgets('carte de routine : huit exercices au plus par image, plusieurs images au-delà', (t) async {
      await polices(t);
      final data = await donnees(t);
      // Des noms longs exprès : ils doivent tenir sur deux lignes.
      final ids = (data.exercises.all.toList()..sort((a, b) => b.nom.length.compareTo(a.nom.length))).take(16).map((e) => e.id).toList();
      Routine routine(int n) => Routine(
            id: 'r',
            nom: 'Upper 1',
            creeLe: DateTime(2026, 10, 1),
            exercices: [
              for (var i = 0; i < n; i++)
                RoutineExercise(id: 'e$i', exerciseId: ids[i], supersetId: i == 4 || i == 5 ? 'ss' : null, series: const [PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8, repsMax: 12)]),
            ],
          );
      expect([0, 1, 8, 9, 16].map((n) => CarteRoutine.nbCartes(routine(n))), [1, 1, 1, 2, 2]);
      for (final (n, page) in [(7, 0), (8, 0), (12, 0), (12, 1)]) {
        t.view.physicalSize = const Size(CarteRoutine.largeur, CarteRoutine.hauteur);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(RepaintBoundary(
          key: cleBanc,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
              ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
            ],
            child: MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: Scaffold(backgroundColor: Colors.black, body: CarteRoutine(key: ValueKey('$n-$page'), routine: routine(n), page: page))),
          ),
        ));
        await attendre(t, 4);
        expect(t.takeException(), isNull, reason: '$n exercices, image ${page + 1}');
        expect(find.text('UPPER 1'), findsOneWidget);
        expect(find.text(n > 8 ? 'ROUTINE · ${page + 1} SUR 2' : 'ROUTINE'), findsOneWidget);
        // Le total reste celui de la routine entière, sur chaque image.
        expect(find.text('$n'), findsWidgets);
        expect(find.textContaining('Superset A', findRichText: true), page == 0 ? findsNWidgets(2) : findsNothing);
        expect(find.byType(Ecusson), findsNothing);
        await t.runAsync(() => photo(t, 'carte-routine-$n-${page + 1}'));
      }
    });
  });
}
