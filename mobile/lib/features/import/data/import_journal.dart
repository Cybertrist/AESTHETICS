import '../../../core/data/store.dart';

/// Trace d'un import, pour pouvoir le revoir ou l'annuler.
class ImportJournalEntry {
  ImportJournalEntry({
    required this.id,
    required this.date,
    required this.fichier,
    required this.format,
    required this.mode,
    required this.seanceIds,
    required this.exercicesCrees,
    required this.series,
    this.debut,
    this.fin,
    this.remplacees = 0,
    this.doublons = 0,
  });

  final String id;
  final DateTime date;
  final String fichier;
  final String format;
  final String mode;
  final List<String> seanceIds;
  final List<String> exercicesCrees;
  final int series;
  final DateTime? debut;
  final DateTime? fin;
  final int remplacees;
  final int doublons;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'fichier': fichier,
        'format': format,
        'mode': mode,
        'seanceIds': seanceIds,
        'exercicesCrees': exercicesCrees,
        'series': series,
        if (debut != null) 'debut': debut!.toIso8601String(),
        if (fin != null) 'fin': fin!.toIso8601String(),
        'remplacees': remplacees,
        'doublons': doublons,
      };

  factory ImportJournalEntry.fromJson(Map<String, dynamic> j) => ImportJournalEntry(
        id: '${j['id'] ?? ''}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        fichier: '${j['fichier'] ?? 'Fichier'}',
        format: '${j['format'] ?? ''}',
        mode: '${j['mode'] ?? ''}',
        seanceIds: [for (final s in (j['seanceIds'] as List? ?? const [])) '$s'],
        exercicesCrees: [for (final s in (j['exercicesCrees'] as List? ?? const [])) '$s'],
        series: (j['series'] as num?)?.toInt() ?? 0,
        debut: DateTime.tryParse('${j['debut']}'),
        fin: DateTime.tryParse('${j['fin']}'),
        remplacees: (j['remplacees'] as num?)?.toInt() ?? 0,
        doublons: (j['doublons'] as num?)?.toInt() ?? 0,
      );
}

/// Journal des imports (collection `import_journal`) et mémoire des
/// correspondances de noms (collection `import_correspondances`).
abstract final class ImportJournal {
  static const collection = 'import_journal';
  static const correspondances = 'import_correspondances';

  /// Imports, le plus récent d'abord.
  static Future<List<ImportJournalEntry>> lire(Store store) async {
    final list = await store.readList(collection);
    final out = <ImportJournalEntry>[];
    for (final j in list) {
      try {
        out.add(ImportJournalEntry.fromJson(j));
      } catch (_) {}
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static Future<void> ajouter(Store store, ImportJournalEntry e) async {
    final list = await lire(store);
    await store.write(collection, [e.toJson(), for (final x in list) x.toJson()]);
  }

  static Future<void> retirer(Store store, String id) async {
    final list = await lire(store);
    await store.write(collection, [for (final x in list) if (x.id != id) x.toJson()]);
  }

  static Future<void> vider(Store store) => store.delete(collection);

  static Future<Map<String, String>> lireCorrespondances(Store store) async {
    final m = await store.readObject(correspondances);
    return {for (final e in (m ?? const {}).entries) e.key: '${e.value}'};
  }

  static Future<void> ecrireCorrespondances(Store store, Map<String, String> m) =>
      store.write(correspondances, m);

  static Future<void> oublierCorrespondances(Store store) => store.delete(correspondances);
}
