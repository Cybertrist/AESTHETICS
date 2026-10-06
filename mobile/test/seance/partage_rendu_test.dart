import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/objet_3d.dart';
import 'package:aesthetic/features/seance/pages/equivalent_page.dart';
import 'package:aesthetic/features/seance/pages/partager_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

/// Encoche de la maquette : la barre d'état du téléphone (20 px × 1,25).
void _encoche(WidgetTester t) {
  t.view.padding = const FakeViewPadding(top: 25);
  addTearDown(t.view.resetPadding);
}

Equivalent _avec(double kg, String asset) =>
    [for (var g = 0; g < 200; g++) equivalentPour(kg, graine: g)].firstWhere((e) => e.asset == asset);

void main() {
  testWidgets('rendu : cartes de fin de séance', (t) async {
    await t.runAsync(chargerPolices);
    t.view.physicalSize = tailleMaquette;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    _encoche(t);
    final theme = AccentController().theme;
    for (final (nom, kg, volume, asset, fichier) in [
      ('Abdos', 320.0, '320', Objets3D.chat, 'chats'),
      ('Push', 6480.0, '6 480', Objets3D.mammouth, 'mammouth'),
      ('Jambes', 11000.0, '11 000', Objets3D.moai, 'moai'),
      ('Bras', 1000.0, '1 000', Objets3D.burger, 'burgers'),
    ]) {
      await t.pumpWidget(RepaintBoundary(
        key: cleCapture,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: CarteFinDeSeance(nom: nom, volume: volume, unite: 'kg', equivalent: _avec(kg, asset), onFermer: () {}, onPartager: () {}),
        ),
      ));
      await precharger(t, [asset]);
      await attendre(t, tours: 2);
      expect(t.takeException(), isNull, reason: fichier);
      await capture(t, 'equivalent-$fichier');
    }
  });

  testWidgets('rendu : équivalent de la séance de démo et carrousel de partage', (t) async {
    _encoche(t);
    final data = await monter(t, depart: '/');
    // Une séance sans photo : les plus récentes de la démo en portent.
    final s = data.sessions.sessions.firstWhere((x) => x.medias.isEmpty && x.volume > 0);
    final routeur = routeurDe(t);
    await precharger(t, [for (final o in objetsEquivalents) o.asset]);

    routeur.go(SeancePaths.equivalent(s.id));
    await attendre(t);
    expect(find.byType(EquivalentPage), findsOneWidget);
    expect(find.textContaining('séance terminée'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, 'equivalent-demo');

    routeur.go(SeancePaths.partager(s.id));
    await attendre(t, tours: 12);
    expect(find.text('Poids soulevé'), findsOneWidget);
    // Six cartes quand la séance a battu un record, cinq sinon.
    final nombre = t.state<PartagerPageState>(find.byType(PartagerPage)).nombreCartes;
    for (var i = 0; i < nombre; i++) {
      if (i > 0) {
        await t.drag(find.byType(PageView), const Offset(-330, 0));
        await attendre(t, tours: 5);
      }
      expect(t.takeException(), isNull, reason: 'carte ${i + 1}');
      await capture(t, 'partager-${i + 1}');
    }
    expect(find.text('Ta photo ici'), findsOneWidget);
    await demonter(t);
  });
}
