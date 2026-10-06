import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/partage.dart';
import 'package:aesthetic/features/seance/pages/partager_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/cartes_partage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

WorkoutSession _seance({DateTime? debut, List<SessionExercise> ex = const []}) {
  final d = debut ?? DateTime(2026, 8, 12, 18);
  return WorkoutSession(id: 's1', nom: 'Jambes', debut: d, fin: d.add(const Duration(hours: 1, minutes: 27)), exercices: ex);
}

void main() {
  test('graine de l\'équivalent : stable, propre à la séance', () {
    final a = _seance();
    expect(graineEquivalent(a), graineEquivalent(_seance()));
    expect(graineEquivalent(a), isNot(graineEquivalent(_seance(debut: DateTime(2026, 8, 13, 18)))));
    expect(graineEquivalent(a), greaterThanOrEqualTo(0));
    expect(equivalentDeSeance(a).phrase, equivalentDeSeance(_seance()).phrase);
  });

  test('lignes « N × exercice » : séries faites seulement, liste bornée', () async {
    final exos = ExerciseRepo(Store.memory());
    WorkoutSet serie(String id, {bool fait = true}) => WorkoutSet(id: id, poids: 50, reps: 10, fait: fait);
    final s = _seance(ex: [
      SessionExercise(id: 'a', exerciseId: 'x', series: [serie('1'), serie('2'), serie('3', fait: false)]),
      SessionExercise(id: 'b', exerciseId: 'y', series: [serie('4', fait: false)]),
      SessionExercise(id: 'c', exerciseId: 'z', series: [serie('5')]),
    ]);
    final lignes = lignesDetail(s, exos);
    expect(lignes.length, 2);
    expect(lignes.first, startsWith('2 × '));
    expect(lignes.last, startsWith('1 × '));

    final longue = _seance(ex: [
      for (var i = 0; i < 12; i++) SessionExercise(id: 'e$i', exerciseId: 'x$i', series: [serie('s$i')]),
    ]);
    final bornee = lignesDetail(longue, exos, max: 8);
    expect(bornee.length, 8);
    expect(bornee.last, 'et 5 autres exercices');
  });

  test('textes de la série de semaines : 0, 1 et plusieurs', () {
    expect(textesSerie(0).$1, 'semaine d\'affilée');
    expect(textesSerie(1).$1, 'semaine d\'affilée !');
    expect(textesSerie(17), ('semaines d\'affilée !', 'Tu t\'entraînes depuis 17 semaines sans pause.'));
    expect(volumeEntier(10348, UnitePoids.kg), matches(RegExp(r'^10.348 kg$')));
  });

  testWidgets('la croix mène au bilan, Partager ouvre la carte équivalent', (t) async {
    final data = await monter(t, depart: '/');
    final s = data.sessions.sessions.first;
    final routeur = routeurDe(t);
    routeur.go(SeancePaths.equivalent(s.id));
    await attendre(t);

    await t.tap(find.text('Partager'));
    await attendre(t);
    expect(find.byType(PartagerPage), findsOneWidget);
    expect(find.text('Je viens de soulever'), findsOneWidget);
    expect(routeur.state.uri.toString(), SeancePaths.partager(s.id, carte: 1));

    // La croix du partage revient à la carte.
    await t.tap(find.bySemanticsLabel('Fermer').last);
    await attendre(t);
    expect(find.byType(PartagerPage), findsNothing);

    await t.tap(find.bySemanticsLabel('Fermer'));
    await attendre(t);
    expect(routeur.state.uri.toString(), SeancePaths.resume(s.id, nouveau: true));
    await demonter(t);
  });

  testWidgets('séance introuvable : état vide', (t) async {
    await monter(t, depart: SeancePaths.equivalent('inconnue'));
    expect(find.text('Séance introuvable'), findsOneWidget);
    routeurDe(t).go(SeancePaths.partager('inconnue'));
    await attendre(t);
    expect(find.text('Séance introuvable'), findsOneWidget);
    await demonter(t);
  });

  testWidgets('export : la carte affichée sort en PNG', (t) async {
    final data = await monter(t, depart: '/');
    routeurDe(t).go(SeancePaths.partager(data.sessions.sessions.first.id, carte: 3));
    await attendre(t);
    expect(find.byType(CarteSerie), findsOneWidget);
    final etat = t.state<PartagerPageState>(find.byType(PartagerPage));
    final png = (await t.runAsync(() => capturerCarte(etat.cleCourante, pixelRatio: 2)))!;
    expect(png.length, greaterThan(1000));
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(await t.runAsync(() => capturerCarte(GlobalKey())), isNull);
    await demonter(t);
  });
}
