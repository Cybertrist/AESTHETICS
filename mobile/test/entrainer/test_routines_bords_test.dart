import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/routes.dart';
import 'package:aesthetic/features/entrainer/routines/logic/idees.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/ligne_routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'outils.dart';

const _long = 'Programme de préparation physique générale hiver 2026 V12';
const _routineLongue = 'Pectoraux, épaules, triceps et gainage du vendredi soir tard';

/// Une routine au nom très long, faite huit vendredis sur huit, dans un
/// programme au nom très long ; une routine vide ; un programme vide.
Future<AppData> _donneesLongues(DateTime maintenant) async {
  final data = await donneesVides();
  final creation = DateTime(maintenant.year - 1);
  await data.routines.saveAll([
    Routine(
      id: 'r-long',
      nom: _routineLongue,
      ordre: 0,
      creeLe: creation,
      exercices: [
        for (final e in ['developpe-couche', 'developpe-militaire'])
          RoutineExercise(id: newId(), exerciseId: e, reposSec: 300, series: [for (var i = 0; i < 30; i++) const PlannedSet(reps: 8)]),
      ],
    ),
    Routine(id: 'r-vide', nom: 'Vide', ordre: 1, creeLe: creation),
  ]);
  await data.programs.save(Program(id: 'p-long', nom: _long, routineIds: const ['r-long', 'r-vide', 'r-disparue'], actif: true, debuteLe: creation, creeLe: creation));
  await data.programs.save(Program(id: 'p-vide', nom: 'Vide', creeLe: creation.add(const Duration(days: 1))));
  await data.sessions.addAll([
    for (var k = 1; k <= 8; k++)
      WorkoutSession(
        id: 's$k',
        nom: _routineLongue,
        routineId: 'r-long',
        programId: 'p-long',
        debut: DateTime(maintenant.year, maintenant.month, maintenant.day - 7 * k, 18),
        fin: DateTime(maintenant.year, maintenant.month, maintenant.day - 7 * k, 19),
      ),
  ]);
  return data;
}

/// L'onglet dans une coquille à état gardé, comme dans l'appli.
class _AppOnglets extends StatelessWidget {
  _AppOnglets({required this.data});

  final AppData data;
  final _accent = AccentController();
  late final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/accueil',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/accueil', builder: (_, _) => const Center(child: Text('accueil')))]),
          StatefulShellBranch(routes: entrainerRoutes()),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<AppData>.value(value: data),
          Provider<Store>.value(value: data.store),
          ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
          ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
          ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
          ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
          ChangeNotifierProvider<ProgramRepo>.value(value: data.programs),
          ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
        ],
        child: MaterialApp.router(theme: _accent.theme, routerConfig: router),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final maintenant = DateTime.now();

  for (final (nom, taille) in [('320', const Size(320, 640)), ('360', const Size(360, 760)), ('fold', const Size(884, 1000))]) {
    testWidgets('noms très longs, routine vide, programme vide : aucun débordement en $nom', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(() => _donneesLongues(maintenant)))!;
      await t.runAsync(() => RoutinePrefs.of(data.store).basculerFavori('r-long'));
      final erreurs = <String>[];
      void releve(String etape) {
        for (Object? e = t.takeException(); e != null; e = t.takeException()) {
          erreurs.add('$etape : ${e.toString().split('\n').first}');
        }
      }

      await lancer(t, data, '/entrainer', taille: taille);
      expect(find.text(_long), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('2 routines'), findsOneWidget, reason: 'la routine disparue ne compte pas');
      expect(find.text('0 routine'), findsOneWidget, reason: 'programme vide');
      releve('programmes');
      await capturer(t, 'routines', 'bords-$nom-programmes');

      routeur(t).go('/entrainer?onglet=routines');
      await attendre(t, 3);
      expect(find.text('Commencer'), findsOneWidget);

      releve('routines');
      await capturer(t, 'routines', 'bords-$nom-routines');

      await t.scrollUntilVisible(find.bySemanticsLabel('Actions sur $_routineLongue'), 120, scrollable: find.byType(Scrollable).first);
      await t.tap(find.bySemanticsLabel('Actions sur $_routineLongue'));
      await attendre(t, 3);
      releve('actions');
      await capturer(t, 'routines', 'bords-$nom-actions');
      await t.tap(find.text('Déplacer dans un autre programme'));
      await attendre(t, 3);
      releve('déplacer');
      await capturer(t, 'routines', 'bords-$nom-deplacer');
      await t.tapAt(const Offset(10, 10));
      await attendre(t, 3);

      await t.scrollUntilVisible(find.bySemanticsLabel('Actions sur $_routineLongue'), 120, scrollable: find.byType(Scrollable).first);
      await t.tap(find.bySemanticsLabel('Actions sur $_routineLongue'));
      await attendre(t, 3);
      await t.tap(find.text('Changer l’image'));
      await attendre(t, 3);
      releve('vignette');
      await capturer(t, 'routines', 'bords-$nom-vignette');
      await t.tapAt(const Offset(10, 10));
      await attendre(t, 3);

      await t.scrollUntilVisible(find.bySemanticsLabel('Actions sur $_routineLongue'), 120, scrollable: find.byType(Scrollable).first);
      await t.tap(find.bySemanticsLabel('Actions sur $_routineLongue'));
      await attendre(t, 3);
      await t.tap(find.text('Supprimer'));
      await attendre(t, 3);
      releve('confirmation de suppression');
      await capturer(t, 'routines', 'bords-$nom-supprimer');
      await t.tap(find.text('Annuler'));
      await attendre(t, 3);

      await t.scrollUntilVisible(find.text('0 exercice'), 150, scrollable: find.byType(Scrollable).first);
      expect(find.text('0 exercice'), findsOneWidget, reason: 'routine vide');
      releve('routine vide');

      routeur(t).go('/entrainer/programmes/p-long');
      await attendre(t, 4);
      expect(find.byType(LigneRoutine), findsNWidgets(2));
      releve('programme');
      await capturer(t, 'routines', 'bords-$nom-programme');
      await t.tap(find.text('VOIR PLUS'));
      await attendre(t, 2);
      releve('voir plus');
      await t.tap(find.bySemanticsLabel('Actions sur le programme'));
      await attendre(t, 3);
      releve('menu du programme');
      await capturer(t, 'routines', 'bords-$nom-programme-menu');
      await t.tapAt(const Offset(10, 10));
      await attendre(t, 3);

      routeur(t).go('/entrainer/programmes/p-vide');
      await attendre(t, 4);
      expect(find.text('Ajouter une routine au programme'), findsOneWidget);
      expect(find.byType(LigneRoutine), findsNothing);
      releve('programme vide');
      await capturer(t, 'routines', 'bords-$nom-programme-vide');

      routeur(t).go('/entrainer/routines/favoris');
      await attendre(t, 3);
      expect(find.byType(LigneRoutine), findsOneWidget);
      releve('favoris');

      routeur(t).go('/entrainer/programmes/idees');
      await attendre(t, 5);
      releve('idées');
      await capturer(t, 'routines', 'bords-$nom-idees');
      routeur(t).go('/entrainer/programmes/modele/push-pull-legs-6j');
      await attendre(t, 5);
      releve('idée');
      await t.tap(find.text('Ajouter à ma bibliothèque'));
      await attendre(t, 3);
      releve('ajout d\'une idée');
      await capturer(t, 'routines', 'bords-$nom-idee-ajout');
      await t.tapAt(const Offset(10, 10));
      await attendre(t, 3);

      routeur(t).go('/entrainer/routines/r-long/modifier');
      await attendre(t, 4);
      releve('éditeur de routine');
      await capturer(t, 'routines', 'bords-$nom-editeur-routine');
      routeur(t).go('/entrainer/programmes/p-long/modifier');
      await attendre(t, 4);
      releve('éditeur de programme');
      await capturer(t, 'routines', 'bords-$nom-editeur-programme');

      expect(erreurs, isEmpty, reason: erreurs.join('\n'));
    });
  }

  testWidgets('adresses inconnues : routine, programme ou idée introuvable, avec une sortie', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer/programmes/inconnu');
    expect(find.text('Programme introuvable'), findsOneWidget);
    await t.tap(find.text('Voir les programmes'));
    await attendre(t, 3);
    expect(find.text('Créer un programme'), findsOneWidget);
    routeur(t).go('/entrainer/programmes/modele/inconnu');
    await attendre(t, 3);
    expect(find.text('Programme introuvable'), findsOneWidget);
    routeur(t).go('/entrainer/routines/inconnue/modifier');
    await attendre(t, 3);
    expect(find.text('Routine introuvable'), findsOneWidget);
    routeur(t).go('/entrainer/programmes/inconnu/modifier');
    await attendre(t, 3);
    expect(find.text('Programme introuvable'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('les trois volets : un lien vers un volet est suivi même après un changement à la main', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await t.runAsync(prechargerCorps);
    t.view.physicalSize = tailleMaquette;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final app = _AppOnglets(data: data);
    await t.pumpWidget(app);
    await attendre(t, 2);

    // Un lien de l'accueil ouvre les programmes.
    app.router.go('/entrainer/programmes');
    await attendre(t, 3);
    expect(find.text('Créer un programme'), findsOneWidget);
    // On passe aux routines à la main, puis on revient à l'accueil.
    await t.tap(find.text('Routines'));
    await attendre(t, 2);
    expect(find.text('Nouvel entraînement'), findsOneWidget);
    app.router.go('/accueil');
    await attendre(t, 2);
    // Revenir sur l'onglet garde le volet où l'on était.
    app.router.go('/entrainer');
    await attendre(t, 3);
    // Le même lien doit de nouveau montrer les programmes.
    app.router.go('/accueil');
    await attendre(t, 2);
    app.router.go('/entrainer/programmes');
    await attendre(t, 3);
    expect(find.text('Créer un programme'), findsOneWidget, reason: 'le lien « programmes » de l\'accueil doit ouvrir les programmes');
    expect(find.text('Nouvel entraînement'), findsNothing);

    // Aller dans une page puis revenir garde le volet.
    await t.tap(find.text('Routines'));
    await attendre(t, 2);
    await t.tap(find.text('Programmes'));
    await attendre(t, 2);
    await t.tap(find.text('DT COACH Tristan V3'));
    await attendre(t, 4);
    expect(find.text('Ajouter une routine au programme'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Retour'));
    await attendre(t, 4);
    expect(find.text('Créer un programme'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('nom libre et sigles : cas limites', () {
    expect(nomLibre('PPL', {}), 'PPL');
    expect(nomLibre('PPL', {'PPL'}), 'PPL (2)');
    expect(nomLibre('PPL', {'PPL', 'PPL (2)'}), 'PPL (3)');
    expect(sigleProgramme(''), '?');
    expect(sigleProgramme('   '), '?');
    expect(sigleProgramme('é'), 'É');
    expect(sigleProgramme('5x5'), '5X');
    expect(sigleProgramme('💪'), isNotEmpty);
    expect(couvertureProgramme('').gros, '?');
    expect(couvertureProgramme(_long).haut, 'PROGRAMME DE');
    expect(couvertureProgramme(_long).gros, '12');
  });
}
