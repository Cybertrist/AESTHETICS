import 'dart:convert';

import 'package:aesthetic/core/data/exercise_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le catalogue charge les exercices du pack, animations et poses embarquées', () async {
    final chrono = Stopwatch()..start();
    final liste = await ExerciseCatalog.load();
    chrono.stop();
    // ignore: avoid_print
    print('Catalogue : ${liste.length} exercices chargés en ${chrono.elapsedMilliseconds} ms');

    final texte = await rootBundle.loadString(ExerciseCatalog.assetPath);
    final decodage = Stopwatch()..start();
    final brut = jsonDecode(texte) as List;
    decodage.stop();
    // ignore: avoid_print
    print('jsonDecode seul, sur le fil principal : ${decodage.elapsedMilliseconds} ms');
    expect(liste.length, brut.length);
    expect(liste.length, greaterThanOrEqualTo(600));
    expect(liste.map((e) => e.id).toSet().length, liste.length);

    // Identifiants historiques que d'autres modules utilisent.
    final ids = liste.map((e) => e.id).toSet();
    for (final id in ['developpe-couche', 'squat', 'tractions', 'hip-thrust', 'gainage', 'curl-barre']) {
      expect(ids, contains(id));
    }

    for (final e in liste) {
      expect(e.musclesPrincipaux, isNotEmpty, reason: e.id);
      expect(e.instructions, isNotEmpty, reason: e.id);
      expect(e.media.imagesLocales, isNotEmpty, reason: e.id);
    }
    final animes = liste.where((e) => e.media.gif != null).toList();
    expect(animes.length, greaterThanOrEqualTo(490));
    // Tout est embarqué : aucune image ne dépend du réseau.
    expect(animes.every((e) => e.media.gif!.startsWith('assets/exercises/anim/')), isTrue);
    expect(liste.every((e) => e.media.gifSecours == null && e.media.images.isEmpty), isTrue);
    expect(liste.every((e) => e.media.imagesLocales.every((p) => p.startsWith('assets/exercises/poses/'))), isTrue);

    // Les images embarquées sont bien déclarées dans pubspec.yaml.
    for (final e in [liste.first, liste[liste.length ~/ 2], liste.last]) {
      final octets = await rootBundle.load(e.media.imagesLocales.first);
      expect(octets.lengthInBytes, greaterThan(1000));
    }
    for (final e in [animes.first, animes.last]) {
      final octets = await rootBundle.load(e.media.gif!);
      expect(octets.lengthInBytes, greaterThan(50000));
    }
  });
}
