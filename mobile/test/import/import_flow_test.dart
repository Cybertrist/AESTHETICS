import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/import/data/exporters.dart';
import 'package:aesthetic/features/import/data/import_flow.dart';
import 'package:aesthetic/features/import/data/import_journal.dart';
import 'package:aesthetic/features/import/data/sauvegarde.dart';
import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<AppData> _donnees() async {
  final d = AppData(Store.memory());
  await d.loadAll();
  return d;
}

/// Parcours complet sans écran : analyse, choix, import.
Future<ImportResult> _importer(AppData d, String fichier, {ImportFlow? flow}) async {
  final f = flow ?? ImportFlow();
  f.demarrer(ImportSource.application);
  await f.chargerFichier(fichier, File('test/fixtures/$fichier').readAsBytesSync(), d);
  expect(f.etat, EtatAnalyse.pret, reason: f.erreur);
  f.accepterSuggestions(toutes: true);
  f.creerTousLesInconnus();
  expect(f.rapport!.aConfirmer, isEmpty);
  final r = await f.importer(d);
  expect(r, isNotNull, reason: f.erreurImport);
  return r!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    ImportFlow.enIsolat = false;
  });

  test('import complet, doublons au second passage, annulation', () async {
    final d = await _donnees();
    final r = await _importer(d, 'format_a.csv');
    expect(r.seances, greaterThan(0));
    expect(d.sessions.sessions.length, r.seances);
    expect(d.sessions.sessions.every((s) => s.source == 'import' && s.fin != null), isTrue);
    // Les échauffements sont gardés avec leur type.
    expect(
      d.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).any((s) => s.type == SetType.echauffement),
      isTrue,
    );
    // Chaque exercice pointe vers un exercice connu (catalogue ou perso créé).
    for (final e in d.sessions.sessions.expand((s) => s.exercices)) {
      expect(d.exercises.byId(e.exerciseId), isNotNull, reason: e.exerciseId);
    }

    // Même fichier une seconde fois : tout est déjà là.
    final f2 = ImportFlow()..demarrer(ImportSource.application);
    await f2.chargerFichier('format_a.csv', File('test/fixtures/format_a.csv').readAsBytesSync(), d);
    expect(f2.rapport!.seances, 0);
    expect(f2.rapport!.seancesDoublons, r.seances);
    // Les exercices perso créés sont retrouvés sans question.
    expect(f2.rapport!.nouveaux, isEmpty);

    final journal = await ImportJournal.lire(d.store);
    expect(journal, hasLength(1));
    final a = await ImportFlow.annulerImport(d, journal.first);
    expect(a.seances, r.seances);
    expect(d.sessions.sessions, isEmpty);
    expect(d.exercises.perso, isEmpty);
    expect(await ImportJournal.lire(d.store), isEmpty);
  });

  test('remplacer les séances importées garde celles de l\'appli', () async {
    final d = await _donnees();
    await d.sessions.save(WorkoutSession(
      id: 'maison',
      nom: 'Faite dans l\'appli',
      debut: DateTime(2020, 1, 1, 10),
      fin: DateTime(2020, 1, 1, 11),
    ));
    final r1 = await _importer(d, 'format_c.csv');
    final f = ImportFlow()..mode = ImportMode.remplacerImportees;
    f.demarrer(ImportSource.application);
    f.mode = ImportMode.remplacerImportees;
    await f.chargerFichier('format_c.csv', File('test/fixtures/format_c.csv').readAsBytesSync(), d);
    expect(f.rapport!.seancesDoublons, 0, reason: 'les séances importées vont être remplacées');
    f.accepterSuggestions(toutes: true);
    f.creerTousLesInconnus();
    final r2 = await f.importer(d);
    expect(r2!.remplacees, r1.seances);
    expect(d.sessions.sessions.length, r1.seances + 1);
    expect(d.sessions.byId('maison'), isNotNull);
  });

  test('le CSV exporté se réimporte à l\'identique', () async {
    final d = await _donnees();
    await _importer(d, 'format_b.csv');
    final avant = d.sessions.sessions;
    final seriesAvant = avant.expand((s) => s.exercices).expand((e) => e.series).length;
    for (final sep in SeparateurCsv.values) {
      final csv = Exporteurs.seancesCsv(avant, d.exercises.nameOf, sep);
      final d2 = await _donnees();
      final f = ImportFlow()..demarrer(ImportSource.tableau);
      await f.chargerFichier('export.csv', csv, d2);
      expect(f.etat, EtatAnalyse.pret);
      expect(f.besoinColonnes, isTrue);
      await f.appliquerColonnes(f.preview!.detection.colonnes!, d2);
      expect(f.rapport!.seances, avant.length, reason: sep.label);
      // Les noms exportés sont ceux du catalogue : tous reconnus d'office.
      expect(f.rapport!.aConfirmer.where((x) => x.statut == StatutRapprochement.ambigu), isEmpty);
      f.creerTousLesInconnus();
      await f.importer(d2);
      final apres = d2.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).length;
      expect(apres, seriesAvant, reason: sep.label);
    }
  });

  test('fichier vide, binaire ou hors sujet', () async {
    final d = await _donnees();
    final f = ImportFlow()..demarrer(ImportSource.application);
    await f.chargerFichier('vide.csv', const [], d);
    expect(f.etat, EtatAnalyse.erreur);
    await f.chargerFichier('classeur.xlsx', [0x50, 0x4B, 3, 4, 0, 0, 0, 0, 0, 0], d);
    expect(f.etat, EtatAnalyse.erreur);
    await f.chargerFichier('pas_un_historique.csv', File('test/fixtures/pas_un_historique.csv').readAsBytesSync(), d);
    expect(f.etat, EtatAnalyse.pret);
    expect(f.besoinColonnes, isTrue);
    expect(f.rapport!.seances, 0);
  });

  test('sauvegarde JSON lue puis restaurée', () async {
    final d = await _donnees();
    await _importer(d, 'format_a.csv');
    final n = d.sessions.sessions.length;
    final octets = await Sauvegarde.json(d);
    final lue = Sauvegarde.lire(octets);
    expect(lue.seances, n);
    final d2 = await _donnees();
    await Sauvegarde.restaurer(d2, lue);
    expect(d2.sessions.sessions.length, n);
    expect(() => Sauvegarde.lire(utf8.encode('{"a":1}')), throwsA(isA<SauvegardeInvalide>()));
  });

  test('écriture CSV : guillemets et décimales', () {
    final w = CsvEcrivain(SeparateurCsv.pointVirgule)..ligne(['a;b', 'dit "oui"', 72.5, 3]);
    expect(w.toString().trim(), '"a;b";"dit ""oui""";72,5;3');
  });
}
