import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_profil_banc.dart';

void main() {
  tearDown(() {
    Affichage.pouces = false;
    Affichage.miles = false;
  });

  test('distances : kilomètres par défaut, miles sur demande, aller-retour sans perte', () {
    expect(Affichage.distance(5200), '5,2 km');
    expect(Affichage.distance(800), '800 m');
    expect(Affichage.distanceStockee(5), 5000);
    Affichage.miles = true;
    expect(Affichage.distance(5000), '3,11 mi');
    expect(Affichage.distance(800), '0,5 mi');
    expect(Affichage.distanceLabel, 'mi');
    expect(Affichage.distanceAffichee(Affichage.distanceStockee(3.1)), 3.1);
  });

  test('longueurs : centimètres par défaut, pouces au dixième', () {
    expect(Affichage.longueurTexte(39), '39 cm');
    Affichage.pouces = true;
    expect(Affichage.longueurTexte(39), '15,4 po');
    expect(Affichage.ecartLongueur(null), isNull);
    expect(Affichage.longueurStockee(15), closeTo(38.1, 1e-9));
    final cou = ChampSaisie.tous().firstWhere((c) => c.cle == 'cou');
    expect((cou.unite, cou.pas, cou.facteur), ('po', 0.25, 2.54));
    expect(ChampSaisie.tous().first.unite, 'kg', reason: 'le poids ne change pas');
  });

  testWidgets('réglages : choisir pouces et miles, les mensurations suivent, le profil les garde', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await t.runAsync(() => data.health.addMeasurementsAll([
          BodyMeasurement(id: 'a', date: DateTime(2026, 9, 28, 8), poidsKg: 76.7, tours: const {TourCorps.cou: 39}, source: 'manuel'),
        ]));
    final router = await monter(t, data, '/reglages/unites');
    for (final x in ['Kilogrammes', 'Livres', 'Kilomètres', 'Miles', 'Centimètres', 'Pouces']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await t.runAsync(() => photo(t, 'reglages-unites'));
    await t.tap(find.text('Pouces'));
    await attendre(t, 2);
    await t.tap(find.text('Miles'));
    await attendre(t, 2);
    expect((data.profile.profile!.pouces, data.profile.profile!.miles), (true, true));
    expect(UserProfile.fromJson(data.profile.profile!.toJson()).pouces, isTrue);

    router.go(ProfilPaths.mensurations);
    await attendre(t);
    expect(find.textContaining('15,4', findRichText: true), findsOneWidget);
    expect(find.textContaining('po', findRichText: true), findsWidgets);
    expect(t.takeException(), isNull);
    await t.runAsync(() => photo(t, 'mensurations-pouces'));

    router.go('/reglages');
    await attendre(t);
    expect(find.text('kg, mi, po'), findsOneWidget);
  });
}
