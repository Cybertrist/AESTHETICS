import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/seance/widgets/exercice_carte.dart';
import 'package:aesthetic/features/seance/widgets/habillage.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aesthetic/features/seance/widgets/bandeau_record.dart';

import 'banc.dart';
import 'test_saisie_outils.dart';

/// La séance en cours : l'encadré, la liste des exercices qui s'ouvrent sur
/// place, les deux boutons en fin de page, le message « Série supprimée ».

/// Démarre une séance sur les [n] premiers exercices de la routine « Push » de
/// la démo (ils ont un « Précédent »), trois séries chacun.
Future<List<SessionExercise>> _seance(WidgetTester t, AppData d, {int n = 3}) async {
  final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
  final r = Routine(
    id: 'liste-routine',
    nom: 'Push',
    creeLe: DateTime(2026, 9, 1),
    exercices: [
      for (final e in push.exercices.take(n))
        RoutineExercise(id: 'l-${e.id}', exerciseId: e.exerciseId, reposSec: 60, series: [for (var i = 0; i < 3; i++) const PlannedSet(poids: 40, reps: 10)]),
    ],
  );
  await t.runAsync(() async {
    await d.routines.save(r);
    await d.sessions.startFromRoutine(r);
  });
  return d.sessions.active!.exercices;
}

String _nom(AppData d, SessionExercise e) => d.exercises.byId(e.exerciseId)!.nom;

ExerciceCarte _carte(WidgetTester t, int i) => t.widgetList<ExerciceCarte>(find.byType(ExerciceCarte)).elementAt(i);

/// Le cadre visible de la liste qui défile.
Rect _vue(WidgetTester t) => t.getRect(find.byKey(const ValueKey('defile-seance')));

Future<void> _validerTout(WidgetTester t, int series) async {
  for (var i = 0; i < series; i++) {
    final coche = find.bySemanticsLabel('Valider la série').first;
    await t.ensureVisible(coche);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(coche);
    await attendre(t, tours: 2);
  }
}

void main() {
  testWidgets('la liste : le premier exercice à faire est ouvert, une ligne s\'ouvre et se replie au toucher', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(412, 915));
    final exos = await _seance(t, d);
    await ouvrirSeance(t);

    expect(find.byType(ExerciceCarte), findsNWidgets(3));
    expect(_carte(t, 0).ouvert, isTrue);
    expect(_carte(t, 1).ouvert, isFalse);
    expect(_carte(t, 2).ouvert, isFalse);
    // Ouvert : pas de compteur sous le nom ; repliés : « 0/3 effectués ».
    expect(find.text('0/3 effectués'), findsNWidgets(2));
    expect(find.text('Ajouter une note…'), findsOneWidget);
    expect(find.text('Minuteur de repos : 1:00'), findsOneWidget);
    expect(find.byType(EnteteSeries), findsOneWidget);
    expect(find.byType(SerieLigne), findsNWidgets(3));
    expect(find.text('+ Ajouter une série'), findsOneWidget);

    // Toucher la deuxième ligne : elle s'ouvre, la première se replie.
    await t.tap(find.text(_nom(d, exos[1])));
    await attendre(t, tours: 2);
    expect(_carte(t, 0).ouvert, isFalse);
    expect(_carte(t, 1).ouvert, isTrue);
    expect(find.text('0/3 effectués'), findsNWidgets(2));
    expect(find.byType(SerieLigne), findsNWidgets(3));

    // La toucher de nouveau : tout est replié.
    await t.tap(find.text(_nom(d, exos[1])));
    await attendre(t, tours: 2);
    expect(find.byType(SerieLigne), findsNothing);
    expect(find.text('0/3 effectués'), findsNWidgets(3));
    expect(find.text('Ajouter une note…'), findsNothing);

    // La vignette ouvre toujours la fiche, sans ouvrir la ligne.
    await t.tap(find.bySemanticsLabel('Ouvrir la fiche de l\'exercice').first);
    await attendre(t, tours: 2);
    expect(find.byType(SerieLigne), findsNothing);
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('un exercice entièrement validé se replie, passe au vert, et le suivant s\'ouvre', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(412, 915));
    await _seance(t, d);
    await ouvrirSeance(t);

    await _validerTout(t, 2);
    // Le bandeau du haut annonce le record : l'écusson seul, puis l'exercice
    // et le record battu ; l'encadré compte les records de la séance.
    expect(find.byType(BandeauRecord), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    await t.pump(BandeauRecord.tempsEcusson + const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('·', findRichText: true), findsWidgets);
    await capture(t, 'liste-412-series-validees');
    expect(_carte(t, 0).ouvert, isTrue, reason: 'il reste une série : l\'exercice reste ouvert');
    await _validerTout(t, 1);
    expect(d.sessions.active!.exercices[0].series.every((s) => s.fait), isTrue);
    expect(_carte(t, 0).ouvert, isFalse);
    expect(_carte(t, 1).ouvert, isTrue);
    final fait = t.widget<Text>(find.text('3/3 effectués'));
    expect(fait.style!.color, AppTokens.foret);
    expect(t.widget<Text>(find.text('0/3 effectués')).style!.color, AppTokens.text2);

    // Une séance rouverte : le premier exercice non terminé est ouvert.
    await t.tap(find.bySemanticsLabel('Réduire la séance'));
    await attendre(t, tours: 2);
    await ouvrirSeance(t);
    expect(_carte(t, 0).ouvert, isFalse);
    expect(_carte(t, 1).ouvert, isTrue);

    // Tout valider : plus rien d'ouvert.
    await _validerTout(t, 3);
    expect(_carte(t, 2).ouvert, isTrue);
    await _validerTout(t, 3);
    expect(find.byType(SerieLigne), findsNothing);
    expect(find.text('3/3 effectués'), findsNWidgets(3));
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('l\'encadré et les deux boutons défilent avec la page', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(360, 740));
    await _seance(t, d);
    await ouvrirSeance(t);

    final liste = find.byKey(const ValueKey('defile-seance'));
    for (final f in [find.byType(EncadreChiffres), find.text('Ajouter des exercices'), find.text('Plus')]) {
      expect(find.descendant(of: liste, matching: f, skipOffstage: false), findsOneWidget);
    }
    for (final l in ['Durée', 'Volume', 'Séries']) {
      expect(find.text(l), findsOneWidget);
    }
    // La durée est au bleu du minuteur.
    final duree = t.widget<Text>(find.descendant(of: find.byType(TexteVivant), matching: find.byType(Text)));
    expect(duree.style!.color, AppTokens.minuteur);
    // « Terminer » reste blanc.
    final terminer = t.widget<Material>(find.ancestor(of: find.text('Terminer'), matching: find.byType(Material)).first);
    expect(terminer.color, AppTokens.bouton);

    await t.ensureVisible(find.text('Plus'));
    await t.pump(const Duration(milliseconds: 300));
    final ajouter = t.getRect(find.text('Ajouter des exercices'));
    final plus = t.getRect(find.text('Plus'));
    expect(ajouter.bottom, lessThan(plus.top), reason: '« Plus » est sous « Ajouter des exercices »');
    final dernier = t.getRect(find.byType(ExerciceCarte).last);
    expect(dernier.bottom, lessThanOrEqualTo(ajouter.top));

    // Clavier ouvert sur un champ : l'encadré a défilé hors de l'écran, la ligne saisie est visible.
    await t.ensureVisible(find.byType(ExerciceCarte).first);
    await t.pump(const Duration(milliseconds: 300));
    final s = seriesDe(d)[2];
    await t.tap(champ(s, 'reps'));
    await t.pump();
    t.view.viewInsets = const FakeViewPadding(bottom: 330);
    await attendre(t, tours: 3);
    final vue = _vue(t);
    final saisie = t.getRect(find.byKey(ValueKey('ligne-${s.id}')));
    expect(saisie.top, greaterThanOrEqualTo(vue.top));
    expect(saisie.bottom, lessThanOrEqualTo(vue.bottom));
    expect(vue.height, greaterThan(250), reason: 'rien ne reste collé en haut : la place va aux séries');
    expect(t.takeException(), isNull);
    t.view.resetViewInsets();
    await demonter(t);
  });

  testWidgets('« Série supprimée » se pose sous la liste, au-dessus du clavier, sans recouvrir de ligne', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(360, 740));
    await _seance(t, d);
    await ouvrirSeance(t);

    final garde = seriesDe(d)[2];
    await t.tap(champ(garde, 'reps'));
    await t.pump();
    t.view.viewInsets = const FakeViewPadding(bottom: 330);
    await attendre(t, tours: 3);

    final supprimee = seriesDe(d)[1];
    await t.dragFrom(t.getTopLeft(find.byKey(ValueKey('ligne-${supprimee.id}'))) + const Offset(110, 28), const Offset(-340, 0));
    await attendre(t, tours: 6);
    expect(seriesDe(d).length, 2);
    expect(find.text('Série supprimée'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    final bandeau = t.getRect(find.text('Série supprimée'));
    final vue = _vue(t);
    expect(bandeau.top, greaterThanOrEqualTo(vue.bottom), reason: 'le message est hors de la liste');
    expect(bandeau.bottom, lessThanOrEqualTo(740 - 330), reason: 'et au-dessus du clavier');
    final saisie = t.getRect(find.byKey(ValueKey('ligne-${garde.id}')));
    expect(saisie.bottom, lessThanOrEqualTo(vue.bottom), reason: 'la ligne en cours de saisie reste visible');
    expect(saisie.top, greaterThanOrEqualTo(vue.top));
    await capture(t, 'liste-360-clavier-serie-supprimee');

    await t.tap(find.text('Annuler'));
    await attendre(t, tours: 2);
    expect(seriesDe(d).length, 3);
    expect(seriesDe(d)[1].id, supprimee.id);
    expect(find.text('Série supprimée'), findsNothing);

    // Sans « Annuler », le message s'en va tout seul.
    await t.dragFrom(t.getTopLeft(find.byKey(ValueKey('ligne-${supprimee.id}'))) + const Offset(110, 28), const Offset(-340, 0));
    await attendre(t, tours: 6);
    expect(find.text('Série supprimée'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.text('Série supprimée'), findsNothing);
    expect(seriesDe(d).length, 2);
    expect(t.takeException(), isNull);
    t.view.resetViewInsets();
    await demonter(t);
  });

  testWidgets('rendus de la liste : repliée, ouverte, clavier, en 360, 412 et sur le Fold ouvert', (t) async {
    for (final taille in const [Size(360, 740), Size(412, 915), Size(884, 1100)]) {
      final l = taille.width.toInt();
      final d = await monter(t, depart: '/', taille: taille);
      final exos = await _seance(t, d, n: 2);
      await ouvrirSeance(t);
      expect(t.takeException(), isNull, reason: 'débordement en $l, exercice ouvert');
      await capture(t, 'liste-$l-ouverte-debut');

      // Le premier exercice fait : il se replie en vert, le second s'ouvre.
      await _validerTout(t, 3);
      await capture(t, 'liste-$l-ouverte');

      // Clavier ouvert sur la dernière série.
      await t.tap(champ(seriesDe(d, 1)[2], 'poids'));
      await t.pump();
      t.view.viewInsets = const FakeViewPadding(bottom: 330);
      await attendre(t, tours: 3);
      expect(t.takeException(), isNull, reason: 'débordement en $l, clavier ouvert');
      // Quand l'exercice tient au-dessus du clavier, sa ligne (son nom) reste à l'écran.
      final vue = _vue(t);
      final carte = t.getRect(find.byType(ExerciceCarte).last);
      final ligne = t.getRect(find.byKey(ValueKey('ligne-${seriesDe(d, 1)[2].id}')));
      expect(ligne.bottom, lessThanOrEqualTo(vue.bottom), reason: 'ligne saisie visible en $l');
      if (carte.height <= vue.height) expect(carte.top, greaterThanOrEqualTo(vue.top - 1), reason: 'exercice en cours visible en $l');
      await capture(t, 'liste-$l-clavier');
      t.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await attendre(t, tours: 2);

      // Tout replié, comme la liste de départ.
      await t.ensureVisible(find.text(_nom(d, exos[1])));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(_nom(d, exos[1])));
      await attendre(t, tours: 2);
      expect(find.byType(SerieLigne), findsNothing);
      expect(t.takeException(), isNull, reason: 'débordement en $l, tout replié');
      await capture(t, 'liste-$l-repliee');
      await demonter(t);
    }
  });
}
