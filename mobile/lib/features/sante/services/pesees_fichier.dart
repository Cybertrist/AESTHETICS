import 'package:archive/archive.dart';

import '../../import/logic/csv_table.dart';
import '../../import/logic/value_parsers.dart';
import 'corps_hc.dart';

/// Fichier de pesées illisible ; [message] est prêt à afficher.
class PeseesIllisibles implements Exception {
  const PeseesIllisibles(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lit l'export d'une balance connectée : le `weight.csv` de Withings (date,
/// poids, gras en kilos), seul ou dans le zip de l'export complet.
abstract final class PeseesFichier {
  static const _date = ['date'];
  static const _poids = ['poids (kg)', 'weight (kg)', 'poids', 'weight'];
  static const _grasKg = ['gras (kg)', 'fat mass (kg)', 'masse grasse (kg)'];
  static const _grasPct = ['gras (%)', 'fat (%)', 'masse grasse (%)', 'body fat (%)'];

  static bool _zip(List<int> o) => o.length > 2 && o[0] == 0x50 && o[1] == 0x4B;

  /// Une valeur par pesée, le gras en pourcentage du poids.
  static List<ReleveHc> lire(List<int> octets) {
    var csv = octets;
    if (_zip(octets)) {
      final Archive a;
      try {
        a = ZipDecoder().decodeBytes(octets);
      } catch (_) {
        throw const PeseesIllisibles('L\'archive est abîmée.');
      }
      final f = a.files.where((f) => f.isFile && f.name.split('/').last.toLowerCase() == 'weight.csv').firstOrNull;
      if (f == null) throw const PeseesIllisibles('Cette archive ne contient pas de fichier weight.csv.');
      csv = f.content;
    }
    final table = CsvTable.lire(CsvTable.decoder(csv));
    if (!_date.any(table.contient) || !_poids.any(table.contient)) {
      throw const PeseesIllisibles('Ce fichier n\'a pas de colonnes de date et de poids.');
    }
    final out = <ReleveHc>[];
    for (final l in table.lignes) {
      final date = lireDate(l.get(_date));
      final poids = lireNombre(l.get(_poids));
      if (date == null || poids == null || poids <= 0) continue;
      final kg = lireNombre(l.get(_grasKg));
      final pct = kg != null && kg > 0 && kg < poids ? kg / poids * 100 : lireNombre(l.get(_grasPct));
      // Sous 1, le rangement lirait une fraction : un tel taux n'existe pas.
      out.add((date: date, poidsKg: poids, grasPct: pct != null && pct > 1 ? pct : null));
    }
    if (out.isEmpty) throw const PeseesIllisibles('Aucune pesée lisible dans ce fichier.');
    return out;
  }
}
