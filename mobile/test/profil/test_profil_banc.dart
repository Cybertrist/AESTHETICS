import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/profil/data/prefs.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

/// Banc des tests de la zone profil : vraies routes du module, dépôts en
/// mémoire, police Figtree.

final cleBanc = GlobalKey();

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> polices(WidgetTester t) => t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _font('Figtree', ['Figtree-Regular.ttf', 'Figtree-Medium.ttf', 'Figtree-SemiBold.ttf', 'Figtree-Bold.ttf', 'Figtree-ExtraBold.ttf']);
      // Les chiffres des écussons.
      await _font('Montserrat', ['Montserrat-Black.ttf']);
      final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await l.load();
      }
    });

Future<void> photo(WidgetTester t, String nom, {double ratio = 2}) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cleBanc));
  final img = await ro.toImage(pixelRatio: ratio);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/profil/tests/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> attendre(WidgetTester t, [int tours = 3]) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

void ecran(WidgetTester t, {double largeur = 412, double hauteur = 915}) {
  t.view.physicalSize = Size(largeur, hauteur);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 25);
  addTearDown(t.view.reset);
}

/// Chemins des autres modules atteints depuis le profil : la page affiche
/// son propre chemin.
const cheminsVoisins = ['/bienvenue', '/bienvenue/modifier', '/bienvenue/modifier/objectif', '/progres/records', '/progres/calendrier', '/import', '/import/sauvegarde'];

GoRouter routeur(String depart) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: depart,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: child,
            bottomNavigationBar: AppBottomNav(currentIndex: AppTab.profil.rang, onTap: (_) {}),
          ),
          routes: profilRoutes().where((r) => r is GoRoute && r.path == Paths.profil).toList(),
        ),
        ...profilRoutes().where((r) => !(r is GoRoute && r.path == Paths.profil)),
        for (final chemin in cheminsVoisins) GoRoute(path: chemin, builder: (c, s) => Scaffold(body: Text('voisin ${s.uri}'))),
      ],
    );

class Banc extends StatelessWidget {
  const Banc({super.key, required this.data, required this.router, required this.accent});
  final AppData data;
  final GoRouter router;
  final AccentController accent;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return MultiProvider(
      providers: [
        Provider<AppData>.value(value: d),
        Provider<Store>.value(value: d.store),
        ChangeNotifierProvider<AccentController>.value(value: accent),
        ChangeNotifierProvider<ProfileRepo>.value(value: d.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: d.settings),
        ChangeNotifierProvider<ExerciseRepo>.value(value: d.exercises),
        ChangeNotifierProvider<RoutineRepo>.value(value: d.routines),
        ChangeNotifierProvider<ProgramRepo>.value(value: d.programs),
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<NutritionRepo>.value(value: d.nutrition),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
        ChangeNotifierProvider<CoachRepo>.value(value: d.coach),
      ],
      child: Consumer<AccentController>(
        builder: (context, a, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: a.theme,
          routerConfig: router,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}

/// Données vierges avec un profil (pas de séance, pas de mesure).
Future<AppData> donnees(WidgetTester t, {String prenom = 'Tristan', UnitePoids unite = UnitePoids.kg, double? poidsKg = 76.7}) async {
  PrefsRepo.reset();
  final data = AppData(Store.memory());
  await t.runAsync(() async {
    await data.loadAll();
    await data.profile.save(UserProfile(
      id: 'moi',
      prenom: prenom,
      objectif: Objectif.prendreDuMuscle,
      joursParSemaine: 5,
      poidsKg: poidsKg,
      tailleCm: 181,
      unitePoids: unite,
      creeLe: DateTime(2026, 3, 12),
    ));
  });
  return data;
}

/// Monte l'appli du banc sur [depart]. Rend le routeur.
Future<GoRouter> monter(WidgetTester t, AppData data, String depart, {AccentController? accent}) async {
  final router = routeur(depart);
  addTearDown(router.dispose);
  await t.pumpWidget(RepaintBoundary(key: cleBanc, child: Banc(data: data, router: router, accent: accent ?? AccentController())));
  await attendre(t);
  return router;
}
