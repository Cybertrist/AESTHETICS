import 'dart:typed_data';

import '../../../core/models/models.dart';
import '../../profil/data/grades.dart';

/// Ce qu'on peut répondre à une séance.
enum Reaction { coeur, feu, biceps, bravo, etoiles }

/// Mon lien avec une personne.
enum Lien { ami, demandeRecue, demandeEnvoyee, aucun, bloque }

/// Un record affiché sur un profil : « 100 kg × 5 ».
class RecordAmi {
  const RecordAmi(this.exerciceId, this.kg, this.reps);
  final String exerciceId;
  final double kg;
  final int reps;
}

/// Une personne, telle que son profil public la décrit. Ce qu'on en voit
/// dépend de [acces] et de [montre] : voir `SocialRepo.ouvert`.
class Ami {
  const Ami({
    required this.id,
    required this.prenom,
    required this.pseudo,
    required this.couleur,
    this.photo,
    this.vignette,
    this.phrase,
    this.ville,
    this.salle,
    this.depuis,
    this.acces = AccesProfil.amis,
    this.montre = UserProfile.montreParDefaut,
    this.serieSemaines = 0,
    this.seances = 0,
    this.heures = 0,
    this.objectif,
    this.niveau,
    this.jours = const [],
    this.records = const [],
    this.badges = const {},
    this.fetiches = const [],
    this.amis = 0,
    this.enCommun = const [],
  });

  final String id;
  final String prenom;
  final String pseudo;

  /// Couleur de la pastille aux initiales, tant qu'il n'y a pas de photo (ARGB).
  final int couleur;

  /// Chemin local d'une photo : la mienne, dans l'aperçu de mon profil.
  final String? photo;

  /// La vignette d'une personne du serveur : une petite image encodée.
  final Uint8List? vignette;
  final String? phrase;
  final String? ville;
  final String? salle;

  /// L'année de sa première séance.
  final int? depuis;

  /// Qui voit ce profil, et ce qu'il montre.
  final AccesProfil acces;
  final Set<Visible> montre;

  final int serieSemaines;
  final int seances;
  final int heures;

  final String? objectif;
  final String? niveau;

  /// Ses jours d'entraînement récents, en jours avant aujourd'hui (0 : aujourd'hui).
  final List<int> jours;
  final List<RecordAmi> records;

  /// Ses badges : la valeur du compteur de chaque grade.
  final Map<Grade, int> badges;

  /// Ses exercices les plus faits.
  final List<String> fetiches;

  /// Le nombre de ses amis, et ceux que nous avons en commun.
  final int amis;
  final List<String> enCommun;
}

/// Une séance publiée dans le fil.
class Publication {
  const Publication({
    required this.id,
    required this.amiId,
    required this.titre,
    required this.date,
    required this.duree,
    required this.volumeKg,
    required this.series,
    this.exercices = const [],
    this.records = 0,
    this.bravos = 0,
    this.note,
    this.seanceId,
  });

  final String id;
  final String amiId;
  final String titre;
  final DateTime date;
  final Duration duree;
  final double volumeKg;
  final int series;

  /// Identifiants d'exercices du catalogue, pour leurs vignettes.
  final List<String> exercices;
  final int records;
  final int bravos;
  final String? note;

  /// La séance de l'auteur sur son téléphone, quand c'est la mienne.
  final String? seanceId;
}

/// Un commentaire sous une séance. Sans [amiId], c'est le mien.
class Commentaire {
  const Commentaire({required this.id, required this.publicationId, required this.texte, required this.date, this.amiId});
  final String id;
  final String publicationId;
  final String? amiId;
  final String texte;
  final DateTime date;

  bool get mien => amiId == null;
}

/// Ce qu'une ligne d'activité raconte.
enum TypeActivite {
  /// Des amis ont réagi à une de mes séances.
  reaction,

  /// Un ami a commenté une de mes séances.
  commentaire,

  /// Un ami a accepté ma demande.
  accepte,

  /// Un ami a battu un record.
  record,
}

/// Une ligne des notifications : ce que mes amis ont fait.
class Activite {
  const Activite({required this.type, required this.amis, required this.date, this.seanceId, this.publicationId, this.reaction, this.texte});
  final TypeActivite type;

  /// Ceux qui l'ont fait, le plus récent d'abord.
  final List<String> amis;
  final DateTime date;

  /// Ma séance concernée, ou la séance publiée par l'ami.
  final String? seanceId;
  final String? publicationId;
  final Reaction? reaction;

  /// Le nom de la séance, ou le texte du commentaire.
  final String? texte;
}

/// Un programme partagé par le coach.
class ProgrammeCoach {
  const ProgrammeCoach({required this.id, required this.nom, required this.detail, this.nouveau = false});
  final String id;
  final String nom;
  final String detail;
  final bool nouveau;
}

/// Un élève, vu par son coach.
class Eleve {
  const Eleve({required this.id, required this.prenom, required this.couleur, required this.programme, required this.faites, required this.prevues, required this.derniere, this.alerte});
  final String id;
  final String prenom;
  final int couleur;
  final String programme;

  /// Séances faites et prévues cette semaine.
  final int faites;
  final int prevues;
  final String derniere;

  /// Ce que le coach doit regarder en premier, s'il y a lieu.
  final String? alerte;
}

extension VisibleTexte on Visible {
  /// L'ordre des réglages à l'écran : d'abord ce qui est en haut du profil.
  static const ordre = [
    Visible.nbSeances,
    Visible.nbAmis,
    Visible.lieu,
    Visible.heures,
    Visible.objectif,
    Visible.niveau,
    Visible.serie,
    Visible.badges,
    Visible.records,
    Visible.seances,
    Visible.charges,
  ];

  String get titre => switch (this) {
        Visible.nbSeances => 'Mon nombre de séances',
        Visible.nbAmis => 'Mon nombre d\'amis',
        Visible.lieu => 'Ma ville et ma salle',
        Visible.heures => 'Mes heures à la salle',
        Visible.objectif => 'Mon objectif',
        Visible.niveau => 'Mon niveau',
        Visible.serie => 'Ma série',
        Visible.badges => 'Mes badges',
        Visible.records => 'Mes records',
        Visible.seances => 'Mes séances',
        Visible.charges => 'Mes charges',
      };

  String get detail => switch (this) {
        Visible.nbSeances => 'Le total de tes séances, sous ton nom.',
        Visible.nbAmis => 'Le total de tes amis, sous ton nom.',
        Visible.lieu => 'Là où tu t\'entraînes.',
        Visible.heures => 'Le temps passé à t\'entraîner depuis le début.',
        Visible.objectif => 'Sécher, prendre du muscle, gagner en force…',
        Visible.niveau => 'Celui que tu as choisi : débutant, intermédiaire ou avancé.',
        Visible.serie => 'Le calendrier du mois, avec tes semaines d\'affilée.',
        Visible.badges => 'Les badges que tu as gagnés.',
        Visible.records => 'Tes meilleures barres.',
        Visible.seances => 'Le titre, la durée et les exercices de chaque séance.',
        Visible.charges => 'Les kilos soulevés. Sans eux, on voit la séance, pas les poids.',
      };
}
