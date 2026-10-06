import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/progres/progres_paths.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/sante/recuperation/recuperation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _pose(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 500));
  }
}

/// Progrès dans l'appli entière, avec le vrai routeur : l'onglet, le bilan
/// du mois en plein écran, et les écrans des autres modules ouverts depuis
/// Progrès. Dépend des autres modules : s'il casse sans changement ici,
/// regarder d'abord leurs routes.
void main() {
  testWidgets('Progrès dans l\'appli : onglet, bilan plein écran, liens vers les autres modules', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await data.loadAll();
      await DemoData.seed(data);
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          await BodyImageRepository.load(v, f);
        }
      }
    });
    await t.pumpWidget(AestheticApp(data: data, accent: AccentController()));
    await _pose(t);
    // La dernière page, cherchée jusque dans les coquilles : l'appli entière
    // vit maintenant dans un `ShellRoute` (barre de la séance en cours).
    String lieu() {
      final conf = GoRouter.of(rootNavigatorKey.currentContext!).routerDelegate.currentConfiguration;
      RouteMatchBase dernier = conf.matches.last;
      while (dernier is ShellRouteMatch) {
        dernier = dernier.matches.last;
      }
      return (dernier is ImperativeRouteMatch ? dernier.matches.uri : conf.uri).toString();
    }
    final barre = find.byType(AppBottomNav);

    // L'onglet.
    await t.tap(find.descendant(of: barre, matching: find.text('Progrès')));
    await _pose(t);
    expect(find.byType(ProgresPage), findsOneWidget);
    expect(barre.hitTestable(), findsOneWidget);

    // Le résumé mensuel : plein écran, par-dessus la barre ; la croix revient.
    // Il est sur la vue Mois, pour un mois terminé.
    await t.tap(find.text('Mois'));
    await _pose(t);
    await t.tap(find.bySemanticsLabel('Période précédente'));
    await _pose(t);
    final carte = find.byType(CarteResumeMensuel);
    await t.scrollUntilVisible(carte, 300, scrollable: find.descendant(of: find.byType(ProgresPage), matching: find.byType(Scrollable)).first);
    // Entièrement au-dessus de la barre des onglets.
    await t.ensureVisible(carte);
    await _pose(t);
    await t.tap(carte);
    await _pose(t);
    expect(find.byType(BilanStoryPage), findsOneWidget);
    expect(barre.hitTestable(), findsNothing);
    await t.tap(find.byTooltip('Fermer le bilan'));
    await _pose(t);
    expect(find.byType(BilanStoryPage), findsNothing);
    expect(find.byType(ProgresPage), findsOneWidget);
    expect(t.takeException(), isNull);

    // Mensurations (module Profil) puis retour.
    final ctx = t.element(find.byType(ProgresPage));
    GoRouter.of(ctx).push(ProgresPaths.mensurations);
    await _pose(t);
    expect(lieu(), ProgresPaths.mensurations);
    _autreModule(t, 'mensurations');
    GoRouter.of(rootNavigatorKey.currentContext!).pop();
    await _pose(t);
    expect(lieu(), ProgresPaths.racine);

    // Photos (module Profil) puis retour.
    GoRouter.of(ctx).push(ProgresPaths.photos);
    await _pose(t);
    expect(lieu(), ProgresPaths.photos);
    _autreModule(t, 'photos');
    GoRouter.of(rootNavigatorKey.currentContext!).pop();
    await _pose(t);

    // Récupération dans l'onglet, puis un muscle : l'explorateur d'Entraîner.
    GoRouter.of(ctx).push(ProgresPaths.recuperation);
    await _pose(t);
    expect(find.byType(RecuperationPage), findsOneWidget);
    expect(barre.hitTestable(), findsOneWidget);
    await t.tap(find.byType(VignetteMuscle).first);
    await _pose(t);
    expect(lieu(), ProgresPaths.explorateur('pectoraux'));
    _autreModule(t, 'explorateur de muscles');

    // Depuis l'accueil : le bilan s'ouvre par-dessus et rend la main à l'accueil.
    GoRouter.of(rootNavigatorKey.currentContext!).go('/');
    await _pose(t);
    GoRouter.of(rootNavigatorKey.currentContext!).push('/progres/bilan?mois=2026-9&page=serie');
    await _pose(t);
    expect(find.byType(BilanStoryPage), findsOneWidget);
    expect(find.bySemanticsLabel('Page 6 sur 10'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Fermer le bilan'));
    await _pose(t);
    expect(find.byType(BilanStoryPage), findsNothing);
    expect(lieu(), '/');
    expect(t.takeException(), isNull);
  });
}

/// Les écrans des autres modules sont rendus ici avec la police de test,
/// plus large que Figtree : leurs débordements ne sont pas l'affaire de ce
/// test, qui ne vérifie que la navigation. On les signale sans échouer.
void _autreModule(WidgetTester t, String ecran) {
  Object? e;
  while ((e = t.takeException()) != null) {
    debugPrint('Autre module ($ecran) : ${e.toString().split('\n').first}');
  }
}
