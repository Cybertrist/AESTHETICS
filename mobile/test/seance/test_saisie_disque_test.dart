import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/chrono.dart';
import 'package:aesthetic/features/seance/logic/editeur.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// La séance en cours sur un vrai disque : ce qui reste quand l'appli est
/// tuée, fichier abîmé, écriture interrompue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dossier;

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('aesthetic_saisie_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dossier.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    PauseSeance.instance.reinitialiser();
    try {
      dossier.deleteSync(recursive: true);
    } catch (_) {
      // Dossier temporaire encore tenu par le système : sans importance.
    }
  });

  File fichier(String nom) => File('${dossier.path}${Platform.pathSeparator}donnees${Platform.pathSeparator}$nom.json');

  Future<(SessionRepo, EditeurDirect)> ouvrir() async {
    final repo = SessionRepo(await Store.open());
    await repo.load();
    return (repo, EditeurDirect(repo));
  }

  test('chaque série validée est dans le fichier dès que l\'écriture rend la main', () async {
    final (repo, ed) = await ouvrir();
    await repo.startEmpty();
    await ed.ajouterExercices(['a']);
    final se = repo.active!.exercices.single;

    for (var i = 0; i < 3; i++) {
      await ed.validerSerie(se.id, se.series[i].copyWith(poids: 60.0 + i * 2.5, reps: 8 - i), fait: true);
      // L'appli est tuée ici : on relit le fichier tel qu'il est sur le disque.
      final brut = jsonDecode(fichier('seance_active').readAsStringSync()) as Map<String, dynamic>;
      final relu = WorkoutSession.fromJson(brut);
      expect(relu.exercices.single.series.where((s) => s.fait).length, i + 1);
      expect(relu.exercices.single.series[i].poids, 60.0 + i * 2.5);
      expect(relu.exercices.single.series[i].reps, 8 - i);
    }
    expect(File('${fichier('seance_active').path}.tmp').existsSync(), isFalse, reason: 'pas de fichier temporaire oublié');

    // Redémarrage : la séance revient entière, avec la même heure de début.
    final debut = repo.active!.debut;
    final (repo2, ed2) = await ouvrir();
    expect(repo2.active!.id, repo.active!.id);
    expect(repo2.active!.debut, debut);
    expect(repo2.active!.volume, 60 * 8 + 62.5 * 7 + 65 * 6);
    expect(repo2.sessions, isEmpty, reason: 'une séance en cours n\'est pas dans l\'historique');
    ed.dispose();
    ed2.dispose();
  });

  test('rafale de gestes sans attendre : le fichier finit sur le dernier, jamais à moitié écrit', () async {
    final (repo, ed) = await ouvrir();
    await repo.startEmpty();
    await ed.ajouterExercices(['a', 'b']);
    final se = repo.active!.exercices.first;
    final attentes = <Future<void>>[];
    for (var i = 1; i <= 40; i++) {
      attentes.add(ed.majSerie(se.id, se.series.first.copyWith(reps: i, poids: i * 1.5)));
      // À tout moment, ce qui est sur le disque se relit.
      final f = fichier('seance_active');
      if (f.existsSync()) {
        expect(() => jsonDecode(f.readAsStringSync()), returnsNormally);
      }
    }
    await Future.wait(attentes);
    final (repo2, ed2) = await ouvrir();
    expect(repo2.active!.exercices.first.series.first.reps, 40);
    expect(repo2.active!.exercices.first.series.first.poids, 60);
    ed.dispose();
    ed2.dispose();
  });

  test('écriture interrompue ou fichier abîmé : l\'appli démarre, sans séance fantôme', () async {
    final (repo, ed) = await ouvrir();
    await repo.startEmpty();
    await ed.ajouterExercices(['a']);
    final bon = fichier('seance_active').readAsStringSync();

    // Tuée pendant l'écriture : un fichier temporaire tronqué traîne, le vrai est intact.
    File('${fichier('seance_active').path}.tmp').writeAsStringSync(bon.substring(0, bon.length ~/ 2));
    final (repo2, ed2) = await ouvrir();
    expect(repo2.active!.id, repo.active!.id);
    expect(repo2.active!.exercices.single.series.length, 3);

    // Fichier illisible : pas de plantage, pas de séance, et une copie est gardée de côté.
    fichier('seance_active').writeAsStringSync('{"id": "x", "exercices": [');
    final (repo3, ed3) = await ouvrir();
    expect(repo3.active, isNull);
    expect(File('${fichier('seance_active').path}.abime').existsSync(), isTrue);

    // Contenu valide mais inattendu (une liste) : ignoré.
    fichier('seance_active').writeAsStringSync('[1, 2, 3]');
    final (repo4, ed4) = await ouvrir();
    expect(repo4.active, isNull);
    for (final e in [ed, ed2, ed3, ed4]) {
      e.dispose();
    }
  });

  test('abandonner efface le fichier ; la pause survit à la fermeture, sur le disque', () async {
    final (repo, ed) = await ouvrir();
    await repo.startEmpty();
    final t0 = DateTime(2026, 10, 2, 7);
    await repo.updateActive(repo.active!.copyWith(debut: t0));
    final p = PauseSeance.instance..reinitialiser();
    p.mettreEnPause(repo.active!, maintenant: t0.add(const Duration(minutes: 12)), store: repo.store);
    await repo.store.readObject('seance_pause');
    expect(fichier('seance_pause').existsSync(), isTrue);

    p.reinitialiser();
    final (repo2, ed2) = await ouvrir();
    await p.charger(repo2);
    expect(p.enPause(repo2.active), isTrue);
    expect(p.ecoule(repo2.active!), const Duration(minutes: 12));

    p.oublier();
    await repo2.discardActive();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(fichier('seance_active').existsSync(), isFalse);
    expect(fichier('seance_pause').existsSync(), isFalse);
    final (repo3, ed3) = await ouvrir();
    expect(repo3.active, isNull);
    for (final e in [ed, ed2, ed3]) {
      e.dispose();
    }
  });
}
