import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'test_saisie_outils.dart';

/// Saisie des séries dans l'écran de la séance en cours : valider, dévalider,
/// modifier, supprimer, ajouter, et ce qui reste sur disque.
void main() {
  testWidgets('deux appuis coup sur coup sur la coche valident la série une seule fois', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);

    final coche = find.bySemanticsLabel('Valider la série').first;
    await t.tap(coche);
    await t.tap(coche, warnIfMissed: false);
    await attendre(t, tours: 2);

    final s = seriesDe(d).first;
    expect(s.fait, isTrue, reason: 'le second appui ne doit pas dévalider la série');
    expect(s.faitLe, isNotNull);
    expect(seriesDe(d).where((x) => x.fait).length, 1);
    expect(ReposMinuteur.instance.actif, isTrue);
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('une série validée est sur le disque, relue par un nouveau dépôt', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    final avant = seriesDe(d)[1];

    await t.enterText(champ(avant, 'poids'), '12,5');
    await t.enterText(champ(avant, 'reps'), '14');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série').at(1));
    // Aucune attente : l'appli est « tuée » dès que les écritures en file sont passées.
    await t.pump();

    final relu = await relire(t, d.store);
    final s = relu.active!.exercices.single.series[1];
    expect(relu.active!.id, d.sessions.active!.id);
    expect(s.fait, isTrue);
    expect(s.poids, 12.5);
    expect(s.reps, 14);
    expect(s.faitLe, isNotNull);
    expect(relu.active!.exercices.single.series.where((x) => x.fait).length, 1);
    await demonter(t);
  });

  testWidgets('dévalider : la série repasse à faire, sans date, et son repos s\'arrête', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);

    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(ReposMinuteur.instance.actif, isTrue);
    await t.tap(find.bySemanticsLabel('Décocher la série').first);
    await attendre(t, tours: 2);

    final s = seriesDe(d).first;
    expect(s.fait, isFalse);
    expect(s.faitLe, isNull);
    expect(s.tempsReposSec, isNull, reason: 'pas de repos noté sur une série qui n\'est plus faite');
    expect(ReposMinuteur.instance.actif, isFalse, reason: 'le repos lancé par erreur ne doit pas continuer');
    expect(find.bySemanticsLabel('Décocher la série'), findsNothing);
    await demonter(t);
  });

  testWidgets('modifier une série validée garde la validation et met le volume à jour', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(d.sessions.active!.volume, 120);

    await t.enterText(champ(seriesDe(d).first, 'reps'), '15');
    await t.enterText(champ(seriesDe(d).first, 'poids'), '12,5');
    await attendre(t, tours: 2);
    final s = seriesDe(d).first;
    expect(s.fait, isTrue);
    expect(s.reps, 15);
    expect(s.poids, 12.5);
    expect(d.sessions.active!.volume, 187.5);
    expect(find.text('188 kg'), findsOneWidget);
    await demonter(t);
  });

  testWidgets('les répétitions saisies restent affichées quand on quitte l\'écran et qu\'on y revient', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    final s = seriesDe(d)[2];
    expect(texteDe(t, champ(s, 'reps')), '', reason: 'rien de saisi : la fourchette tient lieu de valeur');
    expect(find.text('12-15'), findsNWidgets(4));

    await t.enterText(champ(s, 'reps'), '14');
    await attendre(t, tours: 2);
    expect(seriesDe(d)[2].reps, 14);

    // Réduire la séance puis la rouvrir : l'écran est reconstruit.
    await t.tap(find.bySemanticsLabel('Réduire la séance'));
    await attendre(t, tours: 2);
    await t.tap(find.text('Reprendre'));
    await attendre(t);
    expect(texteDe(t, champ(s, 'reps')), '14', reason: 'la valeur saisie ne doit pas redevenir une fourchette');
    expect(find.text('12-15'), findsNWidgets(3));
    await demonter(t);
  });

  testWidgets('une série vide, sans précédent, ne se valide pas : le champ à remplir prend la main', (t) async {
    final d = await monter(t, depart: '/');
    final ex = jamaisFait(d);
    await seanceLibre(t, d, [ex.id]);
    await ouvrirSeance(t);

    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(seriesDe(d).first.fait, isFalse, reason: 'une série sans répétitions n\'a rien à enregistrer');
    expect(ReposMinuteur.instance.actif, isFalse);
    final reps = t.widget<TextField>(champ(seriesDe(d).first, 'reps'));
    expect(reps.focusNode!.hasFocus, isTrue);

    // Une fois remplie, elle se valide, même sans charge.
    await t.enterText(champ(seriesDe(d).first, 'reps'), '8');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(seriesDe(d).first.fait, isTrue);
    expect(seriesDe(d).first.reps, 8);
    expect(seriesDe(d).first.poids, isNull);
    await demonter(t);
  });

  testWidgets('ajouter une série reprend la dernière ; la supprimer puis annuler la remet à sa place', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d, series: 2);
    await ouvrirSeance(t);

    await t.enterText(champ(seriesDe(d)[1], 'poids'), '14');
    await t.enterText(champ(seriesDe(d)[1], 'reps'), '13');
    await t.pump();
    await t.tap(find.text('+ Ajouter une série'));
    await attendre(t, tours: 2);
    expect(seriesDe(d).length, 3);
    expect(seriesDe(d)[2].poids, 14);
    expect(seriesDe(d)[2].reps, 13);
    expect(seriesDe(d)[2].fait, isFalse);

    // Suppression par le panneau « Type de série », puis « Annuler ».
    final milieu = seriesDe(d)[1];
    await t.tap(find.bySemanticsLabel(RegExp('Type de série')).at(1));
    await attendre(t, tours: 2);
    await t.tap(find.text('Supprimer la série'));
    await attendre(t, tours: 2);
    expect(seriesDe(d).map((s) => s.id), isNot(contains(milieu.id)));
    expect(seriesDe(d).length, 2);
    await t.tap(find.text('Annuler'));
    await attendre(t, tours: 2);
    expect(seriesDe(d).length, 3);
    expect(seriesDe(d)[1].id, milieu.id);
    expect(seriesDe(d)[1].reps, 13);

    // Suppression au glissé.
    final premiere = seriesDe(d).first.id;
    // Le glissé part du précédent : sur un champ de saisie, c'est le champ qui prend le geste.
    await t.dragFrom(t.getTopLeft(find.byKey(ValueKey('ligne-$premiere'))) + const Offset(110, 28), const Offset(-360, 0));
    await attendre(t, tours: 8);
    expect(seriesDe(d).length, 2);
    expect(seriesDe(d).map((s) => s.id), isNot(contains(premiere)));
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('remplacer un exercice qui a des séries validées ne les perd pas', (t) async {
    final d = await monter(t, depart: '/');
    final ex = await seanceFourchette(t, d);
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    ReposMinuteur.instance.passer();

    await t.tap(find.bySemanticsLabel('Plus d\'actions').first);
    await attendre(t, tours: 2);
    await t.tap(find.text('Remplacer l\'exercice'));
    await attendre(t, tours: 3);
    final utiliser = find.text('Utiliser cet exercice');
    expect(utiliser, findsOneWidget, reason: 'le catalogue de la démo doit proposer une alternative');
    await t.tap(utiliser);
    await attendre(t, tours: 3);

    // La question est posée ; on garde ce qui est fait.
    expect(find.textContaining('série validée'), findsWidgets);
    await t.tap(find.textContaining('Garder'));
    await attendre(t, tours: 3);

    final exos = d.sessions.active!.exercices;
    expect(exos.length, 2);
    expect(exos[0].exerciseId, ex.id);
    expect(exos[0].series.length, 1);
    expect(exos[0].series.single.fait, isTrue);
    expect(exos[0].series.single.reps, 12);
    expect(exos[1].exerciseId, isNot(ex.id));
    expect(exos[1].series.length, 3);
    expect(exos[1].series.every((s) => !s.fait), isTrue);
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('la séance entière tient en 360 de large et sur le Fold ouvert, clavier ouvert compris', (t) async {
    for (final taille in const [Size(360, 740), Size(344, 700), Size(320, 640), Size(884, 1100)]) {
      final d = await monter(t, depart: '/', taille: taille);
      await seanceFourchette(t, d);
      await t.runAsync(() => d.settings.update((s) => s.copyWith(afficherRpe: true)));
      await ouvrirSeance(t);
      expect(t.takeException(), isNull, reason: 'débordement en ${taille.width.toInt()} avec la colonne RPE');
      await t.tap(champ(seriesDe(d).first, 'poids'));
      await t.pump();
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await attendre(t, tours: 2);
      expect(t.takeException(), isNull, reason: 'débordement en ${taille.width.toInt()} clavier ouvert');
      await capture(t, 'saisie-${taille.width.toInt()}-clavier');
      t.view.resetViewInsets();
      await t.runAsync(() => d.settings.update((s) => s.copyWith(afficherRpe: false)));
      await demonter(t);
    }
  });
}
