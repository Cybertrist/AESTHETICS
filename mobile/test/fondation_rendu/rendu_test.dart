import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/ui.dart';
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

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1.5);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

final _k = GlobalKey();

Future<void> _pose(WidgetTester t) async {
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
}

/// Rendu hors écran (démo) : captures dans build/rendus/, sans émulateur.
void main() {
  testWidgets('rendu', (t) async {
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _font('Figtree', [
        'Figtree-Regular.ttf',
        'Figtree-Medium.ttf',
        'Figtree-SemiBold.ttf',
        'Figtree-Bold.ttf',
        'Figtree-ExtraBold.ttf',
      ]);
      await _font('Montserrat', [
        'Montserrat-SemiBold.ttf',
        'Montserrat-Bold.ttf',
        'Montserrat-ExtraBold.ttf',
        'Montserrat-Black.ttf',
      ]);
      await _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf']);
    });
    final icons = File('${'C:/src/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await t.runAsync(() async {
        final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await l.load();
      });
    }
    t.view.physicalSize = const Size(412 * 1.0, 915 * 1.0);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data);
    });
    final accent = AccentController();
    await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: accent)));
    await _pose(t);
    await t.runAsync(() => _shot(t, 'onglet'));

    // La barre : quatre onglets, Profil compris.
    expect(find.byType(AppBottomNav), findsOneWidget);
    for (final nom in ['Accueil', 'Entraînement', 'Progrès', 'Profil']) {
      expect(find.descendant(of: find.byType(AppBottomNav), matching: find.text(nom)), findsOneWidget);
    }
    await t.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Profil')));
    await _pose(t);
    expect(find.byType(AppBottomNav), findsOneWidget, reason: 'Profil est un onglet, la barre reste visible');
    await t.runAsync(() => _shot(t, 'onglet-profil'));

    final ctx = t.element(find.byType(Scaffold).first);
    // Les images des objets 3D se décodent hors de la fausse horloge.
    await t.runAsync(() async {
      for (final a in [Objets3D.baleine, Objets3D.chat]) {
        await precacheImage(AssetImage(a), ctx);
      }
    });
    GoRouter.of(ctx).push('/dev/composants');
    await _pose(t);
    await t.runAsync(() => _shot(t, 'composants1'));
    final liste = find.byType(ListView).first;
    for (var i = 2; i <= 7; i++) {
      await t.drag(liste, const Offset(0, -820));
      await _pose(t);
      await t.runAsync(() => _shot(t, 'composants$i'));
    }
    expect(t.takeException(), isNull);

    // Panneaux du bas.
    await t.drag(liste, const Offset(0, 5000));
    await _pose(t);
    await t.drag(liste, const Offset(0, -1250));
    await _pose(t);
    for (final (bouton, nom) in [('Type', 'panneau-type'), ('Actions', 'panneau-actions'), ('Durée', 'panneau-duree')]) {
      await t.tap(find.widgetWithText(BoutonSecondaire, bouton));
      await _pose(t);
      expect(find.byType(PanneauBas), findsOneWidget);
      await t.runAsync(() => _shot(t, nom));
      Navigator.of(t.element(find.byType(PanneauBas))).pop();
      await _pose(t);
    }
    expect(t.takeException(), isNull);
  });
}
