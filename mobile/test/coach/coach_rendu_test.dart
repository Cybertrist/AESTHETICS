import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/coach/data/claude_client.dart';
import 'package:aesthetic/features/coach/logic/coach_engine.dart';
import 'package:aesthetic/features/coach/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'coach_logic_test.dart' show fauxService, sse;

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
  final img = await ro.toImage(pixelRatio: 1);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/coach/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

const _reponse = 'Tes **pectoraux** récupèrent encore (60 %). Aujourd\'hui, place aux jambes :\n\n'
    '- Squat barre, 4 séries de 6 à 8\n- Soulevé de terre roumain, 3 séries de 8\n\n'
    'Je te propose de l\'ajouter ci-dessous.\n\n'
    '```action\n{"type": "routine", "nom": "Jambes 45 min", "exercices": [{"nom": "Squat barre", "series": 4, "reps": 6, "repsMax": 8, "poids": 90, "repos": 150}, '
    '{"nom": "Soulevé de terre roumain", "series": 3, "reps": 8, "poids": 80}, {"nom": "Leg curl assis", "series": 3, "reps": 12}]}\n```\n'
    '```action\n{"type": "repas", "nom": "Skyr et flocons d\'avoine", "repas": "collation", "quantite": 250, "kcal": 320, "proteines": 28, "glucides": 40, "lipides": 5}\n```';

/// Rendu hors écran des pages du coach avec la démo : build/rendus/coach/.
/// Lancer avec RENDU_COACH=1 pour écrire les captures.
void main() {
  final ecrire = Platform.environment['RENDU_COACH'] == '1';
  // Pages avec le personnage (refait en parallèle) : RENDU_CORPS=1 pour les inclure.
  final corps = Platform.environment['RENDU_CORPS'] == '1';

  for (final (largeur, nom) in [(380.0, 'ferme'), (900.0, 'ouvert')]) {
    for (final enLigne in [false, true]) {
      testWidgets('pages du coach ($nom, ${enLigne ? 'en ligne' : 'hors ligne'})', (t) async {
        await t.runAsync(() async {
          await initializeDateFormatting('fr_FR');
          // Polices présentes, quelle que soit celle du thème du moment.
          for (final famille in ['Figtree', 'Roboto', 'Inter']) {
            final fichiers = Directory('assets/fonts').listSync().map((f) => f.uri.pathSegments.last).where((n) => n.startsWith('$famille-') && n.endsWith('.ttf')).toList();
            if (fichiers.isNotEmpty) await _font(famille, fichiers);
          }
          final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
          if (icons.existsSync()) {
            final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
            await l.load();
          }
        });
        t.view.physicalSize = Size(largeur, 1900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final data = AppData(Store.memory(), demo: true);
        await t.runAsync(() async {
          await data.loadAll();
          await DemoData.seed(data);
          if (enLigne) await data.settings.update((s) => s.copyWith(coachApiKey: 'sk-ant-demo-1234567890'));
        });
        CoachEngine.clientFactory = (k) => ClaudeClient(apiKey: k, client: fauxService(sse([_reponse.substring(0, 60), _reponse.substring(60)])));
        addTearDown(() => CoachEngine.clientFactory = null);

        final router = GoRouter(navigatorKey: rootNavigatorKey, initialLocation: '/coach', routes: coachRoutes());
        addTearDown(router.dispose);
        await t.pumpWidget(RepaintBoundary(key: _k, child: _Banc(data: data, router: router)));
        await _attendre(t);
        final suffixe = '$nom-${enLigne ? 'enligne' : 'horsligne'}';

        final pages = {
          'accueil': '/coach',
          'historique': '/coach/historique',
          // Le personnage (BodyMap) est refait en parallèle : ses pages attendent que ses assets soient là.
          if (corps) 'bilan': '/coach/bilan',
          if (corps) 'conseils': '/coach/conseils',
          'reglages': '/coach/reglages',
          'cle': '/coach/reglages/cle',
          'modele': '/coach/reglages/modele',
          'donnees': '/coach/reglages/donnees',
          'contexte': '/coach/reglages/contexte',
          'nouvelle': '/coach/discussion/nouvelle',
          'conversation': '/coach/discussion/${data.coach.conversations.first.id}',
        };
        for (final e in pages.entries) {
          router.go(e.value);
          await _attendre(t);
          expect(t.takeException(), isNull, reason: e.key);
          if (ecrire) await t.runAsync(() => _shot(t, '$suffixe-${e.key}'));
        }

        // Une question posée : réponse (en flux ou hors ligne) et actions.
        router.go('/coach/discussion/nouvelle?q=${Uri.encodeQueryComponent('Que travailler aujourd\'hui ?')}');
        await _attendre(t);
        await _attendre(t);
        expect(t.takeException(), isNull);
        if (enLigne) {
          expect(find.text('Ajouter la routine'), findsOneWidget);
          expect(find.text('Ajouter au journal'), findsOneWidget);
        } else {
          expect(find.textContaining('mode hors ligne', findRichText: true), findsWidgets);
        }
        if (ecrire) await t.runAsync(() => _shot(t, '$suffixe-reponse'));

        if (enLigne) {
          await t.tap(find.text('Ajouter la routine'));
          await _attendre(t);
          expect(data.routines.routines.any((r) => r.nom == 'Jambes 45 min'), isTrue);
          expect(find.text('Routine ajoutée'), findsOneWidget);
          if (ecrire) await t.runAsync(() => _shot(t, '$suffixe-action'));
        }
        await t.pumpWidget(const SizedBox());
        await _attendre(t);
      });
    }
  }
}

/// Banc minimal : les dépôts, le thème et les seules routes du module.
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
        ChangeNotifierProvider<ProgramRepo>.value(value: d.programs),
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<NutritionRepo>.value(value: d.nutrition),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
        ChangeNotifierProvider<CoachRepo>.value(value: d.coach),
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
