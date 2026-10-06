import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/profil/data/backup_service.dart';
import 'package:aesthetic/features/profil/data/career.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/data/prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Cas limites de la zone profil, sans écran.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final champs = ChampSaisie.tous();
  ChampSaisie champ(String cle, [List<ChampSaisie>? dans]) => (dans ?? champs).firstWhere((c) => c.cle == cle);
  BodyMeasurement m(String id, DateTime d, {double? poids, double? gras, Map<TourCorps, double> tours = const {}}) =>
      BodyMeasurement(id: id, date: d, poidsKg: poids, masseGrassePct: gras, tours: tours, source: 'manuel');

  group('écart depuis la première saisie', () {
    test('baisse, inchangé, une seule saisie', () {
      final ms = [
        m('a', DateTime(2026, 6, 1), tours: {TourCorps.taille: 84, TourCorps.cou: 39, TourCorps.poitrine: 100}),
        m('b', DateTime(2026, 9, 1), tours: {TourCorps.taille: 82.5, TourCorps.cou: 39}),
      ];
      expect(Mensurations.ecartTexte(Mensurations.etat(ms, ZoneMesure.taille).ecart), '−1,5');
      expect(Mensurations.etat(ms, ZoneMesure.cou).ecart, isNull);
      // Poitrine : une seule saisie, rien à comparer.
      expect(Mensurations.etat(ms, ZoneMesure.poitrine).derniere!.valeur, 100);
      expect(Mensurations.etat(ms, ZoneMesure.poitrine).ecart, isNull);
      // Jamais mesuré.
      expect(Mensurations.etat(ms, ZoneMesure.mollets).derniere, isNull);
      expect(Mensurations.etat(ms, ZoneMesure.mollets).ecart, isNull);
    });

    test('mesure absente de la première ou de la dernière saisie', () {
      final ms = [
        m('a', DateTime(2026, 6, 1), tours: {TourCorps.cou: 38}),
        m('b', DateTime(2026, 7, 1), tours: {TourCorps.cou: 38.5, TourCorps.epaules: 118}),
        m('c', DateTime(2026, 8, 1), tours: {TourCorps.epaules: 120}),
        m('d', DateTime(2026, 9, 1), poids: 75),
      ];
      // Le cou n'est plus mesuré après juillet : la dernière valeur connue.
      final cou = Mensurations.etat(ms, ZoneMesure.cou);
      expect(cou.derniere!.id, 'b');
      expect(cou.ecart, 0.5);
      // Les épaules commencent en juillet.
      final ep = Mensurations.etat(ms, ZoneMesure.epaules);
      expect(ep.premiere!.id, 'b');
      expect(ep.ecart, 2);
    });

    test('pas d\'erreur d\'arrondi sur les écarts', () {
      for (var i = 0; i < 400; i++) {
        final a = 30 + i * 0.5;
        expect(Mensurations.ecart(a, a + 0.5), 0.5, reason: '$a');
        expect(Mensurations.ecart(a + 0.5, a), -0.5, reason: '$a');
        expect(Mensurations.ecart(a, a), isNull);
      }
      expect(Mensurations.ecart(74.1, 76.7), 2.6);
      expect(Mensurations.ecartTexte(Mensurations.ecart(36.6, 36.7)), '+0,1');
      expect(Mensurations.ecartTexte(Mensurations.ecart(70.1, 70.1 + 1e-9)), isNull);
    });
  });

  group('gauche et droite', () {
    test('un seul côté mesuré, deux côtés différents', () {
      final unSeul = m('a', DateTime(2026, 6, 1), tours: {TourCorps.brasGauche: 37});
      expect(Mensurations.valeur(unSeul, ZoneMesure.biceps), 37);
      final deux = m('b', DateTime(2026, 6, 1), tours: {TourCorps.cuisseGauche: 58, TourCorps.cuisseDroite: 59});
      expect(Mensurations.valeur(deux, ZoneMesure.cuisses), 58.5);
    });

    test('corriger une autre mesure ne lisse pas un écart gauche et droite', () {
      final o = m('a', DateTime(2026, 9, 1), poids: 75, tours: {TourCorps.brasGauche: 36, TourCorps.brasDroit: 36.5, TourCorps.cou: 39});
      final b = BrouillonSaisie.depuis(champs, o, [o]);
      b.cran(champ('cou'), 1);
      final r = b.construire();
      expect(r.tours[TourCorps.brasGauche], 36);
      expect(r.tours[TourCorps.brasDroit], 36.5);
      expect(r.tours[TourCorps.cou], 39.5);
    });

    test('un cran sur une moyenne hors grille rejoint la grille, sans dérive', () {
      final o = m('a', DateTime(2026, 9, 1), tours: {TourCorps.brasGauche: 36, TourCorps.brasDroit: 36.5});
      final b = BrouillonSaisie.depuis(champs, o, [o]);
      b.cran(champ('biceps'), 1);
      expect(b.valeur(champ('biceps')), 36.5);
      b.cran(champ('biceps'), -1);
      expect(b.valeur(champ('biceps')), 36);
    });
  });

  group('pas des boutons', () {
    test('un demi-centimètre, 400 crans montants puis descendants, toujours sur la grille', () {
      final b = BrouillonSaisie.nouvelle(champs, const []);
      final c = champ('epaules');
      b.fixer(c, 30);
      for (var i = 1; i <= 400; i++) {
        b.cran(c, 1);
        expect(b.valeur(c), 30 + i * 0.5, reason: 'cran $i');
        expect(Fmt.n(b.valeur(c)).length <= 5, isTrue);
      }
      for (var i = 399; i >= 0; i--) {
        b.cran(c, -1);
        expect(b.valeur(c), 30 + i * 0.5, reason: 'cran $i');
      }
    });

    test('un dixième de kilo et de pour cent, 1000 crans', () {
      final b = BrouillonSaisie.nouvelle(champs, const []);
      for (final cle in [ChampSaisie.clePoids, ChampSaisie.cleGras]) {
        final c = champ(cle);
        b.fixer(c, 20);
        for (var i = 1; i <= 300; i++) {
          b.cran(c, 1);
          expect(b.valeur(c), (200 + i) / 10, reason: '$cle cran $i');
        }
      }
    });

    test('bornes : on ne descend pas sous le minimum ni au-dessus du maximum', () {
      final b = BrouillonSaisie.nouvelle(champs, const []);
      final c = champ('cou');
      b.fixer(c, c.min);
      b.cran(c, -1);
      expect(b.valeur(c), c.min);
      b.fixer(c, c.max);
      b.cran(c, 1);
      expect(b.valeur(c), c.max);
      b.fixer(c, -3);
      expect(b.valeur(c), c.min);
      b.fixer(c, 0);
      expect(b.valeur(c), c.min);
    });

    test('livres : chaque dixième de livre revient identique après stockage en kilos', () {
      final lb = ChampSaisie.tous(unite: UnitePoids.lb);
      final c = champ(ChampSaisie.clePoids, lb);
      expect(c.unite, 'lb');
      for (var i = 440; i <= 4400; i++) {
        final v = i / 10;
        final b = BrouillonSaisie.nouvelle(lb, const [], date: DateTime(2026, 9, 1))..fixer(c, v);
        final enregistre = b.construire();
        final relu = BrouillonSaisie.depuis(lb, BodyMeasurement(id: 'x', date: enregistre.date, poidsKg: enregistre.poidsKg), const []);
        expect(relu.valeur(c), v, reason: '$v lb');
      }
    });

    test('livres : la valeur de départ vient du profil, convertie', () {
      final lb = ChampSaisie.tous(unite: UnitePoids.lb, poidsProfilKg: 80);
      final b = BrouillonSaisie.nouvelle(lb, const []);
      expect(b.valeur(lb.first), 176.4);
      // Les tours restent en centimètres.
      expect(champ('biceps', lb).unite, 'cm');
    });
  });

  group('fusion de deux saisies le même jour', () {
    final jour = DateTime(2026, 9, 28, 8);
    final matin = BodyMeasurement(
      id: 'matin',
      date: jour,
      poidsKg: 76.7,
      masseGrassePct: 14.2,
      masseMusculaireKg: 61,
      tours: const {TourCorps.cou: 39, TourCorps.brasGauche: 37.5, TourCorps.brasDroit: 38.5, TourCorps.hanches: 96},
      source: 'health connect',
    );

    test('rien n\'est écrasé : ce qui n\'est pas ressaisi reste', () {
      final b = BrouillonSaisie.nouvelle(champs, [matin], date: DateTime(2026, 9, 28, 21))..fixer(champ('taille'), 82);
      final r = b.construire(fusion: Mensurations.duJour([matin], b.date));
      expect(r.id, 'matin');
      expect(r.date, jour);
      expect(r.poidsKg, 76.7);
      expect(r.masseGrassePct, 14.2);
      expect(r.masseMusculaireKg, 61);
      expect(r.source, 'health connect');
      expect(r.tours, {TourCorps.cou: 39, TourCorps.brasGauche: 37.5, TourCorps.brasDroit: 38.5, TourCorps.hanches: 96, TourCorps.taille: 82});
    });

    test('une valeur ressaisie remplace celle du matin, et seulement elle', () {
      final b = BrouillonSaisie.nouvelle(champs, [matin], date: DateTime(2026, 9, 28, 21))
        ..fixer(champ(ChampSaisie.clePoids), 77.4)
        ..fixer(champ('biceps'), 38);
      final r = b.construire(fusion: matin);
      expect(r.poidsKg, 77.4);
      expect(r.masseGrassePct, 14.2);
      // Même valeur moyenne qu'avant : les deux côtés restent tels quels.
      expect(r.tours[TourCorps.brasGauche], 37.5);
      expect(r.tours[TourCorps.brasDroit], 38.5);
      expect(r.tours[TourCorps.cou], 39);
    });

    test('la veille à 23 h 59 et le jour à 0 h ne se fusionnent pas', () {
      final veille = m('v', DateTime(2026, 9, 27, 23, 59), poids: 76);
      expect(Mensurations.duJour([veille], DateTime(2026, 9, 28, 0, 0)), isNull);
      expect(Mensurations.duJour([veille], DateTime(2026, 9, 27, 0, 0))!.id, 'v');
    });

    test('changer la date d\'une saisie vers un jour déjà saisi : une seule saisie ce jour-là, rien de perdu', () async {
      final sante = HealthRepo(Store.memory());
      final a = m('a', DateTime(2026, 9, 14, 8), poids: 76.2, gras: 14.3, tours: {TourCorps.cou: 39, TourCorps.hanches: 95});
      final c = m('c', DateTime(2026, 9, 28, 8), poids: 76.7, tours: {TourCorps.cou: 39.5, TourCorps.taille: 82});
      await sante.addMeasurementsAll([a, c]);
      final b = BrouillonSaisie.depuis(champs, c, sante.measurements)..date = DateTime(2026, 9, 14);
      await enregistrerSaisie(sante, b);
      final duJour = sante.measurements.where((x) => Dates.memeJour(x.date, DateTime(2026, 9, 14))).toList();
      expect(duJour.length, 1, reason: 'deux saisies le même jour');
      expect(sante.measurements.length, 1);
      final r = duJour.single;
      // La saisie déplacée prime là où elle a une valeur.
      expect(r.poidsKg, 76.7);
      expect(r.tours[TourCorps.cou], 39.5);
      expect(r.tours[TourCorps.taille], 82);
      // Ce que seule l'autre saisie portait est gardé.
      expect(r.masseGrassePct, 14.3);
      expect(r.tours[TourCorps.hanches], 95);
    });
  });

  group('périodes et rythme', () {
    test('trois mois avant un 31 mai : la période commence fin février, pas début mars', () {
      final debut = PeriodeMesure.troisMois.debut(DateTime(2026, 5, 31))!;
      expect(debut, DateTime(2026, 2, 28));
      expect(PeriodeMesure.sixMois.debut(DateTime(2026, 8, 31)), DateTime(2026, 2, 28));
      expect(PeriodeMesure.unAn.debut(DateTime(2028, 2, 29)), DateTime(2027, 2, 28));
      expect(PeriodeMesure.troisMois.debut(DateTime(2026, 1, 15)), DateTime(2025, 10, 15));
    });

    test('une seule saisie dans la période : pas d\'écart, la courbe tient en un point', () {
      final ms = [m('a', DateTime(2025, 1, 1), tours: {TourCorps.cou: 38}), m('b', DateTime(2026, 9, 1), tours: {TourCorps.cou: 39})];
      final s = Mensurations.serie(ms, ZoneMesure.cou, depuis: PeriodeMesure.troisMois.debut(DateTime(2026, 10, 2)));
      expect(s.single.id, 'b');
      expect(Mensurations.serie(ms, ZoneMesure.cou, depuis: DateTime(2026, 9, 2)), isEmpty);
    });

    test('rythme : le passage à l\'heure d\'hiver ne fausse pas les jours', () {
      final ms = [m('a', DateTime(2026, 10, 18, 8), poids: 75), m('b', DateTime(2026, 11, 1, 8), poids: 75)];
      expect(Mensurations.joursEntreSaisies(ms), 14);
      final p1 = ProgressPhoto(id: '1', date: DateTime(2026, 10, 18), chemin: '');
      final p2 = ProgressPhoto(id: '2', date: DateTime(2026, 11, 1), chemin: '');
      expect(Mensurations.comparer(p1, p2, ms).semaines, 2);
    });
  });

  group('photos', () {
    test('comparer deux photos du même jour : zéro semaine, pas de division par zéro', () {
      final j = DateTime(2026, 9, 28, 9);
      final p1 = ProgressPhoto(id: '1', date: j, chemin: '');
      final p2 = ProgressPhoto(id: '2', date: j, chemin: '');
      final c = Mensurations.comparer(p1, p2, [m('a', j, poids: 76)]);
      expect(c.semaines, 0);
      expect(c.ecartKg, isNull);
      expect(c.zone, isNull);
      // Pas de « 0 jour » : rien à dire quand c'est le même jour.
      expect(Mensurations.duree(p1.date, p2.date), isNull);
      expect(Mensurations.duree(DateTime(2026, 9, 1, 23), DateTime(2026, 9, 2, 1)), '1 jour');
      expect(Mensurations.duree(DateTime(2026, 9, 1), DateTime(2026, 9, 5)), '4 jours');
      expect(Mensurations.duree(DateTime(2026, 9, 1), DateTime(2026, 9, 8)), '1 semaine');
      expect(Mensurations.duree(DateTime(2026, 6, 14), DateTime(2026, 9, 28)), '15 semaines');
    });

    test('ajouter une photo dont le fichier n\'a pas d\'extension, dans un dossier à point', () async {
      final store = Store.memory();
      final medias = await store.mediaDir();
      medias.createSync(recursive: true);
      final dossier = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}fr.aesthetic.test')..createSync(recursive: true);
      final modele = Directory('assets/objets').listSync().whereType<File>().first;
      final source = File('${dossier.path}${Platform.pathSeparator}image_sans_extension')..writeAsBytesSync(modele.readAsBytesSync());
      final sante = HealthRepo(store);
      addTearDown(() {
        for (final p in sante.photos) {
          if (File(p.chemin).existsSync()) File(p.chemin).deleteSync();
        }
        if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      });
      final p = await sante.addPhoto(source.path);
      expect(File(p.chemin).existsSync(), isTrue);
      expect(File(p.chemin).parent.path, medias.path);
    });
  });

  group('chiffres du profil', () {
    WorkoutSession s(String id, DateTime d, {bool enCours = false}) =>
        WorkoutSession(id: id, nom: 'Séance', debut: d, fin: enCours ? null : d.add(const Duration(hours: 1)));

    test('aucune séance, une séance, séance en cours non comptée', () {
      final now = DateTime(2026, 10, 2, 18);
      expect(CareerStats.from(const [], now: now).seances, 0);
      expect(CareerStats.from(const [], now: now).semainesConsecutives, 0);
      final une = CareerStats.from([s('a', DateTime(2026, 10, 1, 18))], now: now);
      expect(une.seances, 1);
      expect(une.semainesConsecutives, 1);
      expect(une.nbRecords, 0);
      final avecEnCours = CareerStats.from([s('a', DateTime(2026, 10, 1, 18)), s('b', DateTime(2026, 10, 2, 17), enCours: true)], now: now);
      expect(avecEnCours.seances, 1);
    });

    test('série de semaines à cheval sur l\'année et sur le changement d\'heure', () {
      final now = DateTime(2027, 1, 6, 10);
      final dates = [for (var i = 0; i < 16; i++) DateTime(2027, 1, 5, 18).subtract(Duration(days: 7 * i))];
      final stats = CareerStats.from([for (final (i, d) in dates.indexed) s('s$i', d)], now: now);
      expect(stats.semainesConsecutives, 16);
    });
  });

  group('premier jour de la semaine', () {
    test('la semaine commence bien le jour choisi, changement d\'heure compris', () {
      // Dimanche 29 mars 2026 : passage à l'heure d'été en France.
      expect(Dates.debutSemaine(DateTime(2026, 4, 1, 10), premierJour: DateTime.sunday), DateTime(2026, 3, 29));
      expect(Dates.debutSemaine(DateTime(2026, 4, 3, 10), premierJour: DateTime.saturday), DateTime(2026, 3, 28));
      expect(Dates.debutSemaine(DateTime(2026, 4, 1, 10)), DateTime(2026, 3, 30));
      // Dimanche 25 octobre 2026 : retour à l'heure d'hiver.
      expect(Dates.debutSemaine(DateTime(2026, 10, 28, 10), premierJour: DateTime.sunday), DateTime(2026, 10, 25));
      expect(Dates.debutSemaine(DateTime(2026, 10, 30, 10), premierJour: DateTime.saturday), DateTime(2026, 10, 24));
      expect(Dates.debutSemaine(DateTime(2026, 10, 28, 10)), DateTime(2026, 10, 26));
    });
  });

  group('sauvegarde', () {
    Future<AppData> pleine() async {
      PrefsRepo.reset();
      final data = AppData(Store.memory(), demo: true);
      await data.loadAll();
      await DemoData.seed(data);
      await data.settings.update((s) => s.copyWith(reposParDefautSec: 125, premierJourSemaine: DateTime.sunday, incrementPoidsKg: 1.25));
      await data.profile.update((p) => p.copyWith(unitePoids: UnitePoids.lb));
      final prefs = await PrefsRepo.ensure(data.store);
      await prefs.update((p) => p.copyWith(tailleTexte: TailleTexte.grande, minuteurAuto: false, longueur: UniteLongueur.pouce, disques: const [Disque(poidsKg: 5, paires: 3)]));
      await data.health.saveMeasurement(BodyMeasurement(id: '', date: DateTime(2026, 9, 30, 12), poidsKg: 76.75, tours: const {TourCorps.brasGauche: 37.5, TourCorps.hanches: 96}));
      return data;
    }

    test('aller-retour : les données restaurées sont exactement celles exportées', () async {
      final a = await pleine();
      final brut = await a.exportBackup();
      final avant = (jsonDecode(brut) as Map)['donnees'] as Map;
      expect(avant.keys, containsAll(['profil', 'reglages', 'mesures', 'photos', 'seances', PrefsRepo.file]));

      final b = AppData(Store.memory());
      await b.loadAll();
      // Des données déjà présentes, qui doivent disparaître.
      await b.health.saveMeasurement(BodyMeasurement(id: 'intrus', date: DateTime(2020, 1, 1), poidsKg: 99));
      await BackupService(b).restaurer(brut);
      final apres = (jsonDecode(await b.exportBackup()) as Map)['donnees'] as Map;
      expect(apres.keys.toSet(), avant.keys.toSet());
      for (final k in avant.keys) {
        expect(jsonEncode(apres[k]), jsonEncode(avant[k]), reason: 'collection $k');
      }
      expect(b.health.measurements.any((x) => x.id == 'intrus'), isFalse);
      expect(b.health.measurements.length, a.health.measurements.length);
      expect(b.sessions.sessions.length, a.sessions.sessions.length);
      expect(b.settings.settings.reposParDefautSec, 125);
      expect(b.settings.settings.premierJourSemaine, DateTime.sunday);
      expect(b.profile.unite, UnitePoids.lb);
      final relue = b.health.measurements.firstWhere((x) => x.poidsKg == 76.75);
      expect(relue.tours, {TourCorps.brasGauche: 37.5, TourCorps.hanches: 96});
      expect(relue.date, DateTime(2026, 9, 30, 12));
    });

    test('après une restauration faite par un autre module, les préférences relues sont celles de la sauvegarde', () async {
      final a = await pleine();
      final brut = await a.exportBackup();
      // Sur le même téléphone, les préférences changent, puis on restaure
      // par AppData.importBackup (chemin de l'écran Sauvegarde).
      final prefs = await PrefsRepo.ensure(a.store);
      await prefs.update((p) => p.copyWith(tailleTexte: TailleTexte.petite, minuteurAuto: true));
      await a.importBackup(brut);
      final relues = (await PrefsRepo.ensure(a.store)).prefs;
      expect(relues.tailleTexte, TailleTexte.grande);
      expect(relues.minuteurAuto, isFalse);
      expect(relues.disques.single.paires, 3);
    });

    test('fichier refusé : rien n\'est touché', () async {
      final a = await pleine();
      final n = a.health.measurements.length;
      for (final mauvais in ['', 'pas du json', '[]', '{"application":"autre","donnees":{}}', '{"application":"aesthetic"}']) {
        await expectLater(a.importBackup(mauvais), throwsA(isA<FormatException>()), reason: mauvais);
        expect(() => BackupService.lire(mauvais), throwsA(isA<FormatException>()), reason: mauvais);
      }
      expect(a.health.measurements.length, n);
      expect(a.profile.profile, isNotNull);
    });
  });
}
