/// Chemins du module Progrès, pour les autres modules (import de ce seul
/// fichier, sans dépendre des pages).
abstract final class ProgresPaths {
  /// Page d'entrée de l'onglet.
  static const racine = '/progres';

  /// Bilan de la semaine en cours.
  static const semaine = '/progres/semaine';

  /// Bilan de la semaine qui contient [jour].
  static String semaineDe(DateTime jour) => '/progres/semaine?jour=${_date(jour)}';

  /// Statistiques d'un mois (le mois en cours par défaut).
  static String mois([DateTime? mois]) => '/progres/mois${mois == null ? '' : '?mois=${cle(mois)}'}';

  /// Calendrier d'entraînement : ouvert sur le mois de [jour], ce jour
  /// choisi ; sans date, le mois en cours.
  static String calendrier([DateTime? jour]) => '/progres/calendrier${jour == null ? '' : '?jour=${_date(jour)}'}';

  /// Calendrier ouvert sur un mois, sans jour choisi.
  static String calendrierDuMois(DateTime mois) => '/progres/calendrier?mois=${cle(mois)}';

  /// Récupération musculaire, puis tous les muscles.
  static const recuperation = '/progres/recuperation';
  static const tousLesMuscles = '/progres/recuperation/muscles';

  /// Liste des records.
  static const records = '/progres/records';

  /// Bilan du mois façon story, en plein écran par-dessus la barre
  /// d'onglets (le mois précédent par défaut). À ouvrir avec `context.push`.
  ///
  /// [page] ouvre directement une page : `ouverture, seances, regularite,
  /// volume, equivalent, serie, muscles, records, favoris, resume`.
  static String bilan([DateTime? mois, String? page]) {
    final q = [if (mois != null) 'mois=${cle(mois)}', if (page != null) 'page=$page'];
    return '/progres/bilan${q.isEmpty ? '' : '?${q.join('&')}'}';
  }

  /// Bilan d'une année entière, façon story. À ouvrir avec `context.push`.
  static String bilanAnnee(int annee) => '/progres/bilan?annee=$annee';

  /// « 2026-09 » pour un mois.
  static String cle(DateTime mois) => '${mois.year}-${mois.month.toString().padLeft(2, '0')}';

  static String _date(DateTime j) => '${cle(j)}-${j.day.toString().padLeft(2, '0')}';

  // Écrans des autres modules ouverts depuis Progrès.
  /// Mensurations (module Profil).
  static const mensurations = '/profil/mensurations';

  /// Photos de progression (module Profil).
  static const photos = '/profil/photos';

  /// Explorateur de muscles (module Entraîner), ouvert sur un muscle
  /// (nom de l'enum `Muscle`).
  static String explorateur(String muscle) => '/entrainer/muscles?muscle=$muscle';
}
