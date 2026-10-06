import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/progres/ui/torse_ruban.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendu du torse au mètre ruban (tuile Mensurations), à la taille de
/// l'appli et en grand : build/rendus/progres/ruban.png.
void main() {
  testWidgets('le torse au mètre ruban se dessine sans erreur', (t) async {
    t.view.physicalSize = const Size(900, 500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cadre = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(const Color(0xFFFF5A5F)),
        home: RepaintBoundary(
          key: cadre,
          child: const ColoredBox(
            color: AppTokens.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [TorseRuban(), TorseRuban(cote: 184), TorseRuban(cote: 440)],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 7; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cadre));
    final img = await t.runAsync(() => ro.toImage(pixelRatio: 1));
    final octets = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    (File('build/rendus/progres/ruban.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  });
}
