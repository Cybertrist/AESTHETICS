import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/profil/data/backup_service.dart';
import 'package:aesthetic/features/profil/data/career.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/data/plates.dart';
import 'package:aesthetic/features/profil/data/prefs.dart';
import 'package:aesthetic/features/profil/data/reminders.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'jeu_maquette.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('calculateur de disques', () {
    const disques = [Disque(poidsKg: 20, paires: 2), Disque(poidsKg: 10, paires: 1), Disque(poidsKg: 2.5, paires: 2), Disque(poidsKg: 1.25, paires: 1)];

    test('charge exacte', () {
      final r = Plates.charger(85, 20, disques);
      expect(r.parCote, [20, 10, 2.5]);
      expect(r.exact, isTrue);
    });

    test('respecte le nombre de paires', () {
      final r = Plates.charger(200, 20, disques);
      expect(r.parCote.where((d) => d == 20).length, 2);
      expect(r.totalKg, closeTo(20 + 2 * (40 + 10 + 5 + 1.25), 0.001));
      expect(r.exact, isFalse);
    });

    test('barre seule sous son poids', () {
      final r = Plates.charger(15, 20, disques);
      expect(r.parCote, isEmpty);
      expect(Plates.maximum(20, disques), 20 + 2 * (40 + 10 + 5 + 1.25));
    });
  });

  test('préférences : aller-retour JSON', () {
    final p = const ProfilPrefs().copyWith(
      longueur: UniteLongueur.pouce,
      energie: UniteEnergie.kj,
      tailleTexte: TailleTexte.grande,
      minuteurAuto: false,
      disques: const [Disque(poidsKg: 5, paires: 3)],
      eauIntervalleMin: 90,
      devDebloque: true,
    );
    final q = ProfilPrefs.fromJson(p.toJson());
    expect(q.longueur, UniteLongueur.pouce);
    expect(q.energie, UniteEnergie.kj);
    expect(q.tailleTexte, TailleTexte.grande);
    expect(q.minuteurAuto, isFalse);
    expect(q.disques.single.paires, 3);
    expect(q.eauIntervalleMin, 90);
    expect(q.devDebloque, isTrue);
    expect(Unites.taille(180, UniteLongueur.pouce), '5 pi 11');
  });

  test('rappels d\'eau entre le début et la fin', () {
    final h = Reminders.heuresEau(const ProfilPrefs(eauDebut: '09:00', eauFin: '13:00', eauIntervalleMin: 90));
    expect(h, [(9, 0), (10, 30), (12, 0)]);
  });

  test('sauvegarde : lecture et refus', () {
    expect(() => BackupService.lire('pas du json'), throwsFormatException);
    expect(() => BackupService.lire('{"application":"autre","donnees":{}}'), throwsFormatException);
    final r = BackupService.lire('{"application":"aesthetic","date":"2026-09-30T10:00:00","donnees":{"seances":[{},{}],"profil":{"prenom":"Tristan"}}}');
    expect(r.seances, 2);
    expect(r.prenom, 'Tristan');
  });

  test('chiffres du profil : séances et série de semaines', () {
    WorkoutSession seance(int i, DateTime debut) => WorkoutSession(
          id: 's$i',
          nom: 'Séance $i',
          debut: debut,
          fin: debut.add(const Duration(minutes: 60)),
          exercices: [
            SessionExercise(id: 'e$i', exerciseId: 'developpe-couche', series: [
              for (var k = 0; k < 3; k++) WorkoutSet(id: 's$i$k', poids: 100, reps: 10, fait: true),
            ]),
          ],
        );
    final now = DateTime.now();
    final seances = [for (var i = 0; i < 12; i++) seance(i, now.subtract(Duration(days: 7 * (11 - i))))];
    final s = CareerStats.from(seances);
    expect(s.seances, 12);
    expect(s.semainesConsecutives, 12);
    expect(CareerStats.from(const <WorkoutSession>[]).vide, isTrue);
  });

  group('mensurations', () {
    final mesures = JeuMaquette.mesures();
    final ref = DateTime(2026, 10, 2);

    test('huit zones, quatre de chaque côté, ancrées du bon côté du corps', () {
      expect(ZoneMesure.values.length, 8);
      expect(ZoneMesure.gauche.map((z) => z.label), ['Cou', 'Poitrine', 'Taille', 'Cuisses']);
      expect(ZoneMesure.droite.map((z) => z.label), ['Épaules', 'Biceps', 'Avant-bras', 'Mollets']);
      for (final z in ZoneMesure.values) {
        expect(z.ancre.dx < 0.5, z.aGauche, reason: z.name);
        expect(z.ancre.dy > 0 && z.ancre.dy < 1, isTrue);
      }
      // De haut en bas du corps.
      expect(ZoneMesure.cou.ancre.dy < ZoneMesure.epaules.ancre.dy, isTrue);
      expect(ZoneMesure.epaules.ancre.dy < ZoneMesure.poitrine.ancre.dy, isTrue);
      expect(ZoneMesure.poitrine.ancre.dy < ZoneMesure.biceps.ancre.dy, isTrue);
      expect(ZoneMesure.biceps.ancre.dy < ZoneMesure.taille.ancre.dy, isTrue);
      expect(ZoneMesure.taille.ancre.dy < ZoneMesure.cuisses.ancre.dy, isTrue);
      expect(ZoneMesure.cuisses.ancre.dy < ZoneMesure.mollets.ancre.dy, isTrue);
    });

    test('écart depuis la première saisie, rien quand la mesure n\'a pas bougé', () {
      String? ecart(ZoneMesure z) => Mensurations.ecartTexte(Mensurations.etat(mesures, z).ecart);
      expect(Mensurations.etat(mesures, ZoneMesure.biceps).derniere!.valeur, 38);
      expect(ecart(ZoneMesure.biceps), '+1,5');
      expect(ecart(ZoneMesure.cou), '+0,5');
      expect(ecart(ZoneMesure.poitrine), '+2');
      expect(ecart(ZoneMesure.epaules), '+3');
      expect(ecart(ZoneMesure.cuisses), '+2');
      expect(ecart(ZoneMesure.avantBras), '+0,5');
      expect(ecart(ZoneMesure.mollets), '+1');
      // La taille est restée à 82 : aucun texte, pas de « 0 » ni de « = ».
      expect(Mensurations.etat(mesures, ZoneMesure.taille).ecart, isNull);
      expect(ecart(ZoneMesure.taille), isNull);
      expect(Mensurations.ecartTexte(0), isNull);
      expect(Mensurations.ecartTexte(-1.5, unite: 'cm'), '−1,5 cm');
      expect(Mensurations.nbZones(mesures), 8);
      expect(Mensurations.nbZones(const []), 0);
    });

    test('moyenne des deux côtés', () {
      final m = BodyMeasurement(id: 'x', date: ref, tours: const {TourCorps.brasGauche: 37, TourCorps.brasDroit: 38});
      expect(Mensurations.valeur(m, ZoneMesure.biceps), 37.5);
      expect(Mensurations.valeur(m, ZoneMesure.cou), isNull);
      expect(Mensurations.nbMesures(m), 1);
    });

    test('série d\'une zone, période et écarts successifs', () {
      final tout = Mensurations.serie(mesures, ZoneMesure.biceps);
      expect(tout.length, 9);
      expect(tout.first.date.isBefore(tout.last.date), isTrue);
      final e = Mensurations.ecartsSuccessifs(tout);
      // 17 août +0,5 ; 31 août inchangé ; 14 septembre +0,5 ; 28 septembre +0,5.
      expect(e.sublist(5), [0.5, null, 0.5, 0.5]);
      expect(e.first, isNull);
      final trois = Mensurations.serie(mesures, ZoneMesure.biceps, depuis: PeriodeMesure.troisMois.debut(ref));
      expect(trois.first.date, DateTime(2026, 7, 6, 8));
      expect(PeriodeMesure.tout.debut(ref), isNull);
      expect(Mensurations.serie(mesures, ZoneMesure.biceps, depuis: PeriodeMesure.sixMois.debut(ref)).length, 9);
      // Le 17 août, six mesures seulement.
      expect(Mensurations.serie(mesures, ZoneMesure.mollets).length, 8);
    });

    test('historique : la plus récente en haut, nombre de mesures, rythme', () {
      final h = Mensurations.historique(mesures.reversed.toList()..shuffle());
      expect(h.first.date, DateTime(2026, 9, 28, 8));
      expect(h.last.date, DateTime(2026, 6, 8, 8));
      for (var i = 1; i < h.length; i++) {
        expect(h[i - 1].date.isAfter(h[i].date), isTrue);
      }
      expect(Mensurations.nbMesures(h.first), 8);
      expect(Mensurations.nbMesures(h[3]), 6);
      expect(Mensurations.joursEntreSaisies(mesures), 14);
      expect(Mensurations.joursEntreSaisies(mesures.take(1)), isNull);
      expect(Mensurations.jourLong(h.first.date, maintenant: ref), '28 septembre');
      expect(Mensurations.jourCourt(h.first.date), '28 sept. 2026');
      expect(Mensurations.moisDe(h.last.date, maintenant: ref), 'juin');
      expect(Mensurations.moisDe(h.last.date, maintenant: DateTime(2027, 1, 5)), 'juin 2026');
    });

    test('saisie : pas d\'un demi-centimètre et saisie au clavier', () {
      final champs = ChampSaisie.tous();
      expect(champs.map((c) => c.label), ['Poids', 'Taux de gras', 'Cou', 'Épaules', 'Poitrine', 'Biceps', 'Avant-bras', 'Taille', 'Cuisses', 'Mollets']);
      ChampSaisie champ(String cle) => champs.firstWhere((c) => c.cle == cle);
      final b = BrouillonSaisie.nouvelle(champs, mesures, date: ref);
      // Les dernières valeurs sont proposées, mais rien n'est retenu.
      expect(b.vide, isTrue);
      expect(b.valeur(champ('biceps')), 38);
      expect(b.estSaisi(champ('biceps')), isFalse);
      b.cran(champ('biceps'), 1);
      expect(b.valeur(champ('biceps')), 38.5);
      b.cran(champ('biceps'), -1);
      b.cran(champ('biceps'), -1);
      expect(b.valeur(champ('biceps')), 37.5);
      // Une valeur hors grille rejoint le cran voisin.
      b.fixer(champ('taille'), 81.3);
      b.cran(champ('taille'), 1);
      expect(b.valeur(champ('taille')), 81.5);
      b.fixer(champ('taille'), 81.3);
      b.cran(champ('taille'), -1);
      expect(b.valeur(champ('taille')), 81);
      b.cran(champ('poids'), 1);
      expect(b.valeur(champ('poids')), 76.8);
      b.fixer(champ('cou'), 999);
      expect(b.valeur(champ('cou')), 250);
      b.retirer(champ('cou'));

      final m = b.construire();
      expect(m.id, isEmpty);
      expect(m.date, DateTime(2026, 10, 2, 12));
      expect(m.poidsKg, 76.8);
      expect(Mensurations.valeur(m, ZoneMesure.biceps), 37.5);
      expect(m.tours[TourCorps.brasGauche], 37.5);
      expect(m.tours[TourCorps.brasDroit], 37.5);
      expect(Mensurations.valeur(m, ZoneMesure.taille), 81);
      // Ce qui n'a pas été touché n'est pas enregistré.
      expect(Mensurations.valeur(m, ZoneMesure.cou), isNull);
      expect(Mensurations.valeur(m, ZoneMesure.poitrine), isNull);
      expect(m.masseGrassePct, isNull);
    });

    test('saisie : zone jamais mesurée, valeur de départ', () {
      final champs = ChampSaisie.tous(poidsProfilKg: 80);
      final b = BrouillonSaisie.nouvelle(champs, const []);
      expect(b.valeur(champs.first), 80);
      final mollets = champs.firstWhere((c) => c.cle == 'mollets');
      b.cran(mollets, 1);
      expect(b.valeur(mollets), ZoneMesure.mollets.defaut + 0.5);
    });

    test('modifier une saisie : même identifiant, date changée, le reste gardé', () {
      final champs = ChampSaisie.tous();
      final origine = BodyMeasurement(
        id: 'a',
        date: DateTime(2026, 9, 14, 8),
        poidsKg: 76.2,
        masseMusculaireKg: 60,
        tours: const {TourCorps.brasGauche: 37, TourCorps.brasDroit: 38, TourCorps.hanches: 95, TourCorps.cou: 39},
        source: 'manuel',
      );
      final b = BrouillonSaisie.depuis(champs, origine, [origine]);
      ChampSaisie champ(String cle) => champs.firstWhere((c) => c.cle == cle);
      expect(b.modification, isTrue);
      expect(b.estSaisi(champ('biceps')), isTrue);
      expect(b.valeur(champ('biceps')), 37.5);
      expect(b.estSaisi(champ('taille')), isFalse);

      // Sans rien toucher : la saisie ressort identique, côtés compris.
      final meme = b.construire();
      expect(meme.id, 'a');
      expect(meme.date, origine.date);
      expect(meme.tours, origine.tours);
      expect(meme.poidsKg, 76.2);
      expect(meme.masseMusculaireKg, 60);

      b.date = DateTime(2026, 9, 13);
      b.cran(champ('cou'), 1);
      b.retirer(champ('biceps'));
      final m = b.construire();
      expect(m.id, 'a');
      expect(m.date, DateTime(2026, 9, 13, 12));
      expect(m.tours[TourCorps.cou], 39.5);
      expect(m.tours.containsKey(TourCorps.brasGauche), isFalse);
      expect(m.tours.containsKey(TourCorps.brasDroit), isFalse);
      // Les hanches ne sont pas dans le formulaire : elles restent.
      expect(m.tours[TourCorps.hanches], 95);
    });

    test('poids en livres : affichage converti, stockage en kilos', () {
      final champs = ChampSaisie.tous(unite: UnitePoids.lb);
      final m0 = BodyMeasurement(id: 'a', date: ref, poidsKg: 80);
      final b = BrouillonSaisie.depuis(champs, m0, [m0]);
      expect(b.valeur(champs.first), 176.4);
      expect(b.construire().poidsKg, 80);
      b.fixer(champs.first, 180);
      expect(b.construire().poidsKg, closeTo(81.647, 0.001));
    });

    test('dépôt : enregistrer, modifier, fusionner le même jour, supprimer', () async {
      final sante = HealthRepo(Store.memory());
      await sante.addMeasurementsAll(mesures);
      final champs = ChampSaisie.tous();
      ChampSaisie champ(String cle) => champs.firstWhere((c) => c.cle == cle);

      // Modification de la saisie du 14 septembre.
      final cible = sante.measurements.firstWhere((m) => m.id == 'm7');
      final b = BrouillonSaisie.depuis(champs, cible, sante.measurements)..cran(champ('biceps'), 1);
      await sante.saveMeasurement(b.construire());
      expect(sante.measurements.length, 9);
      expect(Mensurations.valeur(sante.measurements.firstWhere((m) => m.id == 'm7'), ZoneMesure.biceps), 38);
      expect(Mensurations.ecartsSuccessifs(Mensurations.serie(sante.measurements, ZoneMesure.biceps)).sublist(6), [null, 1.0, null]);

      // Nouvelle saisie un jour déjà saisi : elle complète la saisie du jour.
      final n = BrouillonSaisie.nouvelle(champs, sante.measurements, date: DateTime(2026, 9, 28, 20))..fixer(champ('cou'), 40);
      final fusion = Mensurations.duJour(sante.measurements, n.date);
      expect(fusion!.id, 'm8');
      await sante.saveMeasurement(n.construire(fusion: fusion));
      expect(sante.measurements.length, 9);
      final m8 = sante.measurements.firstWhere((m) => m.id == 'm8');
      expect(m8.tours[TourCorps.cou], 40);
      expect(m8.poidsKg, 76.7);
      expect(Mensurations.valeur(m8, ZoneMesure.poitrine), 104);

      // Nouvelle saisie un jour libre : une ligne de plus, en tête.
      final libre = BrouillonSaisie.nouvelle(champs, sante.measurements, date: DateTime(2026, 10, 1))..cran(champ('poids'), 1);
      expect(Mensurations.duJour(sante.measurements, libre.date), isNull);
      final cree = await sante.saveMeasurement(libre.construire());
      expect(cree.id, isNotEmpty);
      expect(Mensurations.historique(sante.measurements).first.id, cree.id);
      expect(sante.latestWeight, 76.8);

      // Suppression.
      await sante.deleteMeasurement('m8');
      expect(sante.measurements.any((m) => m.id == 'm8'), isFalse);
      expect(sante.measurements.length, 9);
      expect(Mensurations.etat(sante.measurements, ZoneMesure.cou).derniere!.valeur, 39);
    });
  });

  group('photos', () {
    final mesures = JeuMaquette.mesures();
    final photos = JeuMaquette.photos();

    test('par angle, la plus récente d\'abord', () {
      final face = Mensurations.photosDe(photos, PhotoVue.face);
      expect(face.length, 6);
      expect(face.first.date, DateTime(2026, 9, 28));
      expect(face.last.date, DateTime(2026, 6, 14));
      expect(Mensurations.photosDe(photos, PhotoVue.dos).length, 4);
      expect(photos.length, 14);
      expect(Mensurations.etiquette(face.first.date, maintenant: DateTime(2026, 10, 2)), '28 sept.');
    });

    test('comparaison : poids à chaque date, écart, mesure qui a le plus bougé', () {
      final face = Mensurations.photosDe(photos, PhotoVue.face);
      final c = Mensurations.comparer(face.last, face.first, mesures);
      expect(c.poidsAvant, 74.1);
      expect(c.poidsApres, 76.7);
      expect(c.ecartKg, 2.6);
      expect(c.semaines, 15);
      expect(c.zone, ZoneMesure.epaules);
      expect(c.ecartZone, 3);
      // Dans le désordre : même résultat.
      final inverse = Mensurations.comparer(face.first, face.last, mesures);
      expect(inverse.poidsAvant, 74.1);
      expect(inverse.ecartKg, 2.6);
      // Le poids noté sur la photo prime.
      final notee = ProgressPhoto(id: 'n', date: DateTime(2026, 9, 28), chemin: '', poidsKg: 77.5);
      expect(Mensurations.comparer(face.last, notee, mesures).poidsApres, 77.5);
      // Sans mesure : pas de poids, pas d'écart, pas de zone.
      final vide = Mensurations.comparer(face.last, face.first, const []);
      expect(vide.poidsAvant, isNull);
      expect(vide.ecartKg, isNull);
      expect(vide.zone, isNull);
      // Même poids : aucun écart affiché.
      final memes = [BodyMeasurement(id: 'a', date: DateTime(2026, 6, 1), poidsKg: 75)];
      expect(Mensurations.comparer(face.last, face.first, memes).ecartKg, isNull);
    });

    test('poids connu à une date', () {
      expect(Mensurations.poidsA(mesures, DateTime(2026, 9, 20)), 76.2);
      expect(Mensurations.poidsA(mesures, DateTime(2026, 9, 28)), 76.7);
      expect(Mensurations.poidsA(mesures, DateTime(2026, 1, 1)), 74.1);
      expect(Mensurations.poidsA(const [], DateTime(2026, 1, 1)), isNull);
    });

    test('une photo ajoutée est copiée dans le dossier de l\'appli', () async {
      final store = Store.memory();
      final dossier = await store.mediaDir();
      dossier.createSync(recursive: true);
      final modele = Directory('assets/objets').listSync().whereType<File>().first;
      final source = File('${Directory.systemTemp.path}${Platform.pathSeparator}aesthetic-test-source.png')..writeAsBytesSync(modele.readAsBytesSync());
      final sante = HealthRepo(store);
      final p = await sante.addPhoto(source.path, vue: PhotoVue.dos, poidsKg: 76.7, date: DateTime(2026, 9, 28));
      addTearDown(() {
        if (source.existsSync()) source.deleteSync();
        if (File(p.chemin).existsSync()) File(p.chemin).deleteSync();
      });
      expect(p.chemin, isNot(source.path));
      expect(File(p.chemin).existsSync(), isTrue);
      expect(File(p.chemin).parent.path, dossier.path);
      expect(Mensurations.photosDe(sante.photos, PhotoVue.dos).single.id, p.id);
      await sante.deletePhoto(p.id);
      expect(File(p.chemin).existsSync(), isFalse);
      expect(sante.photos, isEmpty);
    });
  });

  test('chemins du module', () {
    expect(ProfilPaths.mensurations, '/profil/mensurations');
    expect(ProfilPaths.photos, '/profil/photos');
    expect(ProfilPaths.zone(ZoneMesure.avantBras), '/profil/mensurations/zone/avantBras');
    expect(ProfilPaths.saisie(), '/profil/mensurations/saisie');
    expect(ProfilPaths.saisie(id: 'm7', zone: ZoneMesure.biceps), '/profil/mensurations/saisie?id=m7&zone=biceps');
    expect(ProfilPaths.comparer(vue: PhotoVue.dos), '/profil/photos/comparer?vue=dos');
    expect(ZoneMesure.parNom('biceps'), ZoneMesure.biceps);
    expect(ZoneMesure.parNom('inconnu'), isNull);
  });
}
