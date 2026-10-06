import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/carte_jour.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_templates.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/ligne_routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils.dart';

/// Parcours sur les routines et les programmes : supprimer, dupliquer,
/// déplacer, vignette, éditeur. Chaque test part des données de la maquette.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final maintenant = DateTime.now();

  Future<AppData> depart(WidgetTester t, String adresse, {Size taille = tailleMaquette}) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, adresse, taille: taille);
    await attendre(t, 2);
    return data;
  }

  Future<void> ouvrirActions(WidgetTester t, String nom) async {
    final bouton = find.bySemanticsLabel('Actions sur $nom');
    if (bouton.evaluate().isEmpty) await t.scrollUntilVisible(bouton, 200, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(bouton.first);
    await t.pump();
    await t.tap(bouton.first);
    await attendre(t, 3);
  }

  testWidgets('supprimer une routine : l\'historique reste, les programmes sont nettoyés, « Annuler » la remet', (t) async {
    final data = await depart(t, '/entrainer?onglet=routines');
    final prefs = RoutinePrefs.of(data.store);
    await prefs.choisirJour('r-cardio', 7);
    await prefs.basculerFavori('r-cardio');
    final seances = data.sessions.sessions.length;
    final avant = data.routines.byId('r-cardio')!;

    await ouvrirActions(t, 'CARDIO');
    await t.tap(find.text('Supprimer'));
    await attendre(t, 3);
    expect(find.text('Supprimer « CARDIO » ?'), findsOneWidget);
    expect(find.textContaining('DT COACH Tristan V3'), findsOneWidget, reason: 'le message nomme les programmes touchés');
    await t.tap(find.text('Supprimer'));
    await attendre(t, 2);
    await capturer(t, 'routines', 'test-suppression-message');

    expect(data.routines.byId('r-cardio'), isNull);
    expect(data.sessions.sessions.length, seances, reason: 'aucune séance perdue');
    expect(data.sessions.lastForRoutine('r-cardio'), isNotNull, reason: 'la séance garde le lien vers la routine');
    for (final p in data.programs.programs) {
      expect(p.routineIds, isNot(contains('r-cardio')), reason: p.nom);
    }
    expect(prefs.estFavori('r-cardio'), isFalse);
    expect(prefs.vignetteDe('r-cardio'), isNull);
    expect(find.bySemanticsLabel('Actions sur CARDIO'), findsNothing);

    // Le message et son bouton « Annuler » doivent apparaître.
    expect(find.text('Routine supprimée.'), findsOneWidget);
    await t.tap(find.text('Annuler').last);
    await attendre(t, 2);
    final apres = data.routines.byId('r-cardio');
    expect(apres, isNotNull);
    expect(apres!.exercices.length, avant.exercices.length);
    expect(apres.ordre, avant.ordre);
    expect(data.programs.byId('p-v3')!.routineIds, contains('r-cardio'));
    expect(data.programs.byId('p-v3')!.routineIds.indexOf('r-cardio'), 3, reason: 'à sa place dans le cycle');
    expect(prefs.estFavori('r-cardio'), isTrue);
    expect(prefs.vignetteDe('r-cardio')?.jour, 7);
    expect(t.takeException(), isNull);
  });

  testWidgets('dupliquer une routine : copie indépendante, rangée après l\'originale, sans historique', (t) async {
    final data = await depart(t, '/entrainer/programmes/p-v3');
    await RoutinePrefs.of(data.store).choisirJour('r-pecs-triceps', 5);
    await ouvrirActions(t, 'PECS / TRICEPS');
    await t.tap(find.text('Dupliquer'));
    await attendre(t, 3);
    final copie = data.routines.routines.firstWhere((r) => r.nom == 'PECS / TRICEPS (copie)');
    final ids = data.programs.byId('p-v3')!.routineIds;
    expect(ids.indexOf(copie.id), ids.indexOf('r-pecs-triceps') + 1);
    expect(data.programs.byId('p-v1')!.routineIds, contains(copie.id), reason: 'dans tous les programmes de l\'originale');
    expect(data.sessions.lastForRoutine(copie.id), isNull);
    expect(RoutinePrefs.of(data.store).vignetteDe(copie.id)?.jour, 5);
    final original = data.routines.byId('r-pecs-triceps')!;
    expect(copie.exercices.map((e) => e.exerciseId), original.exercices.map((e) => e.exerciseId));
    expect(find.text('PECS / TRICEPS (copie)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('déplacer une routine : elle quitte les autres programmes, « Elle y est déjà » sinon', (t) async {
    final data = await depart(t, '/entrainer?onglet=routines');
    await ouvrirActions(t, 'FULL BODY');
    await t.tap(find.text('Déplacer dans un autre programme'));
    await attendre(t, 3);
    expect(find.text('Déplacer « FULL BODY »'), findsOneWidget);
    await t.tap(find.textContaining('DT COACH Tristan V3', findRichText: true));
    await attendre(t, 2);
    expect(data.programs.byId('p-v3')!.routineIds.last, 'r-ancien');
    expect(data.programs.byId('p-v1')!.routineIds, isNot(contains('r-ancien')));
    expect(data.programs.byId('p-v2')!.routineIds, isNot(contains('r-ancien')));
    expect(find.textContaining('Routine déplacée dans'), findsOneWidget);
    expect(data.routines.byId('r-ancien'), isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('supprimer un programme : routines et séances gardées, retour à la liste', (t) async {
    final data = await depart(t, '/entrainer');
    final routines = data.routines.routines.length;
    final seances = data.sessions.sessions.length;
    await ProgramPlanRepo.of(data.store).save(const ProgramPlan(programId: 'p-v3', dechargeToutesLes: 4));
    await t.tap(find.text('DT COACH Tristan V3'));
    await attendre(t, 4);
    await t.tap(find.bySemanticsLabel('Actions sur le programme'));
    await attendre(t, 3);
    await t.tap(find.text('Supprimer'));
    await attendre(t, 3);
    await t.tap(find.text('Supprimer'));
    await attendre(t, 4);
    expect(data.programs.byId('p-v3'), isNull);
    expect(data.programs.active, isNull);
    expect(data.routines.routines.length, routines);
    expect(data.sessions.sessions.length, seances);
    expect(data.sessions.sessions.where((s) => s.programId == 'p-v3'), isNotEmpty, reason: 'les séances gardent leur programme d\'origine');
    expect(ProgramPlanRepo.of(data.store).hasPlan('p-v3'), isFalse);
    expect(find.text('Programme introuvable'), findsNothing);
    expect(find.text('Créer un programme'), findsOneWidget, reason: 'retour au volet Programmes');
    expect(find.text('DT COACH Tristan V3'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('dupliquer un programme : mêmes routines, avancement à zéro, pas suivi', (t) async {
    final data = await depart(t, '/entrainer/programmes/p-v3');
    await t.tap(find.bySemanticsLabel('Actions sur le programme'));
    await attendre(t, 3);
    await t.tap(find.text('Dupliquer'));
    await attendre(t, 4);
    final copie = data.programs.programs.firstWhere((p) => p.nom == 'DT COACH Tristan V3 (copie)');
    expect(copie.routineIds, data.programs.byId('p-v3')!.routineIds);
    expect(copie.actif, isFalse);
    expect(copie.seancesFaites, 0);
    expect(data.programs.active?.id, 'p-v3');
    expect(find.text('DT COACH Tristan V3 (copie)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('vignette : deux appuis rapides sur « Choisir » ne referment que le panneau', (t) async {
    final data = await depart(t, '/entrainer/programmes/p-v3');
    await ouvrirActions(t, 'PECS / TRICEPS');
    await t.tap(find.text('Changer l’image'));
    await attendre(t, 3);
    await t.tap(find.descendant(of: find.byType(PanneauBas), matching: find.text('Mer')));
    await t.pump();
    final bouton = find.text('Choisir « Mer »');
    await t.tap(bouton);
    await t.tap(bouton, warnIfMissed: false);
    await attendre(t, 4);
    expect(RoutinePrefs.of(data.store).vignetteDe('r-pecs-triceps')?.jour, 3);
    expect(find.byType(PanneauBas), findsNothing);
    expect(find.text('Ajouter une routine au programme'), findsOneWidget, reason: 'la page du programme est toujours là');
    expect(t.takeException(), isNull);
  });

  testWidgets('photo personnelle disparue : la carte de jour revient, sans erreur', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    final absent = '${Directory.systemTemp.path}${Platform.pathSeparator}aesthetic_photo_absente_${maintenant.microsecondsSinceEpoch}.jpg';
    await t.runAsync(() => RoutinePrefs.of(data.store).choisirPhoto('r-dos-biceps', absent));
    await lancer(t, data, '/entrainer/programmes/p-v3');
    await attendre(t, 4);
    final ligne = find.ancestor(of: find.text('DOS / BICEPS'), matching: find.byType(LigneRoutine));
    expect(find.descendant(of: ligne, matching: find.byType(CarteJour)), findsOneWidget);
    expect(find.descendant(of: ligne, matching: find.text('Mar')), findsOneWidget, reason: 'carte de son rang');
    expect(t.takeException(), isNull);
    // Le panneau de vignette s'ouvre quand même, sur la carte de son rang.
    await ouvrirActions(t, 'DOS / BICEPS');
    await t.tap(find.text('Changer l’image'));
    await attendre(t, 3);
    expect(find.text('Choisir « Mar »'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('éditeur : « Annuler » du message après avoir quitté la page ne lève rien', (t) async {
    final data = await depart(t, '/entrainer?onglet=routines');
    routeur(t).push('/entrainer/routines/r-bras/modifier');
    await attendre(t, 4);
    expect(find.text('Modifier la routine'), findsOneWidget);
    await t.tap(find.byTooltip('Options').first);
    await attendre(t, 2);
    await t.tap(find.text('Retirer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('retiré.'), findsOneWidget);
    routeur(t).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Modifier la routine'), findsNothing);
    if (find.text('Annuler').evaluate().isNotEmpty) {
      await t.tap(find.text('Annuler'), warnIfMissed: false);
      await t.pump();
    }
    expect(t.takeException(), isNull);
    expect(data.routines.byId('r-bras')!.exercices, hasLength(3), reason: 'rien n\'a été enregistré');
  });

  testWidgets('éditeur : renommer et réordonner gardent l\'identité, donc l\'historique et la suggestion', (t) async {
    final data = await depart(t, '/entrainer?onglet=routines');
    final avant = data.routines.byId('r-pecs-epaules')!;
    routeur(t).push('/entrainer/routines/r-pecs-epaules/modifier');
    await attendre(t, 4);
    await t.enterText(find.byType(TextField).first, 'Épaules du vendredi');
    await t.pump();
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 4);
    final apres = data.routines.byId('r-pecs-epaules')!;
    expect(apres.nom, 'Épaules du vendredi');
    expect(apres.ordre, avant.ordre);
    expect(apres.creeLe, avant.creeLe);
    expect(apres.exercices.map((e) => e.id), avant.exercices.map((e) => e.id));
    expect(data.sessions.lastForRoutine('r-pecs-epaules'), isNotNull);
    expect(find.text('Épaules du vendredi', skipOffstage: false), findsNWidgets(2), reason: 'la suggestion suit le nouveau nom');
    expect(data.programs.byId('p-v3')!.routineIds, contains('r-pecs-epaules'));
    expect(t.takeException(), isNull);
  });

  testWidgets('éditeur : la dernière série d\'un exercice ne peut pas être supprimée', (t) async {
    final data = await depart(t, '/entrainer?onglet=routines');
    final r = data.routines.byId('r-cardio')!;
    await t.runAsync(() => data.routines.save(r.copyWith(exercices: [r.exercices.first.copyWith(series: const [PlannedSet(reps: 20)])])));
    await t.pump();
    routeur(t).push('/entrainer/routines/r-cardio/modifier');
    await attendre(t, 4);
    await t.tap(find.text('20'));
    await attendre(t, 2);
    expect(find.byTooltip('Supprimer la série'), findsNothing, reason: 'un exercice sans série ne se lance pas');
    expect(t.takeException(), isNull);
  });

  testWidgets('ajouter deux fois la même idée : prévenu, puis deux programmes distincts', (t) async {
    final data = await depart(t, '/entrainer/programmes/modele/full-body-3j');
    await attendre(t, 4);
    final routines = data.routines.routines.length;
    await t.tap(find.text('Ajouter à ma bibliothèque'));
    await attendre(t, 3);
    expect(find.textContaining('déjà dans ta bibliothèque'), findsNothing);
    expect(find.textContaining('à la place de DT COACH Tristan V3', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('Le suivre maintenant', findRichText: true));
    await t.pump();
    await t.tap(find.text('Ajouter à ma bibliothèque').last);
    await attendre(t, 6);
    final premier = data.programs.programs.firstWhere((p) => p.nom == 'Full body 3 jours');
    expect(premier.actif, isTrue);
    expect(data.programs.programs.where((p) => p.actif), hasLength(1), reason: 'un seul programme en cours');
    final ancien = data.programs.byId('p-v3')!;
    expect(ancien.actif, isFalse);
    expect(ancien.seancesFaites, 21, reason: 'l\'avancement de l\'ancien est gardé');
    expect(data.routines.routines.length, routines + 3);

    routeur(t).go('/entrainer/programmes/modele/full-body-3j');
    await attendre(t, 6);
    await t.tap(find.text('Ajouter à ma bibliothèque'));
    await attendre(t, 3);
    expect(find.textContaining('déjà dans ta bibliothèque'), findsOneWidget);
    await t.tap(find.textContaining('L’ajouter sans le suivre', findRichText: true));
    await t.pump();
    await t.tap(find.text('Ajouter à ma bibliothèque').last);
    await attendre(t, 6);
    final copies = data.programs.programs.where((p) => p.nom.startsWith('Full body 3 jours')).toList();
    expect(copies, hasLength(2));
    expect(copies.map((p) => p.nom).toSet(), hasLength(2), reason: 'deux programmes de même nom ne se distinguent pas dans la liste');
    expect(copies.first.routineIds.toSet().intersection(copies.last.routineIds.toSet()), isEmpty, reason: 'chacun ses routines');
    expect(data.programs.active?.id, premier.id);
    expect(t.takeException(), isNull);
  });

  test('ajouter une idée : routines neuves à chaque fois, plan relié au modèle', () async {
    final data = await donneesVides();
    final m = modeleParId('push-pull-legs-6j')!;
    final plans = ProgramPlanRepo.of(data.store);
    final p = await creerProgrammeDepuisModele(modele: m, exercices: data.exercises, routines: data.routines, programmes: data.programs, plans: plans);
    expect(p.actif, isTrue);
    expect(plans.planFor(p.id).modeleId, m.id);
    expect(p.routineIds.every((id) => data.routines.byId(id) != null), isTrue);
    expect(data.routines.routines.every((r) => r.exercices.isNotEmpty), isTrue);
  });
}
