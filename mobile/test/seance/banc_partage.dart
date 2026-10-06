import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Banc des cartes de partage, sans le routeur du module : une carte seule,
/// aux données de la maquette, à la taille de l'écran de la maquette.

const taillePartage = Size(380, 805);
final clePartage = GlobalKey();

Future<void> _police(String famille, List<String> fichiers) async {
  final l = FontLoader(famille);
  for (final f in fichiers) {
    l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> policesPartage() async {
  await initializeDateFormatting('fr_FR');
  await _police('Figtree', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'Figtree-$w.ttf']);
  await _police('Montserrat', [for (final w in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'Montserrat-$w.ttf']);
  // La police à empattement du système (« serif » sur le téléphone) : ici celle du poste, si elle existe.
  final serif = FontLoader('serif');
  var trouve = false;
  for (final f in ['georgia.ttf', 'georgiab.ttf', 'georgiai.ttf', 'georgiaz.ttf']) {
    final file = File('C:/Windows/Fonts/$f');
    if (file.existsSync()) {
      trouve = true;
      serif.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
  }
  if (trouve) await serif.load();
  final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await l.load();
  }
}

/// Prépare l'écran : taille de la maquette, encoche de 25 en haut.
Future<void> preparerPartage(WidgetTester t) async {
  await t.runAsync(policesPartage);
  t.view.physicalSize = taillePartage;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 25);
  addTearDown(t.view.reset);
}

Future<void> poserPartage(WidgetTester t, Widget page, {List<String> assets = const []}) async {
  await t.pumpWidget(RepaintBoundary(
    key: clePartage,
    child: MaterialApp(theme: AccentController().theme, debugShowCheckedModeBanner: false, home: page),
  ));
  final ctx = t.element(find.byType(Navigator).first);
  await t.runAsync(() async {
    for (final a in assets) {
      await precacheImage(AssetImage(a), ctx);
    }
  });
  for (var i = 0; i < 9; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> capturePartage(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(clePartage));
    final img = await ro.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/seance/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
