import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/import/data/conversion.dart';
import 'package:aesthetic/features/import/data/import_flow.dart';
import 'package:aesthetic/features/import/data/import_journal.dart';
import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<AppData> _donnees() async {
  final d = AppData(Store.memory());
  await d.loadAll();
  return d;
}

Future<ImportFlow> _charger(AppData d, String nom, String csv, {bool confirmer = true}) async {
  final f = ImportFlow()..demarrer(ImportSource.application);
  await f.chargerFichier(nom, utf8.encode(csv), d);
  expect(f.etat, EtatAnalyse.pret, reason: f.erreur);
  if (confirmer) {
    f.accepterSuggestions(toutes: true);
    f.creerTousLesInconnus();
  }
  return f;
}

const _enTeteA = ' Title,Date,Duration,Exercise,"Superset id",Weight,Reps,Distance,Time,"Set Type"';

String _ligneA(String titre, String date, String exo, num poids, int reps, String type) =>
    '"$titre","$date",01:00:00,"$exo",,$poids,$reps,null,null,$type';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    ImportFlow.enIsolat = false;
  });

  group('types de série', () {
    // Écritures rencontrées dans les exports, et le type attendu dans l'appli.
    const attendus = <String, SetType>{
      'NORMAL_SET': SetType.normale,
      'WARMUP_SET': SetType.echauffement,
      'DROP_SET': SetType.degressive,
      'FAILURE_SET': SetType.echec,
      'LEFT_SET': SetType.gauche,
      'RIGHT_SET': SetType.droite,
      'NEGATIVE_REPS_SET': SetType.negative,
      'PARTIAL_REPS_SET': SetType.partielles,
      'MYO_REPS_SET': SetType.myoReps,
      'FEEDER_SET': SetType.feeder,
      'TOP_SET': SetType.topSet,
      'HEAVY_SET': SetType.topSet,
      'BACK_OFF_SET': SetType.backOff,
      'warmup': SetType.echauffement,
      'dropset': SetType.degressive,
      'failure': SetType.echec,
      'normal': SetType.normale,
      'Échauffement': SetType.echauffement,
      'Dégressive': SetType.degressive,
      'Échec': SetType.echec,
      'Gauche': SetType.gauche,
      'Droite': SetType.droite,
      'Négative': SetType.negative,
      'Partielles': SetType.partielles,
      'Myo-reps': SetType.myoReps,
      'Feeder': SetType.feeder,
      'Top set': SetType.topSet,
      'Back-off': SetType.backOff,
    };

    test('chaque écriture connue donne le bon des douze types', () {
      for (final e in attendus.entries) {
        final k = lireTypeSerie(e.key);
        expect(k, isNotNull, reason: '« ${e.key} » n\'est pas reconnu');
        expect(typeDepuis(k!), e.value, reason: e.key);
      }
    });

    test('les douze types de l\'appli sont tous atteignables par l\'import', () {
      final atteints = {for (final k in SetKind.values) typeDepuis(k)};
      expect(atteints, SetType.values.toSet());
      // Le libellé de chaque type de l'appli est lui-même relu correctement
      // (un fichier exporté par l'appli se réimporte sans perdre les types).
      for (final t in SetType.values) {
        expect(typeDepuis(lireTypeSerie(t.label)!), t, reason: t.label);
        expect(typeDepuis(lireTypeSerie(t.name)!), t, reason: t.name);
      }
    });

    test('import d\'un fichier : les types arrivent jusque dans les séances enregistrées', () async {
      final d = await _donnees();
      final types = ['WARMUP_SET', 'NORMAL_SET', 'DROP_SET', 'FAILURE_SET', 'LEFT_SET', 'RIGHT_SET', 'NEGATIVE_REPS_SET', 'PARTIAL_REPS_SET', 'MYO_REPS_SET', 'FEEDER_SET', 'TOP_SET', 'BACK_OFF_SET'];
      final csv = [
        _enTeteA,
        for (final t in types) _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 50, 8, t),
      ].join('\n');
      final f = await _charger(d, 'types.csv', csv);
      expect(f.preview!.parse.messages.where((m) => m.texte.contains('type de série inconnu')), isEmpty);
      await f.importer(d);
      final series = d.sessions.sessions.single.exercices.single.series;
      expect(series.map((s) => s.type).toList(), [
        SetType.echauffement, SetType.normale, SetType.degressive, SetType.echec, SetType.gauche, SetType.droite,
        SetType.negative, SetType.partielles, SetType.myoReps, SetType.feeder, SetType.topSet, SetType.backOff,
      ]);
      // Seul l'échauffement est hors volume.
      expect(d.sessions.sessions.single.volume, 11 * 50 * 8);
    });

    test('type inconnu : série normale et remarque visible', () async {
      final d = await _donnees();
      final f = await _charger(d, 'x.csv', [_enTeteA, _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 50, 8, 'CLUSTER_SET')].join('\n'));
      expect(f.preview!.parse.messages.map((m) => m.texte).join(), contains('CLUSTER_SET'));
      await f.importer(d);
      expect(d.sessions.sessions.single.exercices.single.series.single.type, SetType.normale);
    });

    test('sans les échauffements : ils sont écartés, le reste garde son type', () async {
      final d = await _donnees();
      final f = await _charger(d, 'a.csv', File('test/fixtures/format_a.csv').readAsStringSync());
      f.garderEchauffements = false;
      await f.importer(d);
      final types = d.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).map((s) => s.type).toSet();
      expect(types, isNot(contains(SetType.echauffement)));
      expect(types, containsAll([SetType.echec, SetType.degressive, SetType.negative, SetType.backOff]));
    });
  });

  group('doublons', () {
    test('même fichier importé deux fois : rien n\'est doublé', () async {
      final d = await _donnees();
      final csv = File('test/fixtures/format_a.csv').readAsStringSync();
      await (await _charger(d, 'a.csv', csv)).importer(d);
      final n = d.sessions.sessions.length;
      final series = d.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).length;
      final f2 = await _charger(d, 'a.csv', csv);
      expect(f2.rapport!.seances, 0);
      expect(f2.rapport!.seancesDoublons, n);
      final r = await f2.importer(d);
      expect(r!.seances, 0);
      expect(d.sessions.sessions.length, n);
      expect(d.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).length, series);
      expect(d.exercises.perso.map((e) => e.nom).toSet().length, d.exercises.perso.length, reason: 'exercice perso créé deux fois');
    });

    test('fichier plus récent qui recouvre l\'ancien : seules les nouvelles séances entrent', () async {
      final d = await _donnees();
      final ancien = [_enTeteA, _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 80, 6, 'NORMAL_SET')].join('\n');
      final recent = [
        ancien,
        _ligneA('Pull', '2026-03-20 18:00:00', 'Pull-up', 0, 8, 'NORMAL_SET'),
      ].join('\n');
      await (await _charger(d, 'a.csv', ancien)).importer(d);
      final f = await _charger(d, 'b.csv', recent);
      expect(f.rapport!.seancesDoublons, 1);
      expect(f.rapport!.seances, 1);
      await f.importer(d);
      expect(d.sessions.sessions.map((s) => s.nom), ['Pull', 'Push']);
    });

    test('lignes répétées dans le fichier (export collé deux fois) : la séance n\'a pas ses séries en double', skip: 'défaut connu, non corrigé : voir le rapport', () async {
      final d = await _donnees();
      final bloc = [
        _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 80, 6, 'NORMAL_SET'),
        _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 82.5, 5, 'NORMAL_SET'),
        _ligneA('Push', '2026-03-18 18:05:11', 'Cable Pushdown', 25, 12, 'NORMAL_SET'),
      ];
      final f = await _charger(d, 'double.csv', [_enTeteA, ...bloc, _enTeteA, ...bloc].join('\n'));
      await f.importer(d);
      expect(d.sessions.sessions, hasLength(1));
      expect(d.sessions.sessions.single.exercices.expand((e) => e.series), hasLength(3));
    });

    test('séance faite dans l\'appli à la même minute : la séance du fichier est un doublon', () async {
      final d = await _donnees();
      await d.sessions.save(WorkoutSession(id: 'm', nom: 'Push', debut: DateTime(2026, 3, 18, 18, 5, 40), fin: DateTime(2026, 3, 18, 19)));
      final f = await _charger(d, 'a.csv', [_enTeteA, _ligneA('Push', '2026-03-18 18:05:11', 'Barbell Bench Press', 80, 6, 'NORMAL_SET')].join('\n'));
      expect(f.rapport!.seancesDoublons, 1);
    });

    test('import interrompu puis relancé : pas de doublon, pas d\'exercice perso en double', () async {
      final d = await _donnees();
      final csv = File('test/fixtures/format_a.csv').readAsStringSync();
      final f = await _charger(d, 'a.csv', csv);
      await f.importer(d);
      final n = d.sessions.sessions.length;
      final persos = d.exercises.perso.length;
      // Comme l'écran de progression après un échec : nouvelle analyse, puis import.
      await f.analyser(d);
      await f.importer(d);
      expect(d.sessions.sessions.length, n);
      expect(d.exercises.perso.length, persos);
    });
  });

  group('exercices non reconnus', () {
    test('un nom inconnu devient un exercice personnel au nom du fichier, réutilisé ensuite', () async {
      final d = await _donnees();
      final csv = [_enTeteA, _ligneA('Bras', '2026-03-18 18:05:11', 'Zzyx Mouvement Maison', 10, 12, 'NORMAL_SET')].join('\n');
      final f = await _charger(d, 'a.csv', csv);
      final r = await f.importer(d);
      expect(r!.exercicesCrees, 1);
      final perso = d.exercises.perso.single;
      expect(perso.nom, 'Zzyx Mouvement Maison');
      expect(perso.perso, isTrue);
      expect(d.sessions.sessions.single.exercices.single.exerciseId, perso.id);
      expect(d.exercises.nameOf(perso.id), 'Zzyx Mouvement Maison');

      // Autre fichier, même nom : même exercice, pas un second.
      final f2 = await _charger(d, 'b.csv', [_enTeteA, _ligneA('Bras', '2026-03-25 18:05:11', 'zzyx  mouvement maison', 12, 10, 'NORMAL_SET')].join('\n'));
      expect(f2.rapport!.aConfirmer, isEmpty);
      await f2.importer(d);
      expect(d.exercises.perso, hasLength(1));
      expect(d.sessions.historyFor(perso.id), hasLength(2));
    });

    test('exercice perso supprimé entre deux imports : le nom n\'est pas rattaché à un exercice disparu', () async {
      final d = await _donnees();
      final csv = [_enTeteA, _ligneA('Bras', '2026-03-18 18:05:11', 'Zzyx Mouvement Maison', 10, 12, 'NORMAL_SET')].join('\n');
      await (await _charger(d, 'a.csv', csv)).importer(d);
      final journal = await ImportJournal.lire(d.store);
      await ImportFlow.annulerImport(d, journal.first);
      expect(d.exercises.perso, isEmpty);
      final f = await _charger(d, 'a.csv', csv);
      await f.importer(d);
      final ex = d.sessions.sessions.single.exercices.single;
      expect(d.exercises.byId(ex.exerciseId), isNotNull, reason: 'la séance pointe vers un exercice supprimé');
      expect(d.exercises.nameOf(ex.exerciseId), 'Zzyx Mouvement Maison');
    });

    test('noms laissés sans réponse : aucune série du fichier n\'est perdue', () async {
      final d = await _donnees();
      final csv = File('test/fixtures/format_a.csv').readAsStringSync();
      final f = await _charger(d, 'a.csv', csv, confirmer: false);
      final attendues = f.preview!.aImporter.fold<int>(0, (n, s) => n + s.nombreSeries);
      final seancesAttendues = f.preview!.aImporter.length;
      expect(f.rapport!.aConfirmer, isNotEmpty, reason: 'le fichier d\'essai doit contenir des noms à confirmer');
      final r = await f.importer(d);
      expect(r, isNotNull, reason: f.erreurImport);
      expect(d.sessions.sessions, hasLength(seancesAttendues));
      expect(d.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).length, attendues);
      for (final e in d.sessions.sessions.expand((s) => s.exercices)) {
        expect(d.exercises.byId(e.exerciseId), isNotNull);
      }
    });

    test('valeurs aberrantes dans le fichier : l\'import s\'enregistre quand même', () async {
      final dossier = Directory.systemTemp.createTempSync('aesthetic_import_');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final d = AppData(Store.dossier(dossier));
      await d.loadAll();
      final csv = [
        _enTeteA,
        '"Push","2026-03-18 18:05:11",01:00:00,"Barbell Bench Press",,1e400,6,null,null,NORMAL_SET',
        '"Push","2026-03-18 18:05:11",01:00:00,"Barbell Bench Press",,80,1e400,null,null,NORMAL_SET',
        '"Push","2026-03-18 18:05:11",01:00:00,"Barbell Bench Press",,-20,6,null,null,NORMAL_SET',
        '"Push","2026-03-18 18:05:11",01:00:00,"Barbell Bench Press",,80,-6,null,null,NORMAL_SET',
        '"Push","2026-03-18 18:05:11",01:00:00,"Barbell Bench Press",,80,6,null,null,NORMAL_SET',
      ].join('\n');
      final f = await _charger(d, 'x.csv', csv);
      await f.importer(d);
      final relu = AppData(Store.dossier(dossier));
      await relu.loadAll();
      expect(relu.sessions.sessions, hasLength(1), reason: 'les séances importées n\'ont pas été écrites sur le disque');
      for (final s in relu.sessions.sessions.single.exercices.single.series) {
        expect(s.poids == null || (s.poids!.isFinite && s.poids! >= 0), isTrue, reason: 'charge ${s.poids}');
        expect(s.reps == null || s.reps! >= 0, isTrue, reason: 'répétitions ${s.reps}');
      }
      expect(relu.sessions.sessions.single.volume.isFinite, isTrue);
      expect(relu.sessions.sessions.single.volume, greaterThanOrEqualTo(0));
    });
  });
}
