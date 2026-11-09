import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/profil/photos/transformation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:video_player/video_player.dart';

/// Sur un vrai Android : l'animation de transformation est filmée image par
/// image et donne un MP4 lisible, à la bonne taille et à la bonne durée.
///
/// `flutter test integration_test/video_transformation_test.dart -d <appareil>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<File> image(String nom, Color couleur) async {
    final r = ui.PictureRecorder();
    Canvas(r).drawRect(const Rect.fromLTWH(0, 0, 300, 400), Paint()..color = couleur);
    final img = await r.endRecording().toImage(300, 400);
    final octets = await img.toByteData(format: ui.ImageByteFormat.png);
    return File('${Directory.systemTemp.path}/$nom.png')..writeAsBytesSync(octets!.buffer.asUint8List());
  }

  testWidgets('la vidéo de la transformation est un MP4 lisible', (t) async {
    await initializeDateFormatting('fr_FR');
    final avant = await image('avant', Colors.indigo), apres = await image('apres', Colors.teal);
    final video = File('${Directory.systemTemp.path}/transformation.mp4');
    if (video.existsSync()) video.deleteSync();

    await t.pumpWidget(MaterialApp(
      theme: AccentController().theme,
      home: TransformationPage(
        avant: ProgressPhoto(id: 'a', date: DateTime(2026, 6, 26), chemin: avant.path),
        apres: ProgressPhoto(id: 'b', date: DateTime(2026, 10, 9), chemin: apres.path),
        poidsAvant: 129.9,
        poidsApres: 112.8,
        unite: UnitePoids.kg,
        ecart: '−17,1 kg en 15 semaines',
      ),
    ));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Partager la vidéo'));

    // L'export avance d'une image par tour ; on attend que le bouton revienne
    // ou que la feuille de partage masque l'appli.
    final debut = DateTime.now();
    VideoPlayerController? lecteur;
    while (DateTime.now().difference(debut) < const Duration(minutes: 5)) {
      await t.pump(const Duration(milliseconds: 30));
      if (find.textContaining('Préparation').evaluate().isEmpty) break;
      final texte = t.widget<Text>(find.textContaining('Préparation')).data!;
      if (texte.contains('99 %')) {
        await t.pump(const Duration(seconds: 2));
        break;
      }
    }
    expect(video.existsSync(), isTrue);
    // ignore: avoid_print
    print('VIDEO ${video.lengthSync()} octets en ${DateTime.now().difference(debut).inSeconds} s');
    expect(video.lengthSync(), greaterThan(100000));
    // Le fichier n'est lisible qu'une fois refermé : on laisse le temps de finir.
    for (var essai = 0; ; essai++) {
      lecteur = VideoPlayerController.file(video);
      try {
        await lecteur.initialize();
        break;
      } catch (_) {
        await lecteur.dispose();
        if (essai == 10) rethrow;
        await t.pump(const Duration(seconds: 2));
      }
    }
    // ignore: avoid_print
    print('VIDEO ${lecteur.value.size} ${lecteur.value.duration}');
    expect(lecteur.value.size, const Size(720, 1280));
    expect(lecteur.value.duration.inMilliseconds, closeTo(8000, 200));
    await lecteur.dispose();
  });
}
