import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/alternatives.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:aesthetic/features/seance/logic/chrono.dart';
import 'package:aesthetic/features/seance/logic/editeur.dart';
import 'package:aesthetic/features/seance/logic/envoi_sante.dart';
import 'package:aesthetic/features/seance/logic/medias.dart';
import 'package:aesthetic/features/seance/pages/apercu_page.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/exercice_carte.dart';
import 'package:aesthetic/features/seance/widgets/habillage.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'banc.dart';

class _FauxSelecteur implements SelecteurMedias {
  _FauxSelecteur(this.dossier);
  final Directory dossier;

  @override
  Future<List<String>> photos(ImageSource source) async {
    final n = source == ImageSource.gallery ? 2 : 1;
    return [
      for (var i = 0; i < n; i++) (File('${dossier.path}/source$i.jpg')..writeAsBytesSync([1, 2, 3])).path,
    ];
  }

  @override
  Future<String?> video(ImageSource source) async => (File('${dossier.path}/source.mp4')..writeAsBytesSync([4, 5])).path;
}

WorkoutSession _seance(String id, DateTime debut, List<SessionExercise> ex, {String? routineId}) =>
    WorkoutSession(id: id, nom: 'Push', debut: debut, fin: debut.add(const Duration(hours: 1)), exercices: ex, routineId: routineId);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('saisie : durées et nombres à la française', () {
    expect(lireDuree('1:30'), 90);
    expect(lireDuree('45'), 45);
    expect(lireNombre('82,5'), 82.5);
    expect(ecrireNombre(82.5), '82,5');
    expect(ecrireNombre(80), '80');
    expect(reposCourt(120), '2:00');
    expect(reposCourt(150), '2:30');
    expect(reposCourt(45), '0:45');
    expect(chronoSeance(const Duration(minutes: 32, seconds: 10)), '0:32:10');
    expect(dureeLongue(const Duration(hours: 1, minutes: 4)), '1 h 04 min');
    expect(minSec(const Duration(seconds: 116)), '01:56');
  });

  test('repères des séries, précédent par type, fourchette de la routine', () {
    final series = [
      const WorkoutSet(id: 'a', type: SetType.echauffement),
      const WorkoutSet(id: 'b'),
      const WorkoutSet(id: 'c', type: SetType.degressive),
      const WorkoutSet(id: 'd', type: SetType.topSet),
      const WorkoutSet(id: 'e'),
    ];
    expect(libellesSeries(series), ['É', '1', 'DG', 'T', '4']);
    final avant = [
      const WorkoutSet(id: 'x', type: SetType.echauffement, poids: 40, reps: 10, fait: true),
      const WorkoutSet(id: 'y', poids: 80, reps: 8, fait: true),
    ];
    expect(precedentPour(series, 1, avant)?.poids, 80);
    expect(precedentPour(series, 0, avant)?.poids, 40);
    expect(precedentCourt(avant[1], ExerciseTracking.poidsReps, UnitePoids.kg), '80 kg × 8');
    const plan = [PlannedSet(reps: 12, repsMax: 15), PlannedSet(reps: 8)];
    expect(cibleRepsPour(plan, 0), '12-15');
    expect(cibleRepsPour(plan, 1), isNull);
    expect(cibleRepsPour(plan, 5), isNull);
    expect(cibleRepsPour(null, 0), isNull);
  });

  test('repos après une série : celui de l\'exercice, une minute après un échauffement', () {
    const se = SessionExercise(id: 'e', exerciseId: 'x', reposSec: 150);
    expect(reposApresSerie(se, const WorkoutSet(id: 'a')), 150);
    expect(reposApresSerie(se, const WorkoutSet(id: 'a', type: SetType.echauffement)), 60);
    expect(reposApresSerie(se, const WorkoutSet(id: 'a', type: SetType.backOff)), 150);
    expect(reposApresSerie(const SessionExercise(id: 'e', exerciseId: 'x', reposSec: 0), const WorkoutSet(id: 'a')), 0);
  });

  test('valider une série, changer son type, supersets', () async {
    final repo = SessionRepo(Store.memory());
    await repo.load();
    await repo.startEmpty();
    final ed = EditeurDirect(repo);
    await ed.ajouterExercices(['a', 'b', 'c']);
    final ids = repo.active!.exercices.map((e) => e.id).toList();
    final premiere = repo.active!.exercices.first.series.first;

    expect(await ed.basculerSerie(ids[0], premiere.id), isTrue);
    expect(repo.active!.exercices.first.series.first.fait, isTrue);
    expect(repo.active!.exercices.first.series.first.faitLe, isNotNull);
    await ed.majSerie(ids[0], repo.active!.exercices.first.series.first.copyWith(type: SetType.myoReps, poids: 20, reps: 10));
    expect(repo.active!.exercices.first.series.first.type, SetType.myoReps);
    expect(repo.active!.volume, 200);
    await ed.majSerie(ids[0], repo.active!.exercices.first.series.first.copyWith(type: SetType.echauffement));
    expect(repo.active!.volume, 0, reason: 'un échauffement ne compte pas dans le volume');
    expect(await ed.basculerSerie(ids[0], premiere.id), isFalse);

    await ed.notes(ids[0], '  Coudes serrés ');
    expect(repo.active!.exercices.first.note, 'Coudes serrés');
    await ed.notes(ids[0], '');
    expect(repo.active!.exercices.first.note, isNull);

    await ed.lierAuSuivant(ids[0]);
    expect(ed.lettreSuperset(repo.active!.exercices[0].supersetId), 'A');
    expect(ed.finDeSuperset(ids[0]), isFalse);
    expect(ed.finDeSuperset(ids[1]), isTrue);
    await ed.supprimerExercice(ids[1]);
    expect(repo.active!.exercices.every((e) => e.supersetId == null), isTrue);
    ed.dispose();
  });

  test('pause : le chrono se fige et la durée ne compte pas la pause', () async {
    final repo = SessionRepo(Store.memory());
    await repo.load();
    await repo.startEmpty();
    final t0 = DateTime(2026, 10, 2, 8);
    await repo.updateActive(repo.active!.copyWith(debut: t0));
    final p = PauseSeance.instance..oublier();
    expect(p.enPause(repo.active), isFalse);
    expect(p.ecoule(repo.active!, maintenant: t0.add(const Duration(minutes: 10))), const Duration(minutes: 10));

    p.mettreEnPause(repo.active!, maintenant: t0.add(const Duration(minutes: 10)));
    expect(p.enPause(repo.active), isTrue);
    expect(p.ecoule(repo.active!, maintenant: t0.add(const Duration(minutes: 25))), const Duration(minutes: 10));

    await p.reprendre(repo, maintenant: t0.add(const Duration(minutes: 25)));
    expect(p.enPause(repo.active), isFalse);
    expect(repo.active!.debut, t0.add(const Duration(minutes: 15)));
    expect(p.ecoule(repo.active!, maintenant: t0.add(const Duration(minutes: 30))), const Duration(minutes: 15));
  });

  test('comparaison avec la dernière séance de la même routine', () {
    SessionExercise ex(double poids) => SessionExercise(id: 'e', exerciseId: 'x', series: [WorkoutSet(id: '1', poids: poids, reps: 10, fait: true)]);
    final avant = _seance('a', DateTime(2026, 9, 20), [ex(100)], routineId: 'r');
    final autre = _seance('b', DateTime(2026, 9, 25), [ex(300)], routineId: 'autre');
    final s = _seance('c', DateTime(2026, 10, 1), [ex(104)], routineId: 'r');
    final c = comparerAuPrecedent(s, [avant, autre, s])!;
    expect(c.pourcent, 4);
    expect(c.texte, '+4 %');
    expect(c.reference, 'Push');
    expect(comparerAuPrecedent(_seance('d', DateTime(2026, 10, 1), [ex(90)], routineId: 'r'), [avant])!.texte, '-10 %');
    expect(comparerAuPrecedent(_seance('e', DateTime(2026, 10, 1), [ex(100)], routineId: 'r'), [avant]), isNull, reason: 'un écart nul ne s\'affiche pas');
    expect(comparerAuPrecedent(avant, [avant, s]), isNull);
  });

  test('alternatives : mêmes muscles, la séance en cours écartée', () {
    Exercise e(String id, String equipement, List<Muscle> m, {String? mecanique = 'polyarticulaire'}) =>
        Exercise(id: id, nom: id, musclesPrincipaux: m, equipement: equipement, categorie: 'jambes', mecanique: mecanique);
    final squat = e('squat', 'barre', [Muscle.quadriceps]);
    final catalogue = [
      squat,
      e('goblet', 'halteres', [Muscle.quadriceps]),
      e('hack', 'machine', [Muscle.quadriceps]),
      e('extension', 'machine', [Muscle.quadriceps], mecanique: 'isolation'),
      e('curl', 'halteres', [Muscle.biceps]),
    ];
    final alts = alternativesPour(squat, catalogue);
    expect(alts.map((a) => a.exercise.id), isNot(contains('curl')));
    expect(alts.map((a) => a.exercise.id), isNot(contains('squat')));
    expect(alts.first.exercise.id, 'goblet');
    expect(alts.first.raisons, ['Mêmes muscles', 'Plus simple à installer']);
    expect(alts.last.exercise.id, 'extension');
    expect(alternativesPour(squat, catalogue, exclus: {'goblet'}).first.exercise.id, 'hack');
    expect(libelleNiveau('intermediaire'), 'Intermédiaire');
    expect(libelleNiveau(null), isNull);
  });

  test('médias : photos et vidéo copiées dans le dossier de l\'appli', () async {
    final tmp = Directory.systemTemp.createTempSync('medias_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final garde = Directory('${tmp.path}/garde');
    MediasSeance.selecteur = _FauxSelecteur(tmp);
    MediasSeance.dossier = () async => garde;
    MediasSeance.dureeVideo = (_) async => 24;

    final photos = await MediasSeance.choisir(source: ImageSource.gallery, video: false);
    expect(photos.length, 2);
    expect(photos.every((m) => !m.video && m.dureeSec == null), isTrue);
    expect(photos.every((m) => m.chemin.replaceAll('\\', '/').contains('/garde/') && File(m.chemin).existsSync()), isTrue);

    final video = await MediasSeance.choisir(source: ImageSource.camera, video: true);
    expect(video.single.video, isTrue);
    expect(video.single.dureeSec, 24);

    await MediasSeance.supprimer(photos.first);
    expect(File(photos.first.chemin).existsSync(), isFalse);
  });

  test('envoi vers Health Connect : type et garde-fous', () async {
    expect(EnvoiSante.typeDe(TypeSeance.musculation), HealthWorkoutActivityType.STRENGTH_TRAINING);
    expect(EnvoiSante.typeDe(TypeSeance.aviron), HealthWorkoutActivityType.ROWING);
    final recues = <WorkoutSession>[];
    EnvoiSante.envoyeur = (s) async {
      recues.add(s);
      return true;
    };
    final s = _seance('s', DateTime(2026, 10, 2, 8), const []);
    expect(await EnvoiSante.envoyer(s), isTrue);
    expect(await EnvoiSante.envoyer(WorkoutSession(id: 'x', nom: 'En cours', debut: DateTime(2026))), isFalse);
    EnvoiSante.envoyeur = (_) async => throw StateError('indisponible');
    expect(await EnvoiSante.envoyer(s), isFalse, reason: 'une panne ne remonte jamais');
    expect(recues.length, 1);
  });

  test('surcharge progressive, mise à jour de routine, aperçu', () async {
    final data = AppData(Store.memory());
    await data.exercises.load();
    const reId = 'developpe-couche';
    final routine = Routine(id: 'r', nom: 'Push', creeLe: DateTime(2026), exercices: const [
      RoutineExercise(id: 're', exerciseId: reId, series: [PlannedSet(poids: 80, reps: 8), PlannedSet(poids: 80, reps: 8)]),
    ]);
    final s = _seance('s', DateTime(2026, 9, 1, 18), [
      const SessionExercise(id: 'e', exerciseId: reId, series: [
        WorkoutSet(id: '1', poids: 80, reps: 8, fait: true),
        WorkoutSet(id: '2', poids: 80, reps: 9, fait: true),
      ]),
    ]);
    final sugg = Surcharge.calculer(s, exos: data.exercises, routine: routine, increment: 2.5);
    // 8 et 9 répétitions à 80 kg : pas de quoi monter la charge, d'abord 9 partout.
    expect(sugg.single.hausse, isTrue);
    expect(sugg.single.poids, 80);
    expect(sugg.single.reps, 9);
    final apres = MajRoutine.appliquer(routine, s, suggestions: sugg);
    expect(apres.exercices.single.series.first.poids, 80);
    expect(apres.exercices.single.series.first.reps, 9);
    expect(MajRoutine.differences(routine, apres, data.exercises, UnitePoids.kg), isNotEmpty);
    expect(texteSeance(s, data.exercises, UnitePoids.kg), contains('80 kg × 8'));
    expect(resumePlan(routine.exercices.single, UnitePoids.kg), '2 × 8 · 80 kg');
  });

  testWidgets('enregistrer : médias, type, note et durée corrigée sont gardés', (t) async {
    final d = await monter(t, depart: '/');
    final recues = <WorkoutSession>[];
    EnvoiSante.envoyeur = (s) async {
      recues.add(s);
      return true;
    };
    await t.runAsync(() async {
      await d.settings.update((s) => s.copyWith(santeConnectee: true));
      await d.sessions.startFromRoutine(d.routines.routines.first);
      final a = d.sessions.active!;
      await d.sessions.updateActive(a.copyWith(
        debut: DateTime.now().subtract(const Duration(minutes: 50)),
        type: TypeSeance.hiit,
        medias: const [SessionMedia(chemin: '/tmp/a.jpg'), SessionMedia(chemin: '/tmp/b.mp4', video: true, dureeSec: 24)],
        exercices: [
          a.exercices.first.copyWith(series: [for (final s in a.exercices.first.series) s.copyWith(fait: true, poids: 50, reps: 8)]),
          ...a.exercices.skip(1),
        ],
      ));
    });
    routeurDe(t).push(SeancePaths.terminer);
    await attendre(t);
    expect(find.text('HIIT'), findsOneWidget);
    expect(find.text('00:24'), findsOneWidget, reason: 'la vidéo jointe montre sa durée');
    expect(find.bySemanticsLabel('Retirer la photo'), findsOneWidget);
    await capture(t, '10b-terminer-avec-medias');

    await t.enterText(find.widgetWithText(TextField, 'Comment s\'est passée ta séance ?'), 'Bonne forme');
    await t.tap(find.text('Enregistrer'));
    await attendre(t);

    final faite = d.sessions.sessions.first;
    expect(d.sessions.active, isNull);
    expect(faite.medias.length, 2);
    expect(faite.medias[1].video, isTrue);
    expect(faite.type, TypeSeance.hiit);
    expect(faite.notes, 'Bonne forme');
    expect(faite.duree.inMinutes, 50);
    expect(faite.exercices.length, 1, reason: 'seuls les exercices aux séries cochées sont gardés');
    expect(recues.single.id, faite.id, reason: 'l\'envoi vers Health Connect part quand l\'interrupteur est actif');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('abandonner depuis la barre réduite demande confirmation', (t) async {
    final d = await monter(t, depart: '/');
    await t.runAsync(() => d.sessions.startEmpty());
    await attendre(t, tours: 2);
    await t.tap(find.text('Abandonner'));
    await attendre(t, tours: 2);
    expect(find.text('Abandonner la séance ?'), findsOneWidget);
    expect(d.sessions.hasActive, isTrue);
    await t.tap(find.text('Abandonner').last);
    await attendre(t, tours: 2);
    expect(d.sessions.hasActive, isFalse);
    expect(find.text('Entraînement en cours'), findsNothing);
    await demonter(t);
  });
}
