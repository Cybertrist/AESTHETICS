import 'copie_serveur.dart';

/// La personne connectée.
class Utilisateur {
  const Utilisateur({required this.uid, this.nom, this.email, this.photo});
  final String uid;
  final String? nom;
  final String? email;

  /// Adresse de la photo du compte, s'il en a une.
  final String? photo;
}

/// La connexion à un compte. L'appli n'en connaît que ce contrat : le
/// service Google derrière lui se remplace, et se simule dans les tests.
abstract class ServiceConnexion {
  /// La personne connectée au lancement, ou null.
  Utilisateur? get actuel;

  /// Ouvre le choix du compte Google. Null si la personne referme la fenêtre.
  Future<Utilisateur?> connecterGoogle();

  Future<void> deconnecter();
}

/// Les copies gardées sur le serveur, une par compte.
abstract class ServiceCopies {
  /// Le résumé de la copie d'un compte, ou null s'il n'en a pas encore.
  Future<ResumeCopie?> resume(String uid);

  /// Remplace la copie du compte.
  Future<void> envoyer(String uid, ResumeCopie resume, List<String> morceaux);

  /// Les morceaux de la copie du compte, dans l'ordre ; vide sans copie.
  Future<List<String>> lire(String uid, ResumeCopie resume);
}
