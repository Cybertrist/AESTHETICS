// Banc de rendu partagé par les tests du module Aujourd'hui.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/aujourdhui/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

final _k = GlobalKey();

Future<void> polices() async {
  await initializeDateFormatting('fr_FR');
  Future<void> famille(String nom, List<String> fichiers) async {
    final l = FontLoader(nom);
    for (final f in fichiers) {
      final file = File('assets/fonts/$f');
      if (file.existsSync()) l.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await l.load();
  }

  await famille('Figtree', [for (final p in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'Figtree-$p.ttf']);
  await famille('Montserrat', [for (final p in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'Montserrat-$p.ttf']);
  final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await l.load();
  }
}

Future<void> _capture(WidgetTester t, String nom) async {
  if (Platform.environment['RENDUS'] == null) return;
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/aujourdhui/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<AppData> donnees({required bool demo}) async {
  final data = AppData(Store.memory(), demo: demo);
  await data.loadAll();
  if (demo) {
    await DemoData.seed(data);
  } else {
    await data.profile.save(UserProfile(id: 'u', prenom: 'Tristan', creeLe: DateTime.now(), poidsKg: 77, tailleCm: 181));
  }
  return data;
}

Future<void> parcours(WidgetTester t, AppData data, String prefixe, Size taille) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(RepaintBoundary(key: _k, child: _App(data: data)));
  await _attendre(t);
  expect(find.text('Cette semaine'), findsOneWidget);
  expect(find.text('Dernières séances'), findsOneWidget);
  expect(t.takeException(), isNull);
  await t.runAsync(() => _capture(t, '$prefixe-accueil'));

  final router = GoRouter.of(t.element(find.byType(Scaffold).first));
  final pages = <String, String>{
    'seance-du-jour': AujourdhuiPaths.seanceDuJour,
    'recuperation': AujourdhuiPaths.recuperation,
    'muscle': AujourdhuiPaths.muscle(Muscle.pectoraux),
    'nutrition': AujourdhuiPaths.nutrition,
    'sommeil': AujourdhuiPaths.sommeil,
    'pas': AujourdhuiPaths.pas,
    'poids': AujourdhuiPaths.poids,
    'semaine': AujourdhuiPaths.semaine,
    'records': AujourdhuiPaths.records,
  };
  if (data.sessions.sessions.isNotEmpty) pages['seance'] = AujourdhuiPaths.seanceDetail(data.sessions.sessions.first.id);
  // Le personnage touchable (BodyMap avec onTap, en chantier chez l'agent
  // PERSONNAGE) bloque le pompage en test : la page Récupération est vérifiée
  // à la main sur l'appareil.
  pages.remove('recuperation');
  for (final e in pages.entries) {
    router.go(e.value);
    await _attendre(t);
    await t.runAsync(() => _capture(t, '$prefixe-${e.key}'));
  }
  router.go('/');
  await _attendre(t);
}

/// Capture l'écran tel qu'il est (panneau ou dialogue ouvert compris).
Future<void> rendreCapture(WidgetTester t, String nom) => _capture(t, nom);

/// Rend seulement l'accueil, avec une horloge figée, et le capture.
/// [page] remplace l'accueil à l'horloge figée (horloge qui avance, par exemple).
Future<void> rendreAccueil(WidgetTester t, AppData data, String nom, Size taille, DateTime maintenant, {Widget? page}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(RepaintBoundary(key: _k, child: _App(key: UniqueKey(), data: data, maintenant: maintenant, page: page)));
  await _attendre(t);
  expect(t.takeException(), isNull);
  await t.runAsync(() => _capture(t, nom));
}

/// Appli réduite au module : les autres modules sont en chantier en parallèle.
class _App extends StatefulWidget {
  const _App({super.key, required this.data, this.maintenant, this.page});
  final AppData data;
  final Widget? page;

  /// Horloge figée de l'accueil.
  final DateTime? maintenant;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final _accent = AccentController();
  late final _router = GoRouter(routes: [
    if (widget.maintenant == null)
      ...aujourdhuiRoutes()
    else
      GoRoute(path: '/', builder: (_, _) => widget.page ?? AujourdhuiPage(maintenant: widget.maintenant)),
    for (final p in ['/seance', '/coach', '/entrainer', '/nutrition', '/progres', '/sante', '/profil'])
      GoRoute(path: p, builder: (_, _) => Scaffold(body: Center(child: Text(p)))),
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
        ChangeNotifierProvider<NutritionRepo>.value(value: d.nutrition),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
        ChangeNotifierProvider<CoachRepo>.value(value: d.coach),
      ],
      child: MaterialApp.router(
        theme: _accent.theme,
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
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


/// Branche le faux accès aux assets (à appeler dans setUpAll).
void preparerAssets() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (msg) async {
    final cle = Uri.decodeFull(utf8.decode(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes)));
    final f = File(cle);
    if (f.existsSync()) return ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer);
    if (cle == 'AssetManifest.bin') {
      // Manifeste minimal : les poses des exercices, pour que Image.asset les trouve.
      final poses = Directory('assets/exercises/poses');
      final noms = poses.existsSync() ? [for (final e in poses.listSync()) 'assets/exercises/poses/${e.uri.pathSegments.last}'] : <String>[];
      return const StandardMessageCodec().encodeMessage({
        for (final n in noms) n: [<String, Object>{'asset': n}],
      });
    }
    if (cle.endsWith('masques/manifeste.json')) {
      final vide = {for (final v in ['face', 'dos', 'Face', 'Dos']) for (final s in ['', '_buste', '_corps']) '$v$s': {'masques': []}};
      return ByteData.view(Uint8List.fromList(utf8.encode(jsonEncode(vide))).buffer);
    }
    return null;
  });
}
