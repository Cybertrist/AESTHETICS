import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/features/profil/widgets/ecusson.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../aujourdhui/banc.dart';

/// L'écusson « PR » en grand, sur fond transparent, pour les maquettes :
/// build/rendus/ecran_accueil/ecusson-pr.png.
void main() {
  testWidgets('écusson PR en image', (t) async {
    await t.runAsync(polices);
    final cle = GlobalKey();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RepaintBoundary(key: cle, child: Ecusson.record(largeur: 240))),
    ));
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cle));
    final img = await t.runAsync(() => ro.toImage(pixelRatio: 2));
    final octets = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    (File('build/rendus/ecran_accueil/ecusson-pr.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  });
}
