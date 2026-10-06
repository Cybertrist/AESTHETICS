import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/progres_paths.dart';
import 'package:aesthetic/features/progres/routes.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> _police(String famille) async {
  final fichiers = Directory('assets/fonts').listSync().whereType<File>().where((f) {
    final n = f.uri.pathSegments.last;
    return n.startsWith('$famille-') && n.endsWith('.ttf');
  });
  final l = FontLoader(famille);
  for (final f in fichiers) {
    l.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _cadre = GlobalKey();

Future<void> _capture(WidgetTester t, String nom) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_cadre));
  final img = await ro.toImage(pixelRatio: 1);
  final octets = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/progres/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
}

/// Laisse les images du personnage et des exercices se décoder (hors de la
/// fausse horloge), puis repeint.
Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 7; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Rendu hors écran des écrans de Progrès avec les données de la démo :
/// images dans build/rendus/progres/, à comparer aux captures de la maquette
/// (380 de large = 1,25 fois la maquette).
void main() {
  late AppData data;
  late GoRouter router;

  Future<void> preparer(WidgetTester t, {double hauteur = 805}) async {
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await _police('Figtree');
      await _police('Montserrat');
      final icones = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icones.existsSync()) {
        final l = FontLoader('MaterialIcons')..addFont(icones.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await l.load();
      }
    });
    t.view.physicalSize = Size(380, hauteur);
    t.view.devicePixelRatio = 1;
    // La barre d'état du téléphone (l'encoche de la maquette).
    t.view.padding = const FakeViewPadding(top: 25);
    addTearDown(t.view.reset);
    data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await Future.wait([
        data.profile.load(),
        data.settings.load(),
        data.exercises.load(),
        data.routines.load(),
        data.programs.load(),
        data.sessions.load(),
        data.health.load(),
      ]);
      await DemoData.seed(data);
      // Le personnage se charge ici, hors de la fausse horloge : un
      // chargement lancé pendant un test resterait en attente dans le cache.
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          await BodyImageRepository.load(v, f);
        }
      }
    });
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: ProgresPaths.racine,
      routes: [
        ...progresRoutes(),
        // Les écrans des autres modules, ouverts depuis Progrès.
        for (final chemin in ['/profil/mensurations', '/profil/photos', '/entrainer', '/entrainer/muscles', '/seance/historique/:id'])
          GoRoute(path: chemin, builder: (context, state) => Scaffold(body: Center(child: Text('autre module ${state.uri}')))),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(RepaintBoundary(key: _cadre, child: _Banc(data: data, router: router)));
    await _attendre(t);
  }

  Future<void> ouvrir(WidgetTester t, String chemin, String nom) async {
    router.go(chemin);
    await _attendre(t);
    expect(t.takeException(), isNull, reason: nom);
    await t.runAsync(() => _capture(t, nom));
  }

  testWidgets('Progrès, la page entière', (t) async {
    await preparer(t, hauteur: 2700);
    expect(find.text('Progrès'), findsOneWidget);
    // Vue Semaine : le volume jour par jour, pas de résumé mensuel.
    expect(find.text('Volume par jour'), findsOneWidget);
    expect(find.text('DEPUIS LE DÉBUT'), findsOneWidget);
    expect(find.text('Ton corps'), findsOneWidget);
    expect(find.text('Tes repères'), findsOneWidget);
    expect(find.byType(GrilleMois), findsNothing);
    expect(find.byType(CarteResumeMensuel), findsNothing);
    // Ni rang, ni XP, ni classement.
    for (final mot in ['XP', 'Rang', 'Classement', 'Niveau']) {
      expect(find.textContaining(mot), findsNothing, reason: mot);
    }
    await t.runAsync(() => _capture(t, '41-progres'));

    // Vue Mois : les semaines du mois et le calendrier à flammes.
    await t.tap(find.text('Mois'));
    await _attendre(t);
    expect(find.text('Volume par semaine'), findsOneWidget);
    expect(find.byType(GrilleMois), findsOneWidget);
    expect(find.byType(ColonneSerie), findsOneWidget);
    await t.runAsync(() => _capture(t, '41-progres-mois'));
    // Le mois d'avant, fini : son résumé apparaît.
    await t.tap(find.bySemanticsLabel('Période précédente'));
    await _attendre(t);
    expect(find.text('mois terminé'), findsOneWidget);
    expect(find.byType(CarteResumeMensuel), findsOneWidget);
    await t.runAsync(() => _capture(t, '41-progres-mois-precedent'));
    // Vue Année : les douze mois.
    await t.tap(find.text('Année'));
    await _attendre(t);
    expect(find.text('Volume par mois'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Janvier ')), findsOneWidget);
    await t.runAsync(() => _capture(t, '41-progres-annee'));
    expect(t.takeException(), isNull);
  });

  testWidgets('Progrès : les flèches remontent aux mois précédents', (t) async {
    await preparer(t, hauteur: 2700);
    final now = DateTime.now();
    await t.tap(find.text('Mois'));
    await _attendre(t);
    expect(find.text(Calculs.moisAnnee(now)), findsOneWidget);
    // Le mois en cours est le dernier : pas de flèche vers le futur.
    expect(t.widget<InkResponse>(find.descendant(of: find.bySemanticsLabel('Période suivante'), matching: find.byType(InkResponse))).onTap, isNull);
    await t.tap(find.bySemanticsLabel('Période précédente'));
    await _attendre(t);
    final avant = DateTime(now.year, now.month - 1);
    expect(find.text(Calculs.moisAnnee(avant)), findsOneWidget);
    // « Détail » ouvre le calendrier sur le mois affiché.
    await t.tap(find.text('Détail'));
    await _attendre(t);
    expect(find.text('Calendrier d\'entraînement'), findsOneWidget);
    expect(find.text(Calculs.moisAnnee(avant)), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('Progrès : chaque tuile mène à son écran', (t) async {
    await preparer(t, hauteur: 2700);
    Future<void> toucher(Finder f, String attendu) async {
      await t.tap(f);
      await _attendre(t);
      expect(find.textContaining(attendu), findsWidgets, reason: attendu);
      router.go(ProgresPaths.racine);
      await _attendre(t);
    }

    await toucher(find.text('Récupération'), 'Les muscles prêts');
    await toucher(find.text('Mensurations'), '/profil/mensurations');
    await toucher(find.text('Photos'), '/profil/photos');
    // Le résumé façon story : celui d'un mois fini.
    await t.tap(find.text('Mois'));
    await _attendre(t);
    await t.tap(find.bySemanticsLabel('Période précédente'));
    await _attendre(t);
    await t.ensureVisible(find.byType(CarteResumeMensuel));
    await _attendre(t);
    await t.tap(find.byType(CarteResumeMensuel));
    await _attendre(t);
    expect(find.byType(BilanStoryPage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('semaine, mois, calendrier, récupération', (t) async {
    await preparer(t);
    final now = DateTime.now();
    final moisPasse = DateTime(now.year, now.month - 1);
    await ouvrir(t, ProgresPaths.semaine, '42-bilan-semaine');
    expect(find.text('Résumé d\'entraînement'), findsOneWidget);
    // La semaine passée, mieux remplie un début de semaine.
    final j = now.subtract(const Duration(days: 7));
    await ouvrir(t, '${ProgresPaths.semaine}?jour=${j.toIso8601String().substring(0, 10)}', '42-bilan-semaine-passee');

    await ouvrir(t, ProgresPaths.mois(), '43-stats-mois');
    await ouvrir(t, ProgresPaths.mois(moisPasse), '43-stats-mois-passe');
    expect(find.text('RÉPARTITION'), findsOneWidget);
    expect(find.text(Calculs.moisAnnee(moisPasse)), findsOneWidget);

    await ouvrir(t, ProgresPaths.calendrier(), '44-calendrier');
    await ouvrir(t, ProgresPaths.calendrierDuMois(moisPasse), '44-calendrier-mois-passe');
    expect(find.text('semaines de série'), findsOneWidget);
    // Toucher un jour avec séance montre son détail.
    final seance = data.sessions.sessions.lastWhere((s) => s.debut.month == moisPasse.month && s.debut.year == moisPasse.year);
    await t.tap(find.bySemanticsLabel(RegExp('^${seance.debut.day}, Musculation\$')).first);
    await _attendre(t);
    expect(find.text(Fmt.jour(seance.debut).toUpperCase()), findsOneWidget);
    expect(find.text(seance.nom), findsWidgets);
    await t.runAsync(() => _capture(t, '44-calendrier-jour-touche'));

    await ouvrir(t, ProgresPaths.recuperation, '45-recuperation');
    expect(find.text('Tout afficher'), findsOneWidget);
    expect(find.text('CONSEILLÉ AUJOURD\'HUI'), findsOneWidget);
    await t.tap(find.text('Pectoraux'));
    await _attendre(t);
    expect(find.textContaining('/entrainer/muscles?muscle=pectoraux'), findsOneWidget);
  });

  testWidgets('records : les tuiles de muscles filtrent la liste', (t) async {
    await preparer(t);
    await ouvrir(t, '/progres/records', 'records');
    // Les tuiles du personnage remplacent les puces de texte.
    expect(find.text('Tous'), findsNothing);
    expect(find.text('Pecs'), findsOneWidget);
    final tous = t.widgetList(find.textContaining('résultat')).map((w) => (w as Text).data!).single;
    await t.tap(find.text('Dos'));
    await _attendre(t);
    await t.runAsync(() => _capture(t, 'records-dos'));
    final dos = t.widgetList(find.textContaining('résultat')).map((w) => (w as Text).data!).single;
    expect(dos, isNot(tous));
    // Un second appui retire le filtre.
    await t.tap(find.text('Dos'));
    await _attendre(t);
    expect(t.widgetList(find.textContaining('résultat')).map((w) => (w as Text).data!).single, tous);
    expect(t.takeException(), isNull);
  });

  testWidgets('tous les muscles et son filtre', (t) async {
    await preparer(t, hauteur: 1400);
    await ouvrir(t, ProgresPaths.tousLesMuscles, '46-tous-les-muscles');
    expect(find.text('Du moins au plus récupéré'), findsOneWidget);
    expect(find.text('Épaules arrière'), findsOneWidget);
    await t.tap(find.textContaining('Prêts ·'));
    await _attendre(t);
    await t.runAsync(() => _capture(t, '46-tous-les-muscles-prets'));
    expect(t.takeException(), isNull);
  });

  testWidgets('bilan du mois, les dix pages', (t) async {
    await preparer(t);
    final now = DateTime.now();
    final mois = DateTime(now.year, now.month - 1);
    final volume = Calculs.volumeDe(Calculs.entre(data.sessions.sessions, mois, DateTime(now.year, now.month)));
    final eq = equivalentPour(volume, graine: mois.year * 12 + mois.month, mois: true);
    router.push(ProgresPaths.bilan(mois));
    await _attendre(t);
    final ctx = t.element(find.byType(BilanStoryPage));
    await t.runAsync(() => precacheImage(AssetImage(eq.asset), ctx));
    final noms = ['47-ouverture', '48-seances', '49-regularite', '50-volume', '51-equivalent', '61-serie', '62-muscles', '63-records', '64-favoris', '65-resume'];
    for (final (i, nom) in noms.indexed) {
      await _attendre(t);
      expect(t.takeException(), isNull, reason: nom);
      expect(find.bySemanticsLabel('Page ${i + 1} sur 10'), findsOneWidget);
      await t.runAsync(() => _capture(t, nom));
      // Toucher à droite passe à la page suivante.
      if (i < noms.length - 1) {
        await t.tapAt(const Offset(300, 420));
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    // À gauche : retour d'une page.
    await t.tapAt(const Offset(40, 420));
    await _attendre(t);
    expect(find.bySemanticsLabel('Page 9 sur 10'), findsOneWidget);
    await t.tapAt(const Offset(300, 420));
    await _attendre(t);
    expect(find.bySemanticsLabel('Page 10 sur 10'), findsOneWidget);
    // Sur la dernière page, toucher à droite ferme le bilan (défaut 23).
    await t.tapAt(const Offset(300, 420));
    await _attendre(t);
    expect(find.byType(BilanStoryPage), findsNothing);
    expect(find.text('Progrès'), findsOneWidget);
    // La croix ferme aussi.
    router.push(ProgresPaths.bilan(mois));
    await _attendre(t);
    await t.tap(find.byTooltip('Fermer le bilan'));
    await _attendre(t);
    expect(find.byType(BilanStoryPage), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('écran large et petit écran : rien ne déborde', (t) async {
    await preparer(t);
    final now = DateTime.now();
    final mois = DateTime(now.year, now.month - 1);
    final chemins = [
      ProgresPaths.racine,
      ProgresPaths.semaine,
      ProgresPaths.mois(mois),
      ProgresPaths.calendrierDuMois(mois),
      ProgresPaths.recuperation,
      ProgresPaths.tousLesMuscles,
    ];
    // Fold ouvert, puis un petit téléphone (320 sur 568).
    for (final (taille, nom) in [(const Size(900, 800), 'large'), (const Size(320, 568), 'petit')]) {
      t.view.physicalSize = taille;
      for (final chemin in chemins) {
        router.go(chemin);
        await _attendre(t);
        expect(t.takeException(), isNull, reason: '$nom $chemin');
      }
      router.go(ProgresPaths.racine);
      await _attendre(t);
      await t.runAsync(() => _capture(t, '41-progres-$nom'));
      router.push(ProgresPaths.bilan(mois));
      await _attendre(t);
      for (var i = 0; i < 10; i++) {
        expect(t.takeException(), isNull, reason: '$nom, bilan page ${i + 1}');
        if (i == 3 || i == 8) await t.runAsync(() => _capture(t, 'bilan-$nom-${i + 1}'));
        await t.tapAt(Offset(taille.width - 40, taille.height / 2));
        await _attendre(t);
      }
      // Le dixième appui, sur la dernière page, a fermé le bilan.
      expect(find.byType(BilanStoryPage), findsNothing, reason: nom);
    }
  });

  testWidgets('sans aucune séance, rien ne casse', (t) async {
    await preparer(t, hauteur: 2700);
    await t.runAsync(() => data.sessions.clear());
    await _attendre(t);
    expect(find.text('Commencer une séance'), findsOneWidget);
    expect(find.byType(CarteResumeMensuel), findsNothing);
    await t.runAsync(() => _capture(t, '41-progres-vide'));
    for (final chemin in [ProgresPaths.semaine, ProgresPaths.mois(), ProgresPaths.calendrier(), ProgresPaths.recuperation, ProgresPaths.tousLesMuscles]) {
      router.go(chemin);
      await _attendre(t);
      expect(t.takeException(), isNull, reason: chemin);
    }
    router.go(ProgresPaths.racine);
    await _attendre(t);
    router.push(ProgresPaths.bilan());
    await _attendre(t);
    for (var i = 0; i < 10; i++) {
      expect(t.takeException(), isNull, reason: 'bilan vide, page ${i + 1}');
      await t.tapAt(const Offset(300, 420));
      await _attendre(t);
    }
  });
}

/// Banc minimal : les dépôts, le thème et les routes du module.
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
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
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
