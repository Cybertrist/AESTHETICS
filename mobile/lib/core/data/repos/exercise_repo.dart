import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../logic/text_search.dart';
import '../../models/models.dart';
import '../collection.dart';
import '../exercise_catalog.dart';
import '../store.dart';

/// Catalogue embarqué plus exercices créés par l'utilisateur, et favoris.
class ExerciseRepo extends ChangeNotifier {
  ExerciseRepo(this.store)
      : _perso = JsonCollection(
          store: store,
          name: 'exercices_perso',
          fromJson: Exercise.fromJson,
          toJson: (e) => e.toJson(),
          idOf: (e) => e.id,
        );

  final Store store;
  final JsonCollection<Exercise> _perso;
  List<Exercise> _catalogue = [];
  Map<String, Exercise> _index = {};
  Set<String> _favoris = {};
  bool _loaded = false;

  static const _favorisFile = 'exercices_favoris';

  bool get loaded => _loaded;
  bool get catalogueVide => _catalogue.isEmpty;
  List<Exercise> get catalogue => _catalogue;
  List<Exercise> get perso => _perso.items;

  /// Tous les exercices : les persos d'abord, puis le catalogue par nom.
  List<Exercise> get all => [..._perso.items, ..._catalogue];

  Set<String> get favoris => _favoris;

  Future<void> load() async {
    final results = await Future.wait([
      ExerciseCatalog.load(),
      _perso.load(),
      store.read(_favorisFile),
    ]);
    _catalogue = (results[0] as List<Exercise>)..sort((a, b) => a.nom.compareTo(b.nom));
    final fav = results[2];
    _favoris = fav is List ? fav.map((e) => e.toString()).toSet() : {};
    _reindex();
    _loaded = true;
    notifyListeners();
  }

  void _reindex() {
    _index = {for (final e in _catalogue) e.id: e, for (final e in _perso.items) e.id: e};
  }

  Exercise? byId(String id) => _index[id];

  /// Nom lisible même si l'exercice a disparu du catalogue.
  String nameOf(String id) => _index[id]?.nom ?? 'Exercice supprimé';

  bool isFavori(String id) => _favoris.contains(id);

  Future<void> toggleFavori(String id) async {
    if (!_favoris.remove(id)) _favoris.add(id);
    notifyListeners();
    await store.write(_favorisFile, _favoris.toList());
  }

  /// Matériel présent dans le catalogue, pour les filtres.
  List<String> get equipements => all.map((e) => e.equipement).toSet().sorted();

  /// Recherche : texte sans accents, muscles (principaux ou secondaires), matériel.
  List<Exercise> search({
    String query = '',
    Set<Muscle> muscles = const {},
    MuscleRegion? region,
    Set<String> equipements = const {},
    bool favorisSeulement = false,
    bool persoSeulement = false,
    bool principauxSeulement = false,
  }) {
    Iterable<Exercise> it = all;
    if (favorisSeulement) it = it.where((e) => _favoris.contains(e.id));
    if (persoSeulement) it = it.where((e) => e.perso);
    if (region != null) {
      it = it.where((e) => e.musclesPrincipaux.any((m) => m.region == region));
    }
    if (muscles.isNotEmpty) {
      it = it.where((e) => (principauxSeulement ? e.musclesPrincipaux : e.tousMuscles).any(muscles.contains));
    }
    if (equipements.isNotEmpty) {
      it = it.where((e) => equipements.contains(e.famille));
    }
    if (query.trim().isEmpty) return it.toList();
    final scored = <(Exercise, int)>[];
    for (final e in it) {
      final s = TextSearch.score(query, e.nom, [e.nomEn, ...e.alias, e.equipementLabel]);
      if (s > 0) scored.add((e, s));
    }
    scored.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.nom.compareTo(b.$1.nom));
    return scored.map((e) => e.$1).toList();
  }

  /// Crée un exercice perso (l'identifiant est fourni si vide).
  Future<Exercise> addCustom(Exercise e) async {
    final ex = Exercise.fromJson({
      ...e.toJson(),
      'id': e.id.isEmpty ? 'perso-${newId()}' : e.id,
      'perso': true,
      'creeLe': (e.creeLe ?? DateTime.now()).toIso8601String(),
    });
    await _perso.upsert(ex);
    _reindex();
    notifyListeners();
    return ex;
  }

  Future<void> updateCustom(Exercise e) async {
    await _perso.upsert(e);
    _reindex();
    notifyListeners();
  }

  Future<void> deleteCustom(String id) async {
    await _perso.remove(id);
    _favoris.remove(id);
    _reindex();
    notifyListeners();
  }

  /// Ajoute plusieurs exercices perso d'un coup (import, démo).
  Future<void> addCustomAll(List<Exercise> list) async {
    await _perso.upsertAll(list);
    _reindex();
    notifyListeners();
  }

  /// Retrouve un exercice par son nom (français, anglais ou alias), pour l'import.
  Exercise? findByName(String name) {
    final n = TextSearch.normalize(name);
    if (n.isEmpty) return null;
    for (final e in all) {
      if (TextSearch.normalize(e.nom) == n) return e;
      if (e.nomEn != null && TextSearch.normalize(e.nomEn!) == n) return e;
      if (e.alias.any((a) => TextSearch.normalize(a) == n)) return e;
    }
    return null;
  }
}
