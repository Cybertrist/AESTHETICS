import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/envoi_sante.dart';
import 'package:aesthetic/features/seance/logic/medias.dart';
import 'package:aesthetic/features/seance/pages/resume_page.dart';
import 'package:aesthetic/features/seance/pages/terminer_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/bilan_blocs.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'banc.dart';

/// Fin de séance : ce qui est enregistré, ce qui survit à un retour en
/// arrière, le double appui, les séances sans volume, le programme.

class _FauxSelecteur implements SelecteurMedias {
  _FauxSelecteur(this.dossier);
  final Directory dossier;

  @override
  Future<List<String>> photos(ImageSource source) async => [
        for (var i = 0; i < (source == ImageSource.gallery ? 2 : 1); i++)
          (File('${dossier.path}/source$i.jpg')..writeAsBytesSync([1, 2, 3])).path,
      ];

  @override
  Future<String?> video(ImageSource source) async => (File('${dossier.path}/source.mp4')..writeAsBytesSync([4, 5])).path;
}

/// Démarre la première routine de la démo, toutes les séries du premier
/// exercice validées, commencée il y a [minutes] minutes.
Future<WorkoutSession> _lancer(WidgetTester t, AppData d, {int minutes = 50, String? notes, String? programId, bool valider = true}) async {
  await t.runAsync(() async {
    await d.sessions.startFromRoutine(d.routines.routines.firstWhere((r) => r.nom == 'Push'), programId: programId);
    final a = d.sessions.active!;
    await d.sessions.updateActive(a.copyWith(
      debut: DateTime.now().subtract(Duration(minutes: minutes)),
      notes: notes,
      exercices: [
        a.exercices.first.copyWith(series: [for (final s in a.exercices.first.series) s.copyWith(fait: valider, poids: 50, reps: 8)]),
        ...a.exercices.skip(1),
      ],
    ));
  });
  _id = d.sessions.active!.id;
  return d.sessions.active!;
}

/// Identifiant de la séance lancée par le test (la démo a parfois une séance plus récente).
String _id = '';

Future<void> _ouvrir(WidgetTester t) async {
  routeurDe(t).push(SeancePaths.terminer);
  await attendre(t);
  expect(find.byType(TerminerPage), findsOneWidget);
}

Finder get _champNom => find.byType(TextField).first;
Finder get _champNote => find.byType(TextField).at(1);

void main() {
  setUp(() => EnvoiSante.envoyeur = (s) async => true);

  testWidgets('une note effacée à la fin ne revient pas dans la séance enregistrée', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d, notes: 'Épaule douloureuse');
    await _ouvrir(t);
    expect(find.text('Épaule douloureuse'), findsOneWidget);
    await t.enterText(_champNote, '');
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.notes ?? '', isEmpty, reason: 'la note effacée ne doit pas être gardée');
    await demonter(t);
  });

  testWidgets('revenir en arrière puis rouvrir : nom, note, type, date et durée sont gardés', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    await _ouvrir(t);
    await t.enterText(_champNom, 'Push lourd');
    await t.enterText(_champNote, 'Très bonne forme');
    await t.tap(find.text('Musculation'));
    await attendre(t, tours: 2);
    await t.tap(find.text('Hybride'));
    await attendre(t, tours: 2);
    // Durée corrigée : 1 h 30.
    final etat = t.state<State<TerminerPage>>(find.byType(TerminerPage));
    await t.tap(find.text('50 min'));
    await attendre(t, tours: 2);
    expect(find.byType(RoueDuree), findsOneWidget);
    t.widget<RoueDuree>(find.byType(RoueDuree)).onChanged(const Duration(minutes: 20));
    await t.pump();
    await t.tap(find.text('Terminé'));
    await attendre(t, tours: 2);
    expect(find.text('20 min'), findsOneWidget);
    expect(etat.mounted, isTrue);

    // Retour à la saisie, puis de nouveau « Terminer ».
    await t.tap(find.bySemanticsLabel('Retour'));
    await attendre(t);
    expect(find.byType(TerminerPage), findsNothing);
    expect(d.sessions.active, isNotNull);
    await _ouvrir(t);
    expect(find.text('Push lourd'), findsOneWidget, reason: 'le nom saisi est perdu');
    expect(find.text('Très bonne forme'), findsOneWidget, reason: 'la note saisie est perdue');
    expect(find.text('Hybride'), findsOneWidget, reason: 'le type choisi est perdu');
    expect(find.text('20 min'), findsOneWidget, reason: 'la durée corrigée est perdue');

    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.nom, 'Push lourd');
    expect(faite.notes, 'Très bonne forme');
    expect(faite.type, TypeSeance.hybride);
    expect(faite.duree.inMinutes, 20);
    await demonter(t);
  });

  testWidgets('médias : copiés dans le dossier de l\'appli, gardés après un retour, retirés du disque', (t) async {
    final tmp = Directory.systemTemp.createTempSync('fin_medias');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final cible = Directory('${tmp.path}/appli');
    final ancienSelecteur = MediasSeance.selecteur;
    final ancienDossier = MediasSeance.dossier;
    final ancienneDuree = MediasSeance.dureeVideo;
    MediasSeance.selecteur = _FauxSelecteur(tmp);
    MediasSeance.dossier = () async => cible;
    MediasSeance.dureeVideo = (_) async => 12;
    addTearDown(() {
      MediasSeance.selecteur = ancienSelecteur;
      MediasSeance.dossier = ancienDossier;
      MediasSeance.dureeVideo = ancienneDuree;
    });

    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    await _ouvrir(t);
    await t.tap(find.text('Ajouter des photos ou des vidéos'));
    await attendre(t, tours: 2);
    await t.tap(find.text('Choisir des photos'));
    await attendre(t);
    expect(find.bySemanticsLabel('Retirer la photo'), findsNWidgets(2));
    await t.tap(find.bySemanticsLabel('Ajouter une photo ou une vidéo'));
    await attendre(t, tours: 2);
    await t.tap(find.text('Filmer une vidéo'));
    await attendre(t);
    expect(find.text('00:12'), findsOneWidget);
    expect(cible.listSync().length, 3, reason: 'deux photos et une vidéo copiées');

    // Retirer une photo supprime sa copie.
    await t.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Retirer la photo').first);
    await attendre(t, tours: 2);
    expect(find.bySemanticsLabel('Retirer la photo'), findsOneWidget);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(cible.listSync().length, 2, reason: 'la copie de la photo retirée reste sur le disque');

    // Retour puis réouverture : les médias sont toujours là.
    await t.tap(find.bySemanticsLabel('Retour'));
    await attendre(t);
    await _ouvrir(t);
    expect(find.bySemanticsLabel('Retirer la photo'), findsOneWidget, reason: 'la photo ajoutée est perdue au retour');
    expect(find.text('00:12'), findsOneWidget, reason: 'la vidéo ajoutée est perdue au retour');

    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.medias.length, 2);
    for (final m in faite.medias) {
      expect(m.chemin, startsWith(cible.path), reason: 'le média doit vivre dans le dossier de l\'appli');
      expect(File(m.chemin).existsSync(), isTrue);
    }
    expect(faite.medias.where((m) => m.video).single.dureeSec, 12);
    await demonter(t);
  });

  testWidgets('double appui sur Enregistrer : une seule séance, le programme avance d\'un cran', (t) async {
    final d = await monter(t, depart: '/');
    final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
    final prog = (await t.runAsync(() => d.programs.save(Program(
          id: 'prog-fin',
          nom: 'Test',
          routineIds: [push.id, push.id, push.id],
          joursParSemaine: 3,
          actif: true,
          creeLe: DateTime(2026, 9, 1),
        ))))!;
    await _lancer(t, d, programId: prog.id);
    final avant = d.sessions.sessions.length;
    await _ouvrir(t);
    await t.tap(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'), warnIfMissed: false);
    await attendre(t);
    expect(d.sessions.sessions.length, avant + 1);
    expect(d.sessions.active, isNull);
    final p = d.programs.byId(prog.id)!;
    expect(p.seancesFaites, 1);
    expect(p.prochainIndex, 1);
    final faite = d.sessions.byId(_id)!;
    expect(routeurDe(t).state.uri.path, SeancePaths.equivalent(faite.id), reason: 'la carte équivalent suit l\'enregistrement');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('pendant l\'enregistrement, l\'écran ne passe pas par « Aucune séance en cours »', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    await _ouvrir(t);
    await t.tap(find.text('Enregistrer'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 40));
      expect(find.text('Aucune séance en cours'), findsNothing, reason: 'image $i de la transition');
    }
    await attendre(t);
    await demonter(t);
  });

  testWidgets('aucune série validée : rien ne s\'enregistre ; les séries remplies se cochent d\'un geste', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d, valider: false);
    final avant = d.sessions.sessions.length;
    await _ouvrir(t);
    expect(find.text('Valide au moins une série'), findsOneWidget);
    await t.tap(find.text('Valide au moins une série'), warnIfMissed: false);
    await attendre(t, tours: 2);
    expect(d.sessions.active, isNotNull);
    expect(d.sessions.sessions.length, avant);

    final remplies = d.sessions.active!.exercices.fold(0, (a, e) => a + e.series.where((x) => (x.reps ?? 0) > 0).length);
    expect(find.textContaining('ne sont pas cochées'), findsOneWidget);
    expect(find.textContaining('$remplies séries remplies'), findsOneWidget);
    await t.tap(find.textContaining('ne sont pas cochées'));
    await attendre(t, tours: 2);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.textContaining('ne sont pas cochées'), findsNothing);
    await demonter(t);
  });

  testWidgets('séries non cochées : elles ne sont pas enregistrées, les exercices vides non plus', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    final a = d.sessions.active!;
    // Une seule série validée sur le premier exercice.
    await t.runAsync(() => d.sessions.updateActive(a.copyWith(exercices: [
          a.exercices.first.copyWith(series: [
            for (var i = 0; i < a.exercices.first.series.length; i++) a.exercices.first.series[i].copyWith(fait: i == a.exercices.first.series.length - 1),
          ]),
          ...a.exercices.skip(1),
        ])));
    await _ouvrir(t);
    expect(find.textContaining('1 série ·'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.exercices.length, 1);
    expect(faite.exercices.single.series.length, 1);
    expect(faite.exercices.single.series.single.fait, isTrue);
    expect(faite.volume, 400);
    await demonter(t);
  });

  testWidgets('une distance seule compte comme une série remplie', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    final a = d.sessions.active!;
    await t.runAsync(() => d.sessions.updateActive(a.copyWith(exercices: [
          a.exercices.first,
          SessionExercise(id: 'course', exerciseId: a.exercices.first.exerciseId, series: const [WorkoutSet(id: 'd1', distanceM: 5000)]),
        ])));
    await _ouvrir(t);
    expect(find.textContaining('Une série remplie'), findsOneWidget, reason: 'la série à distance seule est proposée');
    await t.tap(find.textContaining('Une série remplie'));
    await attendre(t, tours: 2);
    expect(d.sessions.active!.exercices.last.series.single.fait, isTrue);
    expect(find.textContaining('série remplie'), findsNothing);
    await demonter(t);
  });

  testWidgets('cardio sans volume : pas de carte équivalent, pas de « 0 kg » au bilan', (t) async {
    final d = await monter(t, depart: '/');
    final course = d.exercises.all.firstWhere((e) => e.suivi == ExerciseTracking.distanceDuree || e.suivi == ExerciseTracking.duree);
    await t.runAsync(() async {
      await d.sessions.startEmpty(nom: 'Course');
      await d.sessions.updateActive(d.sessions.active!.copyWith(
        debut: DateTime.now().subtract(const Duration(minutes: 32)),
        type: TypeSeance.cardio,
        exercices: [
          SessionExercise(id: 'c', exerciseId: course.id, series: const [WorkoutSet(id: 'c1', dureeSec: 1800, distanceM: 5000, fait: true)]),
        ],
      ));
    });
    await _ouvrir(t);
    _id = d.sessions.active!.id;
    expect(find.text('Cardio'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    await capture(t, 'fin-terminer-cardio');
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.volume, 0);
    expect(faite.type, TypeSeance.cardio);
    expect(routeurDe(t).state.uri.toString(), SeancePaths.resume(faite.id, nouveau: true));
    expect(find.byType(ResumePage), findsOneWidget);
    expect(find.text('0 kg'), findsNothing, reason: 'un volume nul ne s\'affiche pas');
    expect(find.textContaining('volume soulevé'), findsNothing);
    await capture(t, 'fin-bilan-cardio');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('durée corrigée plus longue que le temps écoulé : la séance ne finit pas dans le futur', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d, minutes: 10);
    await _ouvrir(t);
    await t.tap(find.text('10 min'));
    await attendre(t, tours: 2);
    t.widget<RoueDuree>(find.byType(RoueDuree)).onChanged(const Duration(hours: 2));
    await t.pump();
    await t.tap(find.text('Terminé'));
    await attendre(t, tours: 2);
    expect(find.text('2 h 00 min'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.duree, const Duration(hours: 2));
    expect(faite.fin!.isAfter(DateTime.now().add(const Duration(seconds: 5))), isFalse, reason: 'fin de séance dans le futur : ${faite.fin}');
    await demonter(t);
  });

  testWidgets('durée nulle refusée ; nom vide : le nom d\'origine est gardé', (t) async {
    final d = await monter(t, depart: '/');
    await _lancer(t, d);
    await _ouvrir(t);
    await t.tap(find.text('50 min'));
    await attendre(t, tours: 2);
    t.widget<RoueDuree>(find.byType(RoueDuree)).onChanged(Duration.zero);
    await t.pump();
    await t.tap(find.text('Terminé'));
    await attendre(t, tours: 2);
    expect(find.text('50 min'), findsOneWidget, reason: 'une durée nulle est refusée');
    await t.pump(const Duration(seconds: 5));
    await t.enterText(_champNom, '   ');
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final faite = d.sessions.byId(_id)!;
    expect(faite.nom, 'Push');
    expect(faite.duree.inMinutes, 50);
    await demonter(t);
  });

  testWidgets('en 360 de large et sur le Fold ouvert : rien ne déborde', (t) async {
    for (final (taille, nom) in [(const Size(360, 640), 'etroit'), (const Size(884, 1100), 'large')]) {
      final d = await monter(t, depart: '/', taille: taille);
      await _lancer(t, d, notes: 'Une note assez longue pour passer à la ligne sur un petit écran, et même sur deux lignes.');
      await t.runAsync(() => d.sessions.updateActive(d.sessions.active!.copyWith(
            nom: 'Un nom de séance vraiment très long pour voir ce que ça donne',
            type: TypeSeance.crossTraining,
          )));
      await _ouvrir(t);
      expect(t.takeException(), isNull, reason: nom);
      await capture(t, 'fin-terminer-$nom');
      await t.tap(find.text('Enregistrer'));
      await attendre(t);
      final faite = d.sessions.byId(_id)!;
      routeurDe(t).go(SeancePaths.resume(faite.id, nouveau: true));
      await attendre(t);
      expect(t.takeException(), isNull, reason: 'bilan $nom');
      await capture(t, 'fin-bilan-$nom');
      await demonter(t);
    }
  });

  testWidgets('record battu : grande carte pour un seul, lignes pour plusieurs, écusson sur son exercice', (t) async {
    for (final (nb, nom) in [(1, 'un'), (2, 'deux')]) {
      final d = await monter(t, depart: '/', taille: const Size(412, 1500));
      await _lancer(t, d);
      // Des charges que la démo n'a jamais vues : record assuré.
      await t.runAsync(() async {
        final a = d.sessions.active!;
        await d.sessions.updateActive(a.copyWith(exercices: [
          for (final (i, e) in a.exercices.indexed)
            i < nb ? e.copyWith(series: [for (final x in e.series) x.copyWith(fait: true, poids: 300, reps: 8)]) : e,
        ]));
      });
      await _ouvrir(t);
      await t.tap(find.text('Enregistrer'));
      await attendre(t);
      routeurDe(t).go(SeancePaths.resume(d.sessions.byId(_id)!.id, nouveau: true));
      await attendre(t);
      expect(t.takeException(), isNull, reason: nom);
      expect(find.byType(CarteRecord), nb == 1 ? findsOneWidget : findsNothing);
      expect(find.byType(LigneRecord), nb == 1 ? findsNothing : findsNWidgets(2));
      expect(find.text('RECORD'), findsNWidgets(nb));
      expect(find.textContaining('sur ton ancien record'), nb == 1 ? findsOneWidget : findsNothing);
      await capture(t, 'fin-bilan-record-$nom');
      await demonter(t);
    }
  });
}
