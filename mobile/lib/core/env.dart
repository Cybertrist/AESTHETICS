/// Variables de construction (--dart-define).
abstract final class Env {
  /// Variante démo : données inventées, stockées à part.
  static const demo = bool.fromEnvironment('DEMO');

  /// L'appli se concentre sur la musculation : les onglets Coach et
  /// Nutrition et les cartes santé de l'accueil sont rangés en attendant.
  /// `--dart-define=COMPLET=true` les remet.
  static const muscuSeule = !bool.fromEnvironment('COMPLET');

  /// Adresse des émulateurs Firebase (`--dart-define=EMULATEUR=10.0.2.2`
  /// depuis l'émulateur Android) : vide, l'appli parle au vrai serveur.
  static const emulateur = String.fromEnvironment('EMULATEUR');
  static const portAuth = int.fromEnvironment('PORT_AUTH', defaultValue: 9099);
  static const portFirestore = int.fromEnvironment('PORT_FIRESTORE', defaultValue: 8080);
}
