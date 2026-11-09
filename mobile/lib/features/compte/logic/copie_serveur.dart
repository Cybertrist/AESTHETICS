import 'dart:convert';

import 'package:archive/archive.dart';

/// Ce que le serveur sait d'une copie des données, sans avoir à la lire :
/// de quand elle date et ce qu'elle contient.
class ResumeCopie {
  const ResumeCopie({required this.date, required this.seances, required this.routines, required this.morceaux, required this.octets, this.prenom});

  final DateTime date;
  final int seances;
  final int routines;

  /// Nombre de documents entre lesquels la copie est découpée.
  final int morceaux;

  /// Poids des données, avant compression.
  final int octets;
  final String? prenom;

  /// Vrai quand la copie ne contient rien d'utile : ni séance ni routine.
  bool get vide => seances == 0 && routines == 0;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'seances': seances,
        'routines': routines,
        'morceaux': morceaux,
        'octets': octets,
        if (prenom != null) 'prenom': prenom,
      };

  static ResumeCopie? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = DateTime.tryParse('${j['date']}');
    if (date == null) return null;
    int n(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    return ResumeCopie(
      date: date,
      seances: n('seances'),
      routines: n('routines'),
      morceaux: n('morceaux'),
      octets: n('octets'),
      prenom: j['prenom'] is String ? j['prenom'] as String : null,
    );
  }
}

/// La copie des données qui part sur le serveur.
///
/// C'est la sauvegarde JSON de l'appli (`AppData.exportBackup`), compressée
/// puis découpée : un document du serveur ne dépasse pas un mégaoctet, et
/// un historique de plusieurs années pèse plus que ça.
abstract final class CopieServeur {
  static const _marque = 'AE1:';

  /// Taille d'un morceau, en caractères : bien sous la limite d'un document.
  static const tailleMorceau = 700000;

  /// Les règles du serveur en gardent 20 (14 Mo compressés) : au-delà, la
  /// copie ne part pas.
  static const maxMorceaux = 20;

  /// Le prénom tel que le serveur le garde : 200 unités UTF-16 au plus, sans
  /// couper un emoji en deux.
  static String? prenomCourt(String? p) {
    if (p == null || p.length <= 200) return p;
    var n = 200;
    final u = p.codeUnitAt(n - 1);
    if (u >= 0xD800 && u <= 0xDBFF) n--;
    return p.substring(0, n);
  }

  /// Les collections qui restent sur le téléphone : l'état du compte lui-même.
  static const horsCopie = {'compte'};

  /// Compresse et découpe une sauvegarde JSON.
  static List<String> decouper(String json, {int taille = tailleMorceau}) {
    // En tête, le poids des données : il permet de voir à la relecture qu'un
    // morceau manque, ce que la décompression seule ne dit pas toujours.
    final octets = utf8.encode(json);
    final texte = '$_marque${octets.length}:${base64Encode(const GZipEncoder().encodeBytes(octets))}';
    return [
      for (var i = 0; i < texte.length; i += taille) texte.substring(i, i + taille > texte.length ? texte.length : i + taille),
    ];
  }

  /// Recolle et décompresse ; lève une [FormatException] si un morceau manque
  /// ou est abîmé.
  static String recoller(List<String> morceaux) {
    try {
      final texte = morceaux.join();
      final fin = texte.indexOf(':', _marque.length);
      if (!texte.startsWith(_marque) || fin < 0) throw const FormatException();
      final attendu = int.parse(texte.substring(_marque.length, fin));
      final octets = const GZipDecoder().decodeBytes(base64Decode(texte.substring(fin + 1)));
      if (octets.length != attendu) throw const FormatException();
      return utf8.decode(octets);
    } catch (_) {
      throw const FormatException('La copie du serveur est incomplète ou abîmée.');
    }
  }

  /// Le résumé d'une sauvegarde JSON, pour le serveur et pour comparer.
  static ResumeCopie resumer(String json, {required int morceaux, DateTime? date}) {
    final j = jsonDecode(json);
    final d = j is Map && j['donnees'] is Map ? j['donnees'] as Map : const {};
    int n(String k) => d[k] is List ? (d[k] as List).length : 0;
    final profil = d['profil'];
    return ResumeCopie(
      date: date ?? DateTime.tryParse('${j is Map ? j['date'] : ''}') ?? DateTime.now(),
      seances: n('seances'),
      routines: n('routines'),
      morceaux: morceaux,
      octets: utf8.encode(json).length,
      prenom: profil is Map && profil['prenom'] is String ? prenomCourt(profil['prenom'] as String) : null,
    );
  }
}
