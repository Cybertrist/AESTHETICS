import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Programmes sur plusieurs semaines ; un seul actif à la fois.
class ProgramRepo extends ChangeNotifier {
  ProgramRepo(this.store)
      : _programs = JsonCollection(store: store, name: 'programmes', fromJson: Program.fromJson, toJson: (p) => p.toJson(), idOf: (p) => p.id);

  final Store store;
  final JsonCollection<Program> _programs;

  List<Program> get programs => [..._programs.items]..sort((a, b) => b.creeLe.compareTo(a.creeLe));
  Program? get active => _programs.items.firstWhereOrNull((p) => p.actif);

  Future<void> load() async {
    await _programs.load();
    notifyListeners();
  }

  Program? byId(String id) => _programs.byId(id);

  Future<Program> save(Program p) async {
    final prog = p.id.isEmpty ? Program.fromJson({...p.toJson(), 'id': newId()}) : p;
    await _programs.upsert(prog);
    notifyListeners();
    return prog;
  }

  Future<void> delete(String id) async {
    await _programs.remove(id);
    notifyListeners();
  }

  /// Active un programme (et désactive les autres), en repartant du début si demandé.
  Future<void> activate(String id, {bool restart = false}) async {
    final list = _programs.items.map((p) {
      if (p.id != id) return p.actif ? p.copyWith(actif: false) : p;
      return restart || p.debuteLe == null
          ? p.copyWith(actif: true, debuteLe: DateTime.now(), semaineCourante: 0, prochainIndex: 0, seancesFaites: 0)
          : p.copyWith(actif: true);
    }).toList();
    await _programs.replaceAll(list);
    notifyListeners();
  }

  Future<void> deactivate(String id) async {
    final p = byId(id);
    if (p == null) return;
    await _programs.upsert(p.copyWith(actif: false));
    notifyListeners();
  }

  /// Avance d'une séance dans le programme (appelé à la fin d'une séance du programme).
  Future<void> advance(String id) async {
    final p = byId(id);
    if (p == null || p.routineIds.isEmpty) return;
    final faites = p.seancesFaites + 1;
    await _programs.upsert(p.copyWith(
      seancesFaites: faites,
      prochainIndex: (p.prochainIndex + 1) % p.routineIds.length,
      semaineCourante: p.joursParSemaine == 0 ? 0 : (faites ~/ p.joursParSemaine).clamp(0, p.dureeSemaines - 1),
    ));
    notifyListeners();
  }

  Future<void> clear() async {
    await _programs.clear();
    notifyListeners();
  }
}
