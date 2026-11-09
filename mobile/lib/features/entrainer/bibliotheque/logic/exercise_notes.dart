import 'package:flutter/foundation.dart';

import '../../../../core/data/data.dart';

/// Notes personnelles sur n'importe quel exercice (catalogue compris),
/// gardées dans la collection `exercices_notes` du store.
class ExerciseNotes extends ChangeNotifier {
  ExerciseNotes._(this._store);

  static const _file = 'exercices_notes';
  static final Map<Store, ExerciseNotes> _instances = {};

  /// Une instance par store (la démo et la vraie appli ont chacune le leur).
  static ExerciseNotes of(Store store) => _instances.putIfAbsent(store, () {
        final n = ExerciseNotes._(store);
        n._pret = n._load();
        return n;
      });

  final Store _store;
  Map<String, String> _notes = {};
  bool loaded = false;
  Future<void> _pret = Future.value();

  /// Terminé quand les notes sont lues (à attendre avant d'en réécrire plusieurs).
  Future<void> get pret => _pret;

  /// Toutes les notes, par identifiant d'exercice.
  Map<String, String> get toutes => Map.unmodifiable(_notes);

  Future<void> _load() async {
    try {
      final raw = await _store.read(_file);
      if (raw is Map) _notes = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      _notes = {};
    }
    loaded = true;
    notifyListeners();
  }

  String? noteOf(String exerciseId) => _notes[exerciseId];

  Future<void> set(String exerciseId, String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) {
      _notes.remove(exerciseId);
    } else {
      _notes[exerciseId] = t;
    }
    notifyListeners();
    await _store.write(_file, _notes);
  }

  /// Remplace toutes les notes d'un coup (fusion de deux exercices).
  Future<void> remplacer(Map<String, String> notes) async {
    _notes = Map.of(notes);
    notifyListeners();
    await _store.write(_file, _notes);
  }
}
