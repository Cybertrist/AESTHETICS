// Page de la flamme : semaines d'affilée et calendrier de la série.
// `RENDUS=1 flutter test test/aujourdhui/serie_page_test.dart` écrit les
// images dans build/rendus/aujourdhui/.
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/aujourdhui/pages/serie_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

final _maintenant = DateTime(2026, 10, 3, 12);

WorkoutSession _seance(String id, DateTime d) => WorkoutSession(id: id, nom: 'Push', debut: d, fin: d.add(const Duration(hours: 1)));

void main() {
  setUpAll(() async {
    preparerAssets();
    await polices();
  });

  for (final taille in const [Size(360, 780), Size(412, 915), Size(700, 900)]) {
    testWidgets('série de 17 semaines en ${taille.width.toInt()} de large', (t) async {
      final data = (await t.runAsync(() => donnees(demo: false)))!;
      // Une séance par semaine pendant 17 semaines, plusieurs en septembre.
      final jours = <DateTime>[
        for (var s = 0; s < 17; s++) DateTime(2026, 9, 29).subtract(Duration(days: 7 * s)).add(const Duration(hours: 18)),
        for (final j in [1, 4, 7, 8, 9, 10, 14, 15, 16, 21, 22, 26]) DateTime(2026, 9, j, 18),
        DateTime(2026, 9, 30, 18),
      ];
      await t.runAsync(() => data.sessions.addAll([for (var i = 0; i < jours.length; i++) _seance('s$i', jours[i])]));
      await rendreAccueil(t, data, 'serie-${taille.width.toInt()}', taille, _maintenant, page: SeriePage(maintenant: _maintenant));
      expect(find.bySemanticsLabel('17 semaines d\'affilée'), findsOneWidget);
      expect(find.text('semaines d\'affilée !'), findsOneWidget);
      expect(find.text('Octobre 2026'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Mois précédent'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Septembre 2026'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => rendreCapture(t, 'serie-${taille.width.toInt()}-septembre'));
    });
  }

  testWidgets('aucune séance : zéro, flamme éteinte, rien ne casse', (t) async {
    final data = (await t.runAsync(() => donnees(demo: false)))!;
    await rendreAccueil(t, data, 'serie-vide', const Size(412, 915), _maintenant, page: SeriePage(maintenant: _maintenant));
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('ta série démarre'), findsOneWidget);
  });
}
