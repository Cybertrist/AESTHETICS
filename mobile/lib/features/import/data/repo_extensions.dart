import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Opérations groupées dont l'import a besoin, sans toucher au noyau.
/// Supprimer des centaines de séances une par une réécrirait le fichier
/// à chaque fois : on réécrit la collection d'un coup puis on recharge.
extension SessionRepoImport on SessionRepo {
  /// Nom de la collection des séances dans le Store (voir SessionRepo).
  static const collection = 'seances';

  /// Supprime plusieurs séances en une seule écriture.
  Future<void> supprimerPlusieurs(Set<String> ids) async {
    if (ids.isEmpty) return;
    final restantes = [for (final s in sessions) if (!ids.contains(s.id)) s.toJson()];
    await store.write(collection, restantes);
    await load();
  }

  /// Séances venues d'un import.
  List<WorkoutSession> get seancesImportees => [for (final s in sessions) if (s.source == 'import') s];
}

extension ExerciseRepoImport on ExerciseRepo {
  /// Supprime des exercices perso s'ils ne servent plus dans aucune séance
  /// ni routine. Rend le nombre d'exercices supprimés.
  Future<int> supprimerPersoInutilises(Set<String> ids, {required Set<String> utilises}) async {
    var n = 0;
    for (final id in ids) {
      if (utilises.contains(id)) continue;
      if (byId(id)?.perso != true) continue;
      await deleteCustom(id);
      n++;
    }
    return n;
  }
}
