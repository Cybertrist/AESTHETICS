import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/pages/partager_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/cartes_partage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

/// Une photo claire et chargée (bandes de texte), le pire cas pour lire
/// l'autocollant posé dessus.
Future<String> _photoClaire() async {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawRect(const Rect.fromLTWH(0, 0, 600, 900), Paint()..color = Colors.white);
  final gris = Paint()..color = Colors.grey;
  for (var y = 40.0; y < 900; y += 70) {
    c.drawRect(Rect.fromLTWH(40, y, 380 + (y % 140), 24), gris);
  }
  final img = await r.endRecording().toImage(600, 900);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/rendus/seance/_photo_claire.png')..parent.createSync(recursive: true);
  f.writeAsBytesSync(png!.buffer.asUint8List());
  return f.path;
}

/// Carte « sur ta photo » : damier opaque sans photo, la photo de la séance
/// sinon, qu'on peut retirer. Images dans build/rendus/seance.
void main() {
  for (final taille in const [Size(360, 780), Size(412, 915)]) {
    final l = taille.width.toInt();

    testWidgets('partage sur ta photo en $l de large', (t) async {
      t.view.padding = const FakeViewPadding(top: 25);
      addTearDown(t.view.resetPadding);
      final data = await monter(t, depart: '/', taille: taille);
      // Une séance sans photo : les plus récentes de la démo en portent.
    final s = data.sessions.sessions.firstWhere((x) => x.medias.isEmpty && x.volume > 0);
      final routeur = routeurDe(t);

      Future<void> derniereCarte() async {
        // Six cartes quand la séance a battu un record, cinq sinon.
        final nombre = t.state<PartagerPageState>(find.byType(PartagerPage)).nombreCartes;
        for (var i = 1; i < nombre; i++) {
          await t.drag(find.byType(PageView), const Offset(-330, 0));
          await attendre(t, tours: 5);
          expect(t.takeException(), isNull, reason: 'carte ${i + 1}');
        }
      }

      // Sans photo : le damier opaque et son invitation.
      routeur.push(SeancePaths.partager(s.id));
      await attendre(t, tours: 12);
      // La page couvre ce qui se trouve dessous dans la pile.
      final page = t.widget<Scaffold>(find.descendant(of: find.byType(PartagerPage), matching: find.byType(Scaffold)));
      expect(page.backgroundColor?.a, 1, reason: 'fond opaque');
      await derniereCarte();
      expect(find.text('Ta photo ici'), findsOneWidget);
      expect(find.bySemanticsLabel('Retirer la photo'), findsNothing);
      expect(find.descendant(of: find.byType(CarteAutocollant), matching: find.byType(Image)), findsNothing);
      await capture(t, 'photo-$l-damier');
      routeur.pop();
      await attendre(t);

      // La séance a une photo : elle sert de fond, et on peut la retirer.
      final photo = (await t.runAsync(_photoClaire))!;
      await t.runAsync(() => data.sessions.save(s.copyWith(medias: [SessionMedia(chemin: photo)])));
      routeur.push(SeancePaths.partager(s.id));
      await attendre(t, tours: 12);
      expect(find.bySemanticsLabel('Retirer la photo'), findsNothing, reason: 'seulement sur la carte à photo');
      await derniereCarte();
      await attendre(t, tours: 6);
      expect(find.text('Ta photo ici'), findsNothing);
      expect(find.descendant(of: find.byType(CarteAutocollant), matching: find.byType(Image)), findsOneWidget);
      await capture(t, 'photo-$l-photo');

      await t.tap(find.bySemanticsLabel('Retirer la photo'));
      await attendre(t);
      expect(find.text('Ta photo ici'), findsOneWidget);
      expect(find.bySemanticsLabel('Retirer la photo'), findsNothing);
      expect(t.takeException(), isNull);
      await demonter(t);
    });
  }
}
