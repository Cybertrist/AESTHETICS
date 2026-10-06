import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Nouvel identifiant unique.
String newId() => _uuid.v4();

/// Stockage JSON : un fichier par collection, écriture atomique
/// (fichier temporaire puis renommage), écritures d'une même collection
/// mises en file pour ne jamais se croiser.
class Store {
  Store._(this.dir) : _memory = null;

  /// Stockage dans un dossier donné (tests sur un vrai disque).
  Store.dossier(this.dir) : _memory = null;

  /// Stockage en mémoire, pour les tests.
  Store.memory()
      : dir = Directory.systemTemp,
        _memory = {};

  final Directory dir;
  final Map<String, String>? _memory;
  final Map<String, Future<void>> _queues = {};

  /// Collections trouvées illisibles depuis l'ouverture, avec le chemin du
  /// fichier où leur contenu a été mis de côté (vide en mémoire). Une liste
  /// vide veut dire que tout a été lu.
  final Map<String, String> abimes = {};

  /// Dernière écriture qui a échoué (disque plein, par exemple), ou null.
  Object? derniereErreurEcriture;

  /// Ouvre le stockage. La démo vit dans son propre dossier pour ne
  /// jamais toucher aux vraies données.
  static Future<Store> open({bool demo = false}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}${demo ? 'demo' : 'donnees'}');
    await dir.create(recursive: true);
    return Store._(dir);
  }

  /// Dossier des fichiers joints (photos de progression, photo de profil).
  Future<Directory> mediaDir() async {
    final d = Directory('${dir.path}${Platform.pathSeparator}medias');
    if (_memory == null) await d.create(recursive: true);
    return d;
  }

  File _file(String name) => File('${dir.path}${Platform.pathSeparator}$name.json');

  /// Lit une collection ; null si absente ou illisible.
  Future<Object?> read(String name) async {
    await (_queues[name] ?? Future.value());
    if (_memory != null) {
      final raw = _memory[name];
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        abimes[name] = '';
        return null;
      }
    }
    final f = _file(name);
    try {
      if (!await f.exists()) return null;
      // Lu en octets : un fichier qui n'est plus du texte valide ne doit pas
      // empêcher l'appli de démarrer.
      final octets = await f.readAsBytes();
      if (octets.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(octets));
      } catch (_) {
        abimes[name] = await _mettreDeCote(f, octets);
        return null;
      }
    } catch (_) {
      // Fichier illisible (droits, disque) : on démarre sans lui.
      abimes[name] = '';
      return null;
    }
  }

  /// Garde de côté un fichier abîmé plutôt que de le laisser écraser. Une
  /// copie plus ancienne n'est jamais remplacée : elle peut contenir tout
  /// l'historique, alors que la nouvelle n'en aurait que la suite.
  Future<String> _mettreDeCote(File f, List<int> octets) async {
    try {
      final base = File('${f.path}.abime');
      if (!await base.exists()) {
        await base.writeAsBytes(octets, flush: true);
        return base.path;
      }
      final prefixe = base.uri.pathSegments.last;
      for (final autre in dir.listSync().whereType<File>()) {
        if (!autre.uri.pathSegments.last.startsWith(prefixe)) continue;
        if (await autre.length() != octets.length) continue;
        final contenu = await autre.readAsBytes();
        var pareil = true;
        for (var i = 0; i < octets.length && pareil; i++) {
          pareil = contenu[i] == octets[i];
        }
        if (pareil) return autre.path;
      }
      final copie = File('${base.path}.${DateTime.now().millisecondsSinceEpoch}');
      await copie.writeAsBytes(octets, flush: true);
      return copie.path;
    } catch (_) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> readList(String name) async {
    final v = await read(name);
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> readObject(String name) async {
    final v = await read(name);
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  /// Écrit une collection (liste ou objet JSON).
  Future<void> write(String name, Object? data) {
    final previous = _queues[name] ?? Future.value();
    // Une écriture qui échoue ne bloque pas les suivantes, mais elle remonte
    // à celui qui l'a demandée : une donnée non enregistrée ne doit pas
    // passer pour enregistrée.
    final next = previous.then((_) => _write(name, data));
    _queues[name] = next.then((_) {}, onError: (Object e) {
      derniereErreurEcriture = e;
    });
    return next;
  }

  /// Un nombre non fini (division par zéro, saisie aberrante) n'existe pas en
  /// JSON : il est écrit comme une valeur absente plutôt que de faire échouer
  /// l'écriture de toute la collection, cette fois et toutes les suivantes.
  static Object? _encodable(Object? o) {
    if (o is double && !o.isFinite) return null;
    // ignore: avoid_dynamic_calls
    return (o as dynamic).toJson();
  }

  Future<void> _write(String name, Object? data) async {
    final raw = jsonEncode(data, toEncodable: _encodable);
    if (_memory != null) {
      _memory[name] = raw;
      return;
    }
    final f = _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(raw, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> delete(String name) async {
    await (_queues[name] ?? Future.value());
    if (_memory != null) {
      _memory.remove(name);
      return;
    }
    final f = _file(name);
    if (await f.exists()) await f.delete();
  }

  /// Noms des collections présentes.
  Future<List<String>> names() async {
    if (_memory != null) return _memory.keys.toList();
    if (!await dir.exists()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .map((n) => n.substring(0, n.length - 5))
        .toList();
  }

  /// Toutes les collections, pour la sauvegarde.
  Future<Map<String, Object?>> exportAll() async {
    final out = <String, Object?>{};
    for (final n in await names()) {
      out[n] = await read(n);
    }
    return out;
  }

  /// Remplace toutes les collections par celles d'une sauvegarde.
  Future<void> importAll(Map<String, Object?> data) async {
    await wipe(keepMedia: true);
    for (final e in data.entries) {
      await write(e.key, e.value);
    }
  }

  /// Efface toutes les données (et les médias sauf demande contraire).
  Future<void> wipe({bool keepMedia = false}) async {
    for (final n in await names()) {
      await delete(n);
    }
    if (!keepMedia && _memory == null) {
      final m = Directory('${dir.path}${Platform.pathSeparator}medias');
      if (await m.exists()) await m.delete(recursive: true);
    }
  }
}
