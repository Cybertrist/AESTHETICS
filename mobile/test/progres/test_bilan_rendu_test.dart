import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_bilan_banc.dart';
import 'test_bilan_jeux.dart';

/// Rendu des dix pages du bilan avec des données extrêmes, en étroit (360),
/// à la taille de la maquette (380), en petit (320) et en large (Fold
/// ouvert). Images dans build/rendus/bilan/.
///
/// Chaque page est contrôlée : aucune exception de mise en page, aucun texte
/// rogné sans points de suspension, aucun texte hors de l'écran.
void main() {
  const tailles = {
    '360': Size(360, 760),
    '380': Size(380, 805),
    '320': Size(320, 568),
    'large': Size(900, 800),
    'fold': Size(700, 840),
  };

  final jeux = <String, (List<WorkoutSession> Function(), List<String>)>{
    'normal': (jeuNormal, ['360', '380', '320', 'large', 'fold']),
    'vide': (() => const [], ['360']),
    'moisvide': (jeuMoisVide, ['360']),
    'une': (jeuUneSeance, ['360', '320']),
    'quarante': (jeuQuarante, ['360', '320', 'large']),
    'extreme': (jeuExtreme, ['360', '320', 'large']),
    'sanscharge': (jeuSansCharge, ['360']),
  };

  for (final jeu in jeux.entries) {
    for (final nomTaille in jeu.value.$2) {
      testWidgets('bilan ${jeu.key} en $nomTaille : les dix pages tiennent', (t) async {
        final taille = tailles[nomTaille]!;
        final banc = await monterBilan(
          t,
          sessions: jeu.value.$1(),
          exercices: exercicesExtremes(),
          mois: moisBilan,
          maintenant: maintenantBilan,
          taille: taille,
        );
        final soucis = <String>[];
        for (final page in PageBilan.values) {
          await allerA(t, page);
          expect(find.bySemanticsLabel('Page ${page.index + 1} sur 10'), findsOneWidget);
          final e = t.takeException();
          if (e != null) soucis.add('${page.name} : exception $e');
          for (final x in banc.textesRognes(t)) {
            soucis.add('${page.name} : texte rogné « $x »');
          }
          // Le bandeau penché des favoris déborde exprès.
          for (final x in banc.textesHorsEcran(t, sauf: {'TOP EXERCICES'})) {
            soucis.add('${page.name} : texte hors écran « $x »');
          }
          await capturer(t, '${jeu.key}-$nomTaille-${(page.index + 1).toString().padLeft(2, '0')}-${page.name}');
        }
        expect(soucis, isEmpty, reason: soucis.join('\n'));
      });
    }
  }
}
