import 'dart:io';

import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalogue_test_data.dart';

String fixture(String nom) => File('test/fixtures/$nom').readAsStringSync();

ImportPreview analyser(String nom, {Iterable<DateTime> existants = const []}) =>
    ImportAnalyzer.analyser(fixture(nom), catalogue: catalogueTest, debutsExistants: existants);

ImportedExercise exo(ImportedSession s, String nom) =>
    s.exercices.firstWhere((e) => e.nomSource == nom);

void main() {
  group('détection', () {
    test('chaque fixture a le bon format', () {
      Detection d(String f) => detecterFormat(CsvTable.lire(fixture(f)));
      expect(d('format_a.csv').format, ImportFormat.legacy);
      expect(d('format_b.csv').format, ImportFormat.ordreSeries);
      expect(d('format_b_ancien.csv').format, ImportFormat.ordreSeries);
      expect(d('format_c.csv').format, ImportFormat.snakeCase);
      expect(d('generique_fr.csv').format, ImportFormat.generique);
      expect(d('pas_un_historique.csv').reconnu, isFalse);
      expect(d('format_a.csv').confiance, greaterThanOrEqualTo(0.9));
    });

    test('les libellés ne nomment aucune application', () {
      for (final f in ImportFormat.values) {
        for (final n in const ['atfyl', 'yveh', 'gnorts']) {
          expect(f.libelle.toLowerCase(), isNot(contains(n.split('').reversed.join())));
        }
      }
    });
  });

  group('format A', () {
    late ImportPreview p;
    setUp(() => p = analyser('format_a.csv'));

    test('séances, titres, durées', () {
      expect(p.seances, hasLength(3));
      final s = p.seances.first;
      expect(s.titre, 'Poussée A, lourde');
      expect(s.debut, DateTime(2026, 3, 18, 18, 5, 11));
      expect(s.duree, const Duration(hours: 1, minutes: 7, seconds: 22));
    });

    test('supersets regroupés malgré l\'alternance des lignes', () {
      final s = p.seances.first;
      expect([for (final e in s.exercices) e.nomSource], [
        'Barbell Bench Press',
        'Dumbbell Incline Bench Press',
        'Cable Pushdown',
        'Weighted Front Plank',
      ]);
      final push = exo(s, 'Cable Pushdown');
      expect(push.supersetGroupe, '1');
      expect(push.series.map((x) => x.reps), [12, 10]);
      expect(push.series.last.type, SetKind.degressive);
      expect(push.series.last.index, 2);
    });

    test('types de série, gainage chronométré, cardio', () {
      final bench = exo(p.seances.first, 'Barbell Bench Press');
      expect(bench.series.map((x) => x.type),
          [SetKind.echauffement, SetKind.normale, SetKind.normale, SetKind.echec]);
      final gainage = exo(p.seances.first, 'Weighted Front Plank').series.single;
      expect(gainage.dureeSec, 90);
      expect(gainage.poidsKg, isNull);
      final velo = exo(p.seances.last, 'Stationary Bike').series.single;
      expect(velo.distanceM, 2500);
      expect(velo.dureeSec, 600);
      expect(exo(p.seances[1], 'Pull-up').series.last.type, SetKind.negative);
      expect(exo(p.seances.last, 'Barbell Full Squat').series.last.type, SetKind.retour);
    });

    test('rapport et records', () {
      final r = p.rapport;
      expect(r.format, ImportFormat.legacy);
      expect(r.seances, 3);
      expect(r.seriesEchauffement, 2);
      expect(r.series, 18);
      expect(r.debut, DateTime(2026, 3, 18, 18, 5, 11));
      expect(r.seancesParMois, {'2026-03': 3});
      final bench = r.records.firstWhere((x) => x.exerciceId == 'developpe-couche-barre');
      expect(bench.nom, 'Développé couché à la barre');
      expect(bench.chargeMax, 82.5);
      expect(bench.repsALaChargeMax, 5);
      expect(bench.unRmEstime, closeTo(96.25, 0.001));
      expect(bench.volumeSeanceMax, 80 * 6 + 82.5 * 5 + 82.5 * 4);
      final squat = r.records.firstWhere((x) => x.exerciceId == 'squat-barre');
      expect(squat.chargeMax, 100, reason: 'l\'échauffement ne compte pas');
    });

    test('noms reconnus, ambigus, inconnus', () {
      Rapprochement rap(String n) => p.rapprochements[cleNom(n)]!;
      expect(rap('Barbell Bench Press').statut, StatutRapprochement.exact);
      expect(rap('Dumbbell Incline Curl').exerciceId, 'curl-incline-halteres');
      expect(rap('Pull-up').exerciceId, 'tractions');
      expect(rap('Lever Narrow Grip Seated Row').statut, StatutRapprochement.ambigu);
      expect(rap('Lever Narrow Grip Seated Row').candidats.first.entree.id, 'rowing-assis-machine');
      expect(rap('Curl Zottman Tempo Maison').statut, StatutRapprochement.inconnu);
      expect(p.rapport.pret, isFalse);
    });

    test('confirmation manuelle, exercice personnel et mémoire réutilisable', () {
      p.confirmer('Lever Narrow Grip Seated Row', 'rowing-assis-machine');
      p.creerPersonnel('Curl Zottman Tempo Maison');
      p.accepterSuggestions(toutes: true);
      p.rapport.aConfirmer
          .where((r) => r.statut == StatutRapprochement.inconnu)
          .forEach((r) => p.creerPersonnel(r.nomSource));
      expect(p.rapport.aConfirmer, isEmpty);
      expect(p.rapport.pret, isTrue);
      expect(exo(p.seances[1], 'Lever Narrow Grip Seated Row').exerciceId, 'rowing-assis-machine');
      expect(exo(p.seances[1], 'Curl Zottman Tempo Maison').exerciceId, isNull);

      // Un second import avec la même mémoire ne redemande rien.
      final p2 = ImportAnalyzer.analyser(fixture('format_a.csv'),
          catalogue: catalogueTest, memoire: Map.of(p.memoire));
      expect(p2.rapport.aConfirmer, isEmpty);
    });

    test('doublons écartés', () {
      final p = analyser('format_a.csv', existants: [DateTime(2026, 3, 20, 7, 30, 45)]);
      expect(p.seances[1].doublon, isTrue);
      expect(p.aImporter, hasLength(2));
      expect(p.rapport.seances, 2);
      expect(p.rapport.seancesDoublons, 1);
    });

    test('aller-retour JSON du modèle intermédiaire', () {
      final s = p.seances.first;
      final copie = ImportedSession.fromJson(s.toJson());
      expect(copie.toJson(), s.toJson());
    });
  });

  group('format B', () {
    test('export récent à points-virgules', () {
      final p = analyser('format_b.csv');
      expect(p.seances, hasLength(2));
      final s = p.seances.first;
      expect(s.duree, const Duration(seconds: 3900));
      expect(s.notes, 'Bonne séance');
      final bench = exo(s, 'Bench Press (Barbell)');
      expect(bench.series, hasLength(3), reason: 'la ligne de repos est ignorée');
      expect(bench.series.first.type, SetKind.echauffement);
      expect(bench.series[2].poidsKg, 82.5);
      expect(bench.series[1].rpe, 8);
      expect(bench.notes, 'Pause en bas');
      expect(exo(s, 'Lat Pulldown (Cable)').series.last.type, SetKind.degressive);
      expect(exo(s, 'Plank').series.single.dureeSec, 60);
      expect(exo(p.seances.last, 'Squat (Barbell)').series.last.type, SetKind.echec);
      expect(exo(p.seances.last, 'Running').series.single.distanceM, 1200);
      expect(p.parse.messages.any((m) => m.texte.contains('repos')), isTrue);
      expect(p.rapprochements[cleNom('Bench Press (Barbell)')]!.exerciceId, 'developpe-couche-barre');
      expect(p.rapprochements[cleNom('Lat Pulldown (Cable)')]!.exerciceId, 'tirage-vertical');
    });

    test('ancien export en livres', () {
      final p = analyser('format_b_ancien.csv');
      expect(p.seances, hasLength(2));
      expect(p.seances.first.duree, const Duration(hours: 1, minutes: 5));
      expect(p.seances.last.duree, const Duration(minutes: 45));
      final dl = exo(p.seances.first, 'Deadlift (Barbell)');
      expect(dl.series.first.poidsKg, closeTo(102.06, 0.01));
      expect(exo(p.seances.last, 'Rowing Machine').series.single.distanceM, 2000);
      expect(p.rapprochements[cleNom('Chin Up')]!.exerciceId, 'traction-supination');
    });
  });

  group('format C', () {
    test('snake_case, supersets, notes, fin de séance', () {
      final p = analyser('format_c.csv');
      expect(p.seances, hasLength(2));
      final s = p.seances.first;
      expect(s.debut, DateTime(2025, 12, 22, 8));
      expect(s.duree, const Duration(minutes: 72));
      expect(s.notes, 'Salle vide');
      expect([for (final e in s.exercices) e.nomSource],
          ['Bench Press (Barbell)', 'Lateral Raise (Dumbbell)', 'Triceps Rope Pushdown']);
      expect(exo(s, 'Bench Press (Barbell)').notes, 'Coudes serrés');
      expect(exo(s, 'Lateral Raise (Dumbbell)').series.map((x) => x.type),
          [SetKind.normale, SetKind.degressive]);
      expect(exo(s, 'Triceps Rope Pushdown').series.last.type, SetKind.echec);
      expect(exo(s, 'Bench Press (Barbell)').series.last.rpe, 8.5);
      expect(exo(p.seances.last, 'Dead Hang').series.single.dureeSec, 45);
      expect(p.rapprochements[cleNom('Pull Up (Assisted)')]!.exerciceId, 'tractions-assistees');
      expect(p.rapprochements[cleNom('Triceps Rope Pushdown')]!.exerciceId, 'extension-triceps-poulie');
    });
  });

  group('tableau quelconque', () {
    test('colonnes françaises devinées', () {
      final p = analyser('generique_fr.csv');
      expect(p.parse.format, ImportFormat.generique);
      final m = p.detection.colonnes!;
      expect(m.colonnes[ChampImport.seance], 1);
      expect(m.colonnes[ChampImport.poids], 4);
      expect(m.colonnes[ChampImport.reps], 5);
      expect(p.seances, hasLength(2));
      expect(p.seances.first.debut, DateTime(2026, 7, 13));
      final dc = exo(p.seances.first, 'Développé couché barre');
      expect(dc.series.map((x) => x.poidsKg), [70, 72.5]);
      expect(dc.exerciceId, 'developpe-couche-barre');
      expect(exo(p.seances.first, 'Écarté poulie vis-à-vis').exerciceId, 'ecarte-poulie');
      expect(exo(p.seances.last, 'Tractions').exerciceId, 'tractions');
      expect(exo(p.seances.last, 'Tractions').series.single.poidsKg, isNull);
      expect(p.rapprochements[cleNom('Rowing haltère un bras')]!.candidats.first.entree.id,
          'rowing-haltere');
    });

    test('association manuelle des colonnes', () {
      const csv = 'quand,quoi,combien,fois\n2026-01-02,Squat (Barbell),100,5\n';
      final auto = ImportAnalyzer.analyser(csv, catalogue: catalogueTest);
      expect(auto.seances, isEmpty);
      final m = ColumnMapping({
        ChampImport.date: 0,
        ChampImport.exercice: 1,
        ChampImport.poids: 2,
        ChampImport.reps: 3,
      });
      final p = ImportAnalyzer.analyser(csv, catalogue: catalogueTest, colonnes: m);
      expect(p.seances.single.exercices.single.series.single.volume, 500);
      expect(p.seances.single.exercices.single.exerciceId, 'squat-barre');
    });

    test('fichier sans rapport ou vide', () {
      final p = analyser('pas_un_historique.csv');
      expect(p.seances, isEmpty);
      expect(p.parse.aDesErreurs, isTrue);
      final vide = ImportAnalyzer.analyser('', catalogue: catalogueTest);
      expect(vide.parse.aDesErreurs, isTrue);
    });
  });
}
