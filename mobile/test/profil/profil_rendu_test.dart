import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/profil/data/prefs.dart';
import 'package:aesthetic/features/profil/mensurations/mensurations_page.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'jeu_maquette.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _k = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1.8);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/profil/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _polices(WidgetTester t) => t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _font('Figtree', ['Figtree-Regular.ttf', 'Figtree-Medium.ttf', 'Figtree-SemiBold.ttf', 'Figtree-Bold.ttf', 'Figtree-ExtraBold.ttf']);
      final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await l.load();
      }
    });

/// Routeur du banc : l'onglet Profil dans une coquille avec la barre du
/// bas, les sous-pages en plein écran, et des pages vides pour les autres
/// modules.
GoRouter _routeur(String depart) => GoRouter(
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
        for (final chemin in ['/bienvenue/modifier', '/progres/records', '/progres/calendrier', '/import'])
          GoRoute(path: chemin, builder: (c, s) => Scaffold(body: Text('autre module $chemin'))),
      ],
    );

class _Banc extends StatelessWidget {
  const _Banc({required this.data, required this.router, required this.accent});
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

Future<AppData> _donnees(WidgetTester t, {bool maquette = true}) async {
  PrefsRepo.reset();
  final data = AppData(Store.memory(), demo: true);
  await t.runAsync(() async {
    await data.loadAll();
    await DemoData.seed(data);
    if (maquette) {
      await JeuMaquette.poser(data.health);
      final p = data.profile.profile!;
      await data.profile.save(UserProfile(
        id: p.id,
        prenom: 'Tristan',
        objectif: Objectif.prendreDuMuscle,
        joursParSemaine: 5,
        poidsKg: 76.7,
        tailleCm: p.tailleCm,
        creeLe: DateTime(2026, 3, 12),
      ));
      await data.settings.update((s) => s.copyWith(reposParDefautSec: 120));
    }
  });
  return data;
}

void _ecran(WidgetTester t, {double largeur = 378, double hauteur = 803}) {
  // L'écran de la maquette : 302 sur 642, à l'échelle 1,25 ; l'encoche
  // tient la place de la barre d'état.
  t.view.physicalSize = Size(largeur, hauteur);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 25);
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('rendu des écrans 66 à 73 sur le jeu de la maquette', (t) async {
    await _polices(t);
    _ecran(t);
    final data = await _donnees(t);
    final router = _routeur('/profil');
    addTearDown(router.dispose);
    await t.pumpWidget(RepaintBoundary(key: _k, child: _Banc(data: data, router: router, accent: AccentController())));
    await t.runAsync(() => precacheImage(const AssetImage('assets/body/pack/face_base.webp'), t.element(find.byType(Scaffold).first)));
    await _attendre(t);

    final pages = <String, String>{
      '66-profil': '/profil',
      '67-mensurations': ProfilPaths.mensurations,
      '68-une-mesure': ProfilPaths.zone(ZoneMesure.biceps),
      '69-modifier': ProfilPaths.saisie(id: 'm7'),
      '69-nouvelle': ProfilPaths.saisie(),
      '70-historique': ProfilPaths.historique,
      '71-photos': ProfilPaths.photos,
      '72-comparer': ProfilPaths.comparer(vue: PhotoVue.face),
      '73-reglages': '/reglages',
    };
    for (final e in pages.entries) {
      router.go(e.value);
      await _attendre(t);
      expect(t.takeException(), isNull, reason: e.key);
      await t.runAsync(() => _shot(t, e.key));
    }

    // Les traits arrivent sur le corps : chaque point visé est dans le
    // cadre de l'image, du bon côté.
    router.go(ProfilPaths.mensurations);
    await _attendre(t);
    final largeur = t.getSize(find.byType(CorpsMesures)).width;
    final corps = CorpsMesures.cadreCorps(largeur);
    for (final z in ZoneMesure.values) {
      final a = CorpsMesures.ancre(z, largeur);
      expect(corps.contains(a), isTrue, reason: z.name);
      expect(a.dx < corps.center.dx, z.aGauche, reason: z.name);
    }
    expect(find.text('Touche une mesure pour voir son évolution'), findsOneWidget);
    expect(find.text('Saisir mes mesures'), findsOneWidget);
    // La taille n'a pas bougé : aucun écart affiché, ni « 0 » ni « = ».
    expect(find.text('+0'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('='), findsNothing);
    expect(find.text('+1,5'), findsOneWidget);

    // Toucher une mesure ouvre son détail ; le crayon rouvre la saisie.
    await t.tap(find.text('Biceps'));
    await _attendre(t);
    expect(find.text('Bras contracté'), findsOneWidget);
    expect(find.text('+1,5 cm'), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp('Modifier la mesure du 14 septembre')));
    await _attendre(t);
    expect(find.text('Modifier la saisie'), findsOneWidget);
    expect(find.text('Supprimer cette saisie'), findsOneWidget);

    // « + » sur le biceps : un demi-centimètre de plus, puis Enregistrer.
    await t.tap(find.bySemanticsLabel('Augmenter Biceps'));
    await t.pump();
    await t.tap(find.text('Enregistrer'));
    await _attendre(t);
    final m7 = data.health.measurements.firstWhere((m) => m.id == 'm7');
    expect(Mensurations.valeur(m7, ZoneMesure.biceps), 38.0);
    expect(m7.poidsKg, 76.2);
    expect(data.health.measurements.length, 9);
  });

  testWidgets('supprimer une saisie depuis l\'historique', (t) async {
    await _polices(t);
    _ecran(t);
    final data = await _donnees(t);
    final router = _routeur(ProfilPaths.historique);
    addTearDown(router.dispose);
    await t.pumpWidget(RepaintBoundary(key: _k, child: _Banc(data: data, router: router, accent: AccentController())));
    await _attendre(t);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('14 jours'), findsOneWidget);
    // La plus récente en haut.
    final haut = t.getTopLeft(find.text('28 septembre 2026')).dy;
    expect(haut < t.getTopLeft(find.text('14 septembre 2026')).dy, isTrue);

    await t.tap(find.text('17 août 2026'));
    await _attendre(t);
    await t.tap(find.text('Supprimer cette saisie'));
    await _attendre(t);
    await t.runAsync(() => _shot(t, '69-supprimer'));
    await t.tap(find.text('Supprimer'));
    await _attendre(t);
    expect(data.health.measurements.length, 8);
    expect(data.health.measurements.any((m) => m.id == 'm5'), isFalse);
  });

  testWidgets('écrans vides et données de la démo, téléphone et écran large', (t) async {
    await _polices(t);
    for (final (largeur, hauteur, nom) in [(378.0, 803.0, 'demo'), (900.0, 1100.0, 'large')]) {
      _ecran(t, largeur: largeur, hauteur: hauteur);
      final data = await _donnees(t, maquette: false);
      final router = _routeur('/profil');
      await t.pumpWidget(RepaintBoundary(key: _k, child: _Banc(data: data, router: router, accent: AccentController())));
      await t.runAsync(() => precacheImage(const AssetImage('assets/body/pack/face_base.webp'), t.element(find.byType(Scaffold).first)));
      await _attendre(t);
      final pages = <String, String>{
        'profil': '/profil',
        'mensurations': ProfilPaths.mensurations,
        'mesure': ProfilPaths.zone(ZoneMesure.poitrine),
        'saisie': ProfilPaths.saisie(),
        'historique': ProfilPaths.historique,
        'photos': ProfilPaths.photos,
        'comparer': ProfilPaths.comparer(),
        'reglages': '/reglages',
        'reglages-unites': '/reglages/unites',
        'reglages-entrainement': '/reglages/entrainement',
        'reglages-disques': '/reglages/entrainement/disques',
        'reglages-notifications': '/reglages/notifications',
        'reglages-donnees': '/reglages/donnees',
        'reglages-a-propos': '/reglages/a-propos',
      };
      for (final e in pages.entries) {
        router.go(e.value);
        await _attendre(t);
        expect(t.takeException(), isNull, reason: '$nom ${e.key}');
        await t.runAsync(() => _shot(t, '$nom-${e.key}'));
      }

      // Tout vide : ni mesure, ni photo, ni séance.
      await t.runAsync(() async {
        for (final m in [...data.health.measurements]) {
          await data.health.deleteMeasurement(m.id);
        }
        for (final s in [...data.sessions.sessions]) {
          await data.sessions.delete(s.id);
        }
      });
      for (final e in pages.entries.take(7)) {
        router.go(e.value);
        await _attendre(t);
        expect(t.takeException(), isNull, reason: '$nom vide ${e.key}');
        await t.runAsync(() => _shot(t, '$nom-vide-${e.key}'));
      }
      router.dispose();
      await t.pumpWidget(const SizedBox());
    }
  });
}
