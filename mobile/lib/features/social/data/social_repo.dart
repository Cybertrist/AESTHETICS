import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import 'modeles.dart';
import 'source.dart';
import 'source_exemple.dart';

export 'modeles.dart';
export 'source.dart' show EtatPseudo;

/// Les amis, le fil et le coach, pour les écrans.
///
/// Le dépôt ne garde rien lui-même : il lit sa [source], des personnes
/// d'exemple en mémoire (démo, tests, construction sans serveur) ou la
/// vraie communauté sur Firestore (voir serveur/CONCEPTION.md), et redit
/// aux écrans chaque changement de la source. L'espace coach reste un
/// aperçu en mémoire.
class SocialRepo extends ChangeNotifier {
  SocialRepo({DateTime? maintenant, SourceSociale? source}) : source = source ?? SourceExemple(maintenant: maintenant) {
    this.source.addListener(notifyListeners);
  }

  final SourceSociale source;

  @override
  void dispose() {
    source.removeListener(notifyListeners);
    source.dispose();
    super.dispose();
  }

  /// Des personnes d'exemple : les écrans le disent (« Aperçu »).
  bool get apercu => source.apercu;

  /// La communauté est allumée mais personne n'est connecté : les écrans
  /// invitent à se connecter avec Google.
  bool get aConnecter => source.moi == null;

  /// Mon identifiant dans la communauté, ou null sans compte.
  String? get moi => source.moi;

  /// Mon pseudo sur le serveur : pris, libre, refusé.
  EtatPseudo get etatPseudo => source.etatPseudo;

  Lien lien(String id) => source.lien(id);
  bool estAmi(String id) => lien(id) == Lien.ami;
  bool demandeEnvoyee(String id) => lien(id) == Lien.demandeEnvoyee;

  List<Ami> get amis => source.avec(Lien.ami);
  List<Ami> get demandes => source.avec(Lien.demandeRecue);
  List<Ami> get envoyees => source.avec(Lien.demandeEnvoyee);
  List<Ami> get bloques => source.avec(Lien.bloque);

  /// Ceux de mes contacts que je peux ajouter.
  List<Ami> get suggestions => source.suggestions;

  /// Ce qui attend une réponse : le point sur la cloche de l'accueil.
  int get enAttente => demandes.length;

  Ami? ami(String id) => source.ami(id);

  /// Une page s'ouvre sur [id] : son profil est relu s'il le faut.
  void voir(String id) => source.voir(id);

  /// Son profil m'est-il ouvert ? À tous, ou à ses amis si j'en suis.
  bool ouvert(Ami a) => ouvertA(a.acces, ami: estAmi(a.id));
  static bool ouvertA(AccesProfil acces, {required bool ami}) => acces == AccesProfil.tous || (acces == AccesProfil.amis && ami);

  /// Le fil : les séances de mes amis qui me les montrent, la plus récente d'abord.
  List<Publication> get fil => [
        for (final p in source.publications)
          if (_lisible(p)) p,
      ];

  bool _lisible(Publication p) {
    final a = ami(p.amiId);
    return a != null && estAmi(a.id) && ouvert(a) && a.montre.contains(Visible.seances);
  }

  List<Publication> publicationsDe(String amiId) => source.publications.where((p) => p.amiId == amiId).toList();

  /// Ses jours d'entraînement, pour le calendrier.
  Set<DateTime> joursDe(Ami a) => source.joursDe(a);

  /// Ma réaction à une séance, s'il y en a une.
  Reaction? reaction(String publicationId) => source.reaction(publicationId);
  bool aBravo(String publicationId) => reaction(publicationId) != null;

  /// Toutes les réactions reçues, la mienne comprise.
  int bravos(Publication p) => source.bravos(p);

  /// Donne [r] à une séance ; `null` reprend ma réaction.
  Future<void> reagir(String publicationId, Reaction? r) => source.reagir(publicationId, r);

  void basculerBravo(String publicationId) => reagir(publicationId, aBravo(publicationId) ? null : Reaction.coeur);

  /// Les commentaires d'une séance, le plus ancien d'abord. Ceux d'une
  /// personne bloquée ne s'affichent pas.
  List<Commentaire> commentairesDe(String publicationId) => [
        for (final c in source.commentaires(publicationId))
          if (c.mien || lien(c.amiId!) != Lien.bloque) c,
      ]..sort((a, b) => a.date.compareTo(b.date));

  int nbCommentaires(String publicationId) => commentairesDe(publicationId).length;

  /// Ajoute mon commentaire ; un texte vide n'ajoute rien.
  Future<void> commenter(String publicationId, String texte, {DateTime? maintenant}) async {
    final t = texte.trim();
    if (t.isEmpty) return;
    await source.commenter(publicationId, t, maintenant: maintenant);
  }

  /// Retire un de mes commentaires.
  Future<void> retirerCommentaire(String id) => source.retirerCommentaire(id);

  Publication? publication(String id) => source.publication(id);

  /// Ce que mes amis ont fait, le plus récent d'abord : leurs réactions et
  /// leurs commentaires sur mes séances, une demande acceptée, leurs
  /// records. Les exemples les rattachent à [maSeance] (ma dernière séance,
  /// s'il y en a une) ; le serveur, aux séances que j'ai publiées.
  ///
  /// Une personne bloquée sort des lignes groupées (« Bob et Chloé ont
  /// réagi » devient « Bob a réagi ») ; seule une ligne qui n'avait qu'elle
  /// disparaît.
  List<Activite> activites({String? maSeance, String? nomSeance, DateTime? finSeance}) => [
        for (final a in source.activites(maSeance: maSeance, nomSeance: nomSeance, finSeance: finSeance))
          if (a.amis.every((id) => lien(id) != Lien.bloque))
            a
          else if (a.amis.where((id) => lien(id) != Lien.bloque).toList() case final restent when restent.isNotEmpty)
            Activite(type: a.type, amis: restent, date: a.date, seanceId: a.seanceId, publicationId: a.publicationId, reaction: a.reaction, texte: a.texte),
      ];

  Future<void> accepter(String id) async {
    if (lien(id) == Lien.demandeRecue) await source.accepter(id);
  }

  Future<void> refuser(String id) async {
    if (lien(id) == Lien.demandeRecue) await source.refuser(id);
  }

  /// Envoie ma demande ; s'il m'en a déjà envoyé une, c'est l'accepter.
  Future<void> inviter(String id) async {
    switch (lien(id)) {
      case Lien.aucun:
        await source.inviter(id);
      case Lien.demandeRecue:
        await source.accepter(id);
      case Lien.ami || Lien.demandeEnvoyee || Lien.bloque:
        break;
    }
  }

  Future<void> annulerInvitation(String id) async {
    if (lien(id) == Lien.demandeEnvoyee) await source.annulerInvitation(id);
  }

  Future<void> retirer(String id) async {
    if (lien(id) == Lien.ami) await source.retirer(id);
  }

  /// Plus rien l'un de l'autre : l'amitié et les demandes partent aussi.
  Future<void> bloquer(String id) => source.bloquer(id);

  Future<void> debloquer(String id) async {
    if (lien(id) == Lien.bloque) await source.debloquer(id);
  }

  /// Les personnes dont le prénom ou le pseudo contient [texte], amis
  /// compris ; sur le serveur, celles dont le pseudo commence par [texte].
  List<Ami> chercher(String texte) {
    final t = aPlat(texte);
    if (t.isEmpty) return const [];
    return source.chercher(t);
  }

  /// Le lien ou le code QR d'un ami : retrouve celui qui porte [pseudo] et
  /// lui envoie ma demande. Rend son identifiant, ou null s'il n'existe pas.
  Future<String?> ajouterParPseudo(String pseudo) async {
    final id = await source.trouverPseudo(pseudo);
    if (id == null || id == moi) return id;
    // Sans réseau, l'envoi attend en file : on n'attend pas sa confirmation.
    if (lien(id) == Lien.aucun) unawaited(inviter(id));
    return id;
  }

  /// Le site qui porte les liens d'ami : Android l'ouvre dans l'appli
  /// (serveur/public/.well-known/assetlinks.json), sinon une page explique.
  static const siteLiens = 'aesthetics-cybertrist.web.app';

  /// Le lien d'ami que portent le code QR et le partage.
  static String lienAmi(String pseudo) => 'https://$siteLiens/ami/${Uri.encodeComponent(pseudo.trim().toLowerCase())}';

  /// Le pseudo porté par un lien d'ami, ou null si ce n'en est pas un. Les
  /// anciens codes (`aesthetics://ami?pseudo=…`) restent lus.
  static String? pseudoDuLien(String? lien) {
    final u = Uri.tryParse(lien?.trim() ?? '');
    if (u == null) return null;
    String? p;
    if (u.scheme == 'aesthetics' && u.host == 'ami') p = u.queryParameters['pseudo'];
    if (u.scheme == 'https' && u.host == siteLiens && u.pathSegments.length >= 2 && u.pathSegments.first == 'ami') p = u.pathSegments[1];
    p = p?.trim();
    return p == null || p.isEmpty ? null : p;
  }

  // ---- le coach : un aperçu en mémoire, hors du serveur pour l'instant.
  bool _aUnCoach = true;
  static const _vert = 0xFF2E7D4F, _bleu = 0xFF2F6FB5, _violet = 0xFF7A4FB5, _orange = 0xFFB5702F, _rose = 0xFFB54F7A, _gris = 0xFF4A4F5A;

  bool get aUnCoach => _aUnCoach;
  static const coach = Ami(id: 'coach', prenom: 'Erwan', pseudo: 'coach.erwan', couleur: _orange, phrase: 'Coach diplômé, Brest.');

  final List<ProgrammeCoach> programmesCoach = const [
    ProgrammeCoach(id: 'c1', nom: 'Prise de masse, bloc 2', detail: '4 séances par semaine, 6 semaines', nouveau: true),
    ProgrammeCoach(id: 'c2', nom: 'Mobilité des épaules', detail: '10 minutes, avant chaque séance du haut'),
  ];

  final List<String> messagesCoach = const [
    'Bien joué sur le squat cette semaine. Garde 100 kg et vise 3 séries de 6 avant de monter.',
    'Pense à filmer ton développé couché mardi, je regarde ta trajectoire.',
  ];

  final List<Eleve> eleves = const [
    Eleve(id: 'e1', prenom: 'Léa', couleur: _violet, programme: 'Prise de masse, bloc 2', faites: 3, prevues: 4, derniere: 'Jambes, aujourd\'hui'),
    Eleve(id: 'e2', prenom: 'Malo', couleur: _bleu, programme: 'Force 5 × 5', faites: 2, prevues: 3, derniere: 'Push, hier'),
    Eleve(id: 'e3', prenom: 'Yann', couleur: _vert, programme: 'Reprise en douceur', faites: 0, prevues: 3, derniere: 'Dos, il y a 9 jours', alerte: 'Aucune séance depuis 9 jours'),
    Eleve(id: 'e4', prenom: 'Inès', couleur: _rose, programme: 'Sèche, 3 jours', faites: 1, prevues: 3, derniere: 'Haut du corps, il y a 2 jours'),
    Eleve(id: 'e5', prenom: 'Tom', couleur: _orange, programme: 'Full body débutant', faites: 2, prevues: 2, derniere: 'Full body, hier'),
    Eleve(id: 'e6', prenom: 'Sarah', couleur: _gris, programme: 'Haut / Bas 4 jours', faites: 4, prevues: 4, derniere: 'Bas, aujourd\'hui'),
  ];

  void quitterCoach() {
    _aUnCoach = false;
    notifyListeners();
  }

  void rejoindreCoach() {
    _aUnCoach = true;
    notifyListeners();
  }
}
