import 'dart:io';

import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_profil_banc.dart';

/// Parcours à l'écran de la zone profil : saisie au clavier, dates, écrans
/// vides, unités, photos, profil, réglages.
void main() {
  BodyMeasurement m(String id, DateTime d, {double? poids, double? gras, Map<TourCorps, double> tours = const {}}) =>
      BodyMeasurement(id: id, date: d, poidsKg: poids, masseGrassePct: gras, tours: tours, source: 'manuel');

  Finder valeur(String champ) => find.bySemanticsLabel(RegExp('^$champ, .*Toucher pour taper la valeur\$'));
  String libelle(WidgetTester t, String champ) => t.getSemantics(valeur(champ)).label;

  /// Ouvre le clavier d'un champ, tape [texte], touche Valider.
  Future<void> taper(WidgetTester t, String champ, String texte) async {
    await t.tap(valeur(champ));
    await attendre(t, 2);
    await t.enterText(find.byType(TextField), texte);
    await t.pump();
    await t.tap(find.text('Valider'));
    await attendre(t, 2);
  }

  Future<void> fermerPanneau(WidgetTester t) async {
    await t.tapAt(const Offset(200, 40));
    await attendre(t, 2);
  }

  testWidgets('saisie au clavier : virgule, point, vide, zéro, négative, absurde', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await monter(t, data, ProfilPaths.saisie());
    expect(find.text('Nouvelle saisie'), findsOneWidget);
    // Rien de saisi : Enregistrer n'enregistre rien.
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 1);
    expect(data.health.measurements, isEmpty);

    await taper(t, 'Biceps', '38,5');
    expect(find.byType(TextField), findsNothing);
    expect(libelle(t, 'Biceps'), startsWith('Biceps, 38,5 cm.'));

    await taper(t, 'Cou', '39.5');
    expect(find.byType(TextField), findsNothing);
    expect(libelle(t, 'Cou'), startsWith('Cou, 39,5 cm.'));

    // Valeurs refusées : le panneau reste ouvert, la valeur ne change pas,
    // et la plage acceptée est dite.
    for (final refuse in ['', '0', '999', '4,9', '250,5', ',', '1,2,3']) {
      await taper(t, 'Taille', refuse);
      expect(find.byType(TextField), findsOneWidget, reason: '« $refuse » accepté');
      expect(find.textContaining('5 à 250 cm'), findsOneWidget, reason: 'plage non indiquée pour « $refuse »');
      await fermerPanneau(t);
      expect(find.byType(TextField), findsNothing);
      expect(libelle(t, 'Taille'), contains('pas encore saisi'), reason: refuse);
    }

    // Le signe moins et les lettres ne passent pas le filtre : « -82a » = 82.
    await taper(t, 'Taille', '-82a');
    expect(libelle(t, 'Taille'), startsWith('Taille, 82 cm.'));

    // Bornes comprises.
    await taper(t, 'Mollets', '5');
    expect(libelle(t, 'Mollets'), startsWith('Mollets, 5 cm.'));
    await taper(t, 'Épaules', '250');
    expect(libelle(t, 'Épaules'), startsWith('Épaules, 250 cm.'));

    // Poids : de 20 à 700, au dixième.
    await taper(t, 'Poids', '19,9');
    expect(find.byType(TextField), findsOneWidget);
    await fermerPanneau(t);
    await taper(t, 'Poids', '76,75');
    expect(find.byType(TextField), findsNothing);

    // Retirer une valeur de la saisie.
    await t.tap(valeur('Mollets'));
    await attendre(t, 2);
    await t.tap(find.text('Retirer de cette saisie'));
    await attendre(t, 2);
    expect(libelle(t, 'Mollets'), contains('pas encore saisi'));

    expect(t.takeException(), isNull);
    await t.runAsync(() => photo(t, 'saisie-clavier'));
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final r = data.health.measurements.single;
    expect(r.tours, {
      TourCorps.brasGauche: 38.5,
      TourCorps.brasDroit: 38.5,
      TourCorps.cou: 39.5,
      TourCorps.taille: 82,
      TourCorps.epaules: 250,
    });
    expect(r.poidsKg, closeTo(76.8, 0.051));
    expect(r.masseGrassePct, isNull);
    expect(Dates.memeJour(r.date, DateTime.now()), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('panneau du clavier : la plage est visible et le bouton grisé hors plage', (t) async {
    await polices(t);
    ecran(t, largeur: 360, hauteur: 740);
    final data = await donnees(t);
    await monter(t, data, ProfilPaths.saisie());
    await t.tap(valeur('Biceps'));
    await attendre(t, 2);
    await t.enterText(find.byType(TextField), '999');
    await t.pump();
    expect(t.takeException(), isNull);
    await t.runAsync(() => photo(t, 'saisie-clavier-999-360'));
  });

  testWidgets('modifier la date d\'une saisie vers un jour déjà saisi : les deux saisies sont réunies', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('a', DateTime(2026, 9, 14, 8), poids: 76.2, gras: 14.3, tours: {TourCorps.cou: 39, TourCorps.hanches: 95}),
          m('c', DateTime(2026, 9, 28, 8), poids: 76.7, tours: {TourCorps.cou: 39.5, TourCorps.taille: 82}),
        ]));
    final router = await monter(t, data, ProfilPaths.historique);
    router.push(ProfilPaths.saisie(id: 'c'));
    await attendre(t);
    expect(find.text('Modifier la saisie'), findsOneWidget);
    await t.tap(find.text('28 septembre 2026'));
    await attendre(t, 2);
    await t.tap(find.text('14'));
    await t.pump();
    await t.tap(find.text('Valider'));
    await attendre(t, 2);
    expect(find.text('14 septembre 2026'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    expect(t.takeException(), isNull);

    final ms = data.health.measurements;
    expect(ms.length, 1, reason: 'deux saisies le 14 septembre');
    expect(ms.single.poidsKg, 76.7);
    expect(ms.single.masseGrassePct, 14.3);
    expect(ms.single.tours, {TourCorps.cou: 39.5, TourCorps.hanches: 95, TourCorps.taille: 82});
    // Retour à l'historique : une seule ligne.
    expect(find.text('Historique des mesures'), findsOneWidget);
    expect(find.text('14 septembre 2026'), findsOneWidget);
    expect(find.text('28 septembre 2026'), findsNothing);
  });

  testWidgets('changer la date sans collision : la saisie se déplace, rien d\'autre ne bouge', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('a', DateTime(2026, 9, 14, 8), poids: 76.2),
          m('c', DateTime(2026, 9, 28, 8), poids: 76.7, tours: {TourCorps.brasGauche: 37, TourCorps.brasDroit: 38}),
        ]));
    final router = await monter(t, data, ProfilPaths.historique);
    router.push(ProfilPaths.saisie(id: 'c'));
    await attendre(t);
    await t.tap(find.text('28 septembre 2026'));
    await attendre(t, 2);
    await t.tap(find.text('21'));
    await t.pump();
    await t.tap(find.text('Valider'));
    await attendre(t, 2);
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    final c = data.health.measurements.firstWhere((x) => x.id == 'c');
    expect(Dates.memeJour(c.date, DateTime(2026, 9, 21)), isTrue);
    expect(c.poidsKg, 76.7);
    expect(c.tours, {TourCorps.brasGauche: 37, TourCorps.brasDroit: 38});
    expect(data.health.measurements.length, 2);
    expect(data.health.measurements.firstWhere((x) => x.id == 'a').poidsKg, 76.2);
  });

  testWidgets('supprimer la seule saisie : tous les écrans retombent sur leur état vide', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t, poidsKg: null);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('seule', DateTime(2026, 9, 28, 8), poids: 76.7, gras: 14.2, tours: {TourCorps.cou: 39, TourCorps.brasGauche: 38, TourCorps.brasDroit: 38}),
        ]));
    final router = await monter(t, data, ProfilPaths.mensurations);
    // Une seule saisie : aucune évolution affichée, nulle part.
    expect(find.textContaining('+'), findsNothing);
    expect(find.textContaining('−'), findsNothing);
    expect(find.text('à saisir'), findsNWidgets(6));
    expect(find.textContaining('depuis'), findsNothing);
    await t.runAsync(() => photo(t, 'mensurations-une-saisie'));

    router.push(ProfilPaths.historique);
    await attendre(t);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('saisie depuis'), findsOneWidget);
    expect(find.text('entre deux saisies'), findsNothing);
    await t.tap(find.text('28 septembre 2026'));
    await attendre(t);
    await t.tap(find.text('Supprimer cette saisie'));
    await attendre(t, 2);
    await t.tap(find.text('Supprimer'));
    await attendre(t);
    expect(t.takeException(), isNull);
    expect(data.health.measurements, isEmpty);

    expect(find.text('Aucune saisie pour l\'instant'), findsOneWidget);
    await t.runAsync(() => photo(t, 'historique-vide-apres-suppression'));
    router.pop();
    await attendre(t);
    expect(find.text('à saisir'), findsNWidgets(8));
    expect(find.text('Aucune pesée pour l\'instant'), findsOneWidget);
    expect(find.text('Historique'), findsNothing);
    router.push(ProfilPaths.zone(ZoneMesure.cou));
    await attendre(t);
    expect(find.text('Aucune mesure pour l\'instant'), findsOneWidget);
    router.pop();
    await attendre(t);
    router.go('/profil');
    await attendre(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('saisie supprimée pendant qu\'on la modifie ailleurs : écran « introuvable », pas de plantage', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    final router = await monter(t, data, ProfilPaths.mensurations);
    router.push(ProfilPaths.saisie(id: 'fantome'));
    await attendre(t);
    expect(find.text('Cette saisie n\'existe plus'), findsOneWidget);
    router.pop();
    await attendre(t);
    router.push('/profil/mensurations/zone/inconnue');
    await attendre(t);
    expect(find.text('Mensurations'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('une mesure : un seul point, périodes sans donnée, baisse', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    final now = DateTime.now();
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('vieux', DateTime(now.year - 2, now.month, 10, 8), tours: {TourCorps.taille: 86}),
          m('recent', now.subtract(const Duration(days: 20)), tours: {TourCorps.taille: 84.5, TourCorps.cou: 39}),
        ]));
    final router = await monter(t, data, ProfilPaths.zone(ZoneMesure.cou));
    // Un seul point : la valeur, pas d'écart, une courbe réduite à un point.
    expect(find.text('39 cm'), findsNWidgets(2));
    expect(find.textContaining('depuis'), findsNothing);
    expect(find.textContaining('+'), findsNothing);
    expect(t.takeException(), isNull);
    await t.runAsync(() => photo(t, 'mesure-un-point'));

    router.go(ProfilPaths.zone(ZoneMesure.taille));
    await attendre(t);
    // Six mois : une seule saisie dans la période, donc pas d'écart.
    expect(find.text('84,5 cm'), findsNWidgets(2));
    expect(find.textContaining('depuis'), findsNothing);
    await t.tap(find.text('Tout'));
    await attendre(t, 1);
    // La baisse s'affiche avec un vrai signe moins, en rouge.
    expect(find.text('−1,5 cm'), findsOneWidget);
    expect(find.text('−1,5'), findsOneWidget);
    final gris = t.widget<Text>(find.text('−1,5 cm')).style!.color;
    expect(gris, t.element(find.text('−1,5 cm')).colors.error);
    expect(find.text('86 cm'), findsOneWidget);
    await t.runAsync(() => photo(t, 'mesure-baisse'));

    // Période sans aucune donnée.
    await t.runAsync(() => data.health.deleteMeasurement('recent'));
    await attendre(t, 1);
    await t.tap(find.text('3 mois'));
    await attendre(t, 1);
    expect(find.text('86 cm'), findsOneWidget);
    expect(find.text('Pas de mesure sur cette période.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.runAsync(() => photo(t, 'mesure-periode-vide'));
  });

  testWidgets('écart de poids : vert quand il va dans le sens de l’objectif, rouge sinon, gris sans sens voulu', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('a', DateTime(2026, 6, 8, 8), poids: 74.1),
          m('b', DateTime(2026, 9, 28, 8), poids: 76.7),
        ]));
    await monter(t, data, ProfilPaths.mensurations);
    Color? couleur() => t.widget<Text>(find.textContaining('+2,6 kg')).style?.color;
    final c = t.element(find.textContaining('+2,6 kg')).colors;
    // Le profil du banc veut prendre du muscle : une prise de poids est verte.
    expect(couleur(), c.success);
    for (final (objectif, attendue) in [(Objectif.secher, c.error), (Objectif.force, c.success), (Objectif.recomposition, c.text2), (Objectif.forme, c.text2)]) {
      await t.runAsync(() => data.profile.save(data.profile.profile!.copyWith(objectif: objectif)));
      await attendre(t);
      expect(couleur(), attendue, reason: objectif.label);
    }
  });

  testWidgets('unités : en livres, le poids suit partout, les tours restent en centimètres', (t) async {
    await polices(t);
    ecran(t);
    final data = await donnees(t, unite: UnitePoids.lb);
    await t.runAsync(() => data.health.addMeasurementsAll([
          m('a', DateTime(2026, 6, 8, 8), poids: 74.1, tours: {TourCorps.cou: 38.5}),
          m('b', DateTime(2026, 9, 28, 8), poids: 76.7, tours: {TourCorps.cou: 39}),
        ]));
    final router = await monter(t, data, ProfilPaths.mensurations);
    expect(find.text('169,1 lb'), findsOneWidget);
    expect(find.textContaining('+5,7 lb'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
    router.push(ProfilPaths.historique);
    await attendre(t);
    expect(find.textContaining('169,1 lb'), findsOneWidget);
    router.push(ProfilPaths.saisie(id: 'b'));
    await attendre(t);
    expect(libelle(t, 'Poids'), startsWith('Poids, 169,1 lb.'));
    expect(libelle(t, 'Cou'), startsWith('Cou, 39 cm.'));
    // Sans y toucher, le poids en kilos ne dérive pas.
    await t.tap(find.bySemanticsLabel('Augmenter Cou'));
    await t.pump();
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    expect(data.health.measurements.firstWhere((x) => x.id == 'b').poidsKg, 76.7);
    // Un cran de plus : un dixième de livre.
    router.push(ProfilPaths.saisie(id: 'b'));
    await attendre(t);
    await t.tap(find.bySemanticsLabel('Augmenter Poids'));
    await t.pump();
    expect(libelle(t, 'Poids'), startsWith('Poids, 169,2 lb.'));
    await t.tap(find.text('Enregistrer'));
    await attendre(t);
    expect(data.health.measurements.firstWhere((x) => x.id == 'b').poidsKg, closeTo(169.2 * Fmt.kgParLb, 0.006));
    expect(t.takeException(), isNull);
  });

  group('photos', () {
    late Directory dossier;
    setUp(() => dossier = Directory.systemTemp.createTempSync('aesthetic-photos-'));
    tearDown(() {
      try {
        if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows garde parfois l'image ouverte un instant : sans gravité.
      }
    });

    File image(String nom) {
      final modele = Directory('assets/objets').listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.png'));
      return File('${dossier.path}${Platform.pathSeparator}$nom.png')..writeAsBytesSync(modele.readAsBytesSync());
    }

    testWidgets('une seule photo, fichier disparu, suppression', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      final f1 = image('f1');
      await t.runAsync(() async {
        await data.health.savePhoto(ProgressPhoto(id: 'f1', date: DateTime(2026, 9, 28, 9), chemin: f1.path));
        await data.health.savePhoto(ProgressPhoto(id: 'd1', date: DateTime(2026, 9, 1, 9), chemin: '${dossier.path}/disparue.jpg', vue: PhotoVue.dos));
      });
      final router = await monter(t, data, ProfilPaths.photos);
      expect(find.textContaining('2 photos depuis'), findsOneWidget);
      // Une seule photo de face : rien à comparer.
      await t.tap(find.text('Comparer deux photos'));
      await attendre(t, 1);
      expect(find.text('Avant / après'), findsNothing);
      // Par le lien direct : un message, pas un plantage.
      router.push(ProfilPaths.comparer(vue: PhotoVue.face));
      await attendre(t);
      expect(find.text('Il faut deux photos du même angle'), findsOneWidget);
      router.pop();
      await attendre(t);

      // Fichier disparu du disque : la vignette et la photo en grand
      // montrent la silhouette.
      await t.tap(find.text('Dos'));
      await attendre(t, 1);
      expect(t.takeException(), isNull);
      await t.tap(find.bySemanticsLabel(RegExp('^Photo du 1')));
      await attendre(t);
      expect(t.takeException(), isNull);
      expect(find.bySemanticsLabel('Supprimer la photo'), findsOneWidget);
      await t.runAsync(() => photo(t, 'photo-fichier-disparu'));
      await t.tap(find.bySemanticsLabel('Supprimer la photo'));
      await attendre(t, 2);
      await t.tap(find.text('Supprimer'));
      await attendre(t);
      expect(t.takeException(), isNull);
      expect(data.health.photos.map((p) => p.id), ['f1']);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.textContaining('1 photo depuis'), findsOneWidget);
      expect(find.textContaining('Pas encore de photo de dos'), findsOneWidget);

      // Supprimer la dernière photo efface aussi son fichier.
      router.push(ProfilPaths.photo('f1'));
      await attendre(t);
      await t.tap(find.bySemanticsLabel('Supprimer la photo'));
      await attendre(t, 2);
      await t.tap(find.text('Supprimer'));
      await attendre(t);
      expect(data.health.photos, isEmpty);
      expect(f1.existsSync(), isFalse);
      expect(find.text('Aucune photo pour l\'instant'), findsOneWidget);
      router.push(ProfilPaths.photo('f1'));
      await attendre(t);
      expect(find.text('Cette photo n\'existe plus'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('comparer deux photos du même jour : pas de « 0 jour », pas de photo comparée à elle-même', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      await t.runAsync(() async {
        await data.health.addMeasurementsAll([m('a', DateTime(2026, 9, 28, 8), poids: 76.7)]);
        await data.health.savePhoto(ProgressPhoto(id: 'p1', date: DateTime(2026, 9, 28, 9), chemin: image('p1').path));
        await data.health.savePhoto(ProgressPhoto(id: 'p2', date: DateTime(2026, 9, 28, 9), chemin: image('p2').path));
      });
      final router = await monter(t, data, ProfilPaths.comparer(vue: PhotoVue.face));
      expect(find.text('Avant / après'), findsOneWidget);
      expect(find.textContaining('0 jour'), findsNothing);
      expect(find.textContaining('0 semaine'), findsNothing);
      expect(find.text('Même poids, le même jour'), findsOneWidget);
      expect(find.text('76,7 kg'), findsNWidgets(2));
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'comparer-meme-jour'));

      // Le même identifiant deux fois dans le lien : on compare quand même
      // deux photos différentes.
      router.go(ProfilPaths.comparer(vue: PhotoVue.face, avant: 'p1', apres: 'p1'));
      await attendre(t);
      final labels = t.widgetList<Semantics>(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Photo du'))).length;
      expect(labels, 2);

      // Changer les dates : la grille s'ouvre et se referme sans erreur.
      await t.tap(find.text('Changer les dates'));
      await attendre(t, 2);
      expect(find.text('Choisir les deux photos'), findsOneWidget);
      await t.tap(find.text('Comparer'));
      await attendre(t, 2);
      expect(t.takeException(), isNull);

      // Quatre jours d'écart : des jours, pas « 1 semaine ».
      await t.runAsync(() => data.health.savePhoto(ProgressPhoto(id: 'p0', date: DateTime(2026, 9, 24, 9), chemin: image('p0').path, poidsKg: 76)));
      router.go(ProfilPaths.comparer(vue: PhotoVue.face, avant: 'p0', apres: 'p2'));
      await attendre(t);
      expect(find.text('+0,7 kg en 4 jours'), findsOneWidget);
    });

    testWidgets('grille de choix avec beaucoup de photos, en 360 de large', (t) async {
      await polices(t);
      ecran(t, largeur: 360, hauteur: 640);
      final data = await donnees(t);
      await t.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await data.health.savePhoto(ProgressPhoto(id: 'p$i', date: DateTime(2026, 1, 1).add(Duration(days: 6 * i)), chemin: 'absente/$i.jpg'));
        }
      });
      await monter(t, data, ProfilPaths.comparer(vue: PhotoVue.face));
      expect(t.takeException(), isNull);
      await t.tap(find.text('Changer les dates'));
      await attendre(t, 2);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'comparer-choix-40-photos-360'));
    });
  });

  group('profil', () {
    WorkoutSession s(String id, DateTime d, {bool enCours = false}) =>
        WorkoutSession(id: id, nom: 'Séance', debut: d, fin: enCours ? null : d.add(const Duration(hours: 1)));

    testWidgets('chiffres exacts, objectif, liens', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      final now = DateTime.now();
      await t.runAsync(() async {
        // Trois semaines d'affilée, dont celle-ci, plus une séance isolée
        // il y a deux mois.
        for (final (i, j) in [0, 7, 14, 60].indexed) {
          await data.sessions.save(s('s$i', now.subtract(Duration(days: j, hours: 1))));
        }
        await data.health.addMeasurementsAll([
          m('a', DateTime(2026, 9, 14, 8), poids: 76.24, tours: {TourCorps.cou: 39}),
          m('b', DateTime(2026, 9, 28, 8), tours: {TourCorps.cou: 39, TourCorps.taille: 82}),
        ]);
        await data.health.savePhoto(ProgressPhoto(id: 'p', date: DateTime(2026, 9, 28), chemin: 'absente.jpg'));
      });
      final router = await monter(t, data, '/profil');
      expect(find.text('Tristan'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.textContaining('Inscrit depuis'), findsNothing);
      expect(find.text('3 sem.'), findsOneWidget);
      // Mensurations, photos, records et séances sont dans Progrès.
      for (final tuile in ['Mensurations', 'Photos', 'Records', 'Séances']) {
        expect(find.text(tuile), findsNothing, reason: tuile);
      }
      expect(find.text('Prendre du muscle · 5 séances par semaine'), findsOneWidget);
      expect(find.byType(GrilleMois), findsOneWidget);
      await t.runAsync(() => photo(t, 'profil-chiffres'));

      await t.tap(find.textContaining('5 séances par semaine'));
      await attendre(t);
      expect(find.textContaining('voisin /bienvenue/modifier/objectif'), findsOneWidget);
      router.go('/profil');
      await attendre(t);
      await t.tap(find.byType(GrilleMois));
      await attendre(t);
      expect(find.textContaining('voisin /progres/calendrier'), findsOneWidget);
      router.go('/profil');
      await attendre(t);
      await t.tap(find.bySemanticsLabel('Réglages').first);
      await attendre(t);
      expect(find.text('ENTRAÎNEMENT'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('phrase du profil : on l’écrit, elle s’affiche et se garde, on peut la retirer', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      await monter(t, data, '/profil');
      expect(find.textContaining('Ajoute une phrase'), findsOneWidget);
      await t.tap(find.textContaining('Ajoute une phrase'));
      await attendre(t);
      await t.enterText(find.byType(TextField), '  La douleur est temporaire, mais la fierté dure toute une vie.  ');
      await t.tap(find.text('Enregistrer'));
      await attendre(t);
      expect(find.text('La douleur est temporaire, mais la fierté dure toute une vie.'), findsOneWidget);
      expect(data.profile.profile!.phrase, 'La douleur est temporaire, mais la fierté dure toute une vie.');
      // Elle survit à l'enregistrement du profil.
      expect(UserProfile.fromJson(data.profile.profile!.toJson()).phrase, data.profile.profile!.phrase);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'profil-phrase'));

      await t.tap(find.textContaining('La douleur est temporaire'));
      await attendre(t);
      await t.tap(find.text('Retirer la phrase'));
      await attendre(t);
      expect(data.profile.profile!.phrase, isEmpty);
      expect(find.textContaining('Ajoute une phrase'), findsOneWidget);
    });

    testWidgets('sans prénom, sans séance, sans poids : un avatar propre et des singuliers', (t) async {
      await polices(t);
      ecran(t, largeur: 360, hauteur: 740);
      final data = await donnees(t, prenom: '   ', poidsKg: null);
      await t.runAsync(() => data.profile.update((p) => p.copyWith(joursParSemaine: 1)));
      await monter(t, data, '/profil');
      expect(find.text('Mon profil'), findsOneWidget);
      // Pas de point d'interrogation dans l'avatar.
      expect(find.text('?'), findsNothing);
      expect(find.text('Aucune séance ce mois-ci'), findsOneWidget);
      // Sans série en cours, pas de pastille « 0 sem. ».
      expect(find.textContaining('sem.'), findsNothing);
      expect(find.textContaining('1 séance par semaine'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'profil-sans-prenom-360'));
    });

    testWidgets('prénom très long ou commençant par un émoji', (t) async {
      await polices(t);
      ecran(t, largeur: 360, hauteur: 740);
      final data = await donnees(t, prenom: '🦁 Jean-Christophe-Emmanuel de la Tour du Pin');
      await monter(t, data, '/profil');
      expect(t.takeException(), isNull);
      // L'initiale est un caractère entier, pas la moitié d'un émoji.
      expect(find.text('🦁'), findsOneWidget);
      await t.runAsync(() => photo(t, 'profil-prenom-long-360'));
    });
  });

  group('réglages', () {
    testWidgets('premier jour : les sept jours se choisissent, la semaine commence bien ce jour-là', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      await monter(t, data, '/reglages');
      await t.tap(find.text('Premier jour'));
      await attendre(t, 2);
      for (final j in ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']) {
        expect(find.text(j), findsWidgets, reason: j);
      }
      expect(t.takeException(), isNull);
      await t.runAsync(() => photo(t, 'reglages-premier-jour'));
      await t.tap(find.text('Mercredi'));
      await attendre(t, 2);
      expect(data.settings.settings.premierJourSemaine, DateTime.wednesday);
      expect(find.text('Mercredi'), findsOneWidget);
      // Le samedi 3 octobre 2026 appartient à la semaine du mercredi 30 septembre.
      for (var jour = DateTime.monday; jour <= DateTime.sunday; jour++) {
        final debut = Dates.debutSemaine(DateTime(2026, 10, 3, 15), premierJour: jour);
        expect(debut.weekday, jour);
        expect(DateTime(2026, 10, 3).difference(debut).inDays, inInclusiveRange(0, 6));
      }
      expect(Dates.debutSemaine(DateTime(2026, 10, 3), premierJour: DateTime.wednesday), DateTime(2026, 9, 30));
    });

    testWidgets('accent, premier jour, repos et unités : chaque ligne change bien le réglage', (t) async {
      await polices(t);
      ecran(t);
      final data = await donnees(t);
      final accent = AccentController();
      await t.runAsync(() => data.settings.update((s) => s.copyWith(reposParDefautSec: 125)));
      final router = await monter(t, data, '/reglages', accent: accent);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('kg, km, cm'), findsOneWidget);
      expect(find.text('Lundi'), findsOneWidget);

      // L'accent ne se choisit plus : le rouge, sans ligne dans les réglages.
      expect(accent.choice, AccentChoice.corail);
      expect(find.text('Accent'), findsNothing);
      expect(find.text('Apparence'), findsNothing);

      // Premier jour.
      await t.tap(find.text('Premier jour'));
      await attendre(t, 2);
      await t.tap(find.text('Dimanche'));
      await attendre(t, 2);
      expect(data.settings.settings.premierJourSemaine, DateTime.sunday);
      expect(find.text('Dimanche'), findsOneWidget);

      // Repos par défaut : le panneau s'ouvre sur la valeur en cours.
      await t.tap(find.text('Repos par défaut'));
      await attendre(t, 2);
      expect(find.text('Valider'), findsOneWidget);
      await t.tap(find.text('Valider'));
      await attendre(t, 2);
      expect(data.settings.settings.reposParDefautSec, 125);

      // Unités : la page de détail change l'unité du profil, la ligne suit.
      await t.tap(find.text('Unités'));
      await attendre(t);
      await t.tap(find.text('Livres'));
      await attendre(t, 2);
      expect(data.profile.unite, UnitePoids.lb);
      router.pop();
      await attendre(t);
      expect(find.text('lb, km, cm'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('réglages en 360 de large et en large : rien ne déborde', (t) async {
      await polices(t);
      for (final (l, h) in [(360.0, 740.0), (412.0, 915.0), (900.0, 1100.0)]) {
        ecran(t, largeur: l, hauteur: h);
        final data = await donnees(t, unite: UnitePoids.lb);
        final router = await monter(t, data, '/reglages');
        expect(t.takeException(), isNull, reason: '$l');
        await t.runAsync(() => photo(t, 'reglages-${l.round()}'));
        router.go(ProfilPaths.saisie());
        await attendre(t);
        expect(t.takeException(), isNull, reason: 'saisie $l');
        await t.runAsync(() => photo(t, 'saisie-${l.round()}'));
        await t.pumpWidget(const SizedBox());
      }
    });
  });
}
