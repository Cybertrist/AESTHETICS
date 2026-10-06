import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/seance/logic/partage.dart';
import 'package:aesthetic/features/seance/pages/detail_page.dart';
import 'package:aesthetic/features/seance/pages/modifier_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/bilan_blocs.dart';
import 'package:aesthetic/features/seance/widgets/habillage.dart';
import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'test_saisie_outils.dart';

/// Défauts relevés sur l'émulateur (CHASSE.md, zone SÉANCE) : un test par
/// point, avec un rendu dans `build/rendus/seance/chasse-*.png`.

const _etroit = Size(360, 760);
const _fold = Size(884, 1100);

/// Une séance en cours : un échauffement et deux séries de travail validés,
/// une série de travail à faire.
Future<void> _avecEchauffement(WidgetTester t, AppData d) async {
  final ex = jamaisFait(d);
  await seanceLibre(t, d, [ex.id]);
  await t.runAsync(() async {
    final a = d.sessions.active!;
    final s = a.exercices.single.series;
    await d.sessions.updateActive(a.copyWith(exercices: [
      a.exercices.single.copyWith(series: [
        WorkoutSet(id: 'ech', type: SetType.echauffement, poids: 20, reps: 10, fait: true, faitLe: DateTime.now()),
        s[0].copyWith(poids: 50, reps: 8, fait: true, faitLe: DateTime.now()),
        s[1].copyWith(poids: 50, reps: 8, fait: true, faitLe: DateTime.now()),
        s[2].copyWith(poids: 50, reps: 8),
      ]),
    ]));
  });
}

/// Termine une séance « Push » de la démo bien plus légère que d'habitude.
Future<WorkoutSession> _pushLeger(WidgetTester t, AppData d) async {
  late WorkoutSession faite;
  await t.runAsync(() async {
    await d.sessions.startFromRoutine(d.routines.routines.firstWhere((r) => r.nom == 'Push'));
    final a = d.sessions.active!;
    await d.sessions.updateActive(a.copyWith(
      debut: DateTime.now().subtract(const Duration(minutes: 7)),
      exercices: [
        a.exercices.first.copyWith(series: [for (final s in a.exercices.first.series.take(2)) s.copyWith(fait: true, poids: 40, reps: 8)]),
        ...a.exercices.skip(1),
      ],
    ));
    faite = (await d.sessions.finishActive())!.session;
  });
  return faite;
}

SessionRepo _depot() => SessionRepo(Store.memory());

void main() {
  group('écriture commune', () {
    test('repos en minutes:secondes, précédent avec espace et signe ×', () {
      expect(reposCourt(150), '2:30');
      expect(reposCourt(120), '2:00');
      expect(reposCourt(45), '0:45');
      const p = WorkoutSet(id: 'p', poids: 72.5, reps: 6, fait: true);
      expect(precedentCourt(p, ExerciseTracking.poidsReps, UnitePoids.kg), '72,5 kg × 6');
      expect(precedentCourt(p, ExerciseTracking.poidsDuCorpsLeste, UnitePoids.kg), '+72,5 kg × 6');
    });

    testWidgets('un point tapé dans le champ de charge devient une virgule', (t) async {
      final b = await monterLigne(t, const BancLigne(depart: WorkoutSet(id: 's'), suivi: ExerciseTracking.poidsReps));
      final poids = find.byKey(const ValueKey('s-poids'));
      await t.enterText(poids, '72.5');
      await t.pump();
      expect(texteDe(t, poids), '72,5');
      expect(b.set.poids, 72.5);
      // Une seule virgule : la seconde est refusée.
      await t.enterText(poids, '72,5,');
      await t.pump();
      expect(texteDe(t, poids), '72,5');
      expect(t.takeException(), isNull);
    });

    testWidgets('la ligne bleue du repos et la colonne Précédent suivent l\'écriture commune', (t) async {
      final d = await monter(t, depart: '/');
      await seanceFourchette(t, d, series: 2);
      await t.runAsync(() => d.sessions.updateActive(
          d.sessions.active!.copyWith(exercices: [d.sessions.active!.exercices.single.copyWith(reposSec: 150)])));
      await ouvrirSeance(t);
      expect(find.text('Minuteur de repos : 2:30'), findsOneWidget);
      expect(find.text('10 kg × 15'), findsNWidgets(2));
      expect(find.textContaining('kg x'), findsNothing);
      await capture(t, 'chasse-18a-ecriture');
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });

  group('nombre de séries (point 5)', () {
    test('les échauffements ne comptent ni dans les séries ni dans le détail partagé', () async {
      final exos = ExerciseRepo(Store.memory());
      final s = WorkoutSession(
        id: 's',
        nom: 'Push',
        debut: DateTime(2026, 10, 1, 18),
        fin: DateTime(2026, 10, 1, 19),
        exercices: const [
          SessionExercise(id: 'a', exerciseId: 'x', series: [
            WorkoutSet(id: '1', type: SetType.echauffement, poids: 20, reps: 10, fait: true),
            WorkoutSet(id: '2', poids: 50, reps: 8, fait: true),
            WorkoutSet(id: '3', poids: 50, reps: 8, fait: true),
            WorkoutSet(id: '4', poids: 50, reps: 8),
          ]),
          SessionExercise(id: 'b', exerciseId: 'y', series: [
            WorkoutSet(id: '5', type: SetType.echauffement, poids: 20, reps: 10, fait: true),
          ]),
        ],
      );
      expect(seriesComptees(s), 2);
      expect(s.nbSeriesFaites, 2);
      expect(s.volume, 800);
      final lignes = lignesDetail(s, exos);
      expect(lignes.length, 1, reason: 'un exercice où seul l\'échauffement est fait n\'a pas de série à montrer');
      expect(lignes.single, startsWith('2 × '));
    });

    testWidgets('l\'encadré de la séance et « Terminer la séance » donnent le même nombre', (t) async {
      final d = await monter(t, depart: '/');
      await _avecEchauffement(t, d);
      await ouvrirSeance(t);
      expect(find.descendant(of: find.byType(EncadreChiffres), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: find.byType(EncadreChiffres), matching: find.text('800 kg')), findsOneWidget);
      await capture(t, 'chasse-05-series-seance');
      routeurDe(t).push(SeancePaths.terminer);
      await attendre(t);
      expect(find.text('2 séries · 800 kg'), findsOneWidget);
      await capture(t, 'chasse-05-series-terminer');
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });

  group('bilan de séance', () {
    testWidgets('une baisse de volume s\'écrit en rouge, une hausse en vert (point 7a)', (t) async {
      final d = await monter(t, depart: '/');
      final faite = await _pushLeger(t, d);
      routeurDe(t).go(SeancePaths.resume(faite.id, nouveau: true));
      await attendre(t);
      final ecart = t.widget<Text>(find.textContaining(RegExp(r'^-\d+ %$')));
      expect(ecart.style!.color, AppTokens.error);
      expect(find.textContaining('vs dernier Push'), findsOneWidget);
      await capture(t, 'chasse-07a-bilan-baisse');
      expect(t.takeException(), isNull);
      await demonter(t);
    });

    for (final (nom, taille) in [('maquette', tailleMaquette), ('etroit', _etroit)]) {
      testWidgets('tableau de la routine : aucun nom d\'exercice coupé ($nom) (point 20)', (t) async {
        final d = await monter(t, depart: '/', taille: taille);
        // Les deux exercices aux noms les plus longs du catalogue.
        final longs = [...d.exercises.all.where((e) => e.suivi == ExerciseTracking.poidsReps)]..sort((a, b) => b.nom.length.compareTo(a.nom.length));
        final r = Routine(
          id: 'chasse-longs',
          nom: 'Noms longs',
          creeLe: DateTime(2026, 9, 1),
          exercices: [
            for (final e in longs.take(2))
              RoutineExercise(id: 're-${e.id}', exerciseId: e.id, series: const [PlannedSet(reps: 10, repsMax: 12), PlannedSet(reps: 10, repsMax: 12), PlannedSet(reps: 10, repsMax: 12)]),
          ],
        );
        late WorkoutSession faite;
        await t.runAsync(() async {
          await d.routines.save(r);
          await d.sessions.startFromRoutine(r);
          final a = d.sessions.active!;
          await d.sessions.updateActive(a.copyWith(exercices: [
            for (final e in a.exercices) e.copyWith(series: [for (final s in e.series) s.copyWith(fait: true, poids: 17.5, reps: 11)]),
          ]));
          faite = (await d.sessions.finishActive())!.session;
        });
        routeurDe(t).go(SeancePaths.resume(faite.id, nouveau: true));
        await attendre(t);
        await t.scrollUntilVisible(find.text('Mettre à jour la routine'), 300, scrollable: find.byType(Scrollable).first);
        await attendre(t, tours: 2);
        final bloc = find.byType(MajRoutineBloc);
        expect(bloc, findsOneWidget);
        for (final e in longs.take(2)) {
          final texte = find.descendant(of: bloc, matching: find.text(e.nom));
          expect(texte, findsOneWidget);
          expect(t.renderObject<RenderParagraph>(texte).didExceedMaxLines, isFalse, reason: '« ${e.nom} » est coupé');
        }
        expect(find.descendant(of: bloc, matching: find.textContaining('17,5 kg × 10 à 12')), findsNWidgets(2));
        await capture(t, 'chasse-20-routine-$nom');
        expect(t.takeException(), isNull);
        await demonter(t);
      });
    }
  });

  testWidgets('séance en paysage : les personnages tiennent dans la carte (point 15)', (t) async {
    final d = await monter(t, depart: '/', taille: const Size(890, 400));
    await _avecEchauffement(t, d);
    await ouvrirSeance(t);
    expect(find.text('MUSCLES TRAVAILLÉS'), findsOneWidget);
    final corps = t.getRect(find.byKey(const ValueKey('volet-muscles')));
    final carte = t.getRect(find.ancestor(of: find.text('MUSCLES TRAVAILLÉS'), matching: find.byType(Container)).first);
    expect(corps.bottom, lessThanOrEqualTo(carte.bottom), reason: 'les personnages débordent de la carte');
    expect(carte.bottom, lessThanOrEqualTo(400));
    await capture(t, 'chasse-15-paysage');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  group('supprimer une série', () {
    testWidgets('le glissé part aussi d\'un champ de saisie', (t) async {
      final d = await monter(t, depart: '/');
      await seanceFourchette(t, d, series: 3);
      await ouvrirSeance(t);
      final premiere = seriesDe(d).first;
      await t.drag(champ(premiere, 'poids'), const Offset(-360, 0), warnIfMissed: false);
      await attendre(t, tours: 8);
      expect(seriesDe(d).map((s) => s.id), isNot(contains(premiere.id)));
      expect(find.text('Série supprimée'), findsOneWidget);
      await capture(t, 'chasse-glisse-serie');
      // Depuis le champ des répétitions aussi, puis « Annuler » la remet.
      final suivante = seriesDe(d).first;
      await t.drag(champ(suivante, 'reps'), const Offset(-360, 0), warnIfMissed: false);
      await attendre(t, tours: 8);
      expect(seriesDe(d).length, 1);
      await t.tap(find.text('Annuler'));
      await attendre(t, tours: 2);
      expect(seriesDe(d).first.id, suivante.id);
      expect(t.takeException(), isNull);
      await demonter(t);
    });

    testWidgets('toucher un champ lui donne toujours la main pour saisir', (t) async {
      final d = await monter(t, depart: '/');
      await seanceFourchette(t, d, series: 2);
      await ouvrirSeance(t);
      final s = seriesDe(d).first;
      await t.tap(champ(s, 'poids'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.widget<TextField>(champ(s, 'poids')).focusNode!.hasFocus, isTrue);
      t.testTextInput.enterText('12.5');
      await t.pump();
      expect(seriesDe(d).first.poids, 12.5);
      expect(texteDe(t, champ(s, 'poids')), '12,5');
      expect(t.takeException(), isNull);
      await demonter(t);
    });

    testWidgets('« Supprimer la série » est dans le panneau « Type de série »', (t) async {
      final d = await monter(t, depart: '/');
      await seanceFourchette(t, d, series: 2);
      await ouvrirSeance(t);
      await t.tap(find.bySemanticsLabel(RegExp('Type de série')).first);
      await attendre(t, tours: 2);
      expect(find.text('Supprimer la série'), findsOneWidget);
      await t.tap(find.text('Supprimer la série'));
      await attendre(t, tours: 2);
      expect(seriesDe(d).length, 1);
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });

  group('modifier la séance (point 2)', () {
    for (final (nom, taille) in [('maquette', tailleMaquette), ('etroit', _etroit), ('fold', _fold)]) {
      testWidgets('nouvel habillage, musculation ($nom)', (t) async {
        final d = await monter(t, depart: '/', taille: taille);
        final s = d.sessions.sessions.firstWhere((x) => x.exercices.isNotEmpty);
        routeurDe(t).push(SeancePaths.modifier(s.id));
        await attendre(t);
        expect(find.byType(ModifierPage), findsOneWidget);
        expect(find.text('Modifier la séance'), findsOneWidget);
        expect(find.bySemanticsLabel('Retour'), findsOneWidget);
        expect(find.text('Enregistrer'), findsOneWidget);
        expect(find.text('INFORMATIONS'), findsNothing);
        // Aucune icône Material bleue : les icônes de la page sont au trait.
        expect(find.descendant(of: find.byType(ModifierPage), matching: find.byType(Icon)), findsNothing);
        await capture(t, 'chasse-02-modifier-$nom');
        await t.drag(find.byType(ListView).first, const Offset(0, -500));
        await attendre(t, tours: 2);
        await capture(t, 'chasse-02-modifier-$nom-bas');
        expect(t.takeException(), isNull);
        await demonter(t);
      });
    }

    testWidgets('séance de cardio sans exercice : elle s\'ouvre, se modifie et s\'enregistre', (t) async {
      final d = await monter(t, depart: '/');
      final s = d.sessions.sessions.firstWhere((x) => x.exercices.isEmpty && x.type == TypeSeance.cardio);
      routeurDe(t).push(SeancePaths.modifier(s.id));
      await attendre(t);
      expect(find.text('Cardio'), findsOneWidget);
      await capture(t, 'chasse-02-modifier-cardio');
      await t.tap(find.text('Ressenti'));
      await attendre(t, tours: 2);
      await t.tap(find.text('Bien'));
      await attendre(t, tours: 2);
      await t.tap(find.text('Enregistrer'));
      await attendre(t);
      final maj = d.sessions.byId(s.id)!;
      expect(maj.ressenti, 4);
      expect(maj.type, TypeSeance.cardio, reason: 'le type d\'activité est perdu en modifiant le ressenti');
      expect(find.byType(ModifierPage), findsNothing, reason: 'la séance sans exercice doit pouvoir être enregistrée');
      expect(t.takeException(), isNull);
      await demonter(t);
    });

    testWidgets('changer le ressenti garde les photos et le type de la séance', (t) async {
      final d = await monter(t, depart: '/');
      final base = d.sessions.sessions.firstWhere((x) => x.exercices.isNotEmpty);
      const medias = [SessionMedia(chemin: 'photo-a.jpg'), SessionMedia(chemin: 'video-b.mp4', video: true, dureeSec: 9)];
      await t.runAsync(() => d.sessions.save(base.copyWith(type: TypeSeance.hybride, medias: medias)));
      routeurDe(t).push(SeancePaths.modifier(base.id));
      await attendre(t);
      await t.tap(find.text('Ressenti'));
      await attendre(t, tours: 2);
      await t.tap(find.text('Non noté'));
      await attendre(t, tours: 2);
      await t.tap(find.text('Enregistrer'));
      await attendre(t);
      final maj = d.sessions.byId(base.id)!;
      expect(maj.ressenti, isNull);
      expect(maj.medias, medias);
      expect(maj.type, TypeSeance.hybride);
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });

  group('pages reprises au design validé', () {
    for (final (nom, taille) in [('maquette', tailleMaquette), ('etroit', _etroit), ('fold', _fold)]) {
      testWidgets('historique, détail, disques, réordonner, démarrer ($nom)', (t) async {
        final d = await monter(t, depart: '/', taille: taille);

        // Démarrer une séance : plus de rond de lecture corail ni d'icône Material.
        routeurDe(t).push(SeancePaths.enCours);
        await attendre(t);
        expect(find.text('Démarrer une séance'), findsOneWidget);
        expect(find.text('Démarrer une séance vide'), findsOneWidget);
        expect(find.byType(Icon), findsNothing);
        await capture(t, 'chasse-demarrer-$nom');
        expect(t.takeException(), isNull);

        // Historique.
        await t.tap(find.bySemanticsLabel('Historique'));
        await attendre(t);
        expect(find.text('SÉANCES DU MOIS'), findsOneWidget);
        expect(find.text('Historique'), findsOneWidget);
        expect(find.bySemanticsLabel('Mois précédent'), findsOneWidget);
        expect(find.textContaining(' · 0 kg'), findsNothing, reason: 'une séance de cardio ne montre pas « 0 kg »');
        expect(find.byType(Icon), findsNothing);
        await capture(t, 'chasse-historique-$nom');
        await t.tap(find.bySemanticsLabel('Mois précédent'));
        await attendre(t, tours: 2);
        await capture(t, 'chasse-historique-$nom-mois-precedent');
        expect(t.takeException(), isNull);

        // Détail d'une séance de musculation.
        final s = d.sessions.sessions.firstWhere((x) => x.exercices.length > 2);
        routeurDe(t).push(SeancePaths.detail(s.id));
        await attendre(t, tours: 8);
        expect(find.byType(DetailPage), findsOneWidget);
        expect(find.text('Refaire'), findsOneWidget);
        expect(find.text('Modifier'), findsOneWidget);
        expect(find.descendant(of: find.byType(DetailPage), matching: find.byType(Icon)), findsNothing);
        await capture(t, 'chasse-detail-$nom');
        await t.drag(find.descendant(of: find.byType(DetailPage), matching: find.byType(ListView)), const Offset(0, -600));
        await attendre(t, tours: 2);
        await capture(t, 'chasse-detail-$nom-bas');
        await t.tap(find.bySemanticsLabel('Plus d\'actions'));
        await attendre(t, tours: 2);
        expect(find.text('Enregistrer comme routine'), findsOneWidget);
        await capture(t, 'chasse-detail-$nom-menu');
        await t.tapAt(const Offset(20, 20));
        await attendre(t, tours: 2);
        expect(t.takeException(), isNull);

        // Disques et échauffement.
        routeurDe(t).push('${SeancePaths.disques}?poids=72.5');
        await attendre(t);
        expect(find.text('Disques et échauffement'), findsOneWidget);
        expect(find.text('72,5 kg', findRichText: true), findsOneWidget);
        expect(find.textContaining('Par côté : 25 + 1,25'), findsOneWidget);
        await capture(t, 'chasse-disques-$nom');
        await t.tap(find.bySemanticsLabel('Plus'));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('75 kg', findRichText: true), findsOneWidget);
        expect(t.takeException(), isNull);

        // Réordonner la séance en cours.
        await t.runAsync(() => d.sessions.startFromRoutine(d.routines.routines.firstWhere((r) => r.nom == 'Push')));
        routeurDe(t).push(SeancePaths.reordonner);
        await attendre(t);
        expect(find.text('Réordonner'), findsOneWidget);
        expect(find.text('Valider l\'ordre'), findsOneWidget);
        expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Déplacer'), findsWidgets);
        await capture(t, 'chasse-reordonner-$nom');
        expect(t.takeException(), isNull);
        await demonter(t);
      });
    }

    testWidgets('historique vide et détail introuvable', (t) async {
      final d = await monter(t, depart: '/', data: (await t.runAsync(() => donneesDemo(demo: false)))!);
      expect(d.sessions.sessions, isEmpty);
      routeurDe(t).push(SeancePaths.historique);
      await attendre(t);
      expect(find.text('Aucune séance pour l\'instant'), findsOneWidget);
      await capture(t, 'chasse-historique-vide');
      routeurDe(t).push(SeancePaths.detail('inconnue'));
      await attendre(t);
      expect(find.text('Séance introuvable'), findsOneWidget);
      await capture(t, 'chasse-detail-introuvable');
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });

  group('médias d\'une séance abandonnée ou supprimée', () {
    late Directory tmp;
    late Directory appli;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('chasse_medias');
      appli = Directory('${tmp.path}/medias_seances')..createSync();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    File fichier(String nom, {bool dansAppli = true}) => File('${(dansAppli ? appli : tmp).path}/$nom')..writeAsBytesSync([1, 2, 3]);

    WorkoutSession seance(String id, List<File> fichiers, {bool finie = true}) => WorkoutSession(
          id: id,
          nom: 'Push',
          debut: DateTime(2026, 10, 1, 18),
          fin: finie ? DateTime(2026, 10, 1, 19) : null,
          medias: [for (final f in fichiers) SessionMedia(chemin: f.path)],
        );

    test('séance supprimée : ses fichiers disparaissent', () async {
      final repo = _depot();
      final a = fichier('a.jpg');
      final b = fichier('b.mp4');
      await repo.save(seance('s1', [a, b]));
      await repo.delete('s1');
      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isFalse);
    });

    test('séance abandonnée : ses fichiers disparaissent', () async {
      final repo = _depot();
      final a = fichier('a.jpg');
      await repo.updateActive(seance('en-cours', [a], finie: false));
      await repo.discardActive();
      expect(repo.active, isNull);
      expect(a.existsSync(), isFalse);
    });

    test('un fichier hors du dossier de l\'appli (galerie) n\'est jamais supprimé', () async {
      final repo = _depot();
      final galerie = fichier('galerie.jpg', dansAppli: false);
      await repo.save(seance('s1', [galerie]));
      await repo.delete('s1');
      expect(galerie.existsSync(), isTrue);
    });

    test('un fichier encore utilisé par une autre séance est gardé', () async {
      final repo = _depot();
      final commun = fichier('commun.jpg');
      final seul = fichier('seul.jpg');
      await repo.save(seance('s1', [commun, seul]));
      await repo.save(seance('s2', [commun]));
      await repo.delete('s1');
      expect(commun.existsSync(), isTrue);
      expect(seul.existsSync(), isFalse);
    });

    test('suppression annulable : les fichiers restent, et une séance restaurée garde les siens', () async {
      final repo = _depot();
      final a = fichier('a.jpg');
      final s = seance('s1', [a]);
      await repo.save(s);
      await repo.delete('s1', garderMedias: true);
      expect(a.existsSync(), isTrue);
      await repo.save(s);
      await repo.supprimerMedias(s);
      expect(a.existsSync(), isTrue, reason: 'la séance a été restaurée');
      await repo.delete('s1', garderMedias: true);
      await repo.supprimerMedias(s);
      expect(a.existsSync(), isFalse);
    });

    test('un fichier déjà disparu ne fait pas échouer la suppression', () async {
      final repo = _depot();
      await repo.save(seance('s1', [File('${appli.path}/absent.jpg')]));
      await repo.delete('s1');
      expect(repo.byId('s1'), isNull);
    });

    testWidgets('détail : supprimer la séance efface ses photos une fois le délai d\'annulation passé', (t) async {
      final d = await monter(t, depart: '/');
      final a = fichier('photo.jpg');
      final base = d.sessions.sessions.firstWhere((x) => x.exercices.isNotEmpty);
      await t.runAsync(() => d.sessions.save(base.copyWith(medias: [SessionMedia(chemin: a.path)])));
      routeurDe(t).push(SeancePaths.detail(base.id));
      await attendre(t);
      await t.scrollUntilVisible(find.text('Supprimer la séance'), 400, scrollable: find.descendant(of: find.byType(DetailPage), matching: find.byType(Scrollable)).first);
      await t.tap(find.text('Supprimer la séance'));
      await attendre(t, tours: 2);
      await t.tap(find.text('Supprimer'));
      await attendre(t, tours: 2);
      expect(d.sessions.byId(base.id), isNull);
      expect(a.existsSync(), isTrue, reason: 'la suppression peut encore être annulée');
      await t.pump(DetailPage.delaiAnnulation);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      expect(a.existsSync(), isFalse);
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  });
}
