import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/editeur.dart';
import 'package:aesthetic/features/seance/widgets/exercice_carte.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_saisie_outils.dart';

/// Valeurs saisies dans une ligne de série, pour chaque suivi d'exercice, et
/// logique de l'éditeur (types, remplacement, précédent, fourchette).
void main() {
  Finder cle(String c) => find.byKey(ValueKey('s-$c'));

  testWidgets('poids à virgule, à point, vide, absurde', (t) async {
    final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.poidsReps));
    await t.enterText(cle('poids'), '62,5');
    expect(b.set.poids, 62.5);
    await t.enterText(cle('poids'), '62.25');
    expect(b.set.poids, 62.25);
    await t.enterText(cle('poids'), '');
    expect(b.set.poids, isNull, reason: 'champ vidé, charge effacée');
    await t.enterText(cle('poids'), '1,2,3');
    expect(b.set.poids, isNull, reason: 'nombre illisible : pas de charge inventée');
    await t.enterText(cle('poids'), '-80kg');
    expect(b.set.poids, 80, reason: 'seuls les chiffres passent');
    await t.enterText(cle('poids'), '123456789012');
    expect(texteDe(t, cle('poids')).length, lessThanOrEqualTo(7), reason: 'une charge ne fait pas douze chiffres');
    await t.enterText(cle('reps'), '12:5');
    expect(b.set.reps, 125, reason: 'les répétitions ne prennent que des chiffres');
    await t.enterText(cle('reps'), '1234567');
    expect(texteDe(t, cle('reps')).length, lessThanOrEqualTo(4));
    await t.enterText(cle('reps'), '');
    expect(b.set.reps, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('en livres : la charge est stockée en kilos et réaffichée sans dérive', (t) async {
    final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.poidsReps, unite: UnitePoids.lb));
    await t.enterText(cle('poids'), '135');
    await t.pump();
    expect(b.set.poids, closeTo(61.235, 0.001));
    expect(texteDe(t, cle('poids')), '135', reason: 'le champ n\'est pas réécrit pendant la saisie');
    // Reconstruit sans le curseur : toujours 135, pas 134,99.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(texteDe(t, cle('poids')), '135');
    expect(find.text('Lb'), findsOneWidget);
  });

  testWidgets('poids du corps lesté et assisté : en-tête signé, précédent signé, validation sans charge', (t) async {
    final leste = await monterLigne(
      t,
      const BancLigne(
        depart: WorkoutSet(id: 's'),
        suivi: ExerciseTracking.poidsDuCorpsLeste,
        precedent: WorkoutSet(id: 'p', poids: 10, reps: 8, fait: true),
      ),
    );
    expect(find.text('+Kg'), findsOneWidget);
    expect(find.text('+10 kg × 8'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(leste.set.fait, isTrue);
    expect(leste.set.poids, 10, reason: 'champs vides : la série reprend la fois précédente');
    expect(leste.set.reps, 8);

    await t.pumpWidget(const SizedBox());
    final assiste = await monterLigne(
      t,
      const BancLigne(
        key: ValueKey('assiste'),
        depart: WorkoutSet(id: 's', reps: 6),
        suivi: ExerciseTracking.poidsDuCorpsAssiste,
        precedent: WorkoutSet(id: 'p', poids: 20, reps: 5, fait: true),
      ),
    );
    expect(find.text('-Kg'), findsOneWidget);
    expect(find.text('-20 kg × 5'), findsOneWidget);
    expect(precedentCourt(const WorkoutSet(id: 'p', reps: 12), ExerciseTracking.poidsDuCorpsLeste, UnitePoids.kg), '12 reps',
        reason: 'au poids du corps sans lest, pas de « +0kg »');
    await t.enterText(cle('poids'), '15');
    expect(assiste.set.poids, 15, reason: 'l\'aide est stockée positive, le signe est dans l\'affichage');
    expect(assiste.set.reps, 6);
  });

  testWidgets('répétitions seules : la série se valide sans charge', (t) async {
    final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.repsSeules));
    expect(cle('poids'), findsNothing);
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.validations, 0, reason: 'rien de saisi, rien à valider');
    await t.enterText(cle('reps'), '20');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.set.fait, isTrue);
    expect(b.set.reps, 20);
    expect(b.set.poids, isNull);
    expect(b.set.volume, 0);
  });

  testWidgets('exercice à la durée : secondes ou minutes:secondes, réécrit proprement', (t) async {
    final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.duree));
    expect(find.text('Temps'), findsOneWidget);
    expect(cle('reps'), findsNothing);
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.validations, 0, reason: 'pas de durée, pas de validation');

    await t.enterText(cle('duree'), '90');
    expect(b.set.dureeSec, 90);
    await t.enterText(cle('duree'), '1:45');
    expect(b.set.dureeSec, 105);
    await t.enterText(cle('duree'), '2:');
    expect(b.set.dureeSec, 120);
    await t.enterText(cle('duree'), '');
    expect(b.set.dureeSec, isNull);
    await t.enterText(cle('duree'), '75');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.set.fait, isTrue);
    expect(b.set.dureeSec, 75);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(texteDe(t, cle('duree')), '01:15');
  });

  testWidgets('distance et durée : kilomètres à virgule, stockés en mètres', (t) async {
    final b = await monterLigne(
      t,
      const BancLigne(
        depart: WorkoutSet(id: 's'),
        suivi: ExerciseTracking.distanceDuree,
        precedent: WorkoutSet(id: 'p', distanceM: 5000, dureeSec: 1500, fait: true),
      ),
    );
    expect(find.text('Km'), findsOneWidget);
    expect(find.text('Temps'), findsOneWidget);
    expect(find.textContaining('km × 25:00'), findsOneWidget);
    await t.enterText(cle('dist'), '2,5');
    expect(b.set.distanceM, 2500);
    await t.enterText(cle('duree'), '12:30');
    expect(b.set.dureeSec, 750);
    await t.enterText(cle('dist'), '');
    expect(b.set.distanceM, isNull);
    expect(b.set.dureeSec, 750, reason: 'vider la distance ne touche pas à la durée');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.set.fait, isTrue);
    expect(b.set.distanceM, 5000, reason: 'la distance vide reprend la fois précédente');
    expect(b.set.dureeSec, 750);
    expect(t.takeException(), isNull);
  });

  testWidgets('poids et durée (gainage lesté) : les deux champs, validation sur la durée', (t) async {
    final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.poidsDuree));
    await t.enterText(cle('poids'), '20');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.validations, 0);
    await t.enterText(cle('duree'), '60');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(b.set.fait, isTrue);
    expect(b.set.poids, 20);
    expect(b.set.dureeSec, 60);
  });

  testWidgets('toucher « Précédent » remplit les champs, même celui qui a le curseur', (t) async {
    final b = await monterLigne(
      t,
      const BancLigne(
        depart: WorkoutSet(id: 's'),
        suivi: ExerciseTracking.poidsReps,
        precedent: WorkoutSet(id: 'p', poids: 42.5, reps: 9, fait: true),
      ),
    );
    await t.tap(cle('poids'));
    await t.enterText(cle('poids'), '3');
    await t.pump();
    await t.tap(find.text('42,5 kg × 9'));
    await t.pump();
    expect(b.set.poids, 42.5);
    expect(b.set.reps, 9);
    expect(texteDe(t, cle('poids')), '42,5', reason: 'le champ en cours de saisie doit montrer la valeur copiée');
    expect(texteDe(t, cle('reps')), '9');
  });

  testWidgets('fourchette de la routine : montrée tant que rien n\'est saisi, jamais à la place d\'une valeur saisie', (t) async {
    await monterLigne(
      t,
      const BancLigne(depart: WorkoutSet(id: 's', poids: 10, reps: 12), suivi: ExerciseTracking.poidsReps, cible: '12-15', cibleDepart: 12),
    );
    expect(find.text('12-15'), findsOneWidget);
    expect(texteDe(t, cle('reps')), '');

    // Ligne reconstruite (défilement, redémarrage) avec 14 déjà saisi.
    await t.pumpWidget(const SizedBox());
    await monterLigne(
      t,
      const BancLigne(key: ValueKey('b'), depart: WorkoutSet(id: 's', poids: 10, reps: 14), suivi: ExerciseTracking.poidsReps, cible: '12-15', cibleDepart: 12),
    );
    expect(find.text('12-15'), findsNothing);
    expect(texteDe(t, cle('reps')), '14');

    // Validée telle quelle : c'est le bas de la fourchette qui est enregistré et montré.
    await t.pumpWidget(const SizedBox());
    final c = await monterLigne(
      t,
      const BancLigne(key: ValueKey('c'), depart: WorkoutSet(id: 's', poids: 10, reps: 12), suivi: ExerciseTracking.poidsReps, cible: '12-15', cibleDepart: 12),
    );
    await t.tap(find.bySemanticsLabel('Valider la série'));
    await t.pump();
    expect(c.set.fait, isTrue);
    expect(c.set.reps, 12);
    expect(texteDe(t, cle('reps')), '12');
    expect(find.text('12-15'), findsNothing);
  });

  testWidgets('la ligne tient en 320 de large avec de grandes valeurs', (t) async {
    await monterLigne(
      t,
      const BancLigne(
        depart: WorkoutSet(id: 's', poids: 1234.5, reps: 9999, fait: true),
        suivi: ExerciseTracking.poidsReps,
        precedent: WorkoutSet(id: 'p', poids: 1234.5, reps: 9999, fait: true),
      ),
      largeur: 320,
    );
    expect(t.takeException(), isNull);
    final coche = t.getSize(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Décocher la série'));
    expect(coche.width, greaterThanOrEqualTo(44));
    expect(coche.height, greaterThanOrEqualTo(44));
    final repere = t.getSize(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Type de série'));
    expect(repere.height, greaterThanOrEqualTo(44));
  });

  group('éditeur', () {
    Future<(SessionRepo, EditeurDirect)> depart(List<String> ids) async {
      final repo = SessionRepo(Store.memory());
      await repo.load();
      await repo.startEmpty();
      final ed = EditeurDirect(repo);
      await ed.ajouterExercices(ids);
      return (repo, ed);
    }

    test('les douze types se posent sur une série validée sans toucher à ses valeurs', () async {
      final (repo, ed) = await depart(['a']);
      final se = repo.active!.exercices.single;
      final s = se.series.first;
      await ed.validerSerie(se.id, s.copyWith(poids: 50, reps: 10), fait: true);
      await repo.updateSet(se.id, repo.active!.exercices.single.series.first.copyWith(tempsReposSec: 95));
      expect(SetType.values.length, 12);
      for (final type in SetType.ordrePanneau) {
        await ed.changerType(se.id, s.id, type);
        final x = repo.active!.exercices.single.series.first;
        expect(x.type, type);
        expect(x.fait, isTrue);
        expect(x.poids, 50);
        expect(x.reps, 10);
        expect(x.tempsReposSec, 95, reason: 'le repos noté survit au changement de type');
        expect(x.faitLe, isNotNull);
        expect(repo.active!.volume, type == SetType.echauffement ? 0 : 500);
        expect(repo.active!.nbSeriesFaites, type == SetType.echauffement ? 0 : 1);
      }
      // Relu depuis le disque, le dernier type est là.
      final relu = SessionRepo(repo.store);
      await relu.load();
      expect(relu.active!.exercices.single.series.first.type, SetType.ordrePanneau.last);
      // Repères : numéros pour les normales, lettres sinon, l'échauffement hors compte.
      expect(
        libellesSeries(const [
          WorkoutSet(id: '1', type: SetType.echauffement),
          WorkoutSet(id: '2'),
          WorkoutSet(id: '3', type: SetType.degressive),
          WorkoutSet(id: '4'),
        ]),
        ['É', '1', 'DG', '3'],
      );
      ed.dispose();
    });

    test('valider est idempotent : deux validations de suite gardent la première date', () async {
      final (repo, ed) = await depart(['a']);
      final se = repo.active!.exercices.single;
      final s = se.series.first.copyWith(poids: 40, reps: 8);
      expect(await ed.validerSerie(se.id, s, fait: true), isTrue);
      final date = repo.active!.exercices.single.series.first.faitLe;
      expect(await ed.validerSerie(se.id, s, fait: true), isFalse, reason: 'déjà validée : rien ne change');
      expect(repo.active!.exercices.single.series.first.fait, isTrue);
      expect(repo.active!.exercices.single.series.first.faitLe, date);
      expect(await ed.validerSerie(se.id, s, fait: false), isTrue);
      expect(repo.active!.exercices.single.series.first.fait, isFalse);
      expect(repo.active!.exercices.single.series.first.faitLe, isNull);
      expect(repo.active!.exercices.single.series.first.poids, 40, reason: 'dévalider garde les valeurs');
      expect(await ed.validerSerie(se.id, s.copyWith(reps: 9), fait: true), isTrue);
      expect(repo.active!.exercices.single.series.first.reps, 9);
      // Une série supprimée entre-temps ne revient pas.
      await ed.supprimerSerie(se.id, s.id);
      expect(await ed.validerSerie(se.id, s, fait: true), isFalse);
      expect(repo.active!.exercices.single.series.any((x) => x.id == s.id), isFalse);
      ed.dispose();
    });

    test('remplacer : tout remplacer, ou garder les séries faites à part', () async {
      final (repo, ed) = await depart(['a', 'b']);
      final se = repo.active!.exercices.first;
      await ed.validerSerie(se.id, se.series[0].copyWith(poids: 60, reps: 8), fait: true);
      await ed.validerSerie(se.id, se.series[1].copyWith(poids: 60, reps: 7), fait: true);
      await ed.notes(se.id, 'Banc à 30 degrés');

      await ed.remplacerExercice(se.id, 'z', garderFaites: true);
      var exos = repo.active!.exercices;
      expect(exos.map((e) => e.exerciseId), ['a', 'z', 'b']);
      expect(exos[0].series.length, 2);
      expect(exos[0].series.every((s) => s.fait), isTrue);
      expect(exos[0].volume, 60 * 8 + 60 * 7);
      expect(exos[0].note, 'Banc à 30 degrés');
      expect(exos[1].series.length, 1, reason: 'la série qui restait à faire passe au nouvel exercice');
      expect(exos[1].series.single.fait, isFalse);
      expect(exos[1].id, isNot(se.id));
      expect(exos[1].reposSec, se.reposSec);

      // Tout était fait : le nouvel exercice démarre avec une série à faire.
      final b = exos[2];
      for (final s in b.series) {
        await ed.validerSerie(b.id, s.copyWith(reps: 5), fait: true);
      }
      await ed.remplacerExercice(b.id, 'y', garderFaites: true);
      exos = repo.active!.exercices;
      expect(exos.map((e) => e.exerciseId), ['a', 'z', 'b', 'y']);
      expect(exos[3].series.length, 1);
      expect(exos[3].series.single.fait, isFalse);

      // Tout remplacer : même emplacement, mêmes séries, rien de validé.
      final a = exos[0];
      await ed.remplacerExercice(a.id, 'w');
      exos = repo.active!.exercices;
      expect(exos[0].exerciseId, 'w');
      expect(exos[0].id, a.id);
      expect(exos[0].series.map((s) => s.id), a.series.map((s) => s.id));
      expect(exos[0].series.every((s) => !s.fait && s.poids == null), isTrue);
      expect(exos[0].note, 'Banc à 30 degrés');
      // Inconnu : rien ne bouge.
      final avant = repo.active!;
      await ed.remplacerExercice('inconnu', 'q');
      expect(repo.active!.exercices.map((e) => e.exerciseId), avant.exercices.map((e) => e.exerciseId));
      ed.dispose();
    });

    test('remplacer reprend la dernière performance du nouvel exercice', () async {
      final store = Store.memory();
      final repo = SessionRepo(store);
      await repo.load();
      final t0 = DateTime(2026, 9, 28, 18);
      await repo.save(WorkoutSession(id: 'h', nom: 'Avant', debut: t0, fin: t0.add(const Duration(hours: 1)), exercices: const [
        SessionExercise(id: 'e', exerciseId: 'z', series: [
          WorkoutSet(id: '1', poids: 30, reps: 12, fait: true),
          WorkoutSet(id: '2', poids: 32.5, reps: 10, fait: true),
        ]),
      ]));
      await repo.startEmpty();
      final ed = EditeurDirect(repo);
      await ed.ajouterExercices(['a']);
      final se = repo.active!.exercices.single;
      await ed.remplacerExercice(se.id, 'z');
      final series = repo.active!.exercices.single.series;
      expect(series.length, 3);
      expect([series[0].poids, series[0].reps], [30, 12]);
      expect([series[1].poids, series[1].reps], [32.5, 10]);
      expect([series[2].poids, series[2].reps], [null, null], reason: 'pas de troisième série la dernière fois');
      ed.dispose();
    });

    test('colonne « Précédent » : la dernière séance terminée, série par série, échauffements à part', () async {
      final repo = SessionRepo(Store.memory());
      await repo.load();
      final t0 = DateTime(2026, 9, 1, 18);
      WorkoutSession s(String id, int jours, List<WorkoutSet> series) => WorkoutSession(
            id: id,
            nom: 'S',
            debut: t0.add(Duration(days: jours)),
            fin: t0.add(Duration(days: jours, hours: 1)),
            exercices: [SessionExercise(id: 'e$id', exerciseId: 'x', series: series)],
          );
      await repo.save(s('vieille', 0, const [WorkoutSet(id: 'v', poids: 50, reps: 5, fait: true)]));
      await repo.save(s('recente', 7, const [
        WorkoutSet(id: 'w', type: SetType.echauffement, poids: 20, reps: 10, fait: true),
        WorkoutSet(id: 'a', poids: 60, reps: 8, fait: true),
        WorkoutSet(id: 'b', poids: 60, reps: 6, fait: true),
      ]));
      // Une séance plus récente où l'exercice n'a aucune série faite ne compte pas.
      await repo.save(s('vide', 9, const [WorkoutSet(id: 'n', poids: 99, reps: 1)]));
      final avant = repo.lastFor('x')!.seriesFaites;
      expect(avant.map((x) => x.id), ['w', 'a', 'b']);

      const enCours = [
        WorkoutSet(id: '1'),
        WorkoutSet(id: '2', type: SetType.echauffement),
        WorkoutSet(id: '3', type: SetType.topSet),
        WorkoutSet(id: '4'),
      ];
      expect(precedentPour(enCours, 0, avant)!.id, 'a');
      expect(precedentPour(enCours, 1, avant)!.id, 'w');
      expect(precedentPour(enCours, 2, avant)!.id, 'b');
      expect(precedentPour(enCours, 3, avant), isNull, reason: 'pas de troisième série de travail la dernière fois');
      expect(precedentPour(enCours, 0, const []), isNull);
      expect(precedentPour(enCours, 0, null), isNull);
      // La séance en cours n'est pas son propre précédent.
      await repo.startEmpty();
      await repo.addExerciseToActive('x');
      final actif = repo.active!.exercices.single;
      await repo.updateSet(actif.id, actif.series.first.copyWith(poids: 200, reps: 1, fait: true));
      expect(repo.lastFor('x')!.seriesFaites.first.id, 'w');

      expect(cibleRepsPour(const [PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8), PlannedSet(reps: 8, repsMax: 8)], 0), '8-12');
      expect(cibleRepsPour(const [PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8)], 1), isNull);
      expect(cibleRepsPour(const [PlannedSet(reps: 8, repsMax: 8)], 0), isNull);
      expect(cibleRepsPour(const [PlannedSet(reps: 8, repsMax: 12)], 3), isNull, reason: 'série ajoutée en plus de la routine');
      expect(cibleRepsPour(null, 0), isNull);
    });

    test('ajouter une série : copie la dernière, jamais validée, et un échauffement donne une série normale', () async {
      final (repo, ed) = await depart(['a']);
      final se = repo.active!.exercices.single;
      await ed.validerSerie(se.id, se.series.last.copyWith(type: SetType.echauffement, poids: 20, reps: 15), fait: true);
      await ed.changerType(se.id, se.series.last.id, SetType.echauffement);
      await ed.ajouterSerie(se.id);
      var l = repo.active!.exercices.single.series;
      expect(l.length, 4);
      expect(l.last.fait, isFalse);
      expect(l.last.type, SetType.normale);
      expect([l.last.poids, l.last.reps], [20, 15]);
      expect(l.last.faitLe, isNull);
      expect(l.map((x) => x.id).toSet().length, 4, reason: 'identifiants uniques');

      // Tout supprimer puis ajouter : une série vide, sans erreur.
      for (final x in [...l]) {
        await ed.supprimerSerie(se.id, x.id);
      }
      expect(repo.active!.exercices.single.series, isEmpty);
      await ed.ajouterSerie(se.id);
      l = repo.active!.exercices.single.series;
      expect(l.single.poids, isNull);
      expect(l.single.type, SetType.normale);
      // Restaurer à un rang hors limites ne casse rien.
      await ed.restaurerSerie(se.id, const WorkoutSet(id: 'r', reps: 3), 99);
      expect(repo.active!.exercices.single.series.last.id, 'r');
      ed.dispose();
    });

    test('rafale de modifications : la dernière gagne, sur le disque aussi', () async {
      final (repo, ed) = await depart(['a']);
      final se = repo.active!.exercices.single;
      final s = se.series.first;
      final attentes = <Future<void>>[];
      for (var i = 1; i <= 60; i++) {
        attentes.add(ed.majSerie(se.id, s.copyWith(reps: i)));
      }
      attentes.add(ed.validerSerie(se.id, s.copyWith(reps: 61, poids: 100), fait: true));
      await Future.wait(attentes);
      final relu = SessionRepo(repo.store);
      await relu.load();
      final x = relu.active!.exercices.single.series.first;
      expect(x.reps, 61);
      expect(x.fait, isTrue);
      expect(relu.active!.volume, 6100);
      ed.dispose();
    });
  });
}
