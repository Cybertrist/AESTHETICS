import 'dart:async';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

/// Outils communs aux tests de la séance en cours (`test_saisie_*`).

/// Un exercice du catalogue qui n'a jamais été fait (aucun « Précédent »).
Exercise jamaisFait(AppData d, {ExerciseTracking suivi = ExerciseTracking.poidsReps}) =>
    d.exercises.all.firstWhere((e) => e.suivi == suivi && d.sessions.lastFor(e.id) == null);

/// Démarre une séance sur une routine d'un exercice à fourchette (12 à 15),
/// avec une séance passée pour la colonne « Précédent ».
Future<Exercise> seanceFourchette(WidgetTester t, AppData d, {int series = 4}) async {
  final ex = jamaisFait(d);
  final r = Routine(
    id: 'saisie-routine',
    nom: 'Épaules',
    creeLe: DateTime(2026, 9, 1),
    exercices: [
      RoutineExercise(
        id: 're1',
        exerciseId: ex.id,
        reposSec: 120,
        series: [for (var i = 0; i < series; i++) const PlannedSet(poids: 10, reps: 12, repsMax: 15)],
      ),
    ],
  );
  await t.runAsync(() async {
    await d.routines.save(r);
    final avant = DateTime.now().subtract(const Duration(days: 4));
    await d.sessions.save(WorkoutSession(
      id: 'saisie-avant',
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
    await d.sessions.startFromRoutine(r);
  });
  return ex;
}

/// Démarre une séance vide avec [ids], trois séries vides chacun.
Future<void> seanceLibre(WidgetTester t, AppData d, List<String> ids) async {
  await t.runAsync(() async {
    await d.sessions.startEmpty();
    for (final id in ids) {
      await d.sessions.addExerciseToActive(id);
    }
  });
}

/// Ouvre l'écran de la séance en cours.
Future<void> ouvrirSeance(WidgetTester t) async {
  routeurDe(t).push('/seance');
  await attendre(t);
}

List<WorkoutSet> seriesDe(AppData d, [int exercice = 0]) => d.sessions.active!.exercices[exercice].series;

Finder champ(WorkoutSet s, String cle) => find.byKey(ValueKey('${s.id}-$cle'));

String texteDe(WidgetTester t, Finder f) => t.widget<TextField>(f).controller!.text;


/// Une ligne de série seule, branchée sur une série gardée en mémoire : pour
/// essayer tous les suivis (durée, distance, lesté, assisté) sans catalogue.
class BancLigne extends StatefulWidget {
  const BancLigne({super.key, required this.depart, required this.suivi, this.precedent, this.cible, this.cibleDepart, this.unite = UnitePoids.kg});

  final WorkoutSet depart;
  final ExerciseTracking suivi;
  final WorkoutSet? precedent;
  final String? cible;
  final int? cibleDepart;
  final UnitePoids unite;

  @override
  State<BancLigne> createState() => BancLigneState();
}

class BancLigneState extends State<BancLigne> {
  late WorkoutSet set = widget.depart;
  int validations = 0;
  int menus = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AccentController().theme,
        home: Scaffold(
          body: Column(
            children: [
              EnteteSeries(suivi: widget.suivi, unite: widget.unite),
              SerieLigne(
                set: set,
                label: '1',
                suivi: widget.suivi,
                unite: widget.unite,
                precedent: widget.precedent,
                cibleReps: widget.cible,
                repsPrevues: widget.cibleDepart,
                onChanged: (s) => setState(() => set = s),
                onMenu: () => menus++,
                onToggle: (s) => setState(() {
                  validations++;
                  set = s.copyWith(fait: !s.fait);
                }),
              ),
            ],
          ),
        ),
      );
}

Future<BancLigneState> monterLigne(WidgetTester t, BancLigne ligne, {double largeur = 380}) async {
  t.view.physicalSize = Size(largeur, 400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ligne);
  await t.pump();
  return t.state<BancLigneState>(find.byType(BancLigne));
}

/// Relit le stockage avec un dépôt neuf, comme au redémarrage de l'appli.
/// Les écritures du test sont parties de la fausse horloge : on laisse tourner
/// les deux boucles (la fausse et la vraie) jusqu'à la fin de la lecture.
Future<SessionRepo> relire(WidgetTester t, Store store) async {
  final relu = SessionRepo(store);
  var fini = false;
  unawaited(relu.load().then((_) => fini = true));
  for (var i = 0; i < 40 && !fini; i++) {
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(fini, isTrue, reason: 'la relecture du stockage doit aboutir');
  return relu;
}

/// Mène [f] à son terme en faisant tourner la fausse horloge et la vraie
/// boucle : utile quand une lecture attend des écritures parties du test.
Future<T> tourner<T>(WidgetTester t, Future<T> f) async {
  T? r;
  var fini = false;
  unawaited(f.then((v) {
    r = v;
    fini = true;
  }));
  for (var i = 0; i < 200 && !fini; i++) {
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(fini, isTrue, reason: 'l\'opération doit aboutir');
  return r as T;
}
