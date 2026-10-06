import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

/// Banc des tests de rendu du module séance : polices réelles, données de
/// démonstration, routeur du module, captures dans `build/rendus/seance/`.

/// Écran de la maquette (304 × 644) à l'échelle du téléphone (× 1,25).
const tailleMaquette = Size(380, 805);

final cleCapture = GlobalKey();

Future<void> _police(String famille, List<String> fichiers) async {
  final l = FontLoader(famille);
  for (final f in fichiers) {
    final file = File('assets/fonts/$f');
    if (file.existsSync()) l.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

/// À appeler dans `t.runAsync`.
Future<void> chargerPolices() async {
  await initializeDateFormatting('fr_FR');
  await _police('Figtree', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'Figtree-$w.ttf']);
  await _police('Montserrat', [for (final w in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'Montserrat-$w.ttf']);
  final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await l.load();
  }
}

/// Données de la démo, en mémoire. À appeler dans `t.runAsync`.
Future<AppData> donneesDemo({bool demo = true}) async {
  final d = AppData(Store.memory(), demo: demo);
  await Future.wait([
    d.profile.load(),
    d.settings.load(),
    d.exercises.load(),
    d.routines.load(),
    d.programs.load(),
    d.sessions.load(),
    d.health.load(),
    d.coach.load(),
  ]);
  if (demo) await DemoData.seed(d);
  return d;
}

Future<void> capture(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cleCapture));
    final img = await ro.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/seance/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Laisse passer les chargements (images, fichiers) et les animations.
Future<void> attendre(WidgetTester t, {int tours = 4}) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Décode des images d'assets hors de la fausse horloge (objets 3D).
Future<void> precharger(WidgetTester t, Iterable<String> assets) async {
  final ctx = t.element(find.byType(Navigator).first);
  await t.runAsync(() async {
    for (final a in assets) {
      await precacheImage(AssetImage(a), ctx);
    }
  });
}

/// L'appli réduite au module séance, avec des pages témoins pour le reste.
class AppBanc extends StatefulWidget {
  const AppBanc({super.key, required this.data, this.depart = '/seance', this.accueil});

  final AppData data;
  final String depart;

  /// Page servie sur « / » (par défaut : la barre de séance réduite seule).
  final Widget? accueil;

  @override
  State<AppBanc> createState() => _AppBancState();
}

class _AppBancState extends State<AppBanc> {
  final _accent = AccentController();
  late final router = GoRouter(initialLocation: widget.depart, routes: [
    ...seanceRoutes(),
    GoRoute(
      path: '/',
      builder: (_, _) => widget.accueil ?? const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SeanceMiniBarre())),
    ),
    for (final p in ['/entrainer', '/reglages/entrainement/disques', '/reglages', '/exercices/:id', '/entrainer/exercices/:id'])
      GoRoute(path: p, builder: (_, s) => Scaffold(body: Center(child: Text('témoin ${s.uri}')))),
  ]);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MultiProvider(
      providers: [
        Provider<AppData>.value(value: d),
        Provider<Store>.value(value: d.store),
        ChangeNotifierProvider<ProfileRepo>.value(value: d.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: d.settings),
        ChangeNotifierProvider<ExerciseRepo>.value(value: d.exercises),
        ChangeNotifierProvider<RoutineRepo>.value(value: d.routines),
        ChangeNotifierProvider<ProgramRepo>.value(value: d.programs),
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
      ],
      child: MaterialApp.router(
        theme: _accent.theme,
        debugShowCheckedModeBanner: false,
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

/// Monte l'appli du banc à la taille voulue et rend ses données.
Future<AppData> monter(WidgetTester t, {String depart = '/seance', Size taille = tailleMaquette, AppData? data, Widget? accueil}) async {
  await t.runAsync(chargerPolices);
  final d = data ?? (await t.runAsync(donneesDemo))!;
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(ReposMinuteur.instance.reinitialiser);
  await t.pumpWidget(RepaintBoundary(key: cleCapture, child: AppBanc(data: d, depart: depart, accueil: accueil)));
  await attendre(t);
  return d;
}

GoRouter routeurDe(WidgetTester t) => GoRouter.of(t.element(find.byType(Navigator).last));

/// Démonte proprement (minuteurs, chrono) en fin de test.
Future<void> demonter(WidgetTester t) async {
  ReposMinuteur.instance.reinitialiser();
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

/// Le bouton « Plus » est à la fin de la page de la séance : on fait défiler
/// jusqu'à lui avant de le toucher.
Future<void> toucherPlus(WidgetTester t) async {
  await t.ensureVisible(find.text('Plus'));
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text('Plus'));
}
