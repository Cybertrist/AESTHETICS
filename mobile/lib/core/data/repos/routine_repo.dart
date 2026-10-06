import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Routines et dossiers.
class RoutineRepo extends ChangeNotifier {
  RoutineRepo(this.store)
      : _routines = JsonCollection(store: store, name: 'routines', fromJson: Routine.fromJson, toJson: (r) => r.toJson(), idOf: (r) => r.id),
        _folders = JsonCollection(store: store, name: 'dossiers', fromJson: Folder.fromJson, toJson: (f) => f.toJson(), idOf: (f) => f.id);

  final Store store;
  final JsonCollection<Routine> _routines;
  final JsonCollection<Folder> _folders;

  /// Routines triées par ordre puis par nom.
  List<Routine> get routines => [..._routines.items]..sort(_byOrder);
  List<Folder> get folders => [..._folders.items]..sort((a, b) => a.ordre.compareTo(b.ordre));

  static int _byOrder(Routine a, Routine b) => a.ordre != b.ordre ? a.ordre.compareTo(b.ordre) : a.nom.compareTo(b.nom);

  Future<void> load() async {
    await Future.wait([_routines.load(), _folders.load()]);
    notifyListeners();
  }

  Routine? byId(String id) => _routines.byId(id);
  Folder? folderById(String id) => _folders.byId(id);

  /// Routines d'un dossier (null : hors dossier).
  List<Routine> routinesIn(String? folderId) => routines.where((r) => r.folderId == folderId).toList();

  /// Crée ou remplace une routine. Un id vide en crée un nouveau.
  Future<Routine> save(Routine r) async {
    final routine = r.id.isEmpty
        ? Routine(
            id: newId(),
            nom: r.nom,
            folderId: r.folderId,
            notes: r.notes,
            exercices: r.exercices,
            creeLe: r.creeLe,
            modifieLe: DateTime.now(),
            ordre: _routines.length,
          )
        : r.copyWith(modifieLe: DateTime.now());
    await _routines.upsert(routine);
    notifyListeners();
    return routine;
  }

  Future<void> saveAll(List<Routine> list) async {
    await _routines.upsertAll(list);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _routines.remove(id);
    notifyListeners();
  }

  Future<Routine> duplicate(String id) async {
    final r = byId(id);
    if (r == null) throw StateError('Routine introuvable');
    return save(Routine(
      id: '',
      nom: '${r.nom} (copie)',
      folderId: r.folderId,
      notes: r.notes,
      exercices: [for (final e in r.exercices) e.copyWith()],
      creeLe: DateTime.now(),
    ));
  }

  Future<void> moveToFolder(String routineId, String? folderId) async {
    final r = byId(routineId);
    if (r == null) return;
    await _routines.upsert(folderId == null ? r.copyWith(clearFolder: true) : r.copyWith(folderId: folderId));
    notifyListeners();
  }

  /// Réordonne les routines d'un dossier selon la liste d'identifiants.
  Future<void> reorder(List<String> orderedIds) async {
    final updated = <Routine>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final r = byId(orderedIds[i]);
      if (r != null) updated.add(r.copyWith(ordre: i));
    }
    await _routines.upsertAll(updated);
    notifyListeners();
  }

  Future<Folder> addFolder(String nom) async {
    final f = Folder(id: newId(), nom: nom, ordre: _folders.length);
    await _folders.upsert(f);
    notifyListeners();
    return f;
  }

  Future<void> saveFolder(Folder f) async {
    await _folders.upsert(f);
    notifyListeners();
  }

  Future<void> toggleFolder(String id) async {
    final f = folderById(id);
    if (f == null) return;
    await saveFolder(f.copyWith(replie: !f.replie));
  }

  /// Supprime un dossier ; ses routines passent hors dossier (ou sont supprimées).
  Future<void> deleteFolder(String id, {bool withRoutines = false}) async {
    if (withRoutines) {
      await _routines.removeWhere((r) => r.folderId == id);
    } else {
      await _routines.upsertAll(routinesIn(id).map((r) => r.copyWith(clearFolder: true)));
    }
    await _folders.remove(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await Future.wait([_routines.clear(), _folders.clear()]);
    notifyListeners();
  }
}
