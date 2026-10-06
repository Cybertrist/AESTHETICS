import 'package:flutter/foundation.dart';

import '../../../../core/data/data.dart';

/// Notes personnelles sur n'importe quel exercice (catalogue compris),
/// gardées dans la collection `exercices_notes` du store.
class ExerciseNotes extends ChangeNotifier {
  ExerciseNotes._(this._store);

  static const _file = 'exercices_notes';
  static final Map<Store, ExerciseNotes> _instances = {};

  /// Une instance par store (la démo et la vraie appli ont chacune le leur).
  static ExerciseNotes of(Store store) => _instances.putIfAbsent(store, () => ExerciseNotes._(store).._load());

  final Store _store;
  Map<String, String> _notes = {};
  bool loaded = false;

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
}
