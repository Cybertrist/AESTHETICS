import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/ui/objet_3d.dart';
import 'package:aesthetic/features/seance/pages/equivalent_page.dart';
import 'package:aesthetic/features/seance/widgets/cartes_partage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc_partage.dart';

Equivalent _avec(double kg, String asset, {bool mois = false}) =>
    [for (var g = 0; g < 200; g++) equivalentPour(kg, graine: g, mois: mois)].firstWhere((e) => e.asset == asset);

/// L'habillage de la page de partage autour d'une carte seule.
Widget _page(Widget carte, int actif) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22.5, 12.5, 22.5, 12.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BoutonRond(icone: Icons.close_rounded, label: 'Fermer', onTap: () {}),
                  BoutonRond(icone: Icons.add_rounded, label: 'Choisir une photo', onTap: () {}),
                ],
              ),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(22.5, 5, 22.5, 0), child: carte)),
            Padding(padding: const EdgeInsets.only(top: 15, bottom: 2.5), child: PointsPagination(nombre: 5, actif: actif)),
            const SizedBox(height: 92.5),
          ],
        ),
      ),
    );

/// Cartes aux données de la maquette, à comparer aux captures 14 à 28.
void main() {
  const jambes = {
    Muscle.quadriceps: 1.0,
    Muscle.mollets: 1.0,
    Muscle.adducteurs: 0.8,
    Muscle.fessiers: 1.0,
    Muscle.ischios: 1.0,
    Muscle.lombaires: 0.8,
  };

  testWidgets('rendu : cartes de fin de séance de la maquette', (t) async {
    await preparerPartage(t);
    for (final (nom, kg, volume, asset, fichier) in [
      ('Abdos', 320.0, '320', Objets3D.chat, 'chats'),
      ('Push', 6480.0, '6 480', Objets3D.mammouth, 'mammouth'),
      ('Jambes', 11000.0, '11 000', Objets3D.moai, 'moai'),
      ('Bras', 1000.0, '1 000', Objets3D.burger, 'burgers'),
    ]) {
      final e = _avec(kg, asset);
      await poserPartage(
        t,
        CarteFinDeSeance(nom: nom, volume: volume, unite: 'kg', equivalent: e, onFermer: () {}, onPartager: () {}),
        assets: [asset],
      );
      expect(find.text('${nom.toUpperCase()} · séance terminée'), findsOneWidget);
      expect(find.text('Partager'), findsOneWidget);
      expect(t.takeException(), isNull, reason: fichier);
      await capturePartage(t, 'equivalent-$fichier');
    }
  });

  testWidgets('rendu : les cinq cartes de partage de la maquette', (t) async {
    await preparerPartage(t);
    final cartes = <Widget>[
      const CarteResume(volume: '10 348 kg', duree: '1 h 27', series: 17, intensites: jambes),
      CarteEquivalent(volume: '10 348 kg', equivalent: _avec(10348, Objets3D.moai, mois: true)),
      const CarteDetail(
        date: '12 août 2026',
        nom: 'Jambes',
        resume: '10 348 kg · 1 h 27',
        lignes: ['4 × Mollets assis', '3 × Leg curl allongé', '3 × Leg extension', '3 × Presse à cuisses', '3 × Extension lombaire', '1 × Marche inclinée'],
        intensites: jambes,
      ),
      const CarteSerie(semaines: 17, libelle: 'semaines d\'affilée !', phrase: 'Tu t\'entraînes depuis 17 semaines sans pause.'),
      const CarteAutocollant(nom: 'Jambes', volume: '10 348 kg', series: 17, duree: '1 h 27'),
    ];
    for (var i = 0; i < cartes.length; i++) {
      await poserPartage(t, _page(cartes[i], i), assets: [Objets3D.moai]);
      expect(t.takeException(), isNull, reason: 'carte ${i + 1}');
      await capturePartage(t, 'partager-maquette-${i + 1}');
    }
  });
}
