/// Chemins du module séance (toutes en plein écran, hors onglets).
abstract final class SeancePaths {
  /// Séance en cours, ou écran « Démarrer » s'il n'y en a pas.
  static const enCours = '/seance';

  /// Démarre la routine puis ouvre la séance : `/seance/routine/<id>?programme=<id>`.
  static String routine(String routineId, {String? programId}) =>
      '/seance/routine/$routineId${programId == null ? '' : '?programme=$programId'}';

  /// Démarre une séance vide puis l'ouvre.
  static const vide = '/seance/vide';

  /// Relance une séance passée : `/seance/refaire/<id>`.
  static String refaire(String sessionId) => '/seance/refaire/$sessionId';

  static const reordonner = '/seance/reordonner';

  /// Calculateur de disques et d'échauffement : `?poids=100&exercice=<id d'emplacement>`.
  static const disques = '/seance/disques';

  static const terminer = '/seance/terminer';

  /// Résumé d'une séance terminée (`?nouveau=1` juste après la fin).
  static String resume(String id, {bool nouveau = false}) => '/seance/resume/$id${nouveau ? '?nouveau=1' : ''}';

  /// Carte « Fin de séance : l'équivalent », juste après l'enregistrement.
  static String equivalent(String id) => '/seance/equivalent/$id';

  /// Carrousel de partage ; `carte` : 0 résumé, 1 équivalent, 2 détail,
  /// 3 série de semaines, 4 autocollant sur photo.
  static String partager(String id, {int carte = 0}) => '/seance/partager/$id${carte == 0 ? '' : '?carte=$carte'}';

  /// « Lancer la séance » : aperçu d'une routine avant de commencer.
  static String apercu(String routineId, {String? programId}) =>
      '/seance/apercu/$routineId${programId == null ? '' : '?programme=$programId'}';

  /// Minuteur de repos en plein écran.
  static const repos = '/seance/repos';

  static const historique = '/seance/historique';
  static String detail(String id) => '/seance/historique/$id';
  static String modifier(String id) => '/seance/historique/$id/modifier';
}
