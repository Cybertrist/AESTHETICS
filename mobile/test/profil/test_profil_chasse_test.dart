import 'dart:io';

import 'package:aesthetic/core/env.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
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
    '/reglages/notifications': 'Rappels',
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

    for (final ligne in ['Unités', 'Paramètres de séance', 'Rappels', 'Mes données', 'À propos']) {
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
