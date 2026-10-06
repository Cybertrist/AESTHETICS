// Point d'entrée de l'import : texte du fichier vers aperçu complet
// (format, séances, rapprochements, rapport). Dart pur.

import 'csv_table.dart';
import 'exercise_matcher.dart';
import 'import_models.dart';
import 'import_report.dart';
import 'parsers.dart';

class ImportPreview {
  ImportPreview._({
    required this.table,
    required this.detection,
    required this.parse,
    required this.matcher,
    required this.memoire,
    required this.rapprochements,
    required this.rapport,
  });

  final CsvTable table;
  final Detection detection;
  final ParseResult parse;
  final ExerciseMatcher matcher;

  /// Choix de l'utilisateur, clé [cleNom] vers identifiant du catalogue
  /// (chaîne vide : créer un exercice personnel). À conserver pour les
  /// imports suivants.
  final Map<String, String> memoire;
  Map<String, Rapprochement> rapprochements;
  ImportReport rapport;

  ImportFormat? get format => parse.seances.isEmpty && !detection.reconnu ? null : parse.format;
  List<ImportedSession> get seances => parse.seances;

  /// Séances à enregistrer (sans les doublons).
  List<ImportedSession> get aImporter => [for (final s in parse.seances) if (!s.doublon) s];

  /// Associe un nom du fichier à un exercice du catalogue.
  void confirmer(String nomSource, String exerciceId) {
    memoire[cleNom(nomSource)] = exerciceId;
    _recalculer();
  }

  /// Garde ce nom comme exercice personnel (créé à l'enregistrement).
  void creerPersonnel(String nomSource) {
    memoire[cleNom(nomSource)] = '';
    _recalculer();
  }

  /// Accepte le premier candidat des noms dont la suggestion est sûre
  /// ([Rapprochement.suggestionSure]) ; les autres restent à confirmer.
  /// [toutes] prend aussi les suggestions incertaines. Renvoie le nombre de
  /// noms acceptés.
  int accepterSuggestions({bool toutes = false}) {
    var n = 0;
    for (final r in rapprochements.values) {
      if (r.statut != StatutRapprochement.ambigu || r.candidats.isEmpty) continue;
      if (!toutes && !r.suggestionSure) continue;
      memoire[cleNom(r.nomSource)] = r.candidats.first.entree.id;
      n++;
    }
    if (n > 0) _recalculer();
    return n;
  }

  void _recalculer() {
    rapprochements = rapprocherSeances(parse.seances, matcher, memoire: memoire);
    rapport = ImportReport.calculer(parse, rapprochements);
  }
}

class ImportAnalyzer {
  /// Analyse le texte d'un CSV.
  /// [forcer] impose un format, [colonnes] impose l'association d'un tableau
  /// quelconque, [debutsExistants] marque comme doublons les séances qui
  /// commencent à la même minute qu'une séance déjà enregistrée.
  static ImportPreview analyser(
    String texte, {
    required List<CatalogueEntry> catalogue,
    ImportOptions options = const ImportOptions(),
    ImportFormat? forcer,
    ColumnMapping? colonnes,
    Map<String, String>? memoire,
    Iterable<DateTime> debutsExistants = const [],
    ExerciseMatcher? matcher,
  }) {
    final table = CsvTable.lire(texte);
    final detection = detecterFormat(table);
    final format = forcer ?? (colonnes != null ? ImportFormat.generique : detection.format);
    final ParseResult parse;
    if (table.enTetes.isEmpty) {
      parse = ParseResult(
        format: format ?? ImportFormat.generique,
        seances: const [],
        lignesLues: 0,
        messages: [const ImportMessage('Le fichier est vide.', gravite: Gravite.erreur)],
      );
    } else if (format == null) {
      parse = ParseResult(
        format: ImportFormat.generique,
        seances: const [],
        lignesLues: table.lignes.length,
        messages: [
          const ImportMessage(
            'Ce fichier ne ressemble pas à un historique d\'entraînement. '
            'Associe ses colonnes à la main pour l\'importer.',
            gravite: Gravite.erreur,
          ),
        ],
      );
    } else {
      parse = parserTable(table, format,
          options: options, colonnes: colonnes ?? detection.colonnes);
    }

    marquerDoublons(parse.seances, debutsExistants);
    final m = matcher ?? ExerciseMatcher(catalogue);
    final mem = memoire ?? <String, String>{};
    final rap = rapprocherSeances(parse.seances, m, memoire: mem);
    return ImportPreview._(
      table: table,
      detection: detection,
      parse: parse,
      matcher: m,
      memoire: mem,
      rapprochements: rap,
      rapport: ImportReport.calculer(parse, rap),
    );
  }

  /// Analyse des octets bruts (UTF-8 ou Latin-1).
  static ImportPreview analyserOctets(
    List<int> octets, {
    required List<CatalogueEntry> catalogue,
    ImportOptions options = const ImportOptions(),
    Map<String, String>? memoire,
    Iterable<DateTime> debutsExistants = const [],
  }) =>
      analyser(CsvTable.decoder(octets),
          catalogue: catalogue,
          options: options,
          memoire: memoire,
          debutsExistants: debutsExistants);
}

/// Marque les séances qui commencent à la même minute qu'une séance existante.
void marquerDoublons(List<ImportedSession> seances, Iterable<DateTime> existants) {
  final minutes = {for (final d in existants) d.millisecondsSinceEpoch ~/ 60000};
  for (final s in seances) {
    s.doublon = minutes.contains(s.debut.millisecondsSinceEpoch ~/ 60000);
  }
}
