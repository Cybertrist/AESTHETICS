import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/theme/app_theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boîte de note avec le clavier ouvert (Fold fermé) : rien n'est coupé,
/// les boutons restent dans la boîte.
void main() {
  testWidgets('boîte de note, clavier ouvert, 412 de large', (t) async {
    t.view.physicalSize = const Size(412, 760);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = const FakeViewPadding(bottom: 370);
    addTearDown(t.view.reset);
    final cle = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
      key: cle,
      child: MaterialApp(
        theme: AppTheme.dark(const Color(0xFFFF5A5F)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTextInputDialog(context, title: 'Note sur l\'exercice', hint: 'Réglage du banc, sensation, prise...', maxLines: 4, maxLength: 400),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final boite = t.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
    final bouton = t.getRect(find.text('Enregistrer'));
    expect(bouton.bottom, lessThan(boite.bottom - 8), reason: 'le bouton reste dans la boîte');
    expect(boite.bottom, lessThanOrEqualTo(760 - 370));
    final ro = cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await t.runAsync(() async {
      final i = await ro.toImage(pixelRatio: 2);
      return i.toByteData(format: ui.ImageByteFormat.png);
    });
    File('build/rendus/core/note-clavier.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(img!.buffer.asUint8List());
  });
}
