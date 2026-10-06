import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/profil/data/grades.dart';
import 'package:aesthetic/features/profil/pages/grades_page.dart';
import 'package:aesthetic/features/profil/widgets/ecusson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_profil_banc.dart';

WorkoutSession seance(String id, DateTime debut, {int minutes = 60, List<String> exercices = const ['squat'], bool enCours = false}) => WorkoutSession(
      id: id,
      nom: 'Séance',
      debut: debut,
      fin: enCours ? null : debut.add(Duration(minutes: minutes)),
      exercices: [
        for (final (i, e) in exercices.indexed)
          SessionExercise(id: '$id-$i', exerciseId: e, series: const [WorkoutSet(id: 'a', poids: 60, reps: 8, fait: true)]),
      ],
    );

void main() {
  group('grades, calcul', () {
    Grades g(List<WorkoutSession> s, {int routines = 0, int records = 0, int objectif = 3}) =>
        Grades.from(s, nbRoutines: routines, nbRecords: records, objectifSemaine: objectif);

    test('sans séance : rien de gagné, tout reste à faire', () {
      final v = g(const []);
      expect(v.gagnes, 0);
      expect(v.vitrine(), isEmpty);
      expect(v.etape.niveau, 0);
      expect(v.etape.prochain, 1);
      for (final x in Grade.values) {
        expect(v.de(x).gagne, isFalse, reason: x.nom);
        expect(v.de(x).part, 0);
      }
    });

    test('heures : lève-tôt avant 7 h, noctambule quand ça finit après 23 h', () {
      final v = g([
        seance('a', DateTime(2026, 9, 7, 6, 15)), // lundi matin
        seance('b', DateTime(2026, 9, 8, 7, 0)), // 7 h pile : pas lève-tôt
        seance('c', DateTime(2026, 9, 9, 22, 30)), // finit à 23 h 30
        seance('d', DateTime(2026, 9, 10, 21, 0)), // finit à 22 h
        seance('e', DateTime(2026, 9, 11, 23, 30)), // finit à 0 h 30
      ]);
      expect(v.valeurs[Grade.leveTot], 1);
      expect(v.valeurs[Grade.noctambule], 2);
    });

    test('week-end, marathon, exercices différents, routines et records', () {
      final v = g(
        [
          seance('a', DateTime(2026, 9, 5, 10), minutes: 125, exercices: ['squat', 'curl']), // samedi, 2 h 05
          seance('b', DateTime(2026, 9, 6, 10), exercices: ['squat', 'tirage']), // dimanche
          seance('c', DateTime(2026, 9, 7, 10), minutes: 119), // lundi
          seance('d', DateTime(2026, 9, 8, 10), minutes: 60 * 30), // oubliée ouverte : ni marathon ni noctambule
        ],
        routines: 4,
        records: 7,
      );
      expect(v.valeurs[Grade.weekEnd], 2);
      expect(v.valeurs[Grade.marathon], 1);
      expect(v.valeurs[Grade.explorateur], 3);
      expect(v.valeurs[Grade.collectionneur], 4);
      expect(v.de(Grade.collectionneur).niveau, 2);
      expect(v.de(Grade.records).palier, 5);
      expect(v.de(Grade.records).prochain, 10);
      expect(v.valeurs[Grade.noctambule], 0);
    });

    test('semaines parfaites et plus longue série, même à travers le changement d\'heure', () {
      final s = <WorkoutSession>[];
      // Huit semaines de suite à trois séances, d'octobre à novembre (heure d'hiver au milieu).
      for (var sem = 0; sem < 8; sem++) {
        for (var j = 0; j < 3; j++) {
          s.add(seance('s$sem-$j', DateTime(2026, 10, 5 + sem * 7 + j * 2, 18)));
        }
      }
      // Un trou, puis deux semaines à une seule séance.
      s.add(seance('t1', DateTime(2026, 12, 14, 18)));
      s.add(seance('t2', DateTime(2026, 12, 21, 18)));
      final v = g(s, objectif: 3);
      expect(v.valeurs[Grade.semaineParfaite], 8);
      expect(v.valeurs[Grade.serie], 8);
      expect(v.de(Grade.serie).niveau, 3);
      expect(g(s, objectif: 1).valeurs[Grade.semaineParfaite], 10);
    });

    test('la séance en cours ne compte pas ; les étapes suivent le nombre de séances', () {
      final s = [for (var i = 0; i < 26; i++) seance('s$i', DateTime(2026, 1, 1 + i, 12)), seance('x', DateTime(2026, 3, 1, 12), enCours: true)];
      final v = g(s);
      expect(v.seances, 26);
      expect(v.etape.palier, 25);
      expect(v.etape.prochain, 50);
      expect(v.etape.part, closeTo(1 / 25, 1e-9));
    });

    test('vitrine : les plus hauts niveaux d\'abord, trois au plus', () {
      final v = g([for (var i = 0; i < 12; i++) seance('s$i', DateTime(2026, 9, 5 + 7 * i, 6))], routines: 1);
      // Douze samedis à 6 h : lève-tôt et week-end au niveau 3, série (12 semaines) au niveau 4.
      expect(v.vitrine().first, Grade.serie);
      expect(v.vitrine(), hasLength(3));
      expect(v.vitrine().every((x) => v.de(x).gagne), isTrue);
    });

    test('paliers croissants, couleurs distinctes', () {
      for (final x in Grade.values) {
        for (var i = 1; i < x.paliers.length; i++) {
          expect(x.paliers[i], greaterThan(x.paliers[i - 1]), reason: x.nom);
        }
      }
      expect(Grade.values.map((x) => x.couleur).toSet(), hasLength(Grade.values.length));
    });
  });

  group('grades, écrans', () {
    Future<void> remplir(WidgetTester t, dynamic data) => t.runAsync(() async {
          for (var i = 0; i < 130; i++) {
            // Une séance tous les deux jours ; une sur cinq à l'aube, une sur quatre tard le soir.
            final jour = DateTime(2026, 1, 3 + i * 2);
            final heure = i % 5 == 0 ? 6 : (i % 4 == 0 ? 22 : 18);
            await data.sessions.save(seance('s$i', DateTime(jour.year, jour.month, jour.day, heure), minutes: i % 9 == 0 ? 130 : 75, exercices: ['e${i % 31}', 'e${(i * 7) % 31}']));
          }
        });

    testWidgets('profil : la carte Badges montre trois écussons et ouvre la page', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      await remplir(t, data);
      final router = await monter(t, data, '/profil');
      await attendre(t);
      expect(find.text('Badges'), findsOneWidget);
      // Trois grades en vitrine, rien d'autre : les tuiles sont parties dans Progrès.
      expect(find.descendant(of: find.byType(VitrineGrades), matching: find.byType(Ecusson)), findsNWidgets(3));
      expect(find.byType(Ecusson), findsNWidgets(3));
      await t.runAsync(() => photo(t, 'grades-profil'));

      // « Voir tout », sur la ligne du titre, ouvre aussi la liste.
      await t.tap(find.text('Voir tout'));
      await attendre(t);
      expect(router.state.uri.path, '/profil/grades');
      router.pop();
      await attendre(t);
      expect(router.state.uri.path, '/profil');

      await t.tap(find.byType(VitrineGrades));
      await attendre(t);
      expect(router.state.uri.path, '/profil/grades');
      expect(find.byType(GradesPage), findsOneWidget);
      for (final g in Grade.values) {
        expect(find.text(g.nom), findsOneWidget, reason: g.nom);
      }
      expect(find.text('Secrets'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'grades-page'));

      await t.tap(find.text('Lève-tôt'));
      await attendre(t);
      expect(find.text('Séances commencées avant 7 h du matin'), findsOneWidget);
      expect(find.textContaining('Niveau'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'grades-detail'));

      // Une étape s'ouvre comme un grade : la jauge mène à la prochaine.
      Navigator.of(t.element(find.text('Séances commencées avant 7 h du matin'))).pop();
      await attendre(t);
      // Les étapes sont sous les secrets : on fait défiler jusqu'à elles.
      await t.scrollUntilVisible(find.text('100 séances'), 250, scrollable: find.byType(Scrollable).first);
      expect(find.text('Étapes importantes'), findsOneWidget);
      await attendre(t);
      await t.tap(find.text('100 séances'));
      await attendre(t);
      expect(find.text('Étape atteinte'), findsOneWidget);
      expect(find.text('130 séances au total'), findsOneWidget);
      expect(find.text('Encore 20 séances pour l’étape des 150'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'grades-etape'));
    });

    testWidgets('sans séance : la carte invite, la page montre tout verrouillé', (t) async {
      await polices(t);
      ecran(t, largeur: 360, hauteur: 780);
      final data = await donnees(t);
      final router = await monter(t, data, '/profil');
      await attendre(t);
      expect(find.descendant(of: find.byType(VitrineGrades), matching: find.byType(Ecusson)), findsNothing);
      expect(find.textContaining('premier badge'), findsOneWidget);
      router.go('/profil/grades');
      await attendre(t);
      expect(find.text('0 sur ${Grade.values.length} gagnés'), findsOneWidget);
      expect(find.text('à gagner'), findsNWidgets(Grade.values.length));
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'grades-page-vide-360'));
    });
  });
}
