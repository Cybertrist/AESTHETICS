import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/json.dart';
import 'prefs.dart';

/// Une sauvegarde gardée sur le téléphone.
class SauvegardeLocale {
  const SauvegardeLocale(this.fichier, this.date, this.taille);
  final File fichier;
  final DateTime date;
  final int taille;
  String get nom => fichier.uri.pathSegments.last;
}

/// Sauvegarde, restauration et exports.
class BackupService {
  BackupService(this.data);
  final AppData data;

  static final _horodatage = DateFormat('yyyyMMdd-HHmm');

  String _nom(String ext) => 'aesthetic-${_horodatage.format(DateTime.now())}.$ext';

  /// Dossier des sauvegardes du téléphone, à côté des données (pas dedans :
  /// « Tout effacer » peut les garder).
  static Future<Directory> dossierSauvegardes() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}${Platform.pathSeparator}sauvegardes');
    await d.create(recursive: true);
    return d;
  }

  Future<String> json() => data.exportBackup();

  /// Enregistre une sauvegarde sur le téléphone et garde les 10 dernières.
  Future<SauvegardeLocale> sauvegarderSurTelephone() async {
    final dir = await dossierSauvegardes();
    final f = File('${dir.path}${Platform.pathSeparator}${_nom('json')}');
    await f.writeAsString(await json(), flush: true);
    final liste = await sauvegardesLocales();
    for (final vieille in liste.skip(10)) {
      await vieille.fichier.delete();
    }
    return SauvegardeLocale(f, DateTime.now(), await f.length());
  }

  static Future<List<SauvegardeLocale>> sauvegardesLocales() async {
    final dir = await dossierSauvegardes();
    final out = <SauvegardeLocale>[];
    for (final e in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      final st = await e.stat();
      out.add(SauvegardeLocale(e, st.modified, st.size));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static Future<void> effacerSauvegardesLocales() async {
    final dir = await dossierSauvegardes();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Vérifie une sauvegarde sans rien écrire et en rend le résumé.
  static ResumeSauvegarde lire(String raw) {
    final Object? j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Ce fichier n\'est pas lisible (JSON abîmé).');
    }
    if (j is! Map || j['application'] != 'aesthetic' || j['donnees'] is! Map) {
      throw const FormatException('Ce fichier n\'est pas une sauvegarde Aesthetics.');
    }
    final d = Map<String, Object?>.from(j['donnees'] as Map);
    int n(String k) => d[k] is List ? (d[k] as List).length : 0;
    final profil = d['profil'] is Map ? asString((d['profil'] as Map)['prenom']) : null;
    return ResumeSauvegarde(
      date: asDate(j['date']),
      prenom: profil,
      seances: n('seances'),
      collections: d.length,
    );
  }

  /// Remplace toutes les données par la sauvegarde.
  Future<void> restaurer(String raw) async {
    await data.importBackup(raw);
    await PrefsRepo.maybeInstance?.load();
  }

  /// Poids du dossier des données, en octets.
  Future<int> tailleDonnees() async {
    var total = 0;
    final dir = data.store.dir;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}

class ResumeSauvegarde {
  const ResumeSauvegarde({this.date, this.prenom, required this.seances, required this.collections});
  final DateTime? date;
  final String? prenom;
  final int seances;
  final int collections;
}

String formatOctets(int o) {
  if (o < 1024) return '$o o';
  if (o < 1024 * 1024) return '${(o / 1024).toStringAsFixed(0)} Ko';
  return '${(o / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
