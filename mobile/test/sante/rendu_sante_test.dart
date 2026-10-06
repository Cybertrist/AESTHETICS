import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/sante/services/activite_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(File(f.contains('/') ? f : 'assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _k = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1.5);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/sante/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Rendu hors écran des pages Santé (données de démo) dans build/rendus/sante/.
/// Lancer avec : flutter test test/sante/rendu_sante_test.dart --dart-define=RENDU=true
void main() {
  const rendu = bool.fromEnvironment('RENDU');
  const large = bool.fromEnvironment('LARGE');

  testWidgets('rendu des pages Santé', (t) async {
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _font('Figtree', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
      const icons = 'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
      if (File(icons).existsSync()) await _font('MaterialIcons', [icons]);
    });
    t.view.physicalSize = large ? const Size(884, 1104) : const Size(412, 915);
    t.view.devicePixelRatio = 1;
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data);
      final j = ActiviteJournal.of(data.store);
      await j.charger();
      final today = DateTime.now();
      await j.enregistrer([
        for (var i = 0; i < 40; i++)
          JourActivite(
            jour: DateTime(today.year, today.month, today.day - i),
            pas: 6000 + (i * 1373) % 7000,
            kcalActives: 350.0 + (i * 37) % 300,
            kcalTotales: 2200.0 + (i * 37) % 300,
            fcRepos: 55.0 + (i * 7) % 6,
            fcMoyenne: 74,
          ),
      ]);
    });
    await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: AccentController())));
    await t.pump(const Duration(seconds: 1));

    final nuit = data.health.sleep.first.id;
    final comp = data.health.supplements.first.id;
    final pages = {
      'hub': '/sante',
      'sommeil': '/sante/sommeil',
      'nuit': '/sante/sommeil/nuit/$nuit',
      'nuit_form': '/sante/sommeil/ajouter',
      'sommeil_historique': '/sante/sommeil/historique',
      'corps': '/sante/corps',
      'mesure_form': '/sante/corps/mesure?tours=1',
      'mesures': '/sante/corps/mesures',
      'mensurations': '/sante/corps/mensurations',
      'tour': '/sante/corps/tour/bras',
      'photos': '/sante/corps/photos',
      'comparer': '/sante/corps/comparer',
      'recuperation': '/sante/recuperation',
      'muscle': '/sante/recuperation/pectoraux',
      'activite': '/sante/activite',
      'complements': '/sante/complements',
      'complement': '/sante/complements/$comp',
      'complement_form': '/sante/complements/ajouter',
      'connexion': '/sante/connexion',
    };
    for (final e in pages.entries) {
      if (const String.fromEnvironment('SAUF').split(',').contains(e.key)) continue;
      GoRouter.of(t.element(find.byType(Scaffold).first)).go(e.value);
      await t.pump(const Duration(milliseconds: 500));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull, reason: e.key);
      if (rendu) {
        await t.runAsync(() => _shot(t, '${large ? 'large_' : ''}${e.key}'));
        final lists = find.byType(Scrollable);
        if (lists.evaluate().isNotEmpty && !large) {
          await t.drag(lists.first, const Offset(0, -700), warnIfMissed: false);
          await t.pump(const Duration(seconds: 1));
          await t.runAsync(() => _shot(t, '${e.key}_2'));
        }
      }
    }
  });
}
