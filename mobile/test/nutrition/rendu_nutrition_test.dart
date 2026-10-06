import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/nutrition/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _k = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1.5);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/nutrition/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Rendu hors écran des pages nutrition (démo), Fold fermé puis ouvert.
/// Lancer avec : flutter test test/nutrition/rendu_nutrition_test.dart --dart-define=RENDU=true
void main() {
  const rendu = bool.fromEnvironment('RENDU');
  testWidgets('rendu nutrition', skip: !rendu, (t) async {
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _font('Figtree', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
    });
    final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await t.runAsync(() async {
        final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await l.load();
      });
    }
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data);
    });
    for (final (nom, taille) in [('ferme', const Size(412, 915)), ('ouvert', const Size(884, 1000))]) {
      t.view.physicalSize = taille;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: AccentController())));
      await t.pump(const Duration(seconds: 1));
      final router = GoRouter.of(t.element(find.byType(Scaffold).first));
      Future<void> page(String path, String file, {Object? extra}) async {
        router.go(path, extra: extra);
        await t.pump(const Duration(milliseconds: 400));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(seconds: 1));
        if (rendu) await t.runAsync(() => _shot(t, '${nom}_$file'));
        expect(t.takeException(), isNull, reason: path);
      }

      await page('/nutrition', 'journal');
      if (nom == 'ferme') {
        await t.drag(find.byType(CustomScrollView).first, const Offset(0, -800));
        await t.pump(const Duration(seconds: 1));
        if (rendu) await t.runAsync(() => _shot(t, '${nom}_journal2'));
        await t.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
        await t.pump(const Duration(seconds: 1));
        if (rendu) await t.runAsync(() => _shot(t, '${nom}_journal3'));
      }
      await page('/nutrition/ajouter', 'ajouter');
      await page('/nutrition/calendrier', 'calendrier');
      await page('/nutrition/repas/journee', 'journee');
      await page('/nutrition/repas/dejeuner', 'dejeuner');
      await page('/nutrition/eau', 'eau');
      await page('/nutrition/objectifs', 'objectifs');
      await page('/nutrition/statistiques', 'statistiques');
      await page('/nutrition/aliments', 'aliments');
      await page('/nutrition/repas-enregistres', 'repas');
      await page('/nutrition/recettes', 'recettes');
      await page('/nutrition/recettes/edition', 'recette_edition');
      await page('/nutrition/aliment-perso', 'aliment_perso');
      await page('/nutrition/ajout-rapide', 'ajout_rapide');
      await page('/nutrition/reglages', 'reglages');
      final food = data.nutrition.recentFoods().first;
      await page('/nutrition/aliment', 'aliment', extra: FoodPageArgs(food: food, nutriscore: 'b'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }
  });
}
