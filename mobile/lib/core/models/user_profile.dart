import 'json.dart';
import 'nutrition.dart';

enum Sexe {
  homme('Homme'),
  femme('Femme'),
  autre('Autre');

  const Sexe(this.label);
  final String label;
}

enum Objectif {
  prendreDuMuscle('Prendre du muscle', 'Masse musculaire et volume'),
  secher('Sécher', 'Perdre du gras en gardant le muscle'),
  recomposition('Recomposition', 'Muscle en plus, gras en moins'),
  force('Gagner en force', 'Charges lourdes, peu de répétitions'),
  forme('Rester en forme', 'Santé, énergie, régularité');

  const Objectif(this.label, this.description);
  final String label;
  final String description;

  /// Prendre du poids est-il une bonne nouvelle ? Non pour sécher, oui pour
  /// prendre du muscle ou de la force ; sans sens voulu (recomposition,
  /// forme), `null`.
  bool? get monterDePoidsEstBien => switch (this) {
        secher => false,
        prendreDuMuscle || force => true,
        recomposition || forme => null,
      };
}

enum Niveau {
  debutant('Débutant', 'Moins d\'un an de pratique'),
  intermediaire('Intermédiaire', 'Un à trois ans'),
  avance('Avancé', 'Plus de trois ans');

  const Niveau(this.label, this.description);
  final String label;
  final String description;
}

enum NiveauActivite {
  sedentaire('Sédentaire', 'Travail assis, peu de marche', 1.2),
  leger('Légère', 'Un peu de marche au quotidien', 1.375),
  modere('Modérée', 'Debout souvent, sport régulier', 1.55),
  actif('Active', 'Métier physique ou sport quotidien', 1.725),
  tresActif('Très active', 'Deux entraînements par jour', 1.9);

  const NiveauActivite(this.label, this.description, this.facteur);
  final String label;
  final String description;
  final double facteur;
}

enum Materiel {
  salleComplete('Salle complète'),
  barre('Barre et disques'),
  halteres('Haltères'),
  banc('Banc'),
  barreTraction('Barre de traction'),
  kettlebell('Kettlebell'),
  elastiques('Élastiques'),
  poidsDuCorps('Poids du corps');

  const Materiel(this.label);
  final String label;
}

enum UnitePoids {
  kg('kg'),
  lb('lb');

  const UnitePoids(this.label);
  final String label;
}

/// Qui voit mon profil dans la communauté.
enum AccesProfil {
  tous('Tout le monde', 'Tous ceux qui ont AESTHETICS voient ton profil.'),
  amis('Mes amis', 'Les autres ne voient que ton prénom et ta photo.'),
  personne('Personne', 'Même tes amis ne voient que ton prénom et ta photo.');

  const AccesProfil(this.titre, this.detail);
  final String titre;
  final String detail;
}

/// Ce que montre le profil public, élément par élément.
enum Visible {
  seances,
  charges,
  serie,
  badges,
  records,
  lieu,
  nbSeances,
  nbAmis,
  heures,
  objectif,
  niveau;

  /// Les réglages arrivés après coup : montrés tant qu'on n'y a pas touché.
  static const recents = {nbSeances, nbAmis, heures, objectif, niveau};
}

/// Profil créé à l'inscription.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.prenom,
    this.sexe = Sexe.homme,
    this.naissance,
    this.tailleCm,
    this.poidsKg,
    this.poidsCibleKg,
    this.objectif = Objectif.prendreDuMuscle,
    this.niveau = Niveau.intermediaire,
    this.activite = NiveauActivite.modere,
    this.joursParSemaine = 4,
    this.dureeSeanceMin = 60,
    this.materiel = const {Materiel.salleComplete},
    this.unitePoids = UnitePoids.kg,
    this.objectifsNutrition,
    this.photo,
    this.phrase = '',
    this.pouces = false,
    this.miles = false,
    this.pseudo = '',
    this.ville = '',
    this.salle = '',
    this.acces = AccesProfil.amis,
    this.montre = montreParDefaut,
    required this.creeLe,
  });

  /// Montré tant que rien n'est réglé : tout, sauf les charges et le lieu.
  static const montreParDefaut = {Visible.seances, Visible.serie, Visible.badges, Visible.records, ...Visible.recents};

  final String id;
  final String prenom;
  final Sexe sexe;
  final DateTime? naissance;
  final double? tailleCm;
  final double? poidsKg;
  final double? poidsCibleKg;
  final Objectif objectif;
  final Niveau niveau;
  final NiveauActivite activite;
  final int joursParSemaine;
  final int dureeSeanceMin;
  final Set<Materiel> materiel;
  final UnitePoids unitePoids;

  /// Objectifs caloriques choisis ; null tant qu'ils ne sont pas calculés.
  final NutritionGoals? objectifsNutrition;

  /// Chemin local de la photo de profil.
  final String? photo;

  /// Phrase libre affichée sous le prénom (devise, présentation). Vide : aucune.
  final String phrase;

  /// Tours du corps affichés en pouces, distances en miles.
  final bool pouces;
  final bool miles;

  /// Le nom par lequel mes amis me trouvent, sans « @ ». Vide : pas encore choisi.
  final String pseudo;
  final String ville;

  /// Le nom de ma salle (« Basic-Fit Brest »).
  final String salle;

  /// Qui voit mon profil, et ce qu'il montre.
  final AccesProfil acces;
  final Set<Visible> montre;
  final DateTime creeLe;

  /// Version de la liste [montre] dans le fichier : elle dit quels réglages
  /// existaient quand la liste a été écrite.
  static const versionMontre = 2;
  bool get _montreParDefaut => montre.length == montreParDefaut.length && montre.containsAll(montreParDefaut);

  int? get age {
    final n = naissance;
    if (n == null) return null;
    final now = DateTime.now();
    var a = now.year - n.year;
    if (now.month < n.month || (now.month == n.month && now.day < n.day)) a--;
    return a;
  }

  /// Premier caractère du prénom, entier : un émoji tient sur deux unités
  /// UTF-16, en prendre une seule fait planter l'affichage du texte.
  String get initiales => prenom.trim().isEmpty ? '?' : String.fromCharCode(prenom.trim().runes.first).toUpperCase();

  UserProfile copyWith({
    String? prenom,
    Sexe? sexe,
    DateTime? naissance,
    double? tailleCm,
    double? poidsKg,
    double? poidsCibleKg,
    Objectif? objectif,
    Niveau? niveau,
    NiveauActivite? activite,
    int? joursParSemaine,
    int? dureeSeanceMin,
    Set<Materiel>? materiel,
    UnitePoids? unitePoids,
    NutritionGoals? objectifsNutrition,
    String? photo,
    String? phrase,
    bool? pouces,
    bool? miles,
    String? pseudo,
    String? ville,
    String? salle,
    AccesProfil? acces,
    Set<Visible>? montre,
    bool sansPhoto = false,
  }) =>
      UserProfile(
        id: id,
        prenom: prenom ?? this.prenom,
        sexe: sexe ?? this.sexe,
        naissance: naissance ?? this.naissance,
        tailleCm: tailleCm ?? this.tailleCm,
        poidsKg: poidsKg ?? this.poidsKg,
        poidsCibleKg: poidsCibleKg ?? this.poidsCibleKg,
        objectif: objectif ?? this.objectif,
        niveau: niveau ?? this.niveau,
        activite: activite ?? this.activite,
        joursParSemaine: joursParSemaine ?? this.joursParSemaine,
        dureeSeanceMin: dureeSeanceMin ?? this.dureeSeanceMin,
        materiel: materiel ?? this.materiel,
        unitePoids: unitePoids ?? this.unitePoids,
        objectifsNutrition: objectifsNutrition ?? this.objectifsNutrition,
        photo: sansPhoto ? null : photo ?? this.photo,
        phrase: phrase ?? this.phrase,
        pouces: pouces ?? this.pouces,
        miles: miles ?? this.miles,
        pseudo: pseudo ?? this.pseudo,
        ville: ville ?? this.ville,
        salle: salle ?? this.salle,
        acces: acces ?? this.acces,
        montre: montre ?? this.montre,
        creeLe: creeLe,
      );

  /// Ce profil, avec tout ce que les questions de l'inscription ne posent
  /// pas repris de [ancien] : la phrase, les unités, le profil public.
  UserProfile gardant(UserProfile ancien) => copyWith(
        phrase: ancien.phrase,
        pouces: ancien.pouces,
        miles: ancien.miles,
        pseudo: ancien.pseudo,
        ville: ancien.ville,
        salle: ancien.salle,
        acces: ancien.acces,
        montre: ancien.montre,
      );

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: asString(j['id']) ?? 'moi',
        prenom: asString(j['prenom']) ?? '',
        sexe: enumByName(Sexe.values, j['sexe'], Sexe.homme),
        naissance: asDate(j['naissance']),
        tailleCm: asDouble(j['tailleCm']),
        poidsKg: asDouble(j['poidsKg']),
        poidsCibleKg: asDouble(j['poidsCibleKg']),
        objectif: enumByName(Objectif.values, j['objectif'], Objectif.prendreDuMuscle),
        niveau: enumByName(Niveau.values, j['niveau'], Niveau.intermediaire),
        activite: enumByName(NiveauActivite.values, j['activite'], NiveauActivite.modere),
        joursParSemaine: asInt(j['joursParSemaine']) ?? 4,
        dureeSeanceMin: asInt(j['dureeSeanceMin']) ?? 60,
        materiel: asStringList(j['materiel'])
            .map((s) => enumByName(Materiel.values, s, Materiel.salleComplete))
            .toSet(),
        unitePoids: enumByName(UnitePoids.values, j['unitePoids'], UnitePoids.kg),
        objectifsNutrition: asJson(j['objectifsNutrition']) == null
            ? null
            : NutritionGoals.fromJson(asJson(j['objectifsNutrition'])!),
        photo: asString(j['photo']),
        phrase: asString(j['phrase']) ?? '',
        pouces: asBool(j['pouces']),
        miles: asBool(j['miles']),
        pseudo: asString(j['pseudo']) ?? '',
        ville: asString(j['ville']) ?? '',
        salle: asString(j['salle']) ?? '',
        acces: enumByName(AccesProfil.values, j['acces'], AccesProfil.amis),
        // Une liste vide est un choix (ne rien montrer) ; une clé absente, le réglage de départ.
        // Une liste écrite avant les derniers réglages ne dit rien d'eux : ils restent montrés.
        montre: j['montre'] is List
            ? {
                for (final v in Visible.values)
                  if (asStringList(j['montre']).contains(v.name)) v,
                if (asInt(j['montreV']) != versionMontre) ...Visible.recents,
              }
            : montreParDefaut,
        creeLe: asDate(j['creeLe']) ?? DateTime.now(),
      );

  Json toJson() => compact({
        'id': id,
        'prenom': prenom,
        'sexe': sexe.name,
        'naissance': dateOut(naissance),
        'tailleCm': tailleCm,
        'poidsKg': poidsKg,
        'poidsCibleKg': poidsCibleKg,
        'objectif': objectif.name,
        'niveau': niveau.name,
        'activite': activite.name,
        'joursParSemaine': joursParSemaine,
        'dureeSeanceMin': dureeSeanceMin,
        'materiel': materiel.map((m) => m.name).toList(),
        'unitePoids': unitePoids.name,
        'objectifsNutrition': objectifsNutrition?.toJson(),
        'photo': photo,
        'phrase': phrase.isEmpty ? null : phrase,
        'pouces': pouces ? true : null,
        'miles': miles ? true : null,
        'pseudo': pseudo.isEmpty ? null : pseudo,
        'ville': ville.isEmpty ? null : ville,
        'salle': salle.isEmpty ? null : salle,
        'acces': acces == AccesProfil.amis ? null : acces.name,
        'montre': _montreParDefaut ? null : [for (final v in Visible.values) if (montre.contains(v)) v.name],
        'montreV': _montreParDefaut ? null : versionMontre,
        'creeLe': dateOut(creeLe),
      });
}
