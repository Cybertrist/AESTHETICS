// Défauts relevés sur l'émulateur le 2 octobre, zone Progrès (CHASSE.md) :
// records et progression au design validé, écarts en rouge et en vert,
// tuiles de la page Progrès, bilan du mois (cardio, dernière page), « Voir »
// de la récupération, pages d'analyse reprises, écriture commune.
import 'package:aesthetic/features/profil/widgets/ecusson.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/progres/progres_paths.dart';
import 'package:aesthetic/features/progres/routes.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:aesthetic/features/progres/ui/communs.dart';
import 'package:aesthetic/features/progres/ui/exercice_page.dart';
import 'package:aesthetic/features/progres/ui/mois_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/progres/ui/progres_widgets.dart';
import 'package:aesthetic/features/progres/ui/records_page.dart';
import 'package:aesthetic/features/sante/recuperation/muscle_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

final _cadre = GlobalKey();

const _exercices = [
  Exercise(id: 'c-dc', nom: 'Développé couché test', perso: true, musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.triceps]),
  Exercise(id: 'c-squat', nom: 'Squat test', perso: true, musclesPrincipaux: [Muscle.quadriceps], musclesSecondaires: [Muscle.fessiers]),
  Exercise(id: 'c-tirage', nom: 'Tirage test', perso: true, musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
];

WorkoutSession _s(String id, DateTime d, String exo, List<(double, int)> sets, {int minutes = 60, TypeSeance type = TypeSeance.musculation, String? nom}) =>
    WorkoutSession(
      id: id,
      nom: nom ?? 'Séance $id',
      debut: d,
      fin: d.add(Duration(minutes: minutes)),
      type: type,
      exercices: [
        if (sets.isNotEmpty)
          SessionExercise(
            id: 'e$id',
            exerciseId: exo,
            series: [for (final (i, x) in sets.indexed) WorkoutSet(id: '$id$i', poids: x.$1, reps: x.$2, fait: true)],
          ),
      ],
    );

Future<void> _attendre(WidgetTester t, {int tours = 4}) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capture(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_cadre));
    final img = await ro.toImage(pixelRatio: 1);
    final octets = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/progres/chasse/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Banc : le vrai jeu de routes de Progrès, les autres modules en témoins.
/// [sessions] nul : les données de la démo.
Future<(AppData, GoRouter)> _banc(
  WidgetTester t, {
  List<WorkoutSession>? sessions,
  String chemin = ProgresPaths.racine,
  Size taille = const Size(380, 805),
  double bas = 0,
}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(top: 25, bottom: bas);
  addTearDown(t.view.reset);
  final data = AppData(Store.memory(), demo: sessions == null);
  await t.runAsync(() async {
    await initializeDateFormatting('fr_FR');
    for (final famille in ['Figtree', 'Montserrat']) {
      final l = FontLoader(famille);
      for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
        final n = f.uri.pathSegments.last;
        if (n.startsWith('$famille-') && n.endsWith('.ttf')) l.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await l.load();
    }
    final icones = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icones.existsSync()) {
      final l = FontLoader('MaterialIcons')..addFont(icones.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await l.load();
    }
    await data.loadAll();
    if (sessions == null) {
      await DemoData.seed(data);
    } else {
      await data.exercises.addCustomAll(_exercices);
      await data.sessions.addAll(sessions);
    }
    for (final v in BodyView.values) {
      for (final f in BodyFraming.values) {
        await BodyImageRepository.load(v, f);
      }
    }
  });
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: chemin,
    routes: [
      ...progresRoutes(),
      GoRoute(path: '/sante/recuperation/:muscle', builder: (context, state) => MusclePage(muscle: Muscle.values.byName(state.pathParameters['muscle']!))),
      for (final c in ['/entrainer', '/entrainer/muscles', '/entrainer/exercices', '/entrainer/exercices/:id', '/profil/mensurations', '/profil/photos', '/seance/historique/:id'])
        GoRoute(path: c, builder: (context, state) => Scaffold(body: Center(child: Text('témoin ${state.uri}')))),
    ],
  );
  addTearDown(router.dispose);
  final accent = AccentController();
  await t.pumpWidget(
    RepaintBoundary(
      key: _cadre,
      child: MultiProvider(
        providers: [
          Provider<AppData>.value(value: data),
          Provider<Store>.value(value: data.store),
          ChangeNotifierProvider<AccentController>.value(value: accent),
          ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
          ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
          ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
          ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
          ChangeNotifierProvider<HealthRepo>.value(value: data.health),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: accent.theme,
          routerConfig: router,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        ),
      ),
    ),
  );
  await _attendre(t);
  return (data, router);
}

/// Tous les textes affichés.
List<String> _textes(WidgetTester t) => [for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText()];

/// L'écriture commune : jamais « 70kg », jamais la lettre x entre charge et
/// répétitions, jamais de point décimal.
void _ecritureCommune(WidgetTester t, String ecran) {
  for (final texte in _textes(t)) {
    expect(RegExp(r'\d(kg|lb)\b').hasMatch(texte), isFalse, reason: '$ecran : « $texte » colle l\'unité au nombre');
    expect(RegExp(r'\d\s?x\s?\d').hasMatch(texte), isFalse, reason: '$ecran : « $texte » écrit x au lieu de ×');
    expect(RegExp(r'\d\.\d').hasMatch(texte), isFalse, reason: '$ecran : « $texte » a un point décimal');
  }
}

/// L'ancien habillage : barre de titre Material, icônes à halo coloré,
/// icônes Material bleues ou corail.
void _habillageValide(WidgetTester t, String ecran) {
  expect(find.byType(SubPageScaffold), findsNothing, reason: '$ecran : ancienne barre de titre');
  expect(find.byType(AppBar), findsNothing, reason: '$ecran : barre Material');
  expect(find.byType(IconHalo), findsNothing, reason: '$ecran : icône à halo');
  expect(find.byType(BigNumber), findsNothing, reason: '$ecran : « 26,9kg » sans espace');
  expect(find.byType(BoutonRetour), findsOneWidget, reason: '$ecran : bouton retour rond');
  final c = t.element(find.byType(BoutonRetour)).colors;
  // Le rond gris du retour.
  final rond = t.widget<Material>(find.descendant(of: find.byType(BoutonRetour), matching: find.byType(Material)).first);
  expect(rond.color, c.surface2, reason: ecran);
  for (final i in t.widgetList<Icon>(find.byType(Icon))) {
    expect(i.color, isNot(AppTokens.domainTraining), reason: '$ecran : icône bleue');
    expect(i.color, isNot(c.accent), reason: '$ecran : icône corail');
  }
}

Color? _couleur(WidgetTester t, String texte) {
  final e = find.byType(RichText).evaluate().firstWhere((e) => (e.widget as RichText).text.toPlainText().startsWith(texte));
  return (e.widget as RichText).text.style?.color;
}

void main() {
  final now = DateTime.now();
  DateTime jour(int avant, [int heure = 18]) => DateTime(now.year, now.month, now.day - avant, heure);

  group('1. records et progression au design validé', () {
    // Le développé couché progresse (80 puis 100 kg), le squat régresse
    // (120 puis 100 kg), le tirage ne bouge pas.
    final sessions = [
      _s('a', jour(40), 'c-dc', [(80, 5)]),
      _s('b', jour(3), 'c-dc', [(100, 5), (72.5, 8)]),
      _s('c', jour(30), 'c-squat', [(120, 5)]),
      _s('d', jour(2), 'c-squat', [(100, 5)]),
      _s('e', jour(20), 'c-tirage', [(60, 10)]),
      _s('f', jour(1), 'c-tirage', [(60, 10)]),
    ];

    testWidgets('Records : en-tête, vignettes, gain en vert, baisse en rouge, écart nul absent', (t) async {
      await _banc(t, sessions: sessions, chemin: ProgresPaths.records, taille: const Size(380, 1100));
      expect(t.takeException(), isNull);
      _habillageValide(t, 'records');
      _ecritureCommune(t, 'records');
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('3 exercices suivis'), findsOneWidget);
      expect(find.byType(VignetteExercice), findsNWidgets(3));
      final c = t.element(find.byType(RecordsPage)).colors;
      // Le gain va du 1RM de la première séance au record : seul le développé
      // couché en a un (le record du squat date de sa première séance, le
      // tirage n'a pas bougé : rien, ni « 0 » ni « stable »).
      final gains = _textes(t).where((x) => x.contains('%')).toList();
      expect(gains, ['+${Fmt.n(Strength.oneRepMax(100, 5) - Strength.oneRepMax(80, 5))} kg · +25 %']);
      expect(_couleur(t, gains.single), c.success);
      expect(find.textContaining('stable'), findsNothing);
      expect(find.text('Charge 100 kg × 5'), findsOneWidget);
      expect(find.text('Charge 120 kg × 5'), findsOneWidget);
      expect(find.text('Charge 60 kg × 10'), findsOneWidget);
      await _capture(t, '01-records');

      // Le tri s'ouvre dans un panneau du bas.
      await t.tap(find.bySemanticsLabel('Trier'));
      await _attendre(t);
      expect(find.text('Trier les records'), findsOneWidget);
      expect(find.byType(PanneauBas), findsOneWidget);
      await _capture(t, '01-records-tri');
      await t.tap(find.text('A à Z'));
      await _attendre(t);
      expect(find.text('3 résultats · a à z'), findsOneWidget);
      final noms = [for (final v in t.widgetList<VignetteExercice>(find.byType(VignetteExercice))) v.exercice!.nom];
      expect(noms, ['Développé couché test', 'Squat test', 'Tirage test']);

      // Filtre par groupe, puis filtre sans résultat.
      await t.tap(find.text('Dos'));
      await _attendre(t);
      expect(find.byType(VignetteExercice), findsOneWidget);
      await t.enterText(find.byType(TextField), 'zzz');
      await _attendre(t);
      expect(find.text('Aucun record ne correspond'), findsOneWidget);
      await _capture(t, '01-records-aucun-resultat');
      await t.tap(find.text('Effacer les filtres'));
      await _attendre(t);
      expect(find.byType(VignetteExercice), findsNWidgets(3));
      expect(t.takeException(), isNull);
    });

    testWidgets('Progression d\'un exercice : « 116,7 kg », courbe blanche, records sans icône colorée', (t) async {
      await _banc(t, sessions: sessions, chemin: '/progres/exercices/c-dc', taille: const Size(380, 1700));
      expect(t.takeException(), isNull);
      _habillageValide(t, 'progression');
      _ecritureCommune(t, 'progression');
      final c = t.element(find.byType(ExerciceProgresPage)).colors;
      expect(find.text('Développé couché test'), findsOneWidget);
      // Le chiffre et son unité sont séparés d'une espace.
      final record = Strength.oneRepMax(100, 5);
      final gain = '+${Fmt.n(record - Strength.oneRepMax(80, 5))} kg sur la période';
      expect(find.text('${Fmt.n(record)} kg'), findsWidgets);
      expect(find.text(gain), findsOneWidget);
      expect(_couleur(t, gain), c.success);
      // La courbe n'est ni bleue ni corail.
      final courbe = t.widget<LineChart>(find.byType(LineChart));
      expect(courbe.data.lineBarsData.single.color, c.text);
      expect(find.byType(Ecusson), findsWidgets);
      expect(find.text('100 kg × 5'), findsWidgets);
      await _capture(t, '02-progression');

      // Une ligne de l'historique ouvre ses séries dans un panneau du bas.
      await t.ensureVisible(find.text('Séance a'));
      await _attendre(t);
      await t.tap(find.text('Séance a'));
      await _attendre(t);
      expect(find.byType(PanneauBas), findsOneWidget);
      expect(find.text('80 kg × 5'), findsWidgets);
      expect(find.text('Toute la séance'), findsOneWidget);
      _ecritureCommune(t, 'séries d\'une séance');
      await _capture(t, '02-progression-series');
      expect(t.takeException(), isNull);
    });

    testWidgets('Progression : une baisse sur la période s\'écrit en rouge', (t) async {
      await _banc(t, sessions: sessions, chemin: '/progres/exercices/c-squat', taille: const Size(380, 1700));
      final c = t.element(find.byType(ExerciceProgresPage)).colors;
      final baisse = '-${Fmt.n(Strength.oneRepMax(120, 5) - Strength.oneRepMax(100, 5))} kg sur la période';
      expect(find.text(baisse), findsOneWidget);
      expect(_couleur(t, baisse), c.error);
      // Écart nul : rien.
      final (_, router) = await _banc(t, sessions: sessions, chemin: '/progres/exercices/c-tirage', taille: const Size(380, 1700));
      expect(find.textContaining('sur la période'), findsNothing);
      // Exercice jamais fait.
      router.go('/progres/exercices/inconnu');
      await _attendre(t);
      expect(find.text('Pas encore fait'), findsOneWidget);
      _habillageValide(t, 'exercice jamais fait');
      expect(t.takeException(), isNull);
    });

    testWidgets('avec la démo, en 380, 320 et 900 de large : rien ne déborde', (t) async {
      final (data, router) = await _banc(t, chemin: ProgresPaths.records, taille: const Size(380, 805), bas: 24);
      final exo = data.sessions.sessions.expand((s) => s.exercices).firstWhere((e) => e.seriesFaites.isNotEmpty && (e.seriesFaites.first.poids ?? 0) > 0).exerciseId;
      for (final (taille, nom) in [(const Size(380, 805), '380'), (const Size(320, 568), '320'), (const Size(900, 800), '900')]) {
        t.view.physicalSize = taille;
        router.go(ProgresPaths.records);
        await _attendre(t, tours: 6);
        expect(t.takeException(), isNull, reason: 'records $nom');
        _ecritureCommune(t, 'records $nom');
        await _capture(t, '01-records-demo-$nom');
        router.go('/progres/exercices/${Uri.encodeComponent(exo)}');
        await _attendre(t, tours: 6);
        expect(t.takeException(), isNull, reason: 'progression $nom');
        _ecritureCommune(t, 'progression $nom');
        _habillageValide(t, 'progression $nom');
        await _capture(t, '02-progression-demo-$nom');
        await t.drag(find.byType(ListView).first, const Offset(0, -620));
        await _attendre(t);
        await _capture(t, '02-progression-demo-$nom-bas');
        await t.drag(find.byType(ListView).first, const Offset(0, -900));
        await _attendre(t);
        expect(t.takeException(), isNull, reason: 'progression $nom, bas');
        await _capture(t, '02-progression-demo-$nom-fin');
      }
    });
  });

  group('7b. une baisse s\'écrit en rouge', () {
    // Ce mois : 1 000 kg ; aux mêmes jours du mois passé : 5 000 kg.
    final debutMois = DateTime(now.year, now.month, 1, 8);
    final sessions = [
      _s('m', debutMois, 'c-dc', [(100, 10)]),
      _s('p', DateTime(now.year, now.month - 1, 1, 8), 'c-dc', [(100, 10), (100, 10), (100, 10), (100, 10), (100, 10)]),
    ];

    testWidgets('Statistiques du mois : la pastille « -80 % » est rouge, les tuiles aussi', (t) async {
      await _banc(t, sessions: sessions, chemin: ProgresPaths.mois());
      final c = t.element(find.byType(MoisPage)).colors;
      final pastille = t.widget<Etiquette>(find.byType(Etiquette));
      expect(pastille.texte, startsWith('-80 % vs '));
      expect(pastille.encre, c.error);
      expect(pastille.fond, c.error.withValues(alpha: 0.14));
      final volume = t.widgetList<TuileChiffre>(find.byType(TuileChiffre)).elementAt(1);
      expect(volume.ecart, '-80 %');
      expect(volume.baisse, isTrue);
      await _capture(t, '07-mois-baisse');
      expect(t.takeException(), isNull);
    });

    testWidgets('Progrès, vue Mois : l\'écart de la carte du volume est rouge', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 1760));
      await t.tap(find.text('Mois'));
      await _attendre(t);
      final c = t.element(find.byType(ProgresPage)).colors;
      expect(_couleur(t, '-80 % vs '), c.error);
      await _capture(t, '07-progres-baisse');
    });

    testWidgets('une hausse reste verte', (t) async {
      final hausse = [
        _s('m', debutMois, 'c-dc', [(100, 10), (100, 10)]),
        _s('p', DateTime(now.year, now.month - 1, 1, 8), 'c-dc', [(100, 10)]),
      ];
      await _banc(t, sessions: hausse, chemin: ProgresPaths.mois());
      final c = t.element(find.byType(MoisPage)).colors;
      final pastille = t.widget<Etiquette>(find.byType(Etiquette));
      expect(pastille.texte, startsWith('+100 % vs '));
      expect(pastille.encre, c.success);
    });
  });

  group('23. résumé mensuel', () {
    final mois = DateTime(now.year, now.month - 1);
    final sessions = [
      _s('x', DateTime(mois.year, mois.month, 3, 18), 'c-dc', [(100, 10)], nom: 'Push'),
      _s('y', DateTime(mois.year, mois.month, 5, 18), '', const [], minutes: 41, type: TypeSeance.cardio, nom: 'Course à pied'),
    ];

    testWidgets('une séance de cardio affiche sa durée seule, jamais « 0 kg »', (t) async {
      final (_, router) = await _banc(t, sessions: sessions);
      router.push(ProgresPaths.bilan(mois, 'seances'));
      await _attendre(t);
      expect(find.text('COURSE À PIED'), findsOneWidget);
      expect(find.text('41 min'), findsOneWidget);
      expect(find.text('0 kg'), findsNothing);
      // La séance de musculation et le total gardent leur volume.
      expect(find.text('1 000 kg'), findsNWidgets(2));
      await _capture(t, '23-bilan-seances-cardio');
      expect(t.takeException(), isNull);
    });

    testWidgets('sur la dernière page, toucher à droite ferme le bilan', (t) async {
      final (_, router) = await _banc(t, sessions: sessions);
      router.push(ProgresPaths.bilan(mois, 'resume'));
      await _attendre(t);
      expect(find.bySemanticsLabel('Page 10 sur 10'), findsOneWidget);
      // À gauche : on revient d'une page, le bilan reste ouvert.
      await t.tapAt(const Offset(40, 420));
      await _attendre(t);
      expect(find.bySemanticsLabel('Page 9 sur 10'), findsOneWidget);
      await t.tapAt(const Offset(300, 420));
      await _attendre(t);
      expect(find.bySemanticsLabel('Page 10 sur 10'), findsOneWidget);
      await t.tapAt(const Offset(300, 420));
      await _attendre(t);
      expect(find.byType(BilanStoryPage), findsNothing);
      expect(find.byType(ProgresPage), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('24. sous la carte du volume', () {
    final sessions = [_s('a', jour(0, 7), 'c-dc', [(100, 10)])];

    testWidgets('plus de tuiles de chiffres : la carte du volume est suivie des barres', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 1760));
      expect(find.text('d\'entraînement'), findsOneWidget, reason: 'seulement dans « Depuis le début »');
      expect(find.text('de suite'), findsNothing);
      expect(find.text('record battu'), findsNothing);
      expect(find.text('Volume par jour'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('pages d\'analyse reprises au design validé', () {
    testWidgets('muscles, détail d\'un muscle, comparer, choix d\'exercice, résumé de séance', (t) async {
      final (data, router) = await _banc(t, taille: const Size(380, 805), bas: 24);
      final muscu = data.sessions.sessions.firstWhere((s) => !s.enCours && s.volume > 0);
      final cardio = data.sessions.sessions.firstWhere((s) => !s.enCours && s.volume <= 0 && s.type != TypeSeance.musculation);
      final ecrans = {
        'muscles': '/progres/muscles',
        'muscle': '/progres/muscles/pectoraux',
        'comparer': '/progres/comparer',
        'exercices': '/progres/exercices',
        'seance': '/progres/seance/${muscu.id}',
        'seance-cardio': '/progres/seance/${cardio.id}',
        'recup-muscle': '/sante/recuperation/pectoraux',
        'muscle-inconnu': '/progres/muscles/inconnu',
        'seance-inconnue': '/progres/seance/inconnue',
      };
      for (final (taille, nom) in [(const Size(380, 805), '380'), (const Size(320, 568), '320'), (const Size(900, 800), '900')]) {
        t.view.physicalSize = taille;
        for (final e in ecrans.entries) {
          router.go(e.value);
          await _attendre(t, tours: 6);
          expect(t.takeException(), isNull, reason: '${e.key} $nom');
          _habillageValide(t, '${e.key} $nom');
          _ecritureCommune(t, '${e.key} $nom');
          await _capture(t, '10-${e.key}-$nom');
          if (nom == '380' && find.byType(ListView).evaluate().isNotEmpty && !e.key.contains('inconnu')) {
            await t.drag(find.byType(ListView).first, const Offset(0, -640));
            await _attendre(t);
            expect(t.takeException(), isNull, reason: '${e.key} $nom, plus bas');
            _ecritureCommune(t, '${e.key} $nom, plus bas');
            await _capture(t, '10-${e.key}-$nom-bas');
          }
        }
      }
      // Un muscle visible de face et de dos.
      t.view.physicalSize = const Size(380, 805);
      router.go('/progres');
      await _attendre(t);
      router.go('/sante/recuperation/avantBras');
      await _attendre(t, tours: 6);
      expect(t.takeException(), isNull);
      _habillageValide(t, 'récupération, muscle à deux vues');
      await _capture(t, '10-recup-muscle-deux-vues');
      // Une séance de cardio ne dit pas « 0 kg ».
      router.go('/progres/seance/${cardio.id}');
      await _attendre(t);
      expect(find.textContaining('0 kg'), findsNothing);
      expect(find.text('DURÉE'), findsOneWidget);
    });

    testWidgets('muscles : volume par muscle, tri dans un panneau, semaine précédente', (t) async {
      await _banc(t, taille: const Size(380, 1500));
      final router = GoRouter.of(t.element(find.byType(ProgresPage)));
      router.go('/progres/muscles');
      await _attendre(t);
      await t.tap(find.text('Volume'));
      await _attendre(t);
      expect(t.takeException(), isNull);
      _ecritureCommune(t, 'muscles, volume');
      await _capture(t, '10-muscles-volume');
      await t.tap(find.textContaining('Tri :'));
      await _attendre(t);
      expect(find.byType(PanneauBas), findsOneWidget);
      await t.tap(find.text('Par ordre alphabétique'));
      await _attendre(t);
      expect(find.text('Tri : A à Z'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Semaine précédente'));
      await _attendre(t);
      expect(find.textContaining('Semaine du '), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('comparer : hausse verte, baisse rouge, écart nul absent', (t) async {
      // Ce mois : 2 séances, 1 000 kg ; le mois passé : 1 séance, 2 000 kg.
      final sessions = [
        _s('a', DateTime(now.year, now.month, 1, 8), 'c-dc', [(50, 10)]),
        _s('b', DateTime(now.year, now.month, 1, 10), 'c-dc', [(50, 10)]),
        _s('c', DateTime(now.year, now.month - 1, 10, 8), 'c-dc', [(100, 10), (100, 10)], minutes: 120),
      ];
      await _banc(t, sessions: sessions, chemin: '/progres/comparer', taille: const Size(380, 1700));
      expect(t.takeException(), isNull);
      final c = t.element(find.byType(BoutonRetour)).colors;
      // Séances : 2 contre 1 ; volume : 1 000 contre 2 000 kg ; durée égale.
      expect(_couleur(t, '+100 %'), c.success);
      expect(_couleur(t, '-50 %'), c.error);
      expect(find.text('stable'), findsNothing);
      expect(find.text('nouveau'), findsNothing);
      await _capture(t, '10-comparer-ecarts');
    });
  });

  group('barres de muscles', () {
    testWidgets('le chevron est celui de la maquette', (t) async {
      await _banc(t, chemin: '/progres/muscles', taille: const Size(380, 1500));
      expect(find.descendant(of: find.byType(BarreMuscle), matching: find.byType(Chevron)), findsWidgets);
      expect(find.descendant(of: find.byType(BarreMuscle), matching: find.byType(Icon)), findsNothing);
    });
  });
}
