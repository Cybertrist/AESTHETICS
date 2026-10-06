import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

void main() {
  setUpAll(preparerAssets);

  testWidgets('nouvel utilisateur : états vides', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: false)))!;
    await parcours(t, data, 'vide', const Size(390, 2000));
    expect(find.text("Aucune séance pour l'instant"), findsOneWidget);
    expect(find.text('Choisir une séance'), findsOneWidget);
  });
}
