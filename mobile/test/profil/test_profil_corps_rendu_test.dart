import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/mensurations/mensurations_page.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:aesthetic/features/profil/widgets/maquette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_profil_banc.dart';

/// L'écran du corps : chacun des huit traits arrive sur le bon muscle, à
/// toutes les largeurs.
void main() {
  /// Calques du pack qui dessinent la zone visée par chaque mesure.
  const calques = {
    ZoneMesure.cou: ['cou'],
    ZoneMesure.poitrine: ['pectoraux'],
    ZoneMesure.taille: ['obliques', 'abdominaux'],
    ZoneMesure.cuisses: ['quadriceps'],
    ZoneMesure.epaules: ['deltoidesLateraux', 'deltoidesAnterieurs'],
    ZoneMesure.biceps: ['biceps'],
    ZoneMesure.avantBras: ['avantBras'],
    ZoneMesure.mollets: ['mollets'],
  };

  Future<(int, int, ByteData)> lire(String nom) async {
    final octets = await File('assets/body/pack/face_$nom.webp').readAsBytes();
    final codec = await ui.instantiateImageCodec(octets);
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return (image.width, image.height, data);
  }

  /// Opacité maximale du calque dans un petit carré autour du point.
  int opacite((int, int, ByteData) c, Offset fraction, {int rayon = 3}) {
    final (w, h, d) = c;
    final x0 = (fraction.dx * w).round();
    final y0 = (fraction.dy * h).round();
    var max = 0;
    for (var y = y0 - rayon; y <= y0 + rayon; y++) {
      for (var x = x0 - rayon; x <= x0 + rayon; x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final a = d.getUint8((y * w + x) * 4 + 3);
        if (a > max) max = a;
      }
    }
    return max;
  }

  testWidgets('chaque point visé tombe sur le calque de son muscle, et sur aucun autre', (t) async {
    final resultats = <String>[];
    await t.runAsync(() async {
      final base = await lire('base');
      expect(base.$1 / base.$2, closeTo(636 / 1500, 0.002), reason: 'proportions de l\'image du corps');
      final tous = <String, (int, int, ByteData)>{};
      for (final nom in {for (final l in calques.values) ...l, 'triceps', 'trapezes', 'adducteurs'}) {
        tous[nom] = await lire(nom);
        expect(tous[nom]!.$1 / tous[nom]!.$2, closeTo(base.$1 / base.$2, 0.002), reason: 'calque $nom');
      }
      for (final z in ZoneMesure.values) {
        // Sur le corps.
        expect(opacite(base, z.ancre) > 200, isTrue, reason: '${z.name} hors du corps');
        final touches = [for (final e in tous.entries) if (opacite(e.value, z.ancre, rayon: 2) > 60) e.key];
        resultats.add('${z.name} -> $touches');
        expect(touches.any(calques[z]!.contains), isTrue, reason: '${z.name} vise $touches au lieu de ${calques[z]}');
        expect(touches.every(calques[z]!.contains), isTrue, reason: '${z.name} déborde sur $touches');
      }
    });
    debugPrint(resultats.join('\n'));
  });

  testWidgets('rendu du corps en 360, 412 et en large : traits, points et étiquettes', (t) async {
    await polices(t);
    for (final (largeur, hauteur) in [(360.0, 740.0), (412.0, 915.0), (900.0, 1100.0)]) {
      ecran(t, largeur: largeur, hauteur: hauteur);
      final data = await donnees(t);
      await t.runAsync(() => data.health.addMeasurementsAll([
            BodyMeasurement(id: 'a', date: DateTime(2026, 6, 8, 8), poidsKg: 104.1, tours: {for (final tc in TourCorps.values) tc: 100}),
            // Les valeurs les plus larges plausibles : trois chiffres et demi.
            BodyMeasurement(id: 'b', date: DateTime(2026, 9, 28, 8), poidsKg: 108.4, masseGrassePct: 14.2, tours: {for (final tc in TourCorps.values) tc: 124.5}),
          ]));
      await monter(t, data, ProfilPaths.mensurations);
      await t.runAsync(() => precacheImage(const AssetImage('assets/body/pack/face_base.webp'), t.element(find.byType(CorpsMesures))));
      await attendre(t);
      expect(t.takeException(), isNull, reason: 'largeur $largeur');

      final cadre = t.getRect(find.byType(CorpsMesures));
      final corps = CorpsMesures.cadreCorps(cadre.width);
      // Le corps garde ses proportions et reste centré.
      expect(corps.width / corps.height, closeTo(636 / 1500, 0.001));
      expect(corps.center.dx, closeTo(cadre.width / 2, 0.01));
      final image = t.getRect(find.descendant(of: find.byType(CorpsMesures), matching: find.byType(Image)));
      expect(image.shift(-cadre.topLeft).left, closeTo(corps.left, 0.01));
      expect(image.width, closeTo(corps.width, 0.01));
      expect(image.height, closeTo(corps.height, 0.01));

      for (final z in ZoneMesure.values) {
        final ancre = CorpsMesures.ancre(z, cadre.width);
        expect(corps.contains(ancre), isTrue, reason: '${z.name} à $largeur');
        // Le point visé est le même point du corps à toutes les largeurs.
        expect((ancre.dx - corps.left) / corps.width, closeTo(z.ancre.dx, 1e-9));
        expect((ancre.dy - corps.top) / corps.height, closeTo(z.ancre.dy, 1e-9));

        // L'étiquette : entièrement dans l'écran, sa valeur ne passe pas
        // sous le départ du trait, et elle ne recouvre pas le corps.
        final etiquette = find.bySemanticsLabel(RegExp('^${z.label}, 124,5 centimètres'));
        expect(etiquette, findsOneWidget, reason: z.name);
        final r = t.getRect(etiquette).shift(-cadre.topLeft);
        expect(r.left >= -0.01 && r.right <= cadre.width + 0.01, isTrue, reason: z.name);
        final valeur = t.getRect(find.descendant(of: etiquette, matching: find.textContaining('124,5'))).shift(-cadre.topLeft);
        final departTrait = z.aGauche ? e(58) : cadre.width - e(58);
        if (z.aGauche) {
          expect(valeur.right <= departTrait, isTrue, reason: '${z.name} à $largeur : la valeur (${valeur.right}) passe sous le trait ($departTrait)');
          expect(r.right <= corps.left, isTrue, reason: '${z.name} à $largeur : étiquette sur le corps');
        } else {
          expect(valeur.left >= departTrait, isTrue, reason: '${z.name} à $largeur : la valeur (${valeur.left}) passe sous le trait ($departTrait)');
          expect(r.left >= corps.right, isTrue, reason: '${z.name} à $largeur : étiquette sur le corps');
        }
        // Cible de toucher confortable.
        expect(r.height >= 48 && r.width >= 48, isTrue, reason: z.name);
      }
      // Le palier du trait s'arrête avant le corps.
      expect(e(76) <= corps.left + ZoneMesure.taille.ancre.dx * corps.width, isTrue, reason: 'palier dans le corps à $largeur');

      await t.runAsync(() => photo(t, 'corps-${largeur.round()}', ratio: 3));
      await t.pumpWidget(const SizedBox());
    }
  });
}
