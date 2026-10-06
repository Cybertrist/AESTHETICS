import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deux ans d'entraînement : quatre séances par semaine, six exercices, quatre séries.
List<WorkoutSession> _deuxAns() {
  final debut = DateTime(2024, 10, 1, 18);
  var n = 0;
  return [
    for (var jour = 0; jour < 730; jour++)
      if (const [0, 1, 3, 4].contains(jour % 7))
        WorkoutSession(
          id: 's$jour',
          nom: 'Séance $jour',
          debut: debut.add(Duration(days: jour)),
          fin: debut.add(Duration(days: jour, minutes: 75)),
          source: 'import',
          exercices: [
            for (var e = 0; e < 6; e++)
              SessionExercise(id: 'e${n++}', exerciseId: 'exo-${(jour + e) % 40}', series: [
                for (var s = 0; s < 4; s++)
                  WorkoutSet(
                    id: 'set${n++}',
                    type: s == 0 ? SetType.echauffement : SetType.normale,
                    poids: 40.0 + e * 5 + s * 2.5,
                    reps: 12 - s,
                    fait: true,
                    faitLe: debut.add(Duration(days: jour, minutes: e * 10 + s * 2)),
                  ),
              ]),
          ],
        ),
  ];
}

/// Stockage dont la lecture du profil lève une erreur inattendue.
class _StoreQuiCasse extends Store {
  _StoreQuiCasse() : super.memory();

  @override
  Future<Object?> read(String name) => name == 'profil' ? Future.error(StateError('lecture impossible')) : super.read(name);
}

void main() {
  late Directory dossier;
  late Store store;

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('aesthetic_store_');
    store = Store.dossier(dossier);
  });
  tearDown(() {
    try {
      dossier.deleteSync(recursive: true);
    } catch (_) {}
  });

  File fichier(String nom) => File('${dossier.path}${Platform.pathSeparator}$nom');

  group('écriture', () {
    test('atomique : aucun fichier temporaire ne reste, le contenu est complet', () async {
      await store.write('seances', [
        {'id': 'a'},
      ]);
      expect(fichier('seances.json').existsSync(), isTrue);
      expect(fichier('seances.json.tmp').existsSync(), isFalse);
      expect(jsonDecode(fichier('seances.json').readAsStringSync()), [
        {'id': 'a'},
      ]);
      // Réécriture par-dessus un fichier existant.
      await store.write('seances', [
        {'id': 'b'},
      ]);
      expect(await store.readList('seances'), [
        {'id': 'b'},
      ]);
    });

    test('un temporaire laissé par une coupure ne gêne ni la lecture ni la liste', () async {
      await store.write('seances', [
        {'id': 'a'},
      ]);
      fichier('seances.json.tmp').writeAsStringSync('[{"id":"a"},{"id":"b"');
      expect(await store.readList('seances'), hasLength(1));
      expect(await store.names(), ['seances']);
      await store.write('seances', [
        {'id': 'a'},
        {'id': 'c'},
      ]);
      expect(await store.readList('seances'), hasLength(2));
      expect(fichier('seances.json.tmp').existsSync(), isFalse);
    });

    test('cent écritures rapprochées non attendues : la dernière gagne, dans l\'ordre', () async {
      final futures = <Future<void>>[];
      for (var i = 0; i < 100; i++) {
        futures.add(store.write('compteur', {'n': i, 'remplissage': 'x' * (i.isEven ? 20000 : 10)}));
      }
      // Une lecture demandée au milieu attend les écritures en cours.
      expect((await store.readObject('compteur'))!['n'], 99);
      await Future.wait(futures);
      expect(jsonDecode(fichier('compteur.json').readAsStringSync())['n'], 99);
      expect(dossier.listSync().map((f) => f.uri.pathSegments.last).toList(), ['compteur.json']);
    });

    test('collections différentes écrites en même temps', () async {
      await Future.wait([for (var i = 0; i < 30; i++) store.write('c$i', {'n': i})]);
      for (var i = 0; i < 30; i++) {
        expect((await store.readObject('c$i'))!['n'], i);
      }
    });

    test('un nombre non fini ne fait pas échouer l\'écriture de toute la collection', () async {
      final repo = SessionRepo(store);
      await repo.load();
      await repo.save(WorkoutSession(id: 'bonne', nom: 'Bonne', debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 1, 1)));
      await repo.save(WorkoutSession(
        id: 'nan',
        nom: 'Avec un NaN',
        debut: DateTime(2026, 1, 2),
        fin: DateTime(2026, 1, 2, 1),
        exercices: const [
          SessionExercise(id: 'e', exerciseId: 'x', series: [
            WorkoutSet(id: 'a', poids: double.nan, reps: 5, fait: true),
            WorkoutSet(id: 'b', poids: double.infinity, reps: 5, fait: true),
          ]),
        ],
      ));
      await repo.save(WorkoutSession(id: 'apres', nom: 'Après', debut: DateTime(2026, 1, 3), fin: DateTime(2026, 1, 3, 1)));
      // Relecture comme au prochain lancement.
      final relu = SessionRepo(Store.dossier(dossier));
      await relu.load();
      expect(relu.sessions.map((s) => s.id), ['apres', 'nan', 'bonne']);
      expect(relu.byId('nan')!.exercices.single.series.first.poids, isNull);
    });

    test('une écriture impossible remonte à celui qui la demande et ne bloque pas la suite', () async {
      // Un dossier à la place du fichier temporaire : l'écriture ne peut pas aboutir.
      Directory('${dossier.path}${Platform.pathSeparator}bloque.json.tmp').createSync();
      Object? erreur;
      try {
        await store.write('bloque', {'a': 1});
      } catch (e) {
        erreur = e;
      }
      expect(erreur, isNotNull, reason: 'un échec d\'écriture ne doit pas passer pour une réussite');
      expect(store.derniereErreurEcriture, isNotNull);
      Directory('${dossier.path}${Platform.pathSeparator}bloque.json.tmp').deleteSync();
      await store.write('bloque', {'a': 2});
      expect((await store.readObject('bloque'))!['a'], 2);
    });
  });

  group('fichier abîmé au démarrage', () {
    Future<AppData> demarrer() async {
      final d = AppData(Store.dossier(dossier));
      await d.loadAll();
      return d;
    }

    test('toutes les collections tronquées ou illisibles : l\'appli démarre', () async {
      for (final n in ['profil', 'reglages', 'seances', 'seance_active', 'routines', 'dossiers', 'programmes', 'exercices_perso', 'exercices_favoris', 'mesures', 'photos']) {
        fichier('$n.json').writeAsStringSync('[{"id":"a","nom":"Pou');
      }
      final d = await demarrer();
      expect(d.profile.hasProfile, isFalse);
      expect(d.sessions.sessions, isEmpty);
      expect(d.store.abimes.keys, containsAll(['profil', 'seances', 'routines']));
    });

    test('fichiers vides, binaires, ou du JSON d\'une autre forme : l\'appli démarre', () async {
      fichier('profil.json').writeAsStringSync('[1,2,3]');
      fichier('reglages.json').writeAsStringSync('"texte"');
      fichier('seances.json').writeAsStringSync('{"id":"pas une liste"}');
      fichier('seance_active.json').writeAsStringSync('[]');
      fichier('routines.json').writeAsBytesSync([0, 159, 146, 150, 255, 254]);
      fichier('programmes.json').writeAsStringSync('');
      fichier('mesures.json').writeAsStringSync('null');
      fichier('exercices_favoris.json').writeAsStringSync('{"a":1}');
      final d = await demarrer();
      expect(d.sessions.sessions, isEmpty);
      expect(d.sessions.hasActive, isFalse);
    });

    test('profil au contenu inattendu : l\'appli démarre', () async {
      fichier('profil.json').writeAsStringSync('{"id":"moi","prenom":"Tristan","creeLe":"2026-01-01T00:00:00.000","objectifsNutrition":"auto","joursParSemaine":"NaN"}');
      fichier('seance_active.json').writeAsStringSync('{"id":"a","debut":12.5,"exercices":"x","medias":{"a":1},"ressenti":"NaN"}');
      final d = await demarrer();
      expect(d.profile.profile!.prenom, 'Tristan');
    });

    test('historique tronqué : mis de côté, et la copie survit à l\'enregistrement suivant', () async {
      final complet = jsonEncode([for (final s in _deuxAns().take(50)) s.toJson()]);
      final tronque = complet.substring(0, complet.length ~/ 2);
      fichier('seances.json').writeAsStringSync(tronque);
      final d = await demarrer();
      expect(d.sessions.sessions, isEmpty);
      expect(d.store.abimes, contains('seances'));
      expect(fichier('seances.json.abime').readAsStringSync(), tronque);

      // L'utilisateur fait une séance : le fichier est réécrit, la copie reste.
      await d.sessions.save(WorkoutSession(id: 'n', nom: 'Nouvelle', debut: DateTime(2026, 10, 2), fin: DateTime(2026, 10, 2, 1)));
      expect(fichier('seances.json.abime').readAsStringSync(), tronque);

      // Seconde panne, plus tard : la première copie (l'historique complet) n'est pas écrasée.
      fichier('seances.json').writeAsStringSync('[{"id":"n","nom":"Nouv');
      final d2 = await demarrer();
      expect(d2.sessions.sessions, isEmpty);
      expect(fichier('seances.json.abime').readAsStringSync(), tronque, reason: 'la copie de l\'historique complet a été écrasée');
      final copies = dossier.listSync().map((f) => f.uri.pathSegments.last).where((n) => n.startsWith('seances.json.abime')).toList();
      expect(copies, hasLength(2));
      // Relancer sans rien changer ne multiplie pas les copies.
      await demarrer();
      await demarrer();
      expect(dossier.listSync().map((f) => f.uri.pathSegments.last).where((n) => n.startsWith('seances.json.abime')), hasLength(2));
    });

    test('une séance illisible au milieu des autres n\'emporte pas les autres', () async {
      fichier('seances.json').writeAsStringSync('[{"id":"a","nom":"A","debut":"2026-01-01T10:00:00.000","fin":"2026-01-01T11:00:00.000"},'
          '"pas une séance",12,null,'
          '{"id":"b","nom":"B","debut":"2026-01-02T10:00:00.000","fin":"2026-01-02T11:00:00.000","exercices":[{"series":"x"}]}]');
      final d = await demarrer();
      expect(d.sessions.sessions.map((s) => s.id), ['b', 'a']);
    });

    test('séance sans date lisible : la date ne change pas d\'un lancement à l\'autre', () async {
      fichier('seances.json').writeAsStringSync('[{"id":"a","nom":"A","debut":"hier soir","fin":"2026-01-01T11:00:00.000"}]');
      final d = await demarrer();
      final premiere = d.sessions.sessions.single.debut;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final d2 = await demarrer();
      expect(d2.sessions.sessions.single.debut, premiere);
      // Une séance sans date ne doit pas se faire passer pour une séance d'aujourd'hui.
      expect(d2.sessions.sessionsOn(DateTime.now()), isEmpty);
    });
  });

  test('un dépôt qui échoue au chargement ne retient pas les autres', () async {
    final casse = _StoreQuiCasse();
    await casse.write('seances', [
      WorkoutSession(id: 'a', nom: 'A', debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 1, 1)).toJson(),
    ]);
    final d = AppData(casse);
    await d.loadAll();
    expect(d.erreursChargement.keys, ['profil']);
    expect(d.sessions.sessions, hasLength(1));
  });

  group('gros volume', () {
    test('deux ans de séances : écriture et chargement mesurés', () async {
      final seances = _deuxAns();
      final repo = SessionRepo(store);
      await repo.load();
      final ecriture = Stopwatch()..start();
      await repo.addAll(seances);
      ecriture.stop();
      final taille = fichier('seances.json').lengthSync();

      final chargement = Stopwatch()..start();
      final relu = SessionRepo(Store.dossier(dossier));
      await relu.load();
      chargement.stop();
      expect(relu.sessions, hasLength(seances.length));
      expect(relu.sessions.first.debut.isAfter(relu.sessions.last.debut), isTrue);

      // Coût d'une séance terminée de plus : toute la collection est réécrite.
      final uneDePlus = Stopwatch()..start();
      await relu.save(WorkoutSession(id: 'x', nom: 'x', debut: DateTime(2026, 10, 2), fin: DateTime(2026, 10, 2, 1)));
      uneDePlus.stop();

      final historique = Stopwatch()..start();
      final h = relu.historyFor('exo-3');
      relu.bestsFor('exo-3');
      historique.stop();
      expect(h, isNotEmpty);

      // ignore: avoid_print
      print('MESURE ${seances.length} séances, ${seances.length * 24} séries, ${(taille / 1024).round()} Ko : '
          'écriture ${ecriture.elapsedMilliseconds} ms, chargement ${chargement.elapsedMilliseconds} ms, '
          'une séance de plus ${uneDePlus.elapsedMilliseconds} ms, historique et records d\'un exercice ${historique.elapsedMilliseconds} ms');
      // Garde-fou large (machine de test) : un chargement de plusieurs secondes serait un défaut.
      expect(chargement.elapsedMilliseconds, lessThan(3000));
      expect(uneDePlus.elapsedMilliseconds, lessThan(3000));
    });
  });

  group('sauvegarde', () {
    test('exportBackup puis importBackup : tout revient, y compris types et médias', () async {
      final d = AppData(store);
      await d.loadAll();
      await d.sessions.save(WorkoutSession(
        id: 's',
        nom: 'Cardio',
        debut: DateTime(2026, 9, 1, 7),
        fin: DateTime(2026, 9, 1, 8),
        type: TypeSeance.cardio,
        medias: const [SessionMedia(chemin: 'm.mp4', video: true, dureeSec: 12)],
        exercices: [
          SessionExercise(id: 'e', exerciseId: 'x', series: [for (final t in SetType.values) WorkoutSet(id: t.name, type: t, poids: 10, reps: 5, fait: true)]),
        ],
      ));
      final sauvegarde = await d.exportBackup();
      final autre = Directory.systemTemp.createTempSync('aesthetic_store2_');
      addTearDown(() => autre.deleteSync(recursive: true));
      final d2 = AppData(Store.dossier(autre));
      await d2.loadAll();
      await d2.importBackup(sauvegarde);
      final s = d2.sessions.sessions.single;
      expect(s.type, TypeSeance.cardio);
      expect(s.medias.single.dureeSec, 12);
      expect(s.exercices.single.series.map((x) => x.type), SetType.values);
      expect(() => d2.importBackup('{"application":"autre"}'), throwsFormatException);
      expect(() => d2.importBackup('pas du json'), throwsFormatException);
      // Une sauvegarde refusée n'a rien effacé.
      expect(d2.sessions.sessions, hasLength(1));
    });
  });
}
