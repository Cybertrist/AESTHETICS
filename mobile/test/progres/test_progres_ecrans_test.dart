// Écrans de Progrès (hors bilan du mois) sur de petits jeux de données à
// date fixe : sélecteur de période, état sans donnée, calendrier (grilles,
// flèches, limites, jour touché), statistiques du mois, bilan de la semaine,
// récupération, premier jour de la semaine, liens vers Entraîner.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/ui/calendrier_page.dart';
import 'package:aesthetic/features/progres/ui/communs.dart';
import 'package:aesthetic/features/progres/ui/mois_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/progres/ui/semaine_page.dart';
import 'package:aesthetic/features/sante/recuperation/recup_calcul.dart';
import 'package:aesthetic/features/sante/recuperation/recuperation_page.dart';
import 'package:aesthetic/features/sante/recuperation/tous_muscles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

final _cadre = GlobalKey();

WorkoutSession _s(
  String id,
  DateTime d,
  String exo,
  List<(double, int)> sets, {
  int minutes = 60,
  TypeSeance type = TypeSeance.musculation,
  String? nom,
}) =>
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
            series: [
              for (var i = 0; i < sets.length; i++) WorkoutSet(id: '$id$i', poids: sets[i].$1, reps: sets[i].$2, fait: true),
            ],
          ),
      ],
    );

const _exercices = [
  Exercise(id: 't-dc', nom: 'Développé couché test', perso: true, musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.deltoidesAnterieurs, Muscle.triceps]),
  Exercise(id: 't-squat', nom: 'Squat test', perso: true, musclesPrincipaux: [Muscle.quadriceps], musclesSecondaires: [Muscle.fessiers]),
  Exercise(id: 't-tirage', nom: 'Tirage test', perso: true, musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
];

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capture(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_cadre));
    final img = await ro.toImage(pixelRatio: 1);
    final octets = await img.toByteData(format: ui.ImageByteFormat.png);
    (File('build/rendus/progres/limites/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Banc : les dépôts en mémoire, le thème, et un écran du module posé
/// derrière un routeur dont les routes des autres modules sont des témoins.
Future<(AppData, GoRouter)> _banc(
  WidgetTester t, {
  required List<WorkoutSession> sessions,
  required Widget Function(BuildContext) ecran,
  Size taille = const Size(380, 1760),
  int premierJour = DateTime.monday,
}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final data = AppData(Store.memory());
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
    await data.loadAll();
    await data.exercises.addCustomAll(_exercices);
    await data.sessions.addAll(sessions);
    if (premierJour != DateTime.monday) await data.settings.update((s) => s.copyWith(premierJourSemaine: premierJour));
    for (final v in BodyView.values) {
      for (final f in BodyFraming.values) {
        await BodyImageRepository.load(v, f);
      }
    }
  });
  final router = GoRouter(
    initialLocation: '/progres',
    routes: [
      GoRoute(path: '/progres', builder: (context, state) => ecran(context)),
      for (final chemin in ['/entrainer', '/entrainer/muscles', '/profil/mensurations', '/profil/photos', '/seance/historique/:id', '/progres/semaine', '/progres/mois', '/progres/calendrier', '/progres/recuperation', '/progres/records'])
        GoRoute(path: chemin, builder: (context, state) => Scaffold(body: Center(child: Text('témoin ${state.uri}')))),
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


/// La flèche de période (« précédente » ou « suivante ») : null si elle est éteinte.
VoidCallback? _fleche(WidgetTester t, String sens) =>
    t.widget<InkResponse>(find.descendant(of: find.bySemanticsLabel('Période $sens'), matching: find.byType(InkResponse))).onTap;
List<String> _chiffres(WidgetTester t) =>
    [for (final w in t.widgetList<TuileChiffre>(find.byType(TuileChiffre))) '${w.valeur} ${w.legende}${w.ecart == null ? '' : ' ${w.ecart}'}'];
List<int> _jours(WidgetTester t) => [for (final w in t.widgetList<PastilleJour>(find.byType(PastilleJour))) w.jour];
Finder _pastille(int jour, {bool estompe = false}) =>
    find.byWidgetPredicate((w) => w is PastilleJour && w.jour == jour && w.estompe == estompe);
String _kg(num v) => '${Fmt.n(v, decimals: 0)} kg';

void main() {
  // Vendredi 2 octobre 2026, midi.
  final now = DateTime(2026, 10, 2, 12);

  group('Progrès, sélecteur Semaine, Mois, Année', () {
    final sessions = [
      _s('o1', DateTime(2026, 10, 1, 18), 't-dc', [(100, 10)]),
      _s('s29', DateTime(2026, 9, 29, 18), 't-squat', [(100, 5), (100, 5)], minutes: 45),
      _s('s10', DateTime(2026, 9, 10, 18), 't-dc', [(80, 10)]),
      _s('m3', DateTime(2026, 3, 3, 18), 't-tirage', [(50, 10)]),
      _s('v', DateTime(2025, 10, 1, 18), 't-dc', [(60, 10)]),
    ];

    testWidgets('chaque période recalcule le volume, l\'écart et les trois tuiles', (t) async {
      await _banc(t, sessions: sessions, ecran: (_) => ProgresPage(maintenant: now));
      // Semaine du 28 septembre : 1 000 + 1 000 kg, 60 + 45 min, un record
      // (le développé couché passe de 80 à 100 kg ; le squat est une première).
      expect(find.text(_kg(2000)), findsOneWidget);
      // Rien du lundi au vendredi de la semaine passée : aucun écart affiché.
      expect(find.textContaining('vs semaine'), findsNothing);
      // La semaine se lit jour par jour ; la série de semaines en quatrième tuile.
      expect(find.text('Volume par jour'), findsOneWidget);
      expect(find.text('28 sept. au 4 oct.'), findsOneWidget);
      expect(find.text('cette semaine'), findsOneWidget);

      await t.tap(find.text('Mois'));
      await _attendre(t);
      expect(find.text(_kg(1000)), findsOneWidget);
      // Rien les 1er et 2 septembre.
      expect(find.textContaining('vs septembre'), findsNothing);
      expect(find.text('Volume par semaine'), findsOneWidget);
      expect(find.text('S40'), findsOneWidget);
      expect(find.text('Octobre 2026'), findsOneWidget);
      // Le mois d'avant : ses chiffres à lui, comparés à août entier.
      await t.tap(find.bySemanticsLabel('Période précédente'));
      await _attendre(t);
      expect(find.text('Septembre 2026'), findsOneWidget);
      expect(find.text('mois terminé'), findsOneWidget);
      // Le 10 et le 29 septembre : 800 + 1 000 kg.
      expect(find.text(_kg(1800)), findsWidgets);
      await t.tap(find.bySemanticsLabel('Période suivante'));
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);

      await t.tap(find.text('Année'));
      await _attendre(t);
      expect(find.text(_kg(3300)), findsOneWidget);
      // Du 1er janvier au 2 octobre 2025 : 600 kg. (3 300 - 600) / 600 = +450 %.
      expect(find.text('+450 % vs 2025 à la même date'), findsOneWidget);
      expect(find.text('Volume par mois'), findsOneWidget);
      expect(find.text('Volume par semaine'), findsNothing);
      expect(t.takeException(), isNull);

      await t.tap(find.text('Semaine'));
      await _attendre(t);
      expect(find.text(_kg(2000)), findsOneWidget);
    });

    testWidgets('la carte du volume et les barres ne mènent nulle part : la page dit déjà tout', (t) async {
      await _banc(t, sessions: sessions, ecran: (_) => ProgresPage(maintenant: now));
      await t.tap(find.text('VOLUME SOULEVÉ'));
      await _attendre(t);
      await t.tap(find.text('Volume par jour'));
      await _attendre(t);
      expect(find.textContaining('témoin /progres/semaine'), findsNothing);
      expect(find.byType(ProgresPage), findsOneWidget);
    });
  });

  group('sans aucune donnée', () {
    testWidgets('Progrès : des zéros, aucun écart, et un lien vers Entraîner', (t) async {
      await _banc(t, sessions: const [], ecran: (_) => ProgresPage(maintenant: now));
      expect(find.text('Rien à mesurer pour l\'instant'), findsOneWidget);
      expect(find.text(_kg(0)), findsWidgets);
      expect(find.textContaining(' vs '), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      // Sans séance, rien à remonter : les deux flèches sont éteintes.
      expect(_fleche(t, 'précédente'), isNull);
      expect(_fleche(t, 'suivante'), isNull);
      expect(find.byType(CarteResumeMensuel), findsNothing);
      await _capture(t, 'progres-vide');
      await t.tap(find.text('Commencer une séance'));
      await _attendre(t);
      expect(find.text('témoin /entrainer'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('semaine, mois, calendrier, récupération', (t) async {
      await _banc(t, sessions: const [], taille: const Size(380, 805), ecran: (_) => SemainePage(maintenant: now));
      expect(find.text('Aucune séance cette semaine.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('28 sept. au 4 oct.'), findsOneWidget);

      await _banc(t, sessions: const [], taille: const Size(380, 805), ecran: (_) => MoisPage(maintenant: now));
      expect(_chiffres(t), ['0 séance', '0 kg volume', '0 min temps d\'entraînement', '0 record battu']);
      expect(find.text('Aucune séance ce mois.'), findsOneWidget);
      expect(find.textContaining(' vs '), findsNothing);

      await _banc(t, sessions: const [], taille: const Size(380, 805), ecran: (_) => CalendrierPage(maintenant: now));
      expect(_chiffres(t), ['0 semaine de série', '0 séance ce mois']);
      expect(find.text('VENDREDI 2 OCTOBRE'), findsOneWidget);
      expect(find.text('Pas de séance ce jour-là.'), findsOneWidget);

      await _banc(t, sessions: const [], taille: const Size(380, 805), ecran: (_) => RecuperationPage(maintenant: now));
      expect(find.text('100 %'), findsNWidgets(7));
      expect(find.text('6 muscles sur 18'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('période : flèches et limites', () {
    testWidgets('sans séance : ni passé ni futur', (t) async {
      await _banc(t, sessions: const [], ecran: (_) => ProgresPage(maintenant: now));
      await t.tap(find.text('Mois'));
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);
      expect(find.text('mois en cours'), findsOneWidget);
      expect(_fleche(t, 'précédente'), isNull);
      expect(_fleche(t, 'suivante'), isNull);
      // « Détail » ouvre le calendrier du mois affiché.
      await t.tap(find.text('Détail'));
      await _attendre(t);
      expect(find.text('témoin /progres/calendrier?mois=2026-10'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('passage d\'année : de janvier à décembre', (t) async {
      final janvier = DateTime(2027, 1, 5, 12);
      await _banc(t, sessions: [_s('d', DateTime(2026, 12, 31, 23, 30), 't-dc', [(100, 10)], minutes: 90)], ecran: (_) => ProgresPage(maintenant: janvier));
      await t.tap(find.text('Mois'));
      await _attendre(t);
      expect(find.text('Janvier 2027'), findsOneWidget);
      // La semaine du 28 décembre est la S53, pas la S1.
      expect(find.text('S53'), findsOneWidget);
      expect(find.text('S1'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Période précédente'));
      await _attendre(t);
      expect(find.text('Décembre 2026'), findsOneWidget);
      // Décembre est le mois de la première séance : on ne remonte pas plus loin.
      expect(_fleche(t, 'précédente'), isNull);
      // La séance à cheval sur minuit marque le 31 décembre, pas le 1er janvier.
      expect(t.widget<PastilleJour>(_pastille(31)).type, TypeSeance.musculation);
      expect(t.widgetList<PastilleJour>(_pastille(1, estompe: true)).every((w) => w.type == null), isTrue);
      await t.ensureVisible(_pastille(31));
      await _attendre(t);
      await t.tap(_pastille(31));
      await _attendre(t);
      expect(find.text('témoin /progres/calendrier?jour=2026-12-31'), findsOneWidget);
    });

    testWidgets('on remonte jusqu\'à la première séance, pas plus loin', (t) async {
      await _banc(t, sessions: [_s('vieux', DateTime(2020, 5, 5, 18), 't-dc', [(100, 10)])], ecran: (_) => ProgresPage(maintenant: now));
      await t.tap(find.text('Année'));
      await _attendre(t);
      for (var i = 0; i < 6; i++) {
        await t.tap(find.bySemanticsLabel('Période précédente'));
        await _attendre(t);
      }
      // Le titre de la période, et la carte du résumé annuel.
      expect(find.text('2020'), findsNWidgets(2));
      expect(find.text('Résumé annuel'), findsOneWidget);
      expect(find.text('année terminée'), findsOneWidget);
      expect(_fleche(t, 'précédente'), isNull);
      // Toucher mai dans le calendrier de l'année ouvre ce mois.
      await t.ensureVisible(find.bySemanticsLabel(RegExp('^Mai 2020')));
      await _attendre(t);
      await t.tap(find.bySemanticsLabel(RegExp('^Mai 2020')));
      await _attendre(t);
      expect(find.text('Mai 2020'), findsOneWidget);
      expect(find.text('mois terminé'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('l\'historique s\'allonge pendant que la page est ouverte : le mois affiché reste le bon', (t) async {
      final (data, _) = await _banc(t, sessions: [_s('a', DateTime(2026, 10, 1, 18), 't-dc', [(100, 10)])], ecran: (_) => ProgresPage(maintenant: now));
      await t.tap(find.text('Mois'));
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);
      expect(_fleche(t, 'précédente'), isNull);
      // Un import ajoute une séance de mars : on peut maintenant remonter.
      await t.runAsync(() => data.sessions.addAll([_s('mars', DateTime(2026, 3, 3, 18), 't-dc', [(60, 10)])]));
      await _attendre(t);
      await t.pumpAndSettle();
      expect(find.text('Octobre 2026'), findsOneWidget);
      // La grille montrée est bien celle d'octobre : aujourd'hui s'y trouve.
      expect(find.byWidgetPredicate((w) => w is PastilleJour && w.aujourdhui), findsOneWidget);
      expect(t.widget<GrilleMois>(find.byType(GrilleMois)).mois, DateTime(2026, 10));
      // Et la flèche recule bien d'un seul mois.
      await t.tap(find.bySemanticsLabel('Période précédente'));
      await _attendre(t);
      expect(find.text('Septembre 2026'), findsOneWidget);
      expect(t.widget<GrilleMois>(find.byType(GrilleMois)).mois, DateTime(2026, 9));
    });
  });

  group('grille du mois', () {
    Future<void> grille(WidgetTester t, DateTime mois, {int premierJour = DateTime.monday}) => _banc(
          t,
          sessions: const [],
          taille: const Size(380, 900),
          premierJour: premierJour,
          ecran: (_) => CalendrierPage(mois: mois, maintenant: DateTime(2028, 12, 31, 12)),
        );

    testWidgets('février de 28 jours qui commence un lundi : quatre lignes pleines', (t) async {
      await grille(t, DateTime(2021, 2));
      expect(_jours(t), [for (var j = 1; j <= 28; j++) j]);
    });

    testWidgets('février 2026 commence un dimanche : cinq lignes', (t) async {
      await grille(t, DateTime(2026, 2));
      expect(_jours(t), [26, 27, 28, 29, 30, 31, for (var j = 1; j <= 28; j++) j, 1]);
      expect(_jours(t).length, 35);
    });

    testWidgets('mars 2026, 31 jours à partir d\'un dimanche : six lignes', (t) async {
      await grille(t, DateTime(2026, 3));
      final j = _jours(t);
      expect(j.length, 42);
      expect(j.take(7).toList(), [23, 24, 25, 26, 27, 28, 1]);
      expect(j.skip(35).toList(), [30, 31, 1, 2, 3, 4, 5]);
      expect(t.takeException(), isNull);
    });

    testWidgets('février bissextile : le 29 est là', (t) async {
      await grille(t, DateTime(2028, 2));
      final j = _jours(t);
      expect(j.length, 35);
      expect(j.sublist(1, 30), [for (var d = 1; d <= 29; d++) d]);
      expect(find.text('Février 2028'), findsOneWidget);
    });

    testWidgets('mois de 30 jours', (t) async {
      await grille(t, DateTime(2026, 4));
      final j = _jours(t);
      expect(j.where((d) => d == 30).length, 2, reason: '30 mars en retrait et 30 avril');
      expect(j.contains(31), isTrue, reason: '31 mars en retrait');
      expect(j.length, 35);
      expect(_pastille(31), findsNothing);
    });

    testWidgets('semaine réglée sur dimanche : la grille commence un dimanche', (t) async {
      await grille(t, DateTime(2026, 2), premierJour: DateTime.sunday);
      expect(_jours(t), [for (var j = 1; j <= 28; j++) j]);
      final enTetes = t.widgetList<Text>(find.descendant(of: find.byType(GrilleMois), matching: find.byType(Text))).map((x) => x.data).take(7).toList();
      expect(enTetes, ['D', 'L', 'M', 'M', 'J', 'V', 'S']);
    });
  });

  group('page Calendrier', () {
    final sessions = [
      _s('push', DateTime(2026, 9, 30, 19), 't-dc', [(100, 10)], nom: 'Push du soir'),
      _s('course', DateTime(2026, 9, 30, 7), 't-dc', const [], type: TypeSeance.cardio, nom: 'Course du matin', minutes: 30),
      _s('nuit', DateTime(2026, 9, 29, 23, 30), 't-squat', [(100, 5)], nom: 'Séance de nuit', minutes: 75),
    ];

    testWidgets('deux séances le même jour, séance à cheval sur minuit, jour sans séance', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 900), ecran: (_) => CalendrierPage(jour: DateTime(2026, 9, 30), maintenant: now));
      expect(find.text('Septembre 2026'), findsOneWidget);
      expect(_chiffres(t), ['1 semaine de série', '3 séances dans le mois']);
      expect(find.text('MERCREDI 30 SEPTEMBRE'), findsOneWidget);
      // Les deux séances du jour, dans l'ordre ; le cardio du matin donne l'icône.
      expect(t.getTopLeft(find.text('Course du matin')).dy, lessThan(t.getTopLeft(find.text('Push du soir')).dy));
      expect(t.widget<PastilleJour>(_pastille(30)).type, TypeSeance.cardio);
      expect(find.text('Séance de nuit'), findsNothing);
      await _capture(t, 'calendrier-deux-seances');

      // La séance de 23 h 30 appartient au 29, et dure 1 h 15.
      await t.tap(_pastille(29));
      await _attendre(t);
      expect(find.text('MARDI 29 SEPTEMBRE'), findsOneWidget);
      expect(find.text('Séance de nuit'), findsOneWidget);
      expect(find.textContaining('1 h 15 · 1 série · 500 kg'), findsOneWidget);

      // Un jour sans séance.
      await t.tap(_pastille(15));
      await _attendre(t);
      expect(find.text('MARDI 15 SEPTEMBRE'), findsOneWidget);
      expect(find.text('Pas de séance ce jour-là.'), findsOneWidget);

      // Un jour d'octobre, en retrait dans la dernière ligne : le mois suit.
      await t.tap(_pastille(1, estompe: true));
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);
      expect(find.text('JEUDI 1 OCTOBRE'), findsOneWidget);
      expect(find.text('Pas de séance ce jour-là.'), findsOneWidget);
      expect(_chiffres(t).last, '0 séance ce mois');

      // Toucher une séance ouvre son détail.
      await t.tap(_pastille(30, estompe: true));
      await _attendre(t);
      expect(find.text('Septembre 2026'), findsOneWidget);
      await t.tap(find.text('Push du soir'));
      await _attendre(t);
      expect(find.text('témoin /seance/historique/push'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('glisser : en arrière tant qu\'on veut, jamais après le mois en cours', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 900), ecran: (_) => CalendrierPage(maintenant: now));
      expect(find.text('Octobre 2026'), findsOneWidget);
      await t.fling(find.byType(GrilleMois), const Offset(-200, 0), 1200);
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);
      await t.fling(find.byType(GrilleMois), const Offset(200, 0), 1200);
      await _attendre(t);
      expect(find.text('Septembre 2026'), findsOneWidget);
      // Sans jour touché, un mois passé montre sa dernière séance.
      expect(find.text('MERCREDI 30 SEPTEMBRE'), findsOneWidget);
      await t.fling(find.byType(GrilleMois), const Offset(-200, 0), 1200);
      await _attendre(t);
      expect(find.text('Octobre 2026'), findsOneWidget);
      // Octobre n'a pas de séance : aujourd'hui.
      expect(find.text('VENDREDI 2 OCTOBRE'), findsOneWidget);
    });

    testWidgets('une adresse sur un mois à venir ouvre le mois en cours', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 900), ecran: (_) => CalendrierPage(mois: DateTime(2027, 3), maintenant: now));
      expect(find.text('Octobre 2026'), findsOneWidget);
      expect(find.text('Mars 2027'), findsNothing);
      expect(_chiffres(t).last, '0 séance ce mois');
    });
  });

  group('statistiques du mois', () {
    final sessions = [
      _s('o1', DateTime(2026, 10, 1, 18), 't-dc', [(100, 10)]),
      _s('s30', DateTime(2026, 9, 30, 18), 't-dc', [(90, 10)]),
      _s('s29', DateTime(2026, 9, 29, 18), 't-squat', [(100, 10), (100, 10), (100, 10)], minutes: 50),
      _s('s2', DateTime(2026, 9, 2, 18), 't-dc', [(80, 10)]),
      _s('a20', DateTime(2026, 8, 20, 18), 't-dc', [(75, 10), (75, 10)]),
    ];

    testWidgets('mois fini : contre le mois d\'avant entier, recoupé à la main', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => MoisPage(mois: DateTime(2026, 9), maintenant: now));
      // Septembre : 900 + 3 000 + 800 = 4 700 kg ; août : 1 500 kg ; +213 %.
      // Trois séances contre une : +2. 60 + 50 + 60 min. Records : le développé
      // couché le 2 (80 > 75) puis le 30 (90 > 80), un seul exercice.
      expect(_chiffres(t), ['3 séances +2', '${_kg(4700)} volume +213 %', '2 h 50 temps d\'entraînement', '1 record battu']);
      expect(find.text('+213 % vs août'), findsOneWidget);
      expect(find.text('Septembre 2026'), findsOneWidget);
      // Les barres ne comptent que septembre : leur somme est le volume du mois.
      final barres = t.widget<BarresVolume>(find.byType(BarresVolume)).barres;
      expect(barres.map((b) => b.label).toList(), ['S36', 'S37', 'S38', 'S39', 'S40']);
      expect(barres.map((b) => b.valeur).toList(), [800, 0, 0, 0, 3900]);
      // Répartition : jambes 3 000 / 4 700 = 64 %, pectoraux 36 %.
      expect(find.text('64 %'), findsOneWidget);
      expect(find.text('36 %'), findsOneWidget);
      expect(find.text('en kilos'), findsNothing);
      expect(find.text('en tonnes'), findsOneWidget);
    });

    testWidgets('mois en cours : comparé aux mêmes jours du mois d\'avant, pas au mois entier', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => MoisPage(maintenant: now));
      // Octobre au 2 : 1 000 kg. Septembre du 1er au 2 : 800 kg. +25 %, pas -79 %.
      expect(find.text('+25 % vs sept.'), findsOneWidget);
      expect(_chiffres(t).take(2).toList(), ['1 séance', '${_kg(1000)} volume +25 %']);
      expect(find.text('Octobre 2026'), findsOneWidget);
      // Le titre tient en entier à côté de l'étiquette.
      final titre = t.renderObject<RenderParagraph>(find.text('Octobre 2026'));
      expect(titre.didExceedMaxLines, isFalse);
      await _capture(t, 'mois-en-cours');
      expect(t.takeException(), isNull);
    });

    testWidgets('mois en cours sans séance : aucun « -100 % »', (t) async {
      await _banc(t, sessions: sessions.skip(1).toList(), taille: const Size(360, 780), ecran: (_) => MoisPage(maintenant: now));
      // Septembre du 1er au 2 : 800 kg, octobre : rien. L'écart est vrai (-100 %),
      // il s'affiche en rouge, dans l'en-tête comme dans les tuiles, jamais en vert.
      expect(_chiffres(t).take(2).toList(), ['0 séance -1', '0 kg volume -100 %']);
      expect(find.text('-100 % vs sept.'), findsOneWidget);
      final rouge = t.element(find.byType(MoisPage)).colors.error;
      final pastille = t.widget<Etiquette>(find.widgetWithText(Etiquette, '-100 % vs sept.'));
      expect(pastille.encre, rouge);
      expect(t.widgetList<TuileChiffre>(find.byType(TuileChiffre)).take(2).every((w) => w.baisse), isTrue);
      await _capture(t, 'mois-en-cours-vide-360');
      expect(t.takeException(), isNull);
    });

    testWidgets('titre long et étiquette large en 320 : rien n\'est coupé ni ne déborde', (t) async {
      final s = [
        _s('d', DateTime(2026, 12, 20, 18), 't-dc', [(100, 10), (100, 10)]),
        _s('n', DateTime(2026, 11, 20, 18), 't-dc', [(100, 10)]),
      ];
      await _banc(t, sessions: s, taille: const Size(320, 568), ecran: (_) => MoisPage(mois: DateTime(2026, 12), maintenant: DateTime(2027, 2, 1)));
      expect(find.text('+100 % vs nov.'), findsOneWidget);
      expect(find.text('Décembre 2026'), findsOneWidget);
      expect(t.renderObject<RenderParagraph>(find.text('Décembre 2026')).didExceedMaxLines, isFalse);
      await _capture(t, 'mois-decembre-320');
      expect(t.takeException(), isNull);
    });
  });

  group('bilan de la semaine', () {
    final sessions = [
      _s('ven', DateTime(2026, 9, 25, 18), 't-dc', [(100, 10)]),
      _s('lun', DateTime(2026, 9, 21, 18), 't-dc', [(100, 10)]),
      _s('avant', DateTime(2026, 9, 15, 18), 't-dc', [(50, 10)]),
    ];

    testWidgets('lundi matin, rien encore : pas de « -100 % »', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => SemainePage(maintenant: DateTime(2026, 9, 28, 8)));
      expect(find.text('28 sept. au 4 oct.'), findsOneWidget);
      expect(find.text(_kg(0)), findsOneWidget);
      // Lundi contre lundi : 1 000 kg la semaine passée, rien encore aujourd'hui.
      // L'écart existe (-100 %) mais ne porte que sur un jour.
      expect(find.text('Aucune séance cette semaine.'), findsOneWidget);
      await _capture(t, 'semaine-lundi-matin');
      expect(t.takeException(), isNull);
    });

    testWidgets('mardi, séance faite lundi : comparée au seul début de la semaine passée', (t) async {
      final s = [_s('lun2', DateTime(2026, 9, 28, 18), 't-dc', [(110, 10)]), ...sessions];
      await _banc(t, sessions: s, taille: const Size(380, 805), ecran: (_) => SemainePage(maintenant: DateTime(2026, 9, 29, 8)));
      // 1 100 kg contre 1 000 kg lundi et mardi derniers : +10 %, pas -45 %.
      expect(find.text(_kg(1100)), findsOneWidget);
      expect(find.text('+10 %'), findsOneWidget);
      expect(find.text('Pectoraux'), findsOneWidget);
      // Meilleure semaine des pectoraux : 2 000 kg, cette semaine 1 100 : 55 %.
      expect(find.text('55 %'), findsOneWidget);
    });

    testWidgets('semaine passée : contre la semaine d\'avant entière', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => SemainePage(jour: DateTime(2026, 9, 23), maintenant: now));
      expect(find.text('21 au 27 sept.'), findsOneWidget);
      expect(find.text(_kg(2000)), findsOneWidget);
      // 2 000 contre 500 : +300 %.
      expect(find.text('+300 %'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);
    });
  });

  group('premier jour de la semaine réglé sur dimanche', () {
    testWidgets('la semaine de Progrès suit le réglage', (t) async {
      // Dimanche 4 octobre : une nouvelle semaine commence.
      final dimanche = DateTime(2026, 10, 4, 12);
      final sessions = [
        _s('dim', DateTime(2026, 10, 4, 9), 't-dc', [(100, 10)]),
        _s('sam', DateTime(2026, 10, 3, 9), 't-dc', [(50, 10)]),
      ];
      await _banc(t, sessions: sessions, premierJour: DateTime.sunday, ecran: (_) => ProgresPage(maintenant: dimanche));
      expect(find.text(_kg(1000)), findsWidgets);
      // La semaine va du dimanche 4 au samedi 10.
      expect(find.text('4 au 10 oct.'), findsOneWidget);
      await t.tap(find.text('Mois'));
      await _attendre(t);
      final enTetes = t.widgetList<Text>(find.descendant(of: find.byType(GrilleMois), matching: find.byType(Text))).map((x) => x.data).take(7).toList();
      expect(enTetes, ['D', 'L', 'M', 'M', 'J', 'V', 'S']);
      // Semaine du dimanche 4 au samedi 10 : la S41 du calendrier.
      expect(find.text('S41'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('avec lundi, le même dimanche clôt la semaine', (t) async {
      final dimanche = DateTime(2026, 10, 4, 12);
      final sessions = [
        _s('dim', DateTime(2026, 10, 4, 9), 't-dc', [(100, 10)]),
        _s('sam', DateTime(2026, 10, 3, 9), 't-dc', [(50, 10)]),
      ];
      await _banc(t, sessions: sessions, ecran: (_) => ProgresPage(maintenant: dimanche));
      expect(find.text(_kg(1500)), findsWidgets);
      expect(find.text('28 sept. au 4 oct.'), findsOneWidget);
    });

    test('série de semaines et barres du dimanche au samedi', () {
      final sessions = [
        _s('a', DateTime(2026, 10, 4, 9), 't-dc', [(100, 10)]),
        _s('b', DateTime(2026, 9, 26, 9), 't-dc', [(50, 10)]),
      ];
      final a = DateTime(2026, 10, 4, 12);
      // Lundi : semaines du 21 et du 28 septembre. Dimanche : celles du 20
      // septembre et du 4 octobre, avec un trou entre les deux.
      expect(Calculs.serieSemaines(sessions, a: a), 2);
      expect(Calculs.serieSemaines(sessions, a: a, premierJour: DateTime.sunday), 1);
      final v = Calculs.volumesParSemaine(sessions, n: 3, now: a, premierJour: DateTime.sunday);
      expect(v.map((b) => b.debut).toList(), [DateTime(2026, 9, 20), DateTime(2026, 9, 27), DateTime(2026, 10, 4)]);
      expect(v.map((b) => b.label).toList(), ['S39', 'S40', 'S41']);
      expect(v.map((b) => b.volume).toList(), [500, 0, 1000]);
      // Autour du 1er janvier : dimanche 27 décembre 2026 (S53), dimanche 3 janvier 2027 (S1).
      final j = Calculs.volumesParSemaine(const [], n: 2, now: DateTime(2027, 1, 5), premierJour: DateTime.sunday);
      expect(j.map((b) => b.label).toList(), ['S53', 'S1']);
    });
  });

  group('récupération', () {
    // Squat lourd la veille au soir, développé couché le matin même.
    final sessions = [
      _s('dc', DateTime(2026, 10, 2, 9), 't-dc', [(80, 10), (80, 10), (80, 10)]),
      _s('squat', DateTime(2026, 10, 1, 20), 't-squat', [(100, 5), (100, 5), (100, 5), (100, 5)]),
    ];

    testWidgets('l\'anneau, les vignettes et le conseil disent la même chose', (t) async {
      final (data, _) = await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => RecuperationPage(maintenant: now));
      final etats = Recup.etats(data.sessions.sessions, data.exercises.byId, now: now);
      final conseil = Recup.conseil(etats, data.sessions.sessions, data.exercises.byId);
      // Fin du développé couché à 10 h, deux heures avant : 3 × (1 - 2/60) / 6 = 0,483.
      expect(etats[Muscle.pectoraux]!.pourcentage, 52);
      // Fin du squat à 21 h, quinze heures avant : 4 × (1 - 15/72) / 6 = 0,528.
      expect(etats[Muscle.quadriceps]!.pourcentage, 47);
      expect(find.text('52 %'), findsOneWidget);
      expect(find.text('47 %'), findsOneWidget);
      expect(find.text('${Recup.global(etats)} %'), findsOneWidget);
      // Le groupe conseillé n'a aucun muscle en récupération, et son chiffre
      // est celui de sa vignette.
      expect(conseil.groupe, isNot(MuscleRegion.jambes));
      expect(conseil.groupe, isNot(MuscleRegion.poitrine));
      expect(etats.values.where((e) => e.muscle.region == conseil.groupe).every((e) => e.pret), isTrue);
      expect(find.text(Recup.groupeLabel(conseil.groupe)), findsOneWidget);
      expect(find.text(Recup.phrase(conseil)), findsOneWidget);
      await _capture(t, 'recuperation');

      // « Voir » ouvre l'explorateur de muscles sur le muscle conseillé, pas
      // la liste des programmes (défaut 14b).
      await t.tap(find.text('Voir'));
      await _attendre(t);
      expect(find.text('témoin /entrainer/muscles?muscle=${conseil.phare.name}'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Progrès annonce le même groupe que la page Récupération', (t) async {
      final (data, _) = await _banc(t, sessions: sessions, ecran: (_) => ProgresPage(maintenant: now));
      final etats = Recup.etats(data.sessions.sessions, data.exercises.byId, now: now);
      final conseil = Recup.conseil(etats, data.sessions.sessions, data.exercises.byId);
      expect(find.text(Recup.pretPour(conseil.groupe)), findsOneWidget);
      expect(find.text('${Recup.global(etats)} %'), findsOneWidget);
    });

    testWidgets('une vignette ouvre l\'explorateur de muscles d\'Entraînement', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(380, 805), ecran: (_) => RecuperationPage(maintenant: now));
      await t.tap(find.text('Quadriceps'));
      await _attendre(t);
      expect(find.text('témoin /entrainer/muscles?muscle=quadriceps'), findsOneWidget);
    });

    testWidgets('tous les muscles : tri, compteurs et filtre', (t) async {
      final (data, _) = await _banc(t, sessions: sessions, taille: const Size(380, 1500), ecran: (_) => TousLesMusclesPage(maintenant: now));
      final etats = Recup.etats(data.sessions.sessions, data.exercises.byId, now: now);
      final nbPrets = etats.values.where((e) => e.pret).length;
      // Quadriceps 47, pectoraux 52, fessiers 74, épaules avant et triceps 76.
      expect(18 - nbPrets, 5);
      expect(find.text('En récupération · 5'), findsOneWidget);
      expect(find.text('Prêts · 13'), findsOneWidget);
      List<int> pcts() => [for (final w in t.widgetList<VignetteMuscle>(find.byType(VignetteMuscle))) w.etat.pourcentage];
      List<String> noms() => [for (final w in t.widgetList<VignetteMuscle>(find.byType(VignetteMuscle))) w.label];
      expect(pcts().length, 18);
      expect(pcts(), [...pcts()]..sort());
      expect(noms().take(5).toList(), ['Quadriceps', 'Pectoraux', 'Fessiers', 'Épaules avant', 'Triceps']);
      expect(pcts().take(5).toList(), [47, 52, 74, 76, 76]);
      expect(pcts().every((p) => p >= 0 && p <= 100), isTrue);

      await t.tap(find.text('En récupération · 5'));
      await _attendre(t);
      expect(pcts(), [47, 52, 74, 76, 76]);
      await t.tap(find.text('Prêts · 13'));
      await _attendre(t);
      expect(pcts().length, 13);
      expect(pcts().every((p) => p >= 90), isTrue);
      // Toucher de nouveau le filtre actif revient à tout.
      await t.tap(find.text('Prêts · 13'));
      await _attendre(t);
      expect(pcts().length, 18);
      await _capture(t, 'tous-les-muscles');
      expect(t.takeException(), isNull);
    });

    testWidgets('tout est prêt : le filtre « En récupération » le dit', (t) async {
      await _banc(t, sessions: const [], taille: const Size(380, 1500), ecran: (_) => TousLesMusclesPage(maintenant: now));
      expect(find.text('En récupération · 0'), findsOneWidget);
      expect(find.text('Prêts · 18'), findsOneWidget);
      await t.tap(find.text('En récupération · 0'));
      await _attendre(t);
      expect(find.byType(VignetteMuscle), findsNothing);
      expect(find.text('Aucun muscle en récupération : tout est prêt.'), findsOneWidget);
    });
  });

  group('360 de large et écran large', () {
    final sessions = [
      _s('o1', DateTime(2026, 10, 1, 18), 't-dc', [(100, 10), (100, 10)], nom: 'Push'),
      _s('s30', DateTime(2026, 9, 30, 18), 't-tirage', [(90, 10)], nom: 'Pull'),
      _s('s29', DateTime(2026, 9, 29, 18), 't-squat', [(100, 10), (100, 10), (100, 10)], minutes: 50, nom: 'Legs'),
      _s('s22', DateTime(2026, 9, 22, 18), 't-dc', [(80, 10), (80, 10)], nom: 'Push'),
      _s('a20', DateTime(2026, 8, 20, 18), 't-dc', [(75, 10), (75, 10)], nom: 'Push'),
    ];
    final ecrans = <String, Widget Function()>{
      'progres': () => ProgresPage(maintenant: now),
      'semaine': () => SemainePage(maintenant: now),
      'mois': () => MoisPage(mois: DateTime(2026, 9), maintenant: now),
      'calendrier': () => CalendrierPage(jour: DateTime(2026, 9, 29), maintenant: now),
      'recuperation': () => RecuperationPage(maintenant: now),
      'muscles': () => TousLesMusclesPage(maintenant: now),
    };
    testWidgets('360 : « Volume soulevé » n\'est pas coupé', (t) async {
      await _banc(t, sessions: sessions, taille: const Size(360, 1800), ecran: (_) => ProgresPage(maintenant: now));
      expect(t.renderObject<RenderParagraph>(find.text('VOLUME SOULEVÉ')).didExceedMaxLines, isFalse);
    });

    testWidgets('un seul groupe dans le mois : « 100 % » tient sur une ligne', (t) async {
      await _banc(t, sessions: [sessions.last], taille: const Size(360, 780), ecran: (_) => MoisPage(mois: DateTime(2026, 8), maintenant: now));
      final p = t.renderObject<RenderParagraph>(find.text('100 %'));
      expect(p.didExceedMaxLines, isFalse);
      expect(p.size.height, lessThan(24));
      expect(p.size.width, greaterThan(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
    });

    for (final (nom, taille) in [('360', const Size(360, 780)), ('large', const Size(720, 900)), ('paysage', const Size(780, 360))]) {
      testWidgets('$nom : aucun débordement', (t) async {
        for (final e in ecrans.entries) {
          final haut = e.key == 'progres' || e.key == 'muscles';
          await _banc(t, sessions: sessions, taille: haut && nom != 'paysage' ? Size(taille.width, 1800) : taille, ecran: (_) => e.value());
          expect(t.takeException(), isNull, reason: '${e.key} en $nom');
          await _capture(t, '$nom-${e.key}');
        }
      });
    }
  });
}
