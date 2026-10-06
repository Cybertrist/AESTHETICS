import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:aesthetic/features/seance/logic/partage.dart';
import 'package:aesthetic/features/seance/pages/equivalent_page.dart';
import 'package:aesthetic/features/seance/pages/partager_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/cartes_partage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'banc_partage.dart';

/// Cartes de fin de séance et de partage aux données extrêmes : phrases les
/// plus longues, nom interminable, vingt exercices, série de semaines à 0 ou
/// 1, petit écran et Fold ouvert ; export en image.

const _petit = Size(360, 640);
const _large = Size(884, 1100);

/// Pour chaque objet, la phrase la plus longue (séance puis mois), plus les
/// pastilles les plus larges.
List<Equivalent> _piresPhrases({required bool mois}) {
  final pires = <String, Equivalent>{};
  int longueur(Equivalent e) => e.phrase.split('\n').map((l) => l.length).reduce((x, y) => x > y ? x : y);
  for (var kg = 1; kg <= 200000; kg += kg < 2000 ? 3 : 53) {
    for (var g = 0; g < 48; g++) {
      final e = equivalentPour(kg.toDouble(), graine: g, mois: mois);
      final a = pires[e.asset];
      if (a == null || longueur(e) > longueur(a)) pires[e.asset] = e;
    }
  }
  final tries = pires.values.toList()..sort((a, b) => longueur(b).compareTo(longueur(a)));
  return [
    ...tries.take(7),
    // La pastille la plus large : 800 000 burgers.
    equivalentPour(200000, graine: 5, mois: mois),
    equivalentPour(200000, graine: 11, mois: mois),
    equivalentPour(0, mois: mois),
  ];
}

/// Une séance démesurée : vingt exercices, nom très long.
WorkoutSession _demesuree(AppData d, {double poids = 120, int reps = 12}) {
  final debut = DateTime.now().subtract(const Duration(hours: 3));
  final exos = d.exercises.all.where((e) => e.suivi == ExerciseTracking.poidsReps).toList()..sort((a, b) => b.nom.length.compareTo(a.nom.length));
  return WorkoutSession(
    id: 'demesuree',
    nom: 'Haut du corps, épaules et bras, version longue du dimanche matin',
    debut: debut,
    fin: debut.add(const Duration(hours: 2, minutes: 47)),
    exercices: [
      for (var i = 0; i < 20; i++)
        SessionExercise(id: 'e$i', exerciseId: exos[i].id, series: [
          for (var j = 0; j < 6; j++) WorkoutSet(id: 's$i-$j', poids: poids, reps: reps, fait: true),
        ]),
    ],
  );
}

void main() {
  testWidgets('les phrases les plus longues tiennent dans la carte de fin de séance et dans la carte de partage', (t) async {
    await t.runAsync(policesPartage);
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    for (final taille in [_petit, taillePartage]) {
      t.view.physicalSize = taille;
      t.view.padding = const FakeViewPadding(top: 25);
      final etroit = taille == _petit;
      var n = 0;
      for (final e in _piresPhrases(mois: false)) {
        await poserPartage(
          t,
          CarteFinDeSeance(nom: 'Jambes', volume: '123 456', unite: 'kg', equivalent: e, onFermer: () {}, onPartager: () {}),
          assets: [e.asset],
        );
        expect(t.takeException(), isNull, reason: 'fin de séance, ${taille.width} : $e « ${e.phrase} »');
        // La marque et « Partager » restent à l'écran.
        expect(t.getRect(find.text('Partager')).bottom, lessThanOrEqualTo(taille.height));
        // La phrase entière est visible : elle ne passe pas sous la marque.
        expect(t.getRect(find.byType(PhraseEquivalent)).bottom, lessThanOrEqualTo(t.getRect(find.byType(MarquePartage)).top + 0.5),
            reason: 'phrase coupée, ${taille.width} : $e « ${e.phrase} »');
        if (e.phrase.contains('virgule près') && n < 2) await capturePartage(t, 'fin-equivalent-long-${etroit ? 'etroit' : 'maquette'}-${n++}');
        if (e.etiquette.length > 8 && e.etiquette.contains('800')) await capturePartage(t, 'fin-equivalent-burgers-${etroit ? 'etroit' : 'maquette'}');
      }
      n = 0;
      for (final e in _piresPhrases(mois: true)) {
        await poserPartage(
          t,
          Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                // La place laissée à la carte par la page de partage.
                padding: const EdgeInsets.fromLTRB(22.5, 80, 22.5, 127),
                child: CarteEquivalent(volume: '123 456 kg', equivalent: e),
              ),
            ),
          ),
          assets: [e.asset],
        );
        expect(t.takeException(), isNull, reason: 'partage, ${taille.width} : $e « ${e.phrase} »');
        if (e.phrase.contains('Pâques') && n < 1) await capturePartage(t, 'fin-partage-equivalent-long-${etroit ? 'etroit' : 'maquette'}-${n++}');
      }
    }
  });

  testWidgets('carrousel de partage : nom long, vingt exercices, petit écran et Fold ouvert', (t) async {
    for (final (taille, nom) in [(_petit, 'etroit'), (tailleMaquette, 'maquette'), (_large, 'large')]) {
      t.view.padding = const FakeViewPadding(top: 25);
      addTearDown(t.view.resetPadding);
      final d = await monter(t, depart: '/', taille: taille);
      final s = _demesuree(d);
      await t.runAsync(() => d.sessions.save(s));
      await precharger(t, [for (final o in objetsEquivalents) o.asset]);
      routeurDe(t).go(SeancePaths.partager(s.id));
      await attendre(t, tours: 8);
      expect(find.byType(PartagerPage), findsOneWidget);
      // Six cartes quand la séance a battu un record, cinq sinon.
      final nombre = t.state<PartagerPageState>(find.byType(PartagerPage)).nombreCartes;
      for (var i = 0; i < nombre; i++) {
        if (i > 0) {
          await t.drag(find.byType(PageView), Offset(-taille.width * 0.8, 0));
          await attendre(t, tours: 5);
        }
        expect(t.takeException(), isNull, reason: 'carte ${i + 1}, $nom');
        await capture(t, 'fin-partager-extreme-$nom-${i + 1}');
      }
      expect(find.text('Ta photo ici'), findsOneWidget);
      await demonter(t);
    }
  });

  testWidgets('carte « série de semaines » à 0 et à 1, carte « détail » sans exercice', (t) async {
    await t.runAsync(policesPartage);
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = _petit;
    t.view.padding = const FakeViewPadding(top: 25);
    Widget page(Widget carte) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22.5, 80, 22.5, 127), child: carte)),
        );
    for (final n in [0, 1, 2, 104]) {
      final (libelle, phrase) = textesSerie(n);
      await poserPartage(t, page(CarteSerie(semaines: n, libelle: libelle, phrase: phrase)));
      expect(t.takeException(), isNull, reason: '$n semaines');
      expect(find.text('$n'), findsOneWidget);
      if (n < 2) await capturePartage(t, 'fin-partage-serie-$n');
    }
    expect(textesSerie(0).$1, isNot(contains('semaines')));
    expect(textesSerie(1).$1, startsWith('semaine d'));
    expect(textesSerie(2).$1, startsWith('semaines d'));

    await poserPartage(t, page(const CarteDetail(date: '2 octobre 2026', nom: 'Course', resume: '0 kg · 32 min', lignes: [], intensites: {})));
    expect(t.takeException(), isNull);
    await poserPartage(t, page(const CarteResume(volume: '1 234 567 kg', duree: '12 h 34', series: 240, intensites: {})));
    expect(t.takeException(), isNull);
    await poserPartage(
      t,
      page(const CarteAutocollant(nom: 'Haut du corps, épaules et bras, version longue', volume: '1 234 567 kg', series: 240, duree: '12 h 34')),
    );
    expect(t.takeException(), isNull);
    await capturePartage(t, 'fin-partage-autocollant-extreme');
  });

  testWidgets('export : image nette, fond opaque jusque dans les coins, carte entière', (t) async {
    final d = await monter(t, depart: '/');
    final s = _demesuree(d);
    await t.runAsync(() => d.sessions.save(s));
    await precharger(t, [for (final o in objetsEquivalents) o.asset]);
    // Les cinq cartes de toujours, puis l'adresse de celle des records.
    for (var carte = 0; carte < CartePartage.values.length; carte++) {
      routeurDe(t).go('/');
      await attendre(t, tours: 2);
      routeurDe(t).go(SeancePaths.partager(s.id, carte: carte));
      await attendre(t, tours: 6);
      final etat = t.state<PartagerPageState>(find.byType(PartagerPage));
      final boite = t.getSize(find.byKey(etat.cleCourante));
      final (largeur, hauteur, coins, centre) = (await t.runAsync(() async {
        final png = (await capturerCarte(etat.cleCourante))!;
        final codec = await ui.instantiateImageCodec(png);
        final image = (await codec.getNextFrame()).image;
        final octets = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int alpha(int x, int y) => octets.getUint8((y * image.width + x) * 4 + 3);
        // La dernière rangée peut être à cheval sur un demi-pixel : on regarde juste au-dessus.
        final coins = [alpha(0, 0), alpha(image.width - 1, 0), alpha(0, image.height - 4), alpha(image.width - 1, image.height - 4)];
        return (image.width, image.height, coins, alpha(image.width ~/ 2, image.height ~/ 2));
      }))!;
      // Trois pixels par point : assez pour un écran de téléphone.
      expect(largeur, closeTo(boite.width * 3, 1), reason: 'carte ${carte + 1}');
      expect(hauteur, closeTo(boite.height * 3, 1), reason: 'carte ${carte + 1}');
      expect(largeur, greaterThanOrEqualTo(900));
      expect(centre, 255);
      expect(coins, everyElement(255), reason: 'carte ${carte + 1} : coins transparents, le fond dépendra de l\'appli qui reçoit l\'image');
    }
    await demonter(t);
  });

  test('carte « détail » : vingt exercices tiennent en huit lignes', () async {
    final d = AppData(Store.memory());
    await d.exercises.load();
    final s = _demesuree(d);
    final lignes = lignesDetail(s, d.exercises);
    expect(lignes.length, 8);
    expect(lignes.last, 'et 13 autres exercices');
    expect(lignes.first, startsWith('6 × '));
    // Un seul exercice en trop : le singulier.
    final neuf = s.copyWith(exercices: s.exercices.take(9).toList());
    expect(lignesDetail(neuf, d.exercises).last, isNot('et 1 autres exercices'));
  });

  test('records et comparaison : première fois, record battu, séance antidatée', () async {
    final d = AppData(Store.memory());
    await d.exercises.load();
    final ex = d.exercises.all.firstWhere((e) => e.suivi == ExerciseTracking.poidsReps);
    WorkoutSession seance(String id, DateTime debut, double poids, int reps, {String? routineId = 'r', String nom = 'Push'}) => WorkoutSession(
          id: id,
          nom: nom,
          routineId: routineId,
          debut: debut,
          fin: debut.add(const Duration(hours: 1)),
          exercices: [
            SessionExercise(id: 'e$id', exerciseId: ex.id, series: [
              const WorkoutSet(id: 'w', type: SetType.echauffement, poids: 200, reps: 20, fait: true),
              WorkoutSet(id: 'a', poids: poids, reps: reps, fait: true),
            ]),
          ],
        );
    final un = seance('1', DateTime(2026, 9, 1, 18), 80, 8);
    await d.sessions.save(un);
    // Première fois : pas de record, pas de comparaison.
    expect(BilanSeance.calculer(un, d.sessions, d.exercises).records, isEmpty);
    expect(comparerAuPrecedent(un, d.sessions.sessions), isNull);

    final deux = seance('2', DateTime(2026, 9, 8, 18), 82.5, 8);
    await d.sessions.save(deux);
    final bilan = BilanSeance.calculer(deux, d.sessions, d.exercises);
    expect(bilan.recordsPrincipaux.single.type, RecordType.poidsMax);
    expect(bilan.recordsPrincipaux.single.valeur, 82.5, reason: 'l\'échauffement à 200 kg ne compte pas');
    expect(comparerAuPrecedent(deux, d.sessions.sessions)!.texte, '+3 %');

    // Même charge, mêmes répétitions : ni record ni écart affiché.
    final trois = seance('3', DateTime(2026, 9, 15, 18), 82.5, 8);
    await d.sessions.save(trois);
    expect(BilanSeance.calculer(trois, d.sessions, d.exercises).records, isEmpty);
    expect(comparerAuPrecedent(trois, d.sessions.sessions), isNull);

    // Séance antidatée (date corrigée à la fin) : comparée à ce qui la précède, pas à ce qui la suit.
    final antidatee = seance('4', DateTime(2026, 9, 5, 18), 81, 8);
    await d.sessions.save(antidatee);
    final b4 = BilanSeance.calculer(antidatee, d.sessions, d.exercises);
    expect(b4.recordsPrincipaux.single.valeur, 81);
    expect(comparerAuPrecedent(antidatee, d.sessions.sessions)!.reference, 'Push');
    expect(comparerAuPrecedent(antidatee, d.sessions.sessions)!.pourcent, 1);

    // Une autre routine du même nom ne sert pas de référence ; une baisse s'écrit avec un signe moins ordinaire.
    final autre = seance('5', DateTime(2026, 9, 20, 18), 40, 8, routineId: 'autre');
    await d.sessions.save(autre);
    expect(comparerAuPrecedent(autre, d.sessions.sessions), isNull);
    final baisse = seance('6', DateTime(2026, 9, 22, 18), 60, 8);
    await d.sessions.save(baisse);
    expect(comparerAuPrecedent(baisse, d.sessions.sessions)!.texte, '-27 %');
  });
}
