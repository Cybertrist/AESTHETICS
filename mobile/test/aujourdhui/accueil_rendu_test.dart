// Accueil avec les données de la maquette (écran 01), horloge figée au
// 2 octobre 2026. `RENDUS=1 flutter test test/aujourdhui` écrit les images
// dans build/rendus/aujourdhui/.
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/aujourdhui/logic/accueil.dart';
import 'package:aesthetic/features/aujourdhui/widgets/accueil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

final _maintenant = DateTime(2026, 10, 2, 12);
var _n = 0;
String _id() => 'm${_n++}';

SessionExercise _ex(String id, int series, double poids, int reps) => SessionExercise(
      id: _id(),
      exerciseId: id,
      series: [for (var i = 0; i < series; i++) WorkoutSet(id: _id(), poids: poids, reps: reps, fait: true)],
    );

Future<AppData> _maquette({bool longs = false}) async {
  final data = AppData(Store.memory(), demo: false);
  await data.loadAll();
  await data.profile.save(UserProfile(
    id: 'u',
    prenom: 'Tristan',
    creeLe: DateTime(2026, 1, 1),
    poidsKg: 77,
    tailleCm: 181,
    joursParSemaine: 5,
  ));
  String ex(String nom, int rang) => (data.exercises.findByName(nom) ?? data.exercises.catalogue[rang]).id;
  final dos = [ex('Tractions', 0), ex('Rowing barre', 1), ex('Curl barre', 2), ex('Curl marteau', 3), ex('Face pull', 4)];
  final pecs = [ex('Développé couché haltères', 5), ex('Dips pectoraux', 6), ex('Extension triceps couché haltères', 7)];

  WorkoutSession dosBiceps(DateTime debut, double charge, {List<SessionMedia> medias = const []}) => WorkoutSession(
        id: _id(),
        nom: longs ? 'Dos, biceps, avant-bras et gainage du jeudi soir' : 'Dos / Biceps',
        debut: debut,
        fin: debut.add(const Duration(hours: 1, minutes: 45)),
        exercices: [for (final e in dos) _ex(e, 4, charge, 9)],
        medias: medias,
      );
  WorkoutSession pecsTriceps(DateTime debut, double charge, {int nb = 3}) => WorkoutSession(
        id: _id(),
        nom: 'Pecs / Triceps',
        debut: debut,
        fin: debut.add(const Duration(hours: 1, minutes: 42)),
        exercices: [
          _ex(pecs[0], 2, charge, 8),
          _ex(pecs[1], 3, charge / 4, 8),
          _ex(pecs[2], 3, charge / 2, 8),
          if (nb > 3) ...[for (final e in dos.take(nb - 3)) _ex(e, 3, 20, 10)],
        ],
      );

  await data.sessions.addAll([
    for (var s = 16; s >= 1; s--) dosBiceps(DateTime(2026, 10, 1, 19).subtract(Duration(days: 7 * s)), 40 + (16 - s) * 0.5),
    pecsTriceps(DateTime(2026, 9, 21, 18, 30), 14),
    pecsTriceps(DateTime(2026, 9, 28, 0, 28), 16, nb: longs ? 7 : 3),
    WorkoutSession(
      id: _id(),
      nom: 'Footing',
      debut: DateTime(2026, 9, 29, 18, 10),
      fin: DateTime(2026, 9, 29, 18, 50),
      type: TypeSeance.cardio,
    ),
    dosBiceps(
      DateTime(2026, 10, 1, 0, 37),
      50.3,
      medias: [
        const SessionMedia(chemin: 'absente/photo-1.jpg'),
        const SessionMedia(chemin: 'absente/video.mp4', video: true, dureeSec: 24),
        const SessionMedia(chemin: 'absente/photo-2.jpg'),
        if (longs)
          for (var i = 0; i < 9; i++) SessionMedia(chemin: 'absente/photo-${i + 3}.jpg'),
      ],
    ),
  ]);
  return data;
}

void main() {
  setUpAll(preparerAssets);

  testWidgets('accueil de la maquette, téléphone', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(_maquette))!;
    await rendreAccueil(t, data, 'maquette-accueil', const Size(390, 1500), _maintenant);
    expect(find.text('Résumé mensuel'), findsOneWidget);
    expect(find.text('septembre 2026'), findsOneWidget);
    expect(find.text('DOS / BICEPS'), findsWidgets);
    expect(find.text('Photo · 1 / 3'), findsOneWidget);
    expect(find.text('Vidéo · 0:24'), findsOneWidget);
    // Une séance avec médias ne liste pas ses exercices.
    expect(
      find.descendant(of: find.byType(CarteSeance).first, matching: find.textContaining('Tractions', findRichText: true)),
      findsNothing,
    );
    expect(find.textContaining('Dips', findRichText: true), findsOneWidget);
  });

  testWidgets('accueil de la maquette, Fold ouvert', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(_maquette))!;
    await rendreAccueil(t, data, 'maquette-accueil-large', const Size(884, 1100), _maintenant);
  });

  testWidgets('libellés longs sur écran très étroit', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(() => _maquette(longs: true)))!;
    await rendreAccueil(t, data, 'maquette-accueil-longs', const Size(320, 1700), _maintenant);
    expect(find.text('et 4 autres exercices'), findsOneWidget);
  });

  testWidgets('le résumé mensuel disparaît après le 3 du mois', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(_maquette))!;
    await rendreAccueil(t, data, 'maquette-accueil-le-4', const Size(390, 1500), DateTime(2026, 10, 4, 12));
    expect(find.text('Résumé mensuel'), findsNothing);
    expect(find.text('Cette semaine'), findsOneWidget);
  });

  test('règle du résumé mensuel et nouveautés', () async {
    final s = WorkoutSession(id: 'a', nom: 'A', debut: DateTime(2026, 9, 12, 18), fin: DateTime(2026, 9, 12, 19));
    expect(moisDuResume(DateTime(2026, 10, 1), [s]), DateTime(2026, 9));
    expect(moisDuResume(DateTime(2026, 10, 3, 23, 59), [s]), DateTime(2026, 9));
    expect(moisDuResume(DateTime(2026, 10, 4), [s]), isNull);
    expect(moisDuResume(DateTime(2026, 10, 2), const []), isNull);
    expect(moisDuResume(DateTime(2027, 1, 2), [s.copyWith(debut: DateTime(2026, 12, 30))]), DateTime(2026, 12));
    expect(libelleMois(DateTime(2026, 9)), 'septembre 2026');
    expect(dateSeance(DateTime(2026, 9, 30, 0, 37), now: DateTime(2026, 10, 2)), '30 septembre · 00:37');
    expect(dureeVideo(24), '0:24');
    final n = nouveautes(sessions: [s], now: DateTime(2026, 10, 2), objectif: 3);
    expect(n.single.cible, CibleNouveaute.bilanMois);
    expect(n.single.id, '2026-9');
  });
}
