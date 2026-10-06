/// Variables de construction (--dart-define).
abstract final class Env {
  /// Variante démo : données inventées, stockées à part.
  static const demo = bool.fromEnvironment('DEMO');

  /// L'appli se concentre sur la musculation : les onglets Coach et
  /// Nutrition et les cartes santé de l'accueil sont rangés en attendant.
  /// `--dart-define=COMPLET=true` les remet.
  static const muscuSeule = !bool.fromEnvironment('COMPLET');
}
