import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../../core/data/data.dart';

/// Libellés des collections du Store, pour décrire une sauvegarde.
const libellesCollections = <String, String>{
  'seances': 'Séances',
  'routines': 'Routines',
  'dossiers': 'Dossiers de routines',
  'programmes': 'Programmes',
  'exercices_perso': 'Exercices personnels',
  'exercices_favoris': 'Exercices favoris',
  'mesures': 'Mesures corporelles',
  'photos': 'Photos de progression',
  'sommeil': 'Nuits de sommeil',
  'journal_repas': 'Aliments notés',
  'repas_enregistres': 'Repas enregistrés',
  'aliments': 'Aliments personnels',
  'eau': 'Prises d\'eau',
  'complements': 'Compléments',
  'prises_complements': 'Prises de compléments',
  'coach_conversations': 'Conversations avec le coach',
  'import_journal': 'Imports',
};

/// Contenu d'un fichier de sauvegarde, lu avant de restaurer.
class SauvegardeLue {
  SauvegardeLue({
    required this.json,
    required this.date,
    required this.version,
    required this.comptes,
    required this.aProfil,
    this.medias = const {},
    this.ancienDossierMedias,
  });

  final String json;
  final DateTime? date;
  final int version;

  /// Nombre d'éléments par collection (listes seulement).
  final Map<String, int> comptes;
  final bool aProfil;

  /// Fichiers joints (nom de fichier vers octets), dans une archive complète.
  final Map<String, List<int>> medias;
  final String? ancienDossierMedias;

  int get seances => comptes['seances'] ?? 0;
  bool get complete => medias.isNotEmpty || ancienDossierMedias != null;
}

class SauvegardeInvalide implements Exception {
  const SauvegardeInvalide(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class Sauvegarde {
  static const version = 1;

  /// Sauvegarde des données seules (JSON).
  static Future<List<int>> json(AppData data) async => utf8.encode(await data.exportBackup());

  /// Sauvegarde complète : données et photos dans une archive ZIP.
  static Future<List<int>> complete(AppData data) async {
    final a = Archive();
    final dir = await data.store.mediaDir();
    a.addFile(ArchiveFile.string('donnees.json', await data.exportBackup()));
    a.addFile(ArchiveFile.string(
      'manifeste.json',
      jsonEncode({
        'application': 'aesthetic',
        'version': version,
        'date': DateTime.now().toIso8601String(),
        'dossierMedias': dir.path,
      }),
    ));
    if (await dir.exists()) {
      for (final f in dir.listSync().whereType<File>()) {
        final nom = f.uri.pathSegments.last;
        a.addFile(ArchiveFile.bytes('medias/$nom', await f.readAsBytes()));
      }
    }
    return ZipEncoder().encodeBytes(a);
  }

  /// Nombre de photos et de fichiers joints qui seraient sauvegardés.
  static Future<({int fichiers, int octets})> medias(AppData data) async {
    final dir = await data.store.mediaDir();
    if (!await dir.exists()) return (fichiers: 0, octets: 0);
    var n = 0, o = 0;
    for (final f in dir.listSync().whereType<File>()) {
      n++;
      o += await f.length();
    }
    return (fichiers: n, octets: o);
  }

  /// Lit un fichier de sauvegarde (JSON ou ZIP) sans rien modifier.
  static SauvegardeLue lire(List<int> octets) {
    if (octets.length > 2 && octets[0] == 0x50 && octets[1] == 0x4B) return _lireZip(octets);
    String texte;
    try {
      texte = utf8.decode(octets, allowMalformed: false);
    } catch (_) {
      throw const SauvegardeInvalide('Ce fichier n\'est pas une sauvegarde Aesthetics.');
    }
    if (texte.startsWith('﻿')) texte = texte.substring(1);
    return _lireJson(texte);
  }

  static SauvegardeLue _lireZip(List<int> octets) {
    final Archive a;
    try {
      a = ZipDecoder().decodeBytes(octets);
    } catch (_) {
      throw const SauvegardeInvalide('L\'archive est abîmée.');
    }
    ArchiveFile? donnees, manifeste;
    final medias = <String, List<int>>{};
    for (final f in a.files) {
      if (!f.isFile) continue;
      if (f.name == 'donnees.json') donnees = f;
      if (f.name == 'manifeste.json') manifeste = f;
      if (f.name.startsWith('medias/') && f.name.length > 7) {
        final nom = f.name.substring(7);
        if (!nom.contains('/') && !nom.contains('..')) medias[nom] = f.content;
      }
    }
    if (donnees == null) {
      throw const SauvegardeInvalide('Cette archive ne contient pas de données Aesthetics.');
    }
    String? ancien;
    if (manifeste != null) {
      try {
        final m = jsonDecode(utf8.decode(manifeste.content));
        if (m is Map) ancien = m['dossierMedias'] as String?;
      } catch (_) {}
    }
    final base = _lireJson(utf8.decode(donnees.content));
    return SauvegardeLue(
      json: base.json,
      date: base.date,
      version: base.version,
      comptes: base.comptes,
      aProfil: base.aProfil,
      medias: medias,
      ancienDossierMedias: ancien,
    );
  }

  static SauvegardeLue _lireJson(String texte) {
    Object? j;
    try {
      j = jsonDecode(texte);
    } catch (_) {
      throw const SauvegardeInvalide('Ce fichier n\'est pas une sauvegarde Aesthetics.');
    }
    if (j is! Map || j['application'] != 'aesthetic' || j['donnees'] is! Map) {
      throw const SauvegardeInvalide('Ce fichier n\'est pas une sauvegarde Aesthetics.');
    }
    final v = (j['version'] as num?)?.toInt() ?? 1;
    if (v > AppData.backupVersion) {
      throw const SauvegardeInvalide('Cette sauvegarde vient d\'une version plus récente de l\'appli. Mets l\'appli à jour.');
    }
    final donnees = j['donnees'] as Map;
    final comptes = <String, int>{
      for (final e in donnees.entries)
        if (e.value is List) '${e.key}': (e.value as List).length,
    };
    return SauvegardeLue(
      json: texte,
      date: DateTime.tryParse('${j['date']}'),
      version: v,
      comptes: comptes,
      aProfil: donnees['profil'] is Map || donnees.keys.any((k) => '$k'.startsWith('profil')),
    );
  }

  /// Remplace toutes les données par la sauvegarde. Les photos d'une
  /// archive complète sont recopiées et leurs chemins mis à jour.
  static Future<void> restaurer(AppData data, SauvegardeLue s) async {
    var json = s.json;
    if (s.medias.isNotEmpty) {
      final dir = await data.store.mediaDir();
      await dir.create(recursive: true);
      for (final e in s.medias.entries) {
        await File('${dir.path}${Platform.pathSeparator}${e.key}').writeAsBytes(e.value, flush: true);
      }
      final ancien = s.ancienDossierMedias;
      if (ancien != null && ancien != dir.path) {
        // Les chemins sont écrits échappés dans le JSON.
        final a = jsonEncode(ancien);
        final n = jsonEncode(dir.path);
        json = json.replaceAll(a.substring(1, a.length - 1), n.substring(1, n.length - 1));
      }
    }
    await data.importBackup(json);
  }
}
