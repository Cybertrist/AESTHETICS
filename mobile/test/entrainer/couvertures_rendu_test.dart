import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/corps_colore.dart';
import 'package:aesthetic/features/entrainer/routines/logic/idees.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/couverture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'outils.dart';

/// Couvertures des idées de programmes sur un téléphone étroit : le titre
/// ne touche jamais le personnage, et le texte sous les cartes s'aligne.
/// Images dans build/rendus/couvertures.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final maintenant = DateTime.now();

  /// Sur chaque couverture visible, l'image finit avant le titre, et le
  /// titre et son bandeau tiennent dans la couverture.
  void verifierCouvertures(WidgetTester t) {
    final couvertures = find.byType(CouvertureIdee);
    expect(couvertures, findsWidgets);
    for (final e in couvertures.evaluate()) {
      final w = e.widget as CouvertureIdee;
      final soi = find.byWidget(w);
      final cadre = t.getRect(soi);
      final titre = t.getRect(find.descendant(of: soi, matching: find.text(w.idee.gros.toUpperCase())));
      final images = [
        ...find.descendant(of: soi, matching: find.byType(CorpsColore)).evaluate(),
        ...find.descendant(of: soi, matching: find.byType(Image)).evaluate(),
      ];
      expect(images, isNotEmpty, reason: '${w.idee.gros} : une image');
      for (final i in images) {
        final r = t.getRect(find.byWidget(i.widget));
        expect(r.bottom, lessThanOrEqualTo(titre.top), reason: '${w.idee.gros} : l\'image passe sous le titre');
        expect(r.top, greaterThanOrEqualTo(cadre.top + 8), reason: '${w.idee.gros} : marge du haut');
      }
      expect(titre.left, greaterThanOrEqualTo(cadre.left + 8), reason: '${w.idee.gros} : le titre déborde');
      expect(titre.right, lessThanOrEqualTo(cadre.right - 8), reason: '${w.idee.gros} : le titre déborde');
      expect((titre.center.dx - cadre.center.dx).abs(), lessThan(1), reason: '${w.idee.gros} : titre centré');
      if (w.idee.bandeau != null) {
        final b = t.getRect(find.descendant(of: soi, matching: find.text(w.idee.bandeau!.toUpperCase())));
        expect(b.top, greaterThanOrEqualTo(titre.bottom), reason: '${w.idee.gros} : bandeau sous le titre');
        expect(b.bottom, lessThanOrEqualTo(cadre.bottom - 6), reason: '${w.idee.gros} : bandeau dans la couverture');
        expect(b.left, greaterThanOrEqualTo(cadre.left + 8), reason: '${w.idee.gros} : le bandeau déborde');
        expect(b.right, lessThanOrEqualTo(cadre.right - 8), reason: '${w.idee.gros} : le bandeau déborde');
      }
    }
  }

  for (final taille in const [Size(360, 780), Size(412, 915)]) {
    final l = taille.width.toInt();

    testWidgets('idées de programmes en $l de large', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
      await lancer(t, data, '/entrainer/programmes/idees', taille: taille);
      await attendre(t, 6);
      expect(find.text('Idées de programmes'), findsOneWidget);
      verifierCouvertures(t);

      // Le texte sous les cartes : même ligne de départ, même hauteur.
      final hauts = <double>{};
      for (final i in ideesClassiques()) {
        final f = find.text(i.idee.titre);
        if (f.evaluate().isNotEmpty) hauts.add(t.getTopLeft(f.first).dy);
      }
      expect(hauts, hasLength(1), reason: 'les noms partent de la même ligne');
      await capturer(t, 'couvertures', 'idees-$l-debut');

      // Les deux rangées défilent : chaque couverture passe à l'écran.
      final rangees = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
      expect(rangees, findsAtLeastNWidgets(2));
      for (var pas = 1; pas <= 3; pas++) {
        for (var r = 0; r < 2; r++) {
          await t.drag(rangees.at(r), const Offset(-330, 0));
        }
        await attendre(t, 5);
        verifierCouvertures(t);
        await capturer(t, 'couvertures', 'idees-$l-suite$pas');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('détail d\'une idée, programme et liste en $l de large', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
      await lancer(t, data, '/entrainer/programmes/modele/push-pull-legs-6j', taille: taille);
      await attendre(t, 6);
      verifierCouvertures(t);
      await capturer(t, 'couvertures', 'detail-$l');

      routeur(t).go('/entrainer/programmes/p-v3');
      await attendre(t, 6);
      final couverture = t.getRect(find.byType(CouvertureProgramme));
      for (final texte in ['DT COACH', '3']) {
        final r = t.getRect(find.descendant(of: find.byType(CouvertureProgramme), matching: find.text(texte)));
        expect(r.left, greaterThanOrEqualTo(couverture.left + 8));
        expect(r.right, lessThanOrEqualTo(couverture.right - 8));
        expect(r.top, greaterThanOrEqualTo(couverture.top + 8));
        expect(r.bottom, lessThanOrEqualTo(couverture.bottom - 8));
      }
      await capturer(t, 'couvertures', 'programme-$l');

      routeur(t).go('/entrainer');
      await attendre(t, 6);
      expect(find.byType(TuileProgramme), findsWidgets);
      await capturer(t, 'couvertures', 'liste-$l');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('planche : toutes les couvertures, trois tailles, titre long', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer/programmes/idees', taille: const Size(412, 915));
    await attendre(t, 6);
    const longue = IdeeProgramme(
      modeleId: 'full-body-3j',
      gros: 'Haut du corps et bas du corps',
      bandeau: 'Quatre jours par semaine au moins',
      titre: 'Titre long',
      face: {},
      dos: {},
      poses: ['inconnu'],
    );
    final theme = Theme.of(t.element(find.byType(CouvertureIdee).first));
    await t.pumpWidget(
      RepaintBoundary(
        key: cleCapture,
        child: ChangeNotifierProvider<ExerciseRepo>.value(
          value: data.exercises,
          child: Theme(data: theme, child: MediaQuery(
            data: const MediaQueryData(size: Size(412, 915), textScaler: TextScaler.linear(1.3)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final i in ideesProgrammes) CouvertureIdee(i, cote: 128),
                      const CouvertureIdee(longue, cote: 128),
                      CouvertureIdee(ideesProgrammes[1], cote: 96),
                      CouvertureIdee(ideesProgrammes[1], cote: 215),
                      const CouvertureProgramme('Programme au nom vraiment très long V12', cote: 128),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ),
      ),
    );
    await attendre(t, 6);
    expect(t.takeException(), isNull);
    await capturer(t, 'couvertures', 'planche');
  });
}
