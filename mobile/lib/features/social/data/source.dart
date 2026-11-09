import 'package:flutter/foundation.dart';

import 'modeles.dart';

/// Où en est mon pseudo sur le serveur.
enum EtatPseudo {
  /// Pas encore vérifié, ou pas de serveur.
  inconnu,

  /// Pris par mon compte : on me trouve avec.
  ok,

  /// Vide, trop court, ou avec des signes refusés.
  invalide,

  /// Déjà pris par quelqu'un d'autre.
  pris,
}

/// D'où viennent les amis, le fil et les réactions : des personnes
/// d'exemple en mémoire ([SourceExemple] de `source_exemple.dart`) ou la
/// vraie communauté sur Firestore ([SourceFirestore] de
/// `source_firestore.dart`). `SocialRepo` ne connaît que ce contrat.
///
/// Les lectures sont immédiates : elles rendent ce que la source a déjà en
/// main, et la source prévient ([notifyListeners]) quand il arrive du
/// nouveau. Les gestes rendent un `Future` que les écrans n'attendent pas.
abstract class SourceSociale extends ChangeNotifier {
  /// Vrai pour les personnes d'exemple : rien n'est envoyé.
  bool get apercu;

  /// L'identifiant de la personne connectée ; null : il faut se connecter.
  String? get moi;

  /// Mon pseudo, tel que le serveur l'a pris.
  EtatPseudo get etatPseudo => EtatPseudo.inconnu;

  Lien lien(String id);
  Ami? ami(String id);

  /// Les personnes que j'ai avec ce lien.
  List<Ami> avec(Lien l);

  /// Ceux de mes contacts que je peux ajouter.
  List<Ami> get suggestions;

  /// Les séances des autres que je peux lire, la plus récente d'abord.
  List<Publication> get publications;
  Publication? publication(String id);

  /// Ses jours d'entraînement, pour le calendrier.
  Set<DateTime> joursDe(Ami a);

  /// Ma réaction à une séance, et toutes celles reçues (la mienne comprise).
  Reaction? reaction(String publicationId);
  int bravos(Publication p);

  /// Les commentaires d'une séance, dans le désordre.
  List<Commentaire> commentaires(String publicationId);

  /// Voir `SocialRepo.activites`.
  List<Activite> activites({String? maSeance, String? nomSeance, DateTime? finSeance});

  /// Les personnes trouvées pour [texte] (déjà mis à plat, non vide).
  List<Ami> chercher(String texte);

  /// L'identifiant de celui qui porte ce pseudo, ou null.
  Future<String?> trouverPseudo(String pseudo);

  /// Une page s'ouvre sur cette personne : la source peut relire son profil.
  void voir(String id) {}

  Future<void> reagir(String publicationId, Reaction? r);
  Future<void> commenter(String publicationId, String texte, {DateTime? maintenant});
  Future<void> retirerCommentaire(String id);
  Future<void> accepter(String id);
  Future<void> refuser(String id);
  Future<void> inviter(String id);
  Future<void> annulerInvitation(String id);
  Future<void> retirer(String id);
  Future<void> bloquer(String id);
  Future<void> debloquer(String id);
}

/// Sans accents, sans majuscules, sans « @ ».
String aPlat(String s) {
  const de = 'àâäéèêëîïôöùûüç', vers = 'aaaeeeeiioouuuc';
  var t = s.trim().toLowerCase().replaceAll('@', '');
  for (var i = 0; i < de.length; i++) {
    t = t.replaceAll(de[i], vers[i]);
  }
  return t;
}
