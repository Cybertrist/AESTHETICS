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
    required this.creeLe,
  });

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
  final DateTime creeLe;

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
        photo: photo ?? this.photo,
        phrase: phrase ?? this.phrase,
        pouces: pouces ?? this.pouces,
        miles: miles ?? this.miles,
        creeLe: creeLe,
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
        'creeLe': dateOut(creeLe),
      });
}
