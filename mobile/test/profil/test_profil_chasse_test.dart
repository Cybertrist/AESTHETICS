import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';

import 'package:aesthetic/core/env.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/profil/photos/cadrage.dart';
import 'package:aesthetic/features/profil/pages/reglages/a_propos_section.dart';
import 'package:aesthetic/features/profil/pages/reglages/donnees_section.dart';
import 'package:aesthetic/features/profil/pages/reglages_page.dart';
import 'package:aesthetic/features/profil/photos/photos_page.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:aesthetic/features/profil/widgets/maquette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_profil_banc.dart';

/// Défauts relevés sur l'émulateur le 2 octobre (CHASSE.md, zone PROFIL).
void main() {
  BodyMeasurement m(String id, DateTime d, {double? poids, Map<TourCorps, double> tours = const {}}) =>
      BodyMeasurement(id: id, date: d, poidsKg: poids, tours: tours, source: 'manuel');

  /// Chaque sous-page des réglages, avec le titre attendu.
  const sousPages = <String, String>{
    '/reglages/unites': 'Unités',
    '/reglages/entrainement': 'Paramètres de séance',
    '/reglages/entrainement/disques': 'Barres et disques',
    '/reglages/notifications': 'Notifications',
    '/reglages/donnees': 'Mes données',
    '/reglages/donnees/sauvegardes': 'Copies du téléphone',
    '/reglages/donnees/effacer': 'Tout effacer',
    '/reglages/a-propos': 'À propos',
  };

  testWidgets('point 3 : chaque sous-page des réglages a l\'habillage de la page Réglages, en 360, 412 et en large', (t) async {
    await polices(t);
    for (final (l, h) in [(412.0, 915.0), (360.0, 740.0), (900.0, 1100.0)]) {
      ecran(t, largeur: l, hauteur: h);
      final data = await donnees(t);
      final router = await monter(t, data, '/reglages');
      for (final e in sousPages.entries) {
        router.go(e.key);
        await attendre(t);
        expect(t.takeException(), isNull, reason: '${e.key} en $l');
        // Le même en-tête : bouton retour rond gris, titre de la maquette.
        expect(find.byType(PageMaquette), findsOneWidget, reason: e.key);
        expect(find.byType(SubPageScaffold), findsNothing, reason: e.key);
        expect(t.widget<PageMaquette>(find.byType(PageMaquette)).titre, e.value);
        expect(t.widget<PageMaquette>(find.byType(PageMaquette)).retourPlein, isTrue, reason: e.key);
        // Plus d'icône à halo coloré ni de carte de l'ancien habillage.
        expect(find.byType(IconHalo), findsNothing, reason: e.key);
        expect(find.byType(TileGroup), findsNothing, reason: e.key);
        expect(find.byType(AppCard), findsNothing, reason: e.key);
        // Interrupteurs blancs.
        final c = t.element(find.byType(PageMaquette)).colors;
        for (final s in t.widgetList<Switch>(find.byType(Switch))) {
          expect(s.activeTrackColor, c.bouton, reason: e.key);
        }
        await t.runAsync(() => photo(t, 'chasse${e.key.replaceAll('/', '-')}-${l.round()}'));
      }
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('point 3 : interrupteurs, incrément et rappel changent bien le réglage', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await monter(t, data, '/reglages/entrainement');
    final avant = data.settings.settings.sonMinuteur;
    await t.tap(find.text('Son en fin de repos'));
    await attendre(t, 2);
    expect(data.settings.settings.sonMinuteur, !avant);

    await t.scrollUntilVisible(find.text('Incrément de poids'), 250, scrollable: find.byType(Scrollable).first);
    await attendre(t, 1);
    await t.tap(find.text('Incrément de poids'));
    await attendre(t, 2);
    await t.runAsync(() => photo(t, 'chasse-increment-panneau'));
    await t.tap(find.text('1,25 kg'));
    await attendre(t, 2);
    expect(data.settings.settings.incrementPoidsKg, 1.25);
    expect(find.text('1,25 kg'), findsOneWidget);

  });

  testWidgets('point 4 : en musculation seule, aucun texte des modules rangés', (t) async {
    expect(Env.muscuSeule, isTrue, reason: 'les tests tournent sans COMPLET=true');
    await polices(t);
    ecran(t, hauteur: 2400);
    final data = await donnees(t);
    final router = await monter(t, data, '/reglages/a-propos');
    final interdits = RegExp('nutrition|sommeil|coach|repas|compléments|boire|alimentaire|Health Connect', caseSensitive: false);
    for (final chemin in ['/reglages/a-propos', '/reglages/donnees', '/reglages/notifications', '/reglages/donnees/effacer']) {
      router.go(chemin);
      await attendre(t);
      final textes = [
        for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? '',
      ];
      expect(textes.where(interdits.hasMatch), isEmpty, reason: chemin);
    }
    expect(AProposSection.accroche, 'Ta musculation, sur ton téléphone.');
    expect(interdits.hasMatch(AProposSection.confidentialite), isFalse);
    expect(interdits.hasMatch(DonneesSection.detailExport), isFalse);
    expect(interdits.hasMatch(DonneesSection.detailEffacer), isFalse);
    router.go('/reglages/notifications');
    await attendre(t);
    expect(find.text('Rappel d\'entraînement'), findsOneWidget);
    expect(find.text('COMPLÉMENTS'), findsNothing);
    expect(find.text('EAU'), findsNothing);
  });

  testWidgets('point 17 : « Dernière saisie » annonce la saisie la plus récente, même sans tour', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('a', DateTime(2026, 9, 19, 8), poids: 76.5, tours: {TourCorps.cou: 38.5, TourCorps.taille: 79}),
          m('b', DateTime(2026, 9, 27, 8), poids: 77),
          m('c', DateTime(2026, 9, 30, 8), poids: 76.9),
        ]));
    final router = await monter(t, data, ProfilPaths.mensurations);
    expect(find.text('Dernière saisie : 30 septembre'), findsOneWidget);
    expect(find.text('Dernière saisie : 19 septembre'), findsNothing);
    await t.runAsync(() => photo(t, 'chasse-derniere-saisie'));
    // La même date que le haut de l'historique.
    router.go(ProfilPaths.historique);
    await attendre(t);
    final dates = [for (final j in ['30', '27', '19']) t.getTopLeft(find.text('$j septembre 2026')).dy];
    expect(dates[0] < dates[1] && dates[1] < dates[2], isTrue);
  });

  testWidgets('point 22 : le titre de chaque page est le libellé de sa ligne ; lignes sans effet retirées', (t) async {
    await polices(t);
    ecran(t, hauteur: 1400);
    final data = await donnees(t);
    final router = await monter(t, data, '/reglages');
    // Réglages sans effet : plus de ligne.
    expect(find.text('Taille du texte'), findsNothing);
    expect(find.text('Repos par défaut'), findsOneWidget);
    await t.runAsync(() => photo(t, 'chasse-reglages'));

    for (final ligne in ['Unités', 'Paramètres de séance', 'Notifications', 'Mes données', 'À propos']) {
      await t.tap(find.text(ligne));
      await attendre(t);
      expect(t.widget<PageMaquette>(find.byType(PageMaquette).last).titre, ligne);
      router.pop();
      await attendre(t);
    }
    for (final s in ReglagesSection.values) {
      expect(s.titre, isNot(anyOf('Entraînement', 'Apparence', 'Données')));
    }

    router.go('/reglages/entrainement');
    await attendre(t);
    // Le repos par défaut ne se règle qu'à un endroit.
    expect(find.text('Repos par défaut'), findsNothing);
    expect(find.textContaining('échauffement'), findsNothing);
    router.go('/reglages/unites');
    await attendre(t);
    expect(find.text('Kilogrammes'), findsOneWidget);
    for (final absent in ['Kilocalories', 'Kilojoules', 'Énergie', 'ÉNERGIE']) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
    router.go('/reglages/donnees');
    await attendre(t);
    await t.scrollUntilVisible(find.text('Copies du téléphone'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Copies du téléphone'));
    await attendre(t);
    expect(t.widget<PageMaquette>(find.byType(PageMaquette).last).titre, 'Copies du téléphone');
  });

  testWidgets('Le calendrier du mois s\'ouvre par-dessus le profil : le retour y ramène', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    final router = await monter(t, data, '/profil');
    for (final (ligne, chemin) in [('ce mois-ci', '/progres/calendrier')]) {
      await t.tap(find.textContaining(ligne));
      await attendre(t);
      expect(find.textContaining('voisin $chemin'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: ligne);
      router.pop();
      await attendre(t);
      expect(find.text('Tristan'), findsOneWidget, reason: 'retour au profil depuis $ligne');
      expect(find.textContaining('voisin'), findsNothing);
    }
  });

  group('photos : vignettes décodées à leur taille', () {
    test("cadrage sur la personne : même taille de tronc d'une photo à l'autre, cadre toujours couvert", () {
      const cadre = Size(180, 320);
      // La même personne, loin puis près, décalée à gauche puis à droite.
      const loin = Cadrage(Cadrage.entier, 0.75, Offset(0.4, 0.40), Offset(0.4, 0.55));
      const pres = Cadrage(Cadrage.entier, 0.5625, Offset(0.55, 0.30), Offset(0.55, 0.52));
      for (final c in [loin, pres]) {
        final r = c.place(cadre);
        // L'image couvre tout le cadre.
        expect(r.left <= 0 && r.top <= 0 && r.right >= cadre.width && r.bottom >= cadre.height, isTrue, reason: '$r');
        // Le tronc prend la même part de la hauteur, l'axe du corps est au milieu.
        expect((c.hanches!.dy - c.epaules!.dy) * r.height, closeTo(cadre.height * Cadrage.partTronc, 0.01));
        expect(r.left + c.epaules!.dx * r.width, closeTo(cadre.width / 2, 0.01));
        expect(r.top + c.epaules!.dy * r.height, closeTo(cadre.height * Cadrage.ligneEpaules, 0.01));
      }
      // Un tronc couché ou minuscule n'est pas retenu.
      expect(Cadrage.tronc({'leftShoulder': (0.4, 0.3, 0.9), 'rightShoulder': (0.6, 0.3, 0.9), 'leftHip': (0.8, 0.35, 0.9), 'rightHip': (0.9, 0.35, 0.9)}, 0.75), isNull);
      expect(Cadrage.tronc({'leftShoulder': (0.4, 0.3, 0.9), 'rightShoulder': (0.6, 0.3, 0.9), 'leftHip': (0.45, 0.5, 0.9), 'rightHip': (0.55, 0.5, 0.2)}, 0.75), isNull);
      expect(Cadrage.tronc({'leftShoulder': (0.4, 0.3, 0.9), 'rightShoulder': (0.6, 0.3, 0.9), 'leftHip': (0.45, 0.5, 0.9), 'rightHip': (0.55, 0.5, 0.9)}, 0.75), isNotNull);
    });

    test('cadrage d\'une paire : même échelle, même ligne d\'épaules, lumière rapprochée', () {
      const cadre = Size(180, 320);
      // « Avant » : la tête touche le haut de la photo, il faut agrandir pour couvrir.
      const avant = Cadrage(Cadrage.entier, 0.5625, Offset(0.5, 0.12), Offset(0.5, 0.42), [200, 170, 150]);
      const apres = Cadrage(Cadrage.entier, 0.5625, Offset(0.5, 0.35), Offset(0.5, 0.57), [140, 100, 70]);
      final ra = avant.placeAvec(apres, cadre), rb = apres.placeAvec(avant, cadre);
      for (final r in [ra, rb]) {
        expect(r.left <= 0.001 && r.top <= 0.001 && r.right >= cadre.width - 0.001 && r.bottom >= cadre.height - 0.001, isTrue, reason: '$r');
      }
      // Les deux troncs font la même taille à l'écran, les épaules sont à la même hauteur.
      expect(0.30 * ra.height, closeTo(0.22 * rb.height, 0.01));
      expect(ra.top + 0.12 * ra.height, closeTo(rb.top + 0.35 * rb.height, 0.01));
      // Chacune va vers l'autre : la claire s'assombrit, la sombre s'éclaircit, sans excès.
      final ga = avant.gainsAvec(apres)!, gb = apres.gainsAvec(avant)!;
      expect(ga.every((g) => g < 1 && g > 0.7), isTrue, reason: '$ga');
      expect(gb.every((g) => g > 1 && g < 1.45), isTrue, reason: '$gb');
      // Même lumière : aucun filtre.
      expect(avant.gainsAvec(avant), isNull);
      // Sans personne reconnue d'un côté : chacune se cadre seule.
      expect(avant.placeAvec(const Cadrage(Cadrage.entier, 0.75), cadre), avant.place(cadre));
    });

    test('cadrage : 80 photos au hasard, grille et paires toujours pleines, mêmes troncs, mêmes épaules', () {
      final alea = math.Random(3);
      double entre(double a, double b) => a + alea.nextDouble() * (b - a);
      Cadrage photo() {
        // Format, bandes noires, taille et place de la personne : tout varie.
        final ratio = [9 / 16, 3 / 4, 2 / 3, 1.0][alea.nextInt(4)];
        final bande = alea.nextBool() ? entre(0, 0.2) : 0.0, bandeV = alea.nextInt(4) == 0 ? entre(0, 0.12) : 0.0;
        final zone = Rect.fromLTRB(bande, bandeV, 1 - bande, 1 - bandeV);
        final tronc = entre(0.12, 0.30), haut = entre(zone.top + 0.02, zone.bottom - tronc - 0.05), axe = entre(zone.left + 0.15, zone.right - 0.15);
        return Cadrage(zone, ratio, Offset(axe + entre(-0.01, 0.01), haut), Offset(axe, haut + tronc));
      }

      bool plein(Cadrage c, Rect r, Size cadre) =>
          r.left + c.zone.left * r.width <= 0.01 &&
          r.top + c.zone.top * r.height <= 0.01 &&
          r.left + c.zone.right * r.width >= cadre.width - 0.01 &&
          r.top + c.zone.bottom * r.height >= cadre.height - 0.01;
      double tronc(Cadrage c, Rect r) => (Offset(c.hanches!.dx * r.width, c.hanches!.dy * r.height) - Offset(c.epaules!.dx * r.width, c.epaules!.dy * r.height)).distance;
      double ligne(Cadrage c, Rect r) => r.top + c.epaules!.dy * r.height;

      for (var i = 0; i < 80; i++) {
        final a = photo(), b = photo();
        // Seule, dans la grille (3:4) et dans la comparaison (9:16).
        for (final cadre in const [Size(120, 160), Size(180, 320), Size(192, 288)]) {
          final r = a.place(cadre);
          expect(r.width.isFinite && r.height.isFinite && r.left.isFinite && r.top.isFinite, isTrue, reason: 'photo $i : $r');
          expect(plein(a, r, cadre), isTrue, reason: 'photo $i seule dans $cadre : $r');
          final ra = a.placeAvec(b, cadre), rb = b.placeAvec(a, cadre);
          expect(plein(a, ra, cadre) && plein(b, rb, cadre), isTrue, reason: 'paire $i dans $cadre : $ra $rb');
          // Dans une paire : même longueur de tronc, mêmes épaules.
          expect(tronc(a, ra), closeTo(tronc(b, rb), 0.01), reason: 'paire $i, échelle');
          expect(ligne(a, ra), closeTo(ligne(b, rb), 0.01), reason: 'paire $i, épaules');
        }
      }
    });

    test('cadrage par la silhouette : tête coupée, le tronc est estimé des épaules au sol', () {
      // 100 lignes : rien jusqu'à 10 %, un cou étroit, puis le buste de 14 % à 55 %, les jambes jusqu'à 80 %.
      List<(double, double)?> silhouette({required int pieds}) => [
            for (var y = 0; y < 100; y++)
              y < 10 || y >= pieds
                  ? null
                  : y < 14
                      ? (0.45, 0.55)
                      : y < 55
                          ? (0.30, 0.70)
                          : (0.38, 0.62),
          ];
      final m = Cadrage.mesures(silhouette(pieds: 80))!;
      expect(m.haut, closeTo(0.10, 0.001));
      expect(m.epaules, closeTo(0.14, 0.001));
      expect(m.bas, closeTo(0.80, 0.001));
      expect(m.axe, closeTo(0.50, 0.001));
      final t = Cadrage.troncDeSilhouette(silhouette(pieds: 80), Cadrage.entier)!;
      expect(t.$1.dy, closeTo(0.14 + 0.66 * Cadrage.epaulesSousSilhouette, 0.001));
      expect(t.$2.dy - t.$1.dy, closeTo(0.66 * Cadrage.troncSurHauteur, 0.001));
      // Pieds coupés par le bas de la photo, ou pas de corps : pas d'estimation.
      expect(Cadrage.troncDeSilhouette(silhouette(pieds: 100), Cadrage.entier), isNull);
      expect(Cadrage.troncDeSilhouette([for (var y = 0; y < 100; y++) null], Cadrage.entier), isNull);
      expect(Cadrage.troncDeSilhouette(const [], Cadrage.entier), isNull);
    });

    test('cadrage d\'une série : même tronc pour toutes, cadre toujours plein, une photo coupée ne gâche pas les autres', () {
      const cadre = Size(360, 640);
      final serie = [
        const Cadrage(Cadrage.entier, 0.5625, Offset(0.5, 0.30), Offset(0.5, 0.52)),
        const Cadrage(Cadrage.entier, 0.75, Offset(0.45, 0.35), Offset(0.46, 0.60)),
        const Cadrage(Rect.fromLTRB(0.1, 0, 0.9, 1), 0.5625, Offset(0.52, 0.25), Offset(0.5, 0.45)),
        // Tête coupée par la photo : les épaules sont tout en haut.
        const Cadrage(Cadrage.entier, 0.5625, Offset(0.5, 0.04), Offset(0.5, 0.30)),
      ];
      final places = [for (final c in serie) c.placeParmi(serie, cadre)];
      for (var i = 0; i < serie.length; i++) {
        final c = serie[i], r = places[i];
        expect(r.left + c.zone.left * r.width <= 0.01 && r.top + c.zone.top * r.height <= 0.01, isTrue, reason: 'photo $i : $r');
        expect(r.left + c.zone.right * r.width >= cadre.width - 0.01 && r.top + c.zone.bottom * r.height >= cadre.height - 0.01, isTrue, reason: 'photo $i : $r');
      }
      double tronc(int i) => ((serie[i].hanches! - serie[i].epaules!).scale(places[i].width, places[i].height)).distance;
      double ligne(int i) => places[i].top + serie[i].epaules!.dy * places[i].height;
      for (var i = 1; i < serie.length; i++) {
        expect(tronc(i), closeTo(tronc(0), 0.01), reason: 'tronc de la photo $i');
      }
      // Les trois photos entières partagent la même ligne d'épaules.
      expect(ligne(1), closeTo(ligne(0), 0.01));
      expect(ligne(2), closeTo(ligne(0), 0.01));
      // Une photo sans personne reconnue se cadre seule.
      const vide = Cadrage(Cadrage.entier, 0.75);
      expect(vide.placeParmi([...serie, vide], cadre), vide.place(cadre));
    });

    test('cadrage : les bandes noires sont rognées, une photo sombre reste entière', () {
      Uint8List image(int l, int h, bool Function(int x, int y) clair) {
        final o = Uint8List(l * h * 4);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < l; x++) {
            final v = clair(x, y) ? 180 : 6;
            o.setRange((y * l + x) * 4, (y * l + x) * 4 + 4, [v, v, v, 255]);
          }
        }
        return o;
      }

      // Une photo au milieu d'un cadre noir : 20 px de chaque côté, 10 en haut et en bas.
      final z = Cadrage.utile(image(100, 100, (x, y) => x >= 20 && x < 80 && y >= 10 && y < 90), 100, 100);
      expect(z, const Rect.fromLTRB(0.21, 0.11, 0.79, 0.89));
      // Sans bande : rien n'est rogné.
      expect(Cadrage.utile(image(100, 100, (x, y) => true), 100, 100), Cadrage.entier);
      // Toute noire, ou presque : on ne rogne pas.
      expect(Cadrage.utile(image(100, 100, (x, y) => false), 100, 100), Cadrage.entier);
      expect(Cadrage.utile(image(100, 100, (x, y) => x > 45 && x < 55 && y > 45 && y < 55), 100, 100), Cadrage.entier);
    });

    test('largeur de décodage', () {
      // Une vignette de 110 sur 147 à la densité 2,6 : environ 510 px,
      // loin des 3000 ou 4000 d'une photo de téléphone.
      final l = VignettePhoto.largeurDecodage(const Size(110, 147), 2.625);
      expect(l, inInclusiveRange(386, 520));
      expect(VignettePhoto.largeurDecodage(const Size(4000, 4000), 3), 2048);
      expect(VignettePhoto.largeurDecodage(Size.infinite, 2), greaterThan(0));
      expect(VignettePhoto.largeurDecodage(Size.zero, 2), 64);
    });

    testWidgets('la grille passe par ResizeImage', (t) async {
      await polices(t);
      ecran(t);
      final dossier = Directory.systemTemp.createTempSync('aesthetic-chasse-');
      addTearDown(() {
        try {
          dossier.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows garde parfois l'image ouverte un instant.
        }
      });
      final modele = Directory('assets/objets').listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.png'));
      final data = await donnees(t);
      await t.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          final f = File('${dossier.path}${Platform.pathSeparator}p$i.png')..writeAsBytesSync(modele.readAsBytesSync());
          await data.health.savePhoto(ProgressPhoto(id: 'p$i', date: DateTime(2026, 9, 1 + i, 9), chemin: f.path));
        }
      });
      await monter(t, data, ProfilPaths.photos);
      // Le temps de trouver le cadrage de chaque photo.
      await attendre(t, 6);
      final images = t.widgetList<Image>(find.descendant(of: find.byType(VignettePhoto), matching: find.byType(Image))).toList();
      expect(images, isNotEmpty);
      for (final i in images) {
        expect(i.image, isA<ResizeImage>());
        final r = i.image as ResizeImage;
        expect(r.width, isNotNull);
        expect(r.width! <= 600, isTrue, reason: 'vignette décodée en ${r.width} px');
      }
      expect(t.takeException(), isNull);
    });
  });
}
