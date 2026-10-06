import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/import/data/import_flow.dart';
import 'package:aesthetic/features/import/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Design validé : les icônes de début de ligne sont blanches (ou grises quand
/// elles sont éteintes) dans un rond gris, jamais teintées.
int _verifierIcones(WidgetTester t, String page) {
  final halos = find.byType(IconHalo).evaluate().toList();
  for (final e in halos) {
    final halo = e.widget as IconHalo;
    final c = e.colors;
    expect(halo.color, isNull, reason: '$page : IconHalo ${halo.icon} coloré');
    final icones = find.descendant(of: find.byWidget(halo), matching: find.byType(Icon));
    for (final i in t.widgetList<Icon>(icones)) {
      expect([c.text, c.text3], contains(i.color), reason: '$page : icône ${i.icon} teintée');
    }
  }
  return halos.length;
}

void main() {
  testWidgets('Import : aucune icône à halo coloré', (t) async {
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
      // Sans la police, les textes débordent (police de test, très large).
      final l = FontLoader('Figtree');
      for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
        l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await l.load();
    });
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(380, 1800);
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data);
    });
    final router = GoRouter(initialLocation: '/import', routes: importRoutes());
    addTearDown(router.dispose);
    final accent = AccentController();
    await t.pumpWidget(MultiProvider(
      providers: [
        Provider<AppData>.value(value: data),
        Provider<Store>.value(value: data.store),
        ChangeNotifierProvider<AccentController>.value(value: accent),
        ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
        ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
        ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
        ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
        ChangeNotifierProvider<HealthRepo>.value(value: data.health),
        ChangeNotifierProvider<NutritionRepo>.value(value: data.nutrition),
      ],
      child: MaterialApp.router(
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
    ));
    await _attendre(t);

    var vus = 0;
    Future<void> page(String chemin) async {
      router.go(chemin);
      await _attendre(t);
      expect(t.takeException(), isNull, reason: chemin);
      vus += _verifierIcones(t, chemin);
    }

    final flow = ImportFlow.instance..demarrer(ImportSource.application);
    await page('/import');
    await page('/import/fichier');
    await t.runAsync(() => flow.chargerFichier('mon-export.csv', File('test/fixtures/format_a.csv').readAsBytesSync(), data));
    await page('/import/fichier');
    await page('/import/apercu');
    await page('/import/apercu/seances');
    await page('/import/apercu/messages');
    await page('/import/exercices');
    flow
      ..accepterSuggestions(toutes: true)
      ..creerTousLesInconnus();
    await page('/import/options');
    await t.runAsync(() => flow.importer(data));
    await page('/import/resume');
    await page('/import/resume/records');
    await page('/import/journal');
    await page('/import/export');
    await page('/import/sauvegarde');
    await page('/import/aide');
    flow.demarrer(ImportSource.tableau);
    await t.runAsync(() => flow.chargerFichier('tableau.csv', File('test/fixtures/generique_fr.csv').readAsBytesSync(), data));
    await page('/import/colonnes');
    expect(vus, greaterThan(30), reason: 'le test doit réellement croiser des icônes');
  });
}
