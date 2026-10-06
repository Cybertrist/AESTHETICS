import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_images.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/entrainer/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

final cleCapture = GlobalKey();

/// Taille de la maquette à l'échelle du téléphone : 304 sur 644, fois 1,25.
const tailleMaquette = Size(380, 805);

Future<void> chargerPolices() async {
  await initializeDateFormatting('fr_FR');
  final fig = FontLoader('Figtree');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final f = File('assets/fonts/Figtree-$w.ttf');
    if (f.existsSync()) fig.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await fig.load();
  final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await l.load();
  }
}

/// Capture hors écran dans `build/rendus/<dossier>/<nom>.png`.
Future<void> capturer(WidgetTester t, String dossier, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cleCapture));
    final img = await ro.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/$dossier/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Laisse les images (personnage, poses) se décoder hors de la fausse horloge.
Future<void> attendre(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Décode d'avance le personnage (vues et calques) : les écrans le
/// trouvent prêt, sans attendre des décodages hors de la fausse horloge.
Future<void> prechargerCorps() async {
  // Un chargement resté en suspens dans un test précédent ne doit pas bloquer celui-ci.
  Future<void> essayer(Future<Object?> f) => f.timeout(const Duration(seconds: 3)).then<void>((_) {}, onError: (_) {});
  for (final f in BodyFraming.values) {
    for (final v in BodyView.values) {
      await essayer(BodyImageRepository.load(v, f));
      final imgs = BodyImageRepository.peek(v, f);
      if (imgs == null || f == BodyFraming.corps) continue;
      await Future.wait([for (final m in imgs.muscles) essayer(BodyImageRepository.loadMask(imgs, m))]);
    }
  }
}

Future<AppData> donneesVides() async {
  final data = AppData(Store.memory());
  await Future.wait([
    data.profile.load(),
    data.settings.load(),
    data.exercises.load(),
    data.routines.load(),
    data.programs.load(),
    data.sessions.load(),
    data.health.load(),
  ]);
  await data.profile.save(UserProfile(id: 'u', prenom: 'Tristan', creeLe: DateTime(2026), poidsKg: 77, tailleCm: 181, joursParSemaine: 5, niveau: Niveau.intermediaire));
  return data;
}

DateTime _jour(DateTime n, int joursAvant, int heure, int minute) => DateTime(n.year, n.month, n.day - joursAvant, heure, minute);

/// Les données de la maquette, posées par rapport à [maintenant] : trois
/// programmes, huit routines, et une routine faite six des huit dernières
/// fois ce jour de la semaine.
Future<AppData> donneesMaquette(DateTime maintenant) async {
  final data = await donneesVides();
  final creation = DateTime(maintenant.year - 1, 1, 1);
  RoutineExercise ex(String id, [int series = 3]) => RoutineExercise(
        id: newId(),
        exerciseId: id,
        reposSec: 120,
        series: [for (var i = 0; i < series; i++) const PlannedSet(reps: 8, repsMax: 12)],
      );
  Routine routine(String id, String nom, List<String> exercices, int ordre) =>
      Routine(id: id, nom: nom, ordre: ordre, creeLe: creation, exercices: [for (final e in exercices) ex(e)]);
  final routines = [
    routine('r-pecs-triceps', 'PECS / TRICEPS', ['developpe-couche', 'extension-triceps-poulie-haute'], 0),
    routine('r-dos-biceps', 'DOS / BICEPS', ['tractions', 'rowing-barre', 'tirage-vertical', 'curl-halteres', 'curl-marteau', 'curl-incline'], 1),
    routine('r-jambes', 'JAMBES', ['squat', 'presse-a-cuisses', 'leg-extension', 'leg-curl-assis', 'souleve-de-terre-roumain', 'mollets-debout-machine'], 2),
    routine('r-cardio', 'CARDIO', ['burpees'], 3),
    routine('r-pecs-epaules', 'PECS / ÉPAULES',
        ['developpe-incline-halteres', 'developpe-militaire', 'elevations-laterales', 'developpe-arnold', 'oiseau', 'dips-pectoraux', 'face-pull'], 4),
    routine('r-bras', 'BRAS', ['curl-barre', 'barre-au-front', 'curl-marteau'], 5),
    routine('r-abdos', 'ABDOS', ['crunch', 'gainage'], 6),
    routine('r-epaules', 'ÉPAULES', ['developpe-militaire', 'elevations-laterales', 'oiseau'], 7),
  ];
  await data.routines.saveAll(routines);
  final extra = routine('r-ancien', 'FULL BODY', ['squat', 'developpe-couche', 'rowing-barre'], 8);
  await data.routines.saveAll([extra]);
  Program programme(String id, String nom, List<String> ids, int age, {bool actif = false}) => Program(
        id: id,
        nom: nom,
        routineIds: ids,
        dureeSemaines: 12,
        joursParSemaine: 5,
        actif: actif,
        debuteLe: actif ? DateTime(maintenant.year, maintenant.month, maintenant.day - 30) : null,
        seancesFaites: actif ? 21 : 0,
        semaineCourante: actif ? 4 : 0,
        creeLe: DateTime(creation.year, creation.month + age),
      );
  final v3 = [for (final r in routines) r.id];
  await data.programs.save(programme('p-v1', 'DT COACH Tristan V1', [...v3, extra.id], 1));
  await data.programs.save(programme('p-v2', 'DTCOACH Tristan V2', [...v3, extra.id], 5));
  await data.programs.save(programme('p-v3', 'DT COACH Tristan V3', v3, 9, actif: true));

  WorkoutSet serie(double kg, int reps) => WorkoutSet(id: newId(), poids: kg, reps: reps, fait: true);
  WorkoutSession seance(String routineId, String nom, DateTime debut, Map<String, List<(double, int)>> exercices) => WorkoutSession(
        id: newId(),
        nom: nom,
        routineId: routineId,
        programId: 'p-v3',
        debut: debut,
        fin: debut.add(const Duration(minutes: 70)),
        exercices: [
          for (final e in exercices.entries)
            SessionExercise(id: newId(), exerciseId: e.key, series: [for (final (kg, reps) in e.value) serie(kg, reps)]),
        ],
      );
  const militaire = [(40.0, 8), (40.0, 8), (40.0, 7)];
  final sessions = <WorkoutSession>[
    // La routine du jour : six des huit dernières fois (les semaines 3 et 7 sautées).
    seance('r-pecs-epaules', 'ÉPAULES', _jour(maintenant, 7, 18, 42), {
      'developpe-militaire': militaire,
      'elevations-laterales': const [(12, 12), (10, 15), (10, 14), (10, 12)],
    }),
    seance('r-pecs-epaules', 'ÉPAULES', _jour(maintenant, 14, 19, 5), {
      'developpe-militaire': militaire,
      'elevations-laterales': const [(10, 15), (10, 13), (10, 12)],
    }),
    for (final semaines in [4, 5, 6, 8]) seance('r-pecs-epaules', 'ÉPAULES', _jour(maintenant, 7 * semaines, 18, 30), {'developpe-militaire': militaire}),
    seance('r-pecs-triceps', 'PECS / TRICEPS', _jour(maintenant, 3, 18, 10), {
      'developpe-couche': const [(80, 8), (80, 8), (80, 7)],
      'extension-triceps-poulie-haute': const [(25, 12), (25, 12), (25, 11)],
    }),
    seance('r-dos-biceps', 'DOS / BICEPS', _jour(maintenant, 2, 18, 20), {
      'tractions': const [(0, 10), (0, 9), (0, 8)],
      'curl-halteres': const [(14, 12), (14, 11), (14, 10), (14, 10)],
      'curl-marteau': const [(16, 10), (16, 10), (16, 9), (16, 9)],
      'curl-incline': const [(12, 12), (12, 12), (12, 11), (12, 10)],
    }),
    seance('r-jambes', 'JAMBES', _jour(maintenant, 16, 18, 0), {'squat': const [(100, 6), (100, 6), (100, 5)]}),
    seance('r-cardio', 'CARDIO', _jour(maintenant, 22, 12, 15), {'burpees': const [(0, 20), (0, 18)]}),
  ];
  await data.sessions.addAll(sessions);
  return data;
}

class AppEntrainer extends StatefulWidget {
  const AppEntrainer({super.key, required this.data, this.initial = '/entrainer'});

  final AppData data;
  final String initial;

  @override
  State<AppEntrainer> createState() => _AppEntrainerState();
}

/// L'onglet dans une coquille réduite : la vraie barre du bas, les vraies
/// routes du module, et des pages factices pour les autres modules.
class _AppEntrainerState extends State<AppEntrainer> {
  final _accent = AccentController();
  final _coquille = GlobalKey<NavigatorState>();
  late final _router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: widget.initial,
    routes: [
      ShellRoute(
        navigatorKey: _coquille,
        builder: (context, state, child) => Scaffold(
          backgroundColor: Colors.black,
          body: child,
          bottomNavigationBar: AppBottomNav(currentIndex: AppTab.entrainer.rang, onTap: (_) {}),
        ),
        routes: entrainerRoutes(),
      ),
      for (final p in ['/seance', '/seance/vide', '/seance/historique', '/import', '/profil'])
        GoRoute(path: p, builder: (_, _) => Scaffold(body: Center(child: Text(p)))),
      GoRoute(path: '/seance/apercu/:id', builder: (_, s) => Scaffold(body: Center(child: Text('apercu ${s.pathParameters['id']}')))),
      GoRoute(path: '/seance/historique/:id', builder: (_, s) => Scaffold(body: Center(child: Text('seance ${s.pathParameters['id']}')))),
    ],
  );

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

Future<void> lancer(WidgetTester t, AppData data, String adresse, {Size taille = tailleMaquette}) async {
  await t.runAsync(prechargerCorps);
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(RepaintBoundary(key: cleCapture, child: AppEntrainer(key: UniqueKey(), data: data, initial: adresse)));
  await attendre(t);
}

GoRouter routeur(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));
