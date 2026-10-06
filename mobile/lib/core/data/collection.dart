import 'dart:collection';

import '../models/json.dart';
import 'store.dart';

/// Liste d'objets persistée dans un fichier du Store.
class JsonCollection<T> {
  JsonCollection({
    required this.store,
    required this.name,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
  });

  final Store store;
  final String name;
  final T Function(Json) fromJson;
  final Json Function(T) toJson;
  final String Function(T) idOf;

  List<T> _items = [];

  UnmodifiableListView<T> get items => UnmodifiableListView(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    final raw = await store.readList(name);
    final out = <T>[];
    for (final j in raw) {
      try {
        out.add(fromJson(j));
      } catch (_) {
        // Élément illisible : ignoré.
      }
    }
    _items = out;
  }

  T? byId(String id) {
    for (final e in _items) {
      if (idOf(e) == id) return e;
    }
    return null;
  }

  Future<void> save() => store.write(name, _items.map(toJson).toList());

  /// Ajoute ou remplace (même identifiant).
  Future<void> upsert(T item) {
    final i = _items.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      _items[i] = item;
    } else {
      _items.add(item);
    }
    return save();
  }

  Future<void> upsertAll(Iterable<T> list) {
    final index = {for (var i = 0; i < _items.length; i++) idOf(_items[i]): i};
    for (final item in list) {
      final i = index[idOf(item)];
      if (i != null) {
        _items[i] = item;
      } else {
        index[idOf(item)] = _items.length;
        _items.add(item);
      }
    }
    return save();
  }

  Future<void> remove(String id) {
    _items.removeWhere((e) => idOf(e) == id);
    return save();
  }

  Future<void> removeWhere(bool Function(T) test) {
    _items.removeWhere(test);
    return save();
  }

  Future<void> replaceAll(List<T> list) {
    _items = List.of(list);
    return save();
  }

  Future<void> clear() => replaceAll(const []);
}
