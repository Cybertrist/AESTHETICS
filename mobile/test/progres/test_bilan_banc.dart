import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
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

/// Banc des tests du bilan du mois : des séances fabriquées à la main (pas
/// la démo), la page montée seule ou derrière le vrai routeur de Progrès.

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

final cadreBilan = GlobalKey();

/// Exercices du banc : des noms courts, un nom très long, un sans charge.
const exercicesBanc = [
  Exercise(id: 'dc', nom: 'Développé couché', musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.deltoidesAnterieurs, Muscle.triceps]),
  Exercise(id: 'squat', nom: 'Squat', musclesPrincipaux: [Muscle.quadriceps], musclesSecondaires: [Muscle.fessiers, Muscle.ischios]),
  Exercise(id: 'tirage', nom: 'Tirage vertical', musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
  Exercise(id: 'curl', nom: 'Curl barre', musclesPrincipaux: [Muscle.biceps]),
  Exercise(id: 'crunch', nom: 'Crunch', musclesPrincipaux: [Muscle.abdominaux]),
  Exercise(id: 'lat', nom: 'Élévations latérales', musclesPrincipaux: [Muscle.deltoidesLateraux], musclesSecondaires: [Muscle.trapezes]),
  Exercise(
    id: 'long',
    nom: 'Extension des triceps à la poulie haute avec la corde, coudes serrés, tempo lent',
    musclesPrincipaux: [Muscle.triceps],
  ),
  Exercise(id: 'tractions', nom: 'Tractions', musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
];

var _n = 0;

/// Une séance d'un seul exercice.
WorkoutSession seance(
  DateTime debut,
  String exo,
  List<(double, int)> series, {
  String nom = 'Séance',
  int minutes = 60,
  bool enCours = false,
}) {
  final id = 's${_n++}';
  return WorkoutSession(
    id: id,
    nom: nom,
    debut: debut,
    fin: enCours ? null : debut.add(Duration(minutes: minutes)),
    exercices: [
      SessionExercise(
        id: 'e$id',
        exerciseId: exo,
        series: [
          for (final (i, s) in series.indexed) WorkoutSet(id: '$id-$i', poids: s.$1 <= 0 ? null : s.$1, reps: s.$2, fait: true),
        ],
      ),
    ],
  );
}

class BancBilan {
  BancBilan(this.data);
  final AppData data;
  GoRouter? router;

  /// Textes coupés sans points de suspension (une ligne de trop, rognée).
  List<String> textesRognes(WidgetTester t) => [
        for (final e in find.descendant(of: find.byType(BilanStoryPage), matching: find.byType(RichText)).evaluate())
          if ((e.renderObject! as RenderParagraph).didExceedMaxLines && (e.widget as RichText).overflow != TextOverflow.ellipsis)
            (e.widget as RichText).text.toPlainText(),
      ];

  /// Textes qui sortent de l'écran, à gauche ou à droite.
  List<String> textesHorsEcran(WidgetTester t, {Set<String> sauf = const {}}) {
    final largeur = t.view.physicalSize.width / t.view.devicePixelRatio;
    final out = <String>[];
    for (final e in find.descendant(of: find.byType(BilanStoryPage), matching: find.byType(RichText)).evaluate()) {
      final texte = (e.widget as RichText).text.toPlainText();
      if (sauf.any(texte.contains)) continue;
      final ro = e.renderObject! as RenderBox;
      final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
      if (r.left < -0.5 || r.right > largeur + 0.5) out.add('$texte [${r.left.round()}..${r.right.round()}]');
    }
    return out;
  }
}

/// Laisse les images se décoder hors de la fausse horloge, puis repeint.
Future<void> poser(WidgetTester t, {int tours = 4}) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> capturer(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cadreBilan));
    final img = await ro.toImage(pixelRatio: 1);
    final octets = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/bilan/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

Future<BancBilan> _donnees(WidgetTester t, List<WorkoutSession> sessions, Size taille, {double haut = 25, List<Exercise> exercices = const []}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(top: haut);
  addTearDown(t.view.reset);
  final data = AppData(Store.memory());
  await t.runAsync(() async {
    await initializeDateFormatting('fr_FR');
    await _police('Figtree');
    await _police('Montserrat');
    await data.exercises.load();
    await data.sessions.load();
    for (final e in [...exercicesBanc, ...exercices]) {
      await data.exercises.addCustom(e);
    }
    await data.sessions.addAll(sessions);
    for (final v in BodyView.values) {
      for (final f in BodyFraming.values) {
        await BodyImageRepository.load(v, f);
      }
    }
  });
  return BancBilan(data);
}

Widget _appli(AppData d, {Widget? home, GoRouter? router, double echelleTexte = 1}) {
  final accent = AccentController();
  Widget enveloppe(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelleTexte)),
        child: child!,
      );
  const locales = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  return RepaintBoundary(
    key: cadreBilan,
    child: MultiProvider(
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
      child: router == null
          ? MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: accent.theme,
              builder: enveloppe,
              home: home,
              locale: const Locale('fr', 'FR'),
              supportedLocales: const [Locale('fr', 'FR')],
              localizationsDelegates: locales,
            )
          : MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: accent.theme,
              builder: enveloppe,
              routerConfig: router,
              locale: const Locale('fr', 'FR'),
              supportedLocales: const [Locale('fr', 'FR')],
              localizationsDelegates: locales,
            ),
    ),
  );
}

/// Monte une page du bilan seule.
Future<BancBilan> monterBilan(
  WidgetTester t, {
  required List<WorkoutSession> sessions,
  required DateTime mois,
  int? annee,
  required DateTime maintenant,
  PageBilan page = PageBilan.ouverture,
  Size taille = const Size(360, 760),
  double echelleTexte = 1,
  List<Exercise> exercices = const [],
}) async {
  final banc = await _donnees(t, sessions, taille, exercices: exercices);
  await t.pumpWidget(_appli(
    banc.data,
    echelleTexte: echelleTexte,
    home: BilanStoryPage(mois: mois, annee: annee, maintenant: maintenant, pageInitiale: page),
  ));
  await poser(t);
  return banc;
}

/// Monte le vrai routeur de Progrès, ouvert sur [chemin].
Future<BancBilan> monterRouteur(
  WidgetTester t, {
  required List<WorkoutSession> sessions,
  required String chemin,
  Size taille = const Size(360, 760),
}) async {
  final banc = await _donnees(t, sessions, taille);
  final router = GoRouter(navigatorKey: rootNavigatorKey, initialLocation: chemin, routes: progresRoutes());
  addTearDown(router.dispose);
  banc.router = router;
  await t.pumpWidget(_appli(banc.data, router: router));
  await poser(t);
  return banc;
}

/// Passe à la page [cible] en touchant à droite.
Future<void> allerA(WidgetTester t, PageBilan cible) async {
  final taille = t.view.physicalSize;
  for (var i = 0; i < 10; i++) {
    if (find.bySemanticsLabel('Page ${cible.index + 1} sur 10').evaluate().isNotEmpty) break;
    await t.tapAt(Offset(taille.width - 30, taille.height / 2));
    await t.pump(const Duration(milliseconds: 350));
  }
  await poser(t, tours: 2);
}
