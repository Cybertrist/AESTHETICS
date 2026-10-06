import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Profil illisible au démarrage : l'appli arrive sur la bienvenue comme à un
/// premier lancement. Elle doit dire qu'un fichier est abîmé et où se trouve
/// la copie de secours, au lieu de laisser croire que tout a disparu.
void main() {
  final cle = GlobalKey();

  Future<void> monter(WidgetTester t, AppData data, Size taille, String nom) async {
    t.view.physicalSize = taille;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      for (final (famille, fichiers) in [
        ('Figtree', [for (final p in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Figtree-$p.ttf']),
        ('MaterialIcons', ['C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']),
      ]) {
        final l = FontLoader(famille);
        for (final f in fichiers) {
          if (File(f).existsSync()) l.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
        }
        await l.load();
      }
    });
    await t.pumpWidget(RepaintBoundary(key: cle, child: AestheticApp(key: UniqueKey(), data: data, accent: AccentController())));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 400));
    }
    await t.runAsync(() async {
      final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cle));
      final img = await ro.toImage(pixelRatio: 1);
      final octets = await img.toByteData(format: ui.ImageByteFormat.png);
      (File('build/rendus/inscription/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
    });
  }

  testWidgets('profil abîmé : la bienvenue le dit et montre la copie de secours, en 360 et sur le Fold ouvert', (t) async {
    final dossier = Directory.systemTemp.createTempSync('aesthetic_abime_');
    addTearDown(() => dossier.deleteSync(recursive: true));
    File('${dossier.path}${Platform.pathSeparator}profil.json').writeAsStringSync('{"id": "u", "prenom": "Tri');
    final data = AppData(Store.dossier(dossier));
    await t.runAsync(data.loadAll);
    expect(data.profile.hasProfile, isFalse);
    expect(data.store.abimes.keys, ['profil']);

    for (final (taille, nom) in const [(Size(360, 780), 'chasse-bienvenue-abime-360'), (Size(900, 800), 'chasse-bienvenue-abime-900')]) {
      await monter(t, data, taille, nom);
      expect(find.byType(AlerteDonnees), findsOneWidget);
      expect(find.text('Un fichier de données est abîmé'), findsOneWidget);
      expect(find.textContaining('ton profil'), findsOneWidget);
      expect(t.widget<SelectableText>(find.byType(SelectableText)).data, contains('profil.json.abime'));
      expect(find.text('Commencer'), findsOneWidget, reason: 'le parcours reste possible');
      expect(find.text('Restaurer une sauvegarde'), findsOneWidget);
      expect(t.takeException(), isNull, reason: nom);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }
    // La copie existe bien à l'endroit annoncé.
    expect(File(data.store.abimes['profil']!).readAsStringSync(), contains('"prenom": "Tri'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('premier lancement normal : aucune alerte', (t) async {
    final data = AppData(Store.memory());
    await t.runAsync(data.loadAll);
    await monter(t, data, const Size(360, 780), 'chasse-bienvenue-saine');
    expect(find.byType(AlerteDonnees), findsNothing);
    expect(find.text('Commencer'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
