import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/import/data/import_flow.dart';
import 'package:aesthetic/features/import/data/repo_extensions.dart';
import 'package:aesthetic/features/import/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

final _k = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/import/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Toutes les pages du module, Fold fermé et ouvert, sans exception.
/// RENDU_IMPORT=1 écrit les captures dans build/rendus/import/.
void main() {
  final ecrire = Platform.environment['RENDU_IMPORT'] == '1';

  testWidgets('pages Import, Fold fermé puis ouvert', (t) async {
    ImportFlow.enIsolat = false;
    // Le catalogue d'aliments est facultatif et absent du dépôt : on le simule vide.
    t.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (msg) async {
      final cle = Uri.decodeFull(utf8.decode(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes)));
      final fichier = File(cle);
      if (fichier.existsSync()) return ByteData.sublistView(fichier.readAsBytesSync());
      if (cle.endsWith('.json')) return ByteData.sublistView(utf8.encode('[]'));
      return null;
    });
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      final l = FontLoader('Figtree');
      for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
        l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await l.load();
      final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        final m = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await m.load();
      }
    });
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data);
    });
    final router = GoRouter(initialLocation: '/import', routes: importRoutes());
    addTearDown(router.dispose);

    for (final (largeur, nom) in [(380.0, 'ferme'), (900.0, 'ouvert')]) {
      t.view.physicalSize = Size(largeur, 1800);
      await t.pumpWidget(RepaintBoundary(key: _k, child: _Banc(data: data, router: router)));
      await _attendre(t);

      Future<void> page(String chemin, String capture) async {
        router.go(chemin);
        await _attendre(t);
        expect(t.takeException(), isNull, reason: capture);
        if (ecrire) await t.runAsync(() => _shot(t, '$nom-$capture'));
      }

      final flow = ImportFlow.instance..demarrer(ImportSource.application);
      await page('/import', 'accueil');
      await page('/import/fichier', 'fichier-vide');
      await t.runAsync(() => flow.chargerFichier('mon-export.csv', File('test/fixtures/format_a.csv').readAsBytesSync(), data));
      await page('/import/fichier', 'fichier-pret');
      await page('/import/apercu', 'apercu');
      await page('/import/apercu/seances', 'seances');
      await page('/import/apercu/seances/0', 'seance');
      await page('/import/apercu/messages', 'messages');
      await page('/import/exercices', 'exercices');
      final nomExo = (flow.rapport!.aConfirmer.isNotEmpty ? flow.rapport!.aConfirmer : flow.rapport!.reconnus).first.nomSource;
      await page('/import/exercices/choisir?nom=${Uri.encodeQueryComponent(nomExo)}', 'choisir');
      flow
        ..accepterSuggestions(toutes: true)
        ..creerTousLesInconnus();
      await page('/import/options', 'options');
      await t.runAsync(() => flow.importer(data));
      await page('/import/resume', 'resume');
      await page('/import/resume/records', 'records');
      await page('/import/journal', 'journal');
      await page('/import/export', 'export');
      await page('/import/sauvegarde', 'sauvegarde');
      await page('/import/aide', 'aide');

      flow.demarrer(ImportSource.tableau);
      await t.runAsync(() => flow.chargerFichier('tableau.csv', File('test/fixtures/generique_fr.csv').readAsBytesSync(), data));
      await page('/import/colonnes', 'colonnes');
      // Le même fichier réimporté au Fold ouvert : tout est déjà là.
      await t.runAsync(() => data.sessions.supprimerPlusieurs({for (final s in data.sessions.seancesImportees) s.id}));
    }
  });
}

class _Banc extends StatelessWidget {
  const _Banc({required this.data, required this.router});
  final AppData data;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final accent = AccentController();
    return MultiProvider(
      providers: [
        Provider<AppData>.value(value: d),
        Provider<Store>.value(value: d.store),
        ChangeNotifierProvider<AccentController>.value(value: accent),
        ChangeNotifierProvider<ProfileRepo>.value(value: d.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: d.settings),
        ChangeNotifierProvider<ExerciseRepo>.value(value: d.exercises),
        ChangeNotifierProvider<RoutineRepo>.value(value: d.routines),
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
        ChangeNotifierProvider<NutritionRepo>.value(value: d.nutrition),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: accent.theme,
        routerConfig: router,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
