import 'package:aesthetic/features/progres/logic/bilan_mois.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_bilan_banc.dart';
import 'test_bilan_jeux.dart';

/// Le résumé annuel : les dix pages du bilan, calculées sur une année.
/// Images dans build/rendus/bilan/annuel-*.png.
void main() {
  test('une année : une ligne par mois, douze mois de régularité, comparée à l\'année d\'avant', () {
    final sessions = jeuNormal();
    final b = BilanMois.calculerAnnee(2026, sessions, (_) => null, now: maintenantBilan);
    expect(b.annuel, isTrue);
    final en2026 = sessions.where((s) => s.debut.year == 2026).length;
    expect(b.nbSeances, en2026);
    // Une ligne par mois où il y a eu une séance, pas une par séance.
    expect(b.seances.length, lessThanOrEqualTo(12));
    expect(b.seances.first.nom, startsWith('Janvier'));
    expect(b.regularite.length, 12);
    expect(b.regularite.first.mois, DateTime(2026));
    expect(b.volumes.length, 12);
    expect(b.titre, 'ANNÉE\n2026');
    expect(b.enPeriode, 'en 2026');
    expect(b.contreAvant, 'par rapport à 2025');
  });

  test('un mois garde ses mots et ses neuf mois de régularité', () {
    final b = BilanMois.calculer(moisBilan, jeuNormal(), (_) => null, now: maintenantBilan);
    expect(b.annuel, isFalse);
    expect(b.regularite.length, 9);
    expect(b.titre, 'SEPTEMBRE\n2026');
    expect(b.contreAvant, 'par rapport à août');
    expect(b.dePeriode, 'de septembre');
  });

  for (final (nom, taille) in [('360', const Size(360, 760)), ('320', const Size(320, 568)), ('fold', const Size(700, 840))]) {
    testWidgets('bilan annuel en $nom : les dix pages tiennent', (t) async {
      final banc = await monterBilan(
        t,
        sessions: jeuNormal(),
        exercices: exercicesExtremes(),
        mois: moisBilan,
        annee: 2026,
        maintenant: maintenantBilan,
        taille: taille,
      );
      expect(find.text('Résumé\nannuel'), findsOneWidget);
      final soucis = <String>[];
      for (final page in PageBilan.values) {
        await allerA(t, page);
        final e = t.takeException();
        if (e != null) soucis.add('${page.name} : exception $e');
        for (final x in banc.textesRognes(t)) {
          soucis.add('${page.name} : texte rogné « $x »');
        }
        for (final x in banc.textesHorsEcran(t, sauf: {'TOP EXERCICES'})) {
          soucis.add('${page.name} : texte hors écran « $x »');
        }
        await capturer(t, 'annuel-$nom-${(page.index + 1).toString().padLeft(2, '0')}-${page.name}');
      }
      expect(soucis, isEmpty, reason: soucis.join('\n'));
    });
  }
}
