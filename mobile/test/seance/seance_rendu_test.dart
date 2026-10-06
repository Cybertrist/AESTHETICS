import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:aesthetic/features/seance/pages/remplacer_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/panneaux.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

/// Rendus du module séance à la taille de la maquette, dans
/// `build/rendus/seance/`, à comparer aux captures `refs/modeles/captures`.

/// Une routine « Élévations latérales » comme sur la maquette 04, avec une
/// séance passée pour remplir la colonne « Précédent ».
Future<Routine> _routineMaquette(AppData d) async {
  final ex = d.exercises.all.firstWhere(
    (e) => e.nom.toLowerCase().contains('élévation') && e.nom.toLowerCase().contains('latérale'),
    orElse: () => d.exercises.all.firstWhere((e) => e.musclesPrincipaux.contains(Muscle.deltoidesLateraux)),
  );
  final r = Routine(
    id: 'maquette-epaules',
    nom: 'Épaules',
    creeLe: DateTime(2026, 9, 1),
    exercices: [
      RoutineExercise(
        id: 're1',
        exerciseId: ex.id,
        reposSec: 120,
        series: const [
          PlannedSet(poids: 10, reps: 12, repsMax: 15),
          PlannedSet(poids: 10, reps: 12, repsMax: 15),
          PlannedSet(poids: 10, reps: 12, repsMax: 15),
          PlannedSet(poids: 10, reps: 12, repsMax: 15),
        ],
      ),
    ],
  );
  await d.routines.save(r);
  final avant = DateTime.now().subtract(const Duration(days: 4));
  await d.sessions.save(WorkoutSession(
    id: 'maquette-avant',
    nom: 'Épaules',
    routineId: r.id,
    debut: avant,
    fin: avant.add(const Duration(minutes: 40)),
    exercices: [
      SessionExercise(id: 'a1', exerciseId: ex.id, reposSec: 120, series: const [
        WorkoutSet(id: 'p1', poids: 10, reps: 15, fait: true),
        WorkoutSet(id: 'p2', poids: 10, reps: 15, fait: true),
        WorkoutSet(id: 'p3', poids: 10, reps: 14, fait: true),
        WorkoutSet(id: 'p4', poids: 10, reps: 12, fait: true),
      ]),
    ],
  ));
  return r;
}

void main() {
  testWidgets('saisie des séries, menu, type de série, repos', (t) async {
    final d = await monter(t, depart: '/');
    final r = (await t.runAsync(() => _routineMaquette(d)))!;
    await t.runAsync(() => d.sessions.startFromRoutine(r));
    // Une séance commencée il y a un peu plus d'une demi-heure, comme la maquette.
    await t.runAsync(() => d.sessions.updateActive(
        d.sessions.active!.copyWith(debut: DateTime.now().subtract(const Duration(minutes: 32, seconds: 10)))));
    await attendre(t);

    // 03 : la barre « Entraînement en cours ».
    expect(find.text('Entraînement en cours'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Abandonner'), findsOneWidget);
    await capture(t, '03-seance-reduite');

    await t.tap(find.text('Reprendre'));
    await attendre(t);
    expect(find.text('Terminer'), findsOneWidget);
    expect(find.text('Minuteur de repos : 2:00'), findsOneWidget);
    expect(find.text('Ajouter une note…'), findsOneWidget);
    expect(find.text('12-15'), findsNWidgets(4), reason: 'la fourchette de la routine tient lieu de valeur');

    // Valider deux séries : la ligne passe au vert et le repos démarre.
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(ReposMinuteur.instance.actif, isTrue);
    expect(ReposMinuteur.instance.total, 120);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    final series = d.sessions.active!.exercices.single.series;
    expect(series.where((s) => s.fait).length, 2);
    expect(series.first.reps, 12);
    expect(find.text('2'), findsWidgets);
    await capture(t, '04-saisie-des-series');
    expect(t.takeException(), isNull);

    // 05 : le menu « Plus ».
    await toucherPlus(t);
    await attendre(t, tours: 2);
    expect(find.byType(PanneauBas), findsOneWidget);
    for (final l in ['Partager la séance', 'Mettre la séance en pause', 'Ajouter une photo', 'Ajouter des notes', 'Réglages de la séance', 'Abandonner la séance']) {
      expect(find.text(l), findsOneWidget);
    }
    await capture(t, '05-menu-de-la-seance');
    Navigator.of(t.element(find.byType(PanneauBas))).pop();
    await attendre(t, tours: 2);

    // 06 : le panneau « Type de série » en touchant le numéro.
    await t.tap(find.bySemanticsLabel(RegExp('Type de série')).at(2));
    await attendre(t, tours: 2);
    expect(find.byType(PanneauTypeSerie), findsOneWidget);
    for (final type in SetType.values) {
      expect(find.text(type.label), findsOneWidget);
    }
    await t.tap(find.bySemanticsLabel(RegExp('Expliquer Dégressive')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Tu baisses la charge'), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp('Expliquer Dégressive')));
    await t.pump(const Duration(milliseconds: 300));
    await capture(t, '06-type-de-serie');
    await t.tap(find.text('Top set'));
    await attendre(t, tours: 2);
    expect(d.sessions.active!.exercices.single.series[2].type, SetType.topSet);
    expect(find.text('T'), findsOneWidget);
    await capture(t, '04b-saisie-type-change');

    // 07 : le repos en plein écran.
    await t.tap(find.bySemanticsLabel(RegExp('Repos en cours')));
    await attendre(t, tours: 2);
    expect(find.text('Arrêter'), findsOneWidget);
    expect(find.text('Compte à rebours'), findsOneWidget);
    await capture(t, '07-repos-compte-a-rebours');
    final avant = ReposMinuteur.instance.total;
    await t.tap(find.text('+10'));
    await t.pump(const Duration(milliseconds: 300));
    expect(ReposMinuteur.instance.total, avant + 10);
    await t.tap(find.text('−10'));
    await t.pump(const Duration(milliseconds: 300));
    expect(ReposMinuteur.instance.total, avant);

    // 08 : « Arrêter » coupe le repos, on règle la durée.
    await t.tap(find.text('Arrêter'));
    await attendre(t, tours: 2);
    expect(ReposMinuteur.instance.actif, isFalse);
    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Minutes'), findsOneWidget);
    await capture(t, '08-repos-regler-la-duree');
    await t.tap(find.text('01:30'));
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Démarrer'));
    await t.pump(const Duration(milliseconds: 300));
    expect(ReposMinuteur.instance.actif, isTrue);
    expect(ReposMinuteur.instance.total, 90);
    ReposMinuteur.instance.passer();
    await t.pump(const Duration(milliseconds: 300));

    // Le chronomètre.
    await t.tap(find.text('Chronomètre'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('00:00'), findsOneWidget);
    await capture(t, '08b-repos-chronometre');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('remplacer un exercice', (t) async {
    final d = await monter(t, depart: '/');
    final squat = d.exercises.all.firstWhere(
      (e) => e.nom.toLowerCase().contains('squat') && e.equipement == 'barre',
      orElse: () => d.exercises.all.firstWhere((e) => e.musclesPrincipaux.contains(Muscle.quadriceps)),
    );
    final nav = Navigator.of(t.element(find.byType(Scaffold).first));
    nav.push(MaterialPageRoute<String>(builder: (_) => RemplacerPage(actuel: squat)));
    await attendre(t);
    expect(find.text('Remplacer ${squat.nom}'), findsOneWidget);
    expect(find.text('ALTERNATIVE CONSEILLÉE'), findsOneWidget);
    expect(find.text('Utiliser cet exercice'), findsOneWidget);
    expect(find.text('AUTRES EXERCICES PROCHES'), findsOneWidget);
    await capture(t, '09-remplacer-un-exercice');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('lancer la séance', (t) async {
    final d = await monter(t, depart: '/');
    final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
    routeurDe(t).push(SeancePaths.apercu(push.id));
    await attendre(t, tours: 8);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Commencer la séance'), findsOneWidget);
    expect(find.text('exercices'), findsOneWidget);
    await capture(t, '02-lancer-la-seance');

    await t.tap(find.text('Commencer la séance'));
    await attendre(t);
    expect(d.sessions.active?.routineId, push.id);
    expect(find.text('Terminer'), findsOneWidget);
    await capture(t, '04c-saisie-routine-push');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('terminer la séance, durée, type, bilan', (t) async {
    final d = await monter(t, depart: '/');
    final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
    await t.runAsync(() async {
      await d.sessions.startFromRoutine(push);
      final a = d.sessions.active!;
      // Toutes les séries faites, un peu plus lourd que d'habitude.
      await d.sessions.updateActive(a.copyWith(
        debut: DateTime.now().subtract(const Duration(hours: 1, minutes: 4, seconds: 12)),
        exercices: [
          for (final e in a.exercices)
            e.copyWith(series: [
              for (final s in e.series) s.copyWith(fait: true, poids: (s.poids ?? 20) + 2.5, reps: s.reps ?? 8, faitLe: DateTime.now()),
            ]),
        ],
      ));
    });
    routeurDe(t).push(SeancePaths.terminer);
    await attendre(t);
    expect(find.text('Terminer la séance'), findsOneWidget);
    expect(find.text('Envoyer vers Health Connect'), findsOneWidget);
    expect(find.text('1 h 04 min'), findsOneWidget);
    await capture(t, '10-terminer-la-seance');

    // 11 : corriger la durée.
    await t.tap(find.text('1 h 04 min'));
    await attendre(t, tours: 2);
    expect(find.byType(RoueDuree), findsOneWidget);
    await capture(t, '11-corriger-la-duree');
    await t.tap(find.text('Terminé'));
    await attendre(t, tours: 2);

    // 12 : le type d'activité.
    await t.tap(find.text('Musculation'));
    await attendre(t, tours: 2);
    expect(find.text('Type d\'activité'), findsOneWidget);
    await capture(t, '12-type-d-activite');
    await t.tap(find.text('Hybride'));
    await attendre(t, tours: 2);
    expect(find.text('Hybride'), findsOneWidget);

    // Enregistrer : la séance part dans l'historique avec son type.
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    expect(d.sessions.active, isNull);
    final faite = d.sessions.sessions.first;
    expect(faite.type, TypeSeance.hybride);
    expect(faite.duree.inMinutes, 64);
    expect(routeurDe(t).state.uri.path, SeancePaths.equivalent(faite.id));

    // 13 : le bilan.
    routeurDe(t).go(SeancePaths.resume(faite.id, nouveau: true));
    await attendre(t);
    expect(find.text('SÉANCE TERMINÉE'), findsOneWidget);
    expect(find.text('Push'), findsWidgets);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
    await capture(t, '13-bilan-de-seance');
    await t.scrollUntilVisible(find.text('EXERCICES'), 200, scrollable: find.byType(Scrollable).first);
    await attendre(t);
    await capture(t, '13-bilan-de-seance-exercices');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('saisie sur le Fold ouvert', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(884, 1100));
    final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
    await t.runAsync(() => d.sessions.startFromRoutine(push));
    routeurDe(t).push(SeancePaths.enCours);
    await attendre(t);
    expect(find.byType(SerieLigne), findsWidgets);
    expect(find.text('MUSCLES TRAVAILLÉS'), findsOneWidget);
    await capture(t, 'ouvert-saisie');
    expect(t.takeException(), isNull);
    await demonter(t);
  });
}
