import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_index.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_stats.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/formats.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/records.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/elements.dart';
import 'package:aesthetic/features/entrainer/routines/logic/idees.dart';
import 'package:aesthetic/features/entrainer/routines/logic/suggestion.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/serie_dialog.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/sous_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'outils.dart';

/// Défauts relevés sur l'émulateur le 2 octobre (CHASSE.md, zone ENTRAÎNER) :
/// un test par point. Images dans build/rendus/routines et bibliotheque
/// (`chasse-...`).
WorkoutSet _s(String id, double? kg, int? reps, {SetType type = SetType.normale}) =>
    WorkoutSet(id: id, type: type, poids: kg, reps: reps, fait: true);

WorkoutSession _seance(String id, DateTime d, List<WorkoutSet> series, {String? routine}) => WorkoutSession(
      id: id,
      nom: 'Push',
      routineId: routine,
      debut: d,
      fin: d.add(const Duration(hours: 1)),
      exercices: [SessionExercise(id: 'e$id', exerciseId: 'x', series: series)],
    );

ExerciseStats _stats(List<WorkoutSession> l) => ExerciseStats([for (final s in l) (session: s, exercise: s.exercices.first)]);

/// Amène le libellé à l'écran (la fenêtre défile sur un petit téléphone), puis le touche.
Future<void> toucher(WidgetTester t, String texte) async {
  await t.ensureVisible(find.text(texte));
  await t.pump();
  await t.tap(find.text(texte));
  await t.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  setUpAll(() => initializeDateFormatting('fr_FR'));
  const suivi = ExerciseTracking.poidsReps;

  group('point 6 : la médaille de l\'historique ne va qu\'aux records', () {
    final seances = [
      _seance('a', DateTime(2026, 4, 4, 18), [_s('a1', 62.5, 8)]),
      _seance('b', DateTime(2026, 8, 29, 18), [_s('b1', 70, 7), _s('b2', 70, 6)]),
      _seance('c', DateTime(2026, 9, 26, 10), [_s('c0', 35, 10, type: SetType.echauffement), _s('c1', 70, 7), _s('c2', 70, 6)]),
      _seance('d', DateTime(2026, 9, 28, 18), [_s('d1', 70, 6), _s('d2', 70, 5)]),
    ];
    final stats = _stats(seances);
    SessionPoint point(String id) => stats.points.firstWhere((p) => p.session.id == id);

    test('record battu ce jour-là : médaille ; record seulement égalé : rien', () {
      expect(rangRecord(stats, point('a'), suivi), RangRecord.ancien, reason: '62,5 kg, battu depuis');
      expect(rangRecord(stats, point('b'), suivi), RangRecord.enCours, reason: '70 kg, toujours le record');
      expect(rangRecord(stats, point('c'), suivi), RangRecord.aucun, reason: '70 kg refaits : pas un record');
      expect(rangRecord(stats, point('d'), suivi), RangRecord.aucun);
      expect(tientLeRecord(stats, point('b'), suivi), isTrue);
      expect(tientLeRecord(stats, point('d'), suivi), isFalse);
    });
  });

  group('point 19 : un record égal n\'est pas un nouveau record', () {
    test('deux 1RM qui s\'écrivent pareil ne font qu\'une ligne', () {
      // On cherche deux séries dont le 1RM diffère mais s'arrondit au même kilo.
      WorkoutSet? premiere, seconde;
      recherche:
      for (var kg = 60.0; kg <= 80; kg += 2.5) {
        for (var reps = 4; reps <= 10; reps++) {
          final a = _s('a', kg, reps);
          for (var kg2 = kg + 2.5; kg2 <= 85; kg2 += 2.5) {
            for (var reps2 = 3; reps2 < reps; reps2++) {
              final b = _s('b', kg2, reps2);
              final ra = Strength.setOneRm(a), rb = Strength.setOneRm(b);
              if (rb > ra && rb.round() == ra.round()) {
                premiere = a;
                seconde = b;
                break recherche;
              }
            }
          }
        }
      }
      expect(premiere, isNotNull, reason: 'aucune paire trouvée : la formule a changé ?');
      final stats = _stats([
        _seance('a', DateTime(2026, 6, 20), [premiere!]),
        _seance('b', DateTime(2026, 8, 29), [seconde!]),
      ]);
      final lignes = progressionRecord(stats, TypeRecord.unRm);
      expect(lignes, hasLength(1), reason: 'la seconde séance égale le record à l\'affichage, elle ne le bat pas');
      expect(lignes.single.sessionId, 'a');
    });

    test('quel que soit le type, deux lignes voisines de l\'historique ne s\'écrivent jamais pareil', () {
      final stats = _stats([
        for (final (i, (kg, reps)) in const [(62.5, 8), (65.0, 7), (65.0, 8), (67.5, 8), (70.0, 7), (70.0, 6), (72.5, 5), (72.5, 6)].indexed)
          _seance('s$i', DateTime(2026, 3, 1 + 7 * i), [_s('s$i-1', kg, reps), _s('s$i-2', kg, reps - 1)]),
      ]);
      for (final t in TypeRecord.pour(suivi)) {
        final textes = [for (final r in progressionRecord(stats, t)) r.valeurTexte(UnitePoids.kg)];
        expect(textes.toSet(), hasLength(textes.length), reason: '${t.label} : $textes');
      }
    });
  });

  group('point 18b : écriture commune sur la fiche', () {
    test('« 70 kg × 6 », « 85 kg », « 1 690 kg », virgule décimale', () {
      expect(ExFmt.serieFiche(_s('a', 70, 6), suivi, UnitePoids.kg), '70 kg × 6');
      expect(ExFmt.serieFiche(_s('a', 72.5, 5), suivi, UnitePoids.kg), '72,5 kg × 5');
      expect(ExFmt.serieFiche(_s('a', 10, 8), ExerciseTracking.poidsDuCorpsLeste, UnitePoids.kg), '+10 kg × 8');
      expect(ExFmt.kg(85, UnitePoids.kg), '85 kg');
      expect(ExFmt.volumeColle(1690, UnitePoids.kg), '1 690 kg');
      final stats = _stats([_seance('a', DateTime(2026, 5, 30), [_s('a1', 67.5, 8), _s('a2', 67.5, 8), _s('a3', 65, 8), _s('a4', 10, 9)])]);
      for (final r in recordsDe(stats, suivi)) {
        for (final texte in [r.valeurTexte(UnitePoids.kg), r.detail(suivi, UnitePoids.kg)]) {
          expect(texte, isNot(matches(RegExp(r'\dkg'))), reason: texte);
          expect(texte, isNot(contains(' x ')), reason: texte);
          expect(texte, isNot(contains('.')), reason: texte);
        }
      }
    });
  });

  group('point 25 et tri par défaut de la bibliothèque', () {
    final catalogue = (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List)
        .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final index = ExerciseIndex();
    List<Exercise> filtrer(LibraryFilters f, {Map<String, int> freq = const {}}) =>
        index.filtrer(catalogue: catalogue, perso: const [], filtres: f, favoris: const {}, recents: const [], frequences: freq);

    test('« dos » : les exercices dont le dos est le muscle principal passent avant un nom qui contient « dos »', () {
      final r = filtrer(const LibraryFilters(query: 'dos'));
      final ids = [for (final e in r) e.id];
      bool duDos(Exercise e) => e.musclesPrincipaux.any((m) => m.region == MuscleRegion.dos);
      // Tant qu'il reste des exercices du dos, aucun autre ne passe devant.
      final dernierDuDos = r.lastIndexWhere(duDos);
      expect(dernierDuDos, greaterThan(20));
      expect(r.take(dernierDuDos + 1).every(duDos), isTrue);
      // Le cas relevé : le shrug « derrière le dos » passait en tête grâce à son nom.
      final shrug = r.indexWhere((e) => e.nom.toLowerCase().contains('derrière le dos') && e.nom.startsWith('Shrug'));
      expect(shrug, greaterThan(0));
      expect(ids.indexOf('tractions'), inInclusiveRange(0, shrug - 1));
      expect(ids.indexOf('rowing-barre'), inInclusiveRange(0, shrug - 1));
      expect(ids.indexOf('tirage-vertical'), inInclusiveRange(0, shrug - 1));
      // Le nom exact garde la tête.
      expect(filtrer(const LibraryFilters(query: 'tractions')).first.id, 'tractions');
      expect(filtrer(const LibraryFilters(query: 'developpe couche')).first.id, 'developpe-couche');
    });

    test('« dos » : parmi les exercices du dos, les plus faits d\'abord', () {
      final r = filtrer(const LibraryFilters(query: 'dos'), freq: const {'rowing-barre': 9, 'tractions': 4});
      expect([r[0].id, r[1].id], ['rowing-barre', 'tractions']);
    });

    test('tri par défaut : les plus faits d\'abord, puis l\'alphabet', () {
      expect(const LibraryFilters().sort, LibrarySort.frequence);
      final r = filtrer(const LibraryFilters(), freq: const {'squat': 12, 'tractions': 30, 'curl-barre': 12});
      expect([for (final e in r.take(3)) e.id], ['tractions', 'curl-barre', 'squat']);
      final reste = [for (final e in r.skip(3).take(40)) TextSearch.normalize(e.nom)];
      expect(reste, [...reste]..sort(), reason: 'à égalité (jamais faits), ordre alphabétique sans accents');
    });
  });

  group('points 11 et 12 : idée « Haut / Bas »', () {
    test('la couverture allume le haut et le bas du corps', () {
      final idee = ideeParModele('haut-bas-4j')!;
      final allumes = {...idee.face, ...idee.dos};
      const bas = {MuscleRegion.jambes};
      expect(allumes.any((m) => bas.contains(m.region)), isTrue, reason: 'le bas');
      expect(allumes.any((m) => !bas.contains(m.region)), isTrue, reason: 'le haut');
      expect(idee.face.every((m) => !bas.contains(m.region)), isTrue, reason: 'de face : le haut');
      expect(idee.dos.every((m) => bas.contains(m.region)), isTrue, reason: 'de dos : le bas');
    });

    test('le sigle et la couverture du programme ajouté laissent le rythme de côté', () {
      final nom = ideeParModele('haut-bas-4j')!.modele.nom;
      expect(nom, 'Haut/Bas 4 jours');
      expect(sigleProgramme(nom), 'HB');
      expect(couvertureProgramme(nom), (haut: 'HAUT/BAS', gros: 'HB'));
      for (final i in ideesProgrammes) {
        final sigle = sigleProgramme(i.modele.nom);
        expect(sigle.length, inInclusiveRange(1, 3), reason: i.modele.nom);
        expect(couvertureProgramme(i.modele.nom).haut, isNot(matches(RegExp(r'\s\d+$'))), reason: '${i.modele.nom} : pas de chiffre qui traîne en fin de ligne');
      }
      expect(sigleProgramme('Push Pull Legs, 12 semaines'), 'PPL');
      expect(sigleProgramme('DT COACH Tristan V3'), 'V3');
    });
  });

  testWidgets('points 11 et 12 : la couverture de cette idée, puis la tuile du programme ajouté', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer/programmes/modele/haut-bas-4j');
    await attendre(t, 4);
    expect(find.text('HAUT / BAS'), findsOneWidget);
    await capturer(t, 'routines', 'chasse-idee-haut-bas');
    await t.tap(find.text('Ajouter à ma bibliothèque'));
    await attendre(t, 3);
    if (find.text('Ajouter à ma bibliothèque').evaluate().length > 1) {
      await t.tap(find.text('Ajouter à ma bibliothèque').last);
      await attendre(t, 6);
    }
    expect(data.programs.programs.single.nom, 'Haut/Bas 4 jours');
    // La page du programme : sa couverture, sans le « 4 » ni « HBJ ».
    expect(find.text('HBJ'), findsNothing);
    expect(find.text('HAUT/BAS 4'), findsNothing);
    await capturer(t, 'routines', 'chasse-programme-haut-bas');
    routeur(t).go('/entrainer?onglet=programmes');
    await attendre(t, 4);
    expect(find.text('HB'), findsOneWidget);
    expect(find.text('HBJ'), findsNothing);
    await capturer(t, 'routines', 'chasse-programmes-sigle');
    expect(t.takeException(), isNull);
  });

  group('point 13 : « Une autre » propose la routine suivante la plus plausible', () {
    final vendredi = DateTime(2026, 10, 2, 9);
    DateTime il(int jours) => DateTime(2026, 10, 2 - jours, 18);
    final seances = [
      // Legs : tous les vendredis. Push : deux vendredis. Pull : lundi dernier.
      for (final k in [1, 2, 3, 4, 5, 6, 7, 8]) _seance('legs$k', il(7 * k), const [], routine: 'legs'),
      for (final k in [3, 5]) _seance('push$k', il(7 * k).add(const Duration(hours: 2)), const [], routine: 'push'),
      _seance('push-mar', il(3), const [], routine: 'push'),
      _seance('pull-lun', il(4), const [], routine: 'pull'),
      _seance('bras', il(40), const [], routine: 'bras'),
    ];
    const routines = ['push', 'pull', 'legs', 'bras', 'abdos'];

    test('ordre de la file : habitude du jour, suite du programme, puis ce qui attend depuis le plus longtemps', () {
      final file = suggestionsRoutines(maintenant: vendredi, seances: seances, routines: routines, cycle: const ['push', 'pull', 'legs']);
      expect([for (final s in file) s.routineId], ['legs', 'push', 'pull', 'bras', 'abdos']);
      expect(file.first.routineId, suggererRoutine(maintenant: vendredi, seances: seances)!.routineId, reason: 'la tête de file est la suggestion sûre');
      expect(file[0].motif, MotifSuggestion.habitude);
      expect(raisonSuggestion(file[0]), 'Tu as fait cette séance 8 des 8 derniers vendredis. Dernière fois : le 25 septembre.');
      expect(raisonSuggestion(file[1]), 'Tu as fait cette séance 2 des 8 derniers vendredis. Dernière fois : le 29 septembre.');
      // Push fait mardi, donc Pull est la suite du cycle.
      expect(file[2].motif, MotifSuggestion.suite);
      expect(raisonSuggestion(file[2]), 'La suite de ton programme. Dernière fois : le 28 septembre.');
      expect(raisonSuggestion(file[3]), 'Pas faite depuis le 23 août.');
      expect(raisonSuggestion(file[4]), 'Pas encore faite.');
      for (final s in file) {
        expect(raisonSuggestion(s), isNot(contains('null')));
      }
    });

    test('une routine faite aujourd\'hui ou supprimée ne revient pas', () {
      final file = suggestionsRoutines(
        maintenant: vendredi,
        seances: [...seances, _seance('push-auj', DateTime(2026, 10, 2, 7), const [], routine: 'push')],
        routines: const ['push', 'pull', 'bras'],
        cycle: const ['push', 'pull', 'legs'],
      );
      expect([for (final s in file) s.routineId], ['pull', 'bras']);
    });

    test('les routines écartées sont gardées pour la journée, relues, et oubliées le lendemain', () async {
      final store = Store.memory();
      final prefs = RoutinePrefs.of(store);
      await prefs.load();
      await prefs.ecarterSuggestion(vendredi, 'legs');
      await prefs.ecarterSuggestion(vendredi, 'push');
      expect(prefs.ecarteesLe(vendredi), ['legs', 'push']);
      expect(prefs.ecarteesLe(DateTime(2026, 10, 3)), isEmpty);
      expect(await store.read(RoutinePrefs.fichierSuggestion), {
        'ecartee': '2026-10-2',
        'routines': ['legs', 'push'],
      });
      await prefs.ecarterSuggestion(DateTime(2026, 10, 3, 8), 'pull');
      expect(prefs.ecarteesLe(DateTime(2026, 10, 3)), ['pull'], reason: 'un nouveau jour repart de zéro');
    });
  });

  group('point 8 : le bas des éditeurs reste au-dessus de la barre de gestes', () {
    for (final (nom, bas) in [('sans barre', 0.0), ('barre de gestes', 24.0), ('trois boutons', 48.0)]) {
      testWidgets('page d\'édition, $nom', (t) async {
        await t.runAsync(chargerPolices);
        t.view.physicalSize = const Size(380, 805);
        t.view.devicePixelRatio = 1;
        t.view.padding = FakeViewPadding(top: 25, bottom: bas);
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          theme: AccentController().theme,
          home: SousPage(
            title: 'Modifier le programme',
            closeIcon: true,
            bottomBar: BoutonPrincipal(label: 'Enregistrer', onPressed: () {}),
            body: ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('ligne $i'))]),
          ),
        ));
        final bouton = t.getRect(find.byType(BoutonPrincipal));
        expect(bouton.bottom, lessThanOrEqualTo(805 - bas - 10), reason: 'le bouton passe sous la zone système');
        expect(bouton.height, 56);
        final retour = t.getRect(find.bySemanticsLabel('Fermer'));
        expect(retour.top, greaterThanOrEqualTo(25), reason: 'l\'en-tête passe sous la barre d\'état');
        expect(t.widget<BoutonRond>(find.byType(BoutonRond)).fond, isNull, reason: 'retour dans un rond gris');
        expect(t.widget<Text>(find.text('Modifier le programme')).style!.fontWeight, FontWeight.w700);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('les éditeurs de programme, de routine et d\'exercice passent par cette page', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(() => donneesMaquette(DateTime.now())))!;
      for (final (adresse, bouton) in [
        ('/entrainer/programmes/p-v3/modifier', 'Enregistrer'),
        ('/entrainer/routines/r-bras/modifier', 'Enregistrer'),
        ('/entrainer/exercices/nouveau', 'Créer l\'exercice'),
      ]) {
        await lancer(t, data, adresse);
        expect(find.byType(SousPage), findsOneWidget, reason: adresse);
        expect(find.descendant(of: find.byType(SousPage), matching: find.text(bouton)), findsOneWidget, reason: adresse);
        expect(find.byType(AppBar), findsNothing, reason: '$adresse : ancien en-tête');
        expect(t.takeException(), isNull);
      }
    });
  });

  group('point 16 : fenêtre de série de l\'éditeur de routine', () {
    for (final (nom, taille) in [('360', const Size(360, 780)), ('412', const Size(412, 915)), ('320', const Size(320, 640))]) {
      testWidgets('rien ne déborde ni n\'est coupé en $nom', (t) async {
        await t.runAsync(chargerPolices);
        final data = (await t.runAsync(() => donneesMaquette(DateTime.now())))!;
        await lancer(t, data, '/entrainer/routines/r-bras/modifier', taille: taille);
        await t.tap(find.text('8 à 12').first);
        await attendre(t, 2);
        expect(t.takeException(), isNull);
        expect(find.text('Série 1'), findsOneWidget);
        for (final x in ['Répétitions', 'Charge', 'Type de série', 'Effort visé', 'Nombre fixe', 'Fourchette', 'Libre', 'Comme la dernière fois', 'Je la choisis', 'Valider', 'Supprimer la série']) {
          expect(find.text(x), findsOneWidget, reason: x);
        }
        expect(find.byType(Switch), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        // Chaque carte dit en une phrase ce que fait le choix retenu, sans « ? ».
        expect(find.text('?'), findsNothing);
        expect(find.text('Un minimum et un maximum à viser.'), findsOneWidget);
        expect(find.textContaining('remet le poids de ta dernière séance'), findsOneWidget);
        if (nom == '360') await capturer(t, 'routines', 'chasse-serie-360-aide');
        // Les douze types et leur explication dans la carte « Type de série ».
        await toucher(t, 'Type de série');
        await attendre(t, 1);
        for (final st in SetType.values) {
          expect(find.text(st.label, skipOffstage: false), findsWidgets, reason: st.label);
        }
        await toucher(t, 'Type de série');
        await attendre(t, 1);
        expect(t.takeException(), isNull);
        await capturer(t, 'routines', 'chasse-serie-$nom');

        // Répétitions libres, charge fixée : la fenêtre garde sa composition.
        await toucher(t, 'Libre');
        await toucher(t, 'Je la choisis');
        await attendre(t, 1);
        expect(find.text('Rien de prévu : tu les notes pendant la séance.'), findsOneWidget);
        expect(find.text('La séance démarre toujours avec le poids que tu fixes ici.'), findsOneWidget);
        expect(t.takeException(), isNull);
        if (nom == '360') await capturer(t, 'routines', 'chasse-serie-360-libres');
        await toucher(t, 'Fourchette');
        await toucher(t, 'Comme la dernière fois');
        await attendre(t, 1);

        // Supprimer : la série part de la routine en cours d'édition.
        final lignes = find.text('8 à 12', skipOffstage: false).evaluate().length;
        await toucher(t, 'Supprimer la série');
        await attendre(t, 2);
        expect(find.text('Supprimer la série'), findsNothing);
        expect(find.text('8 à 12', skipOffstage: false).evaluate().length, lignes - 1);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('fourchette, type et « toutes les séries » sont rendus tels que choisis', (t) async {
      await t.runAsync(chargerPolices);
      SerieEditee? rendu;
      await t.pumpWidget(MaterialApp(
        theme: AccentController().theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => rendu = await showSerieDialog(context, serie: const PlannedSet(reps: 6, repsMax: 8), suivi: ExerciseTracking.poidsReps, unite: UnitePoids.kg, numero: 2),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(find.text('Série 2'), findsOneWidget);
      await toucher(t, 'Type de série');
      await t.ensureVisible(find.text('Top set'));
      await toucher(t, 'Top set');
      expect(find.text('Série 2'), findsNothing);
      expect(find.text('Top set · série 2'), findsOneWidget);
      await toucher(t, 'Nombre fixe');
      await toucher(t, 'Je la choisis');
      await t.ensureVisible(find.text('Appliquer à toutes les séries du même type'));
      await toucher(t, 'Appliquer à toutes les séries du même type');
      await toucher(t, 'Valider');
      await t.pumpAndSettle();
      expect(rendu!.toutes, isTrue);
      expect(rendu!.supprimer, isFalse);
      expect(rendu!.serie.type, SetType.topSet);
      expect(rendu!.serie.reps, 6);
      expect(rendu!.serie.repsMax, isNull, reason: 'répétitions fixes');
      expect(rendu!.serie.poids, 20);
    });
  });
}
