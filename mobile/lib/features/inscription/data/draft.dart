import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Unité d'affichage de la taille.
enum UniteTaille {
  cm('cm'),
  ftIn('ft / in');

  const UniteTaille(this.label);
  final String label;
}

/// Grandes familles de matériel proposées à l'inscription.
enum MaterielPreset {
  salle('Salle complète', 'Machines, poulies, barres, haltères'),
  halteres('Haltères', 'Une paire d\'haltères, un banc si possible'),
  maison('À la maison', 'Un peu de matériel chez toi'),
  poidsDuCorps('Poids du corps', 'Aucun matériel, partout'),
  surMesure('Sur mesure', 'Tu choisis pièce par pièce');

  const MaterielPreset(this.label, this.description);
  final String label;
  final String description;

  Set<Materiel> get materiel => switch (this) {
        MaterielPreset.salle => {Materiel.salleComplete},
        MaterielPreset.halteres => {Materiel.halteres, Materiel.banc, Materiel.poidsDuCorps},
        MaterielPreset.maison => {Materiel.halteres, Materiel.elastiques, Materiel.barreTraction, Materiel.poidsDuCorps},
        MaterielPreset.poidsDuCorps => {Materiel.poidsDuCorps},
        MaterielPreset.surMesure => const {},
      };
}

/// Ce que l'inscription retient en plus du [UserProfile] du socle.
/// Rangé dans la collection `profil_extras`.
class ProfileExtras {
  const ProfileExtras({
    this.musclesPrioritaires = const {},
    this.uniteTaille = UniteTaille.cm,
    this.joursEntrainement = const {1, 2, 4, 5},
    this.materielPreset,
    this.nutritionAuto = true,
  });

  static const collection = 'profil_extras';

  final Set<Muscle> musclesPrioritaires;
  final UniteTaille uniteTaille;

  /// Jours choisis, 1 = lundi … 7 = dimanche.
  final Set<int> joursEntrainement;
  final MaterielPreset? materielPreset;

  /// Objectifs nutritionnels recalculés quand le poids change.
  final bool nutritionAuto;

  factory ProfileExtras.fromJson(Json j) => ProfileExtras(
        musclesPrioritaires: asStringList(j['musclesPrioritaires']).map(Muscle.tryParse).whereType<Muscle>().toSet(),
        uniteTaille: enumByName(UniteTaille.values, j['uniteTaille'], UniteTaille.cm),
        joursEntrainement: (j['joursEntrainement'] is List)
            ? (j['joursEntrainement'] as List).map((e) => asInt(e)).whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
            : const {1, 2, 4, 5},
        materielPreset: j['materielPreset'] == null ? null : enumByName(MaterielPreset.values, j['materielPreset'], MaterielPreset.salle),
        nutritionAuto: j['nutritionAuto'] == null ? true : asBool(j['nutritionAuto']),
      );

  Json toJson() => compact({
        'musclesPrioritaires': musclesPrioritaires.map((m) => m.name).toList(),
        'uniteTaille': uniteTaille.name,
        'joursEntrainement': (joursEntrainement.toList()..sort()),
        'materielPreset': materielPreset?.name,
        'nutritionAuto': nutritionAuto,
      });

  static Future<ProfileExtras> load(Store store) async {
    final j = await store.readObject(collection);
    return j == null ? const ProfileExtras() : ProfileExtras.fromJson(j);
  }

  Future<void> save(Store store) => store.write(collection, toJson());
}

/// Brouillon de l'inscription, sauvé à chaque réponse pour survivre
/// à un passage par l'import ou à la fermeture de l'appli.
class Draft {
  Draft({
    this.prenom = '',
    this.photo,
    this.sexe,
    this.naissance,
    this.tailleCm,
    this.uniteTaille = UniteTaille.cm,
    this.poidsKg,
    this.poidsCibleKg,
    this.unitePoids = UnitePoids.kg,
    this.objectif,
    this.niveau,
    this.activite,
    Set<int>? jours,
    this.dureeSeanceMin = 60,
    this.materielPreset,
    Set<Materiel>? materiel,
    Set<Muscle>? muscles,
    this.objectifsNutrition,
    this.nutritionAuto = true,
    this.santeConnectee = false,
    this.rappels = false,
    this.heureRappel = '18:00',
    this.etape = 0,
    this.profilId,
    this.creeLe,
  })  : jours = jours ?? {1, 3, 5},
        materiel = materiel ?? {},
        muscles = muscles ?? {};

  static const collection = 'inscription_brouillon';

  String prenom;
  String? photo;
  Sexe? sexe;
  DateTime? naissance;
  double? tailleCm;
  UniteTaille uniteTaille;
  double? poidsKg;
  double? poidsCibleKg;
  UnitePoids unitePoids;
  Objectif? objectif;
  Niveau? niveau;
  NiveauActivite? activite;
  Set<int> jours;
  int dureeSeanceMin;
  MaterielPreset? materielPreset;
  Set<Materiel> materiel;
  Set<Muscle> muscles;
  NutritionGoals? objectifsNutrition;
  bool nutritionAuto;
  bool santeConnectee;
  bool rappels;
  String heureRappel;
  int etape;

  /// Renseignés quand on modifie un profil existant.
  String? profilId;
  DateTime? creeLe;

  int? get age {
    final n = naissance;
    if (n == null) return null;
    final now = DateTime.now();
    var a = now.year - n.year;
    if (now.month < n.month || (now.month == n.month && now.day < n.day)) a--;
    return a;
  }

  /// Profil tel qu'il serait enregistré maintenant.
  UserProfile toProfile() => UserProfile(
        id: profilId ?? 'moi',
        prenom: prenom.trim(),
        sexe: sexe ?? Sexe.homme,
        naissance: naissance,
        tailleCm: tailleCm,
        poidsKg: poidsKg,
        poidsCibleKg: poidsCibleKg,
        objectif: objectif ?? Objectif.prendreDuMuscle,
        niveau: niveau ?? Niveau.intermediaire,
        activite: activite ?? NiveauActivite.modere,
        joursParSemaine: jours.isEmpty ? 3 : jours.length,
        dureeSeanceMin: dureeSeanceMin,
        materiel: materiel.isEmpty ? {Materiel.poidsDuCorps} : materiel,
        unitePoids: unitePoids,
        objectifsNutrition: nutritionAuto ? null : objectifsNutrition,
        photo: photo,
        creeLe: creeLe ?? DateTime.now(),
      );

  ProfileExtras toExtras() => ProfileExtras(
        musclesPrioritaires: muscles,
        uniteTaille: uniteTaille,
        joursEntrainement: jours,
        materielPreset: materielPreset,
        nutritionAuto: nutritionAuto,
      );

  factory Draft.fromProfile(UserProfile p, ProfileExtras x, AppSettings s) => Draft(
        prenom: p.prenom,
        photo: p.photo,
        sexe: p.sexe,
        naissance: p.naissance,
        tailleCm: p.tailleCm,
        uniteTaille: x.uniteTaille,
        poidsKg: p.poidsKg,
        poidsCibleKg: p.poidsCibleKg,
        unitePoids: p.unitePoids,
        objectif: p.objectif,
        niveau: p.niveau,
        activite: p.activite,
        jours: x.joursEntrainement.length == p.joursParSemaine ? {...x.joursEntrainement} : joursParDefaut(p.joursParSemaine),
        dureeSeanceMin: p.dureeSeanceMin,
        materielPreset: x.materielPreset,
        materiel: {...p.materiel},
        muscles: {...x.musclesPrioritaires},
        objectifsNutrition: p.objectifsNutrition,
        nutritionAuto: p.objectifsNutrition == null,
        santeConnectee: s.santeConnectee,
        rappels: s.rappelsEntrainement,
        heureRappel: s.heureRappel,
        profilId: p.id,
        creeLe: p.creeLe,
      );

  /// Jours répartis dans la semaine pour un nombre de séances donné.
  static Set<int> joursParDefaut(int n) => switch (n.clamp(1, 7)) {
        1 => {3},
        2 => {2, 5},
        3 => {1, 3, 5},
        4 => {1, 2, 4, 5},
        5 => {1, 2, 3, 5, 6},
        6 => {1, 2, 3, 4, 5, 6},
        _ => {1, 2, 3, 4, 5, 6, 7},
      };

  factory Draft.fromJson(Json j) => Draft(
        prenom: asString(j['prenom']) ?? '',
        photo: asString(j['photo']),
        sexe: j['sexe'] == null ? null : enumByName(Sexe.values, j['sexe'], Sexe.homme),
        naissance: asDate(j['naissance']),
        tailleCm: asDouble(j['tailleCm']),
        uniteTaille: enumByName(UniteTaille.values, j['uniteTaille'], UniteTaille.cm),
        poidsKg: asDouble(j['poidsKg']),
        poidsCibleKg: asDouble(j['poidsCibleKg']),
        unitePoids: enumByName(UnitePoids.values, j['unitePoids'], UnitePoids.kg),
        objectif: j['objectif'] == null ? null : enumByName(Objectif.values, j['objectif'], Objectif.prendreDuMuscle),
        niveau: j['niveau'] == null ? null : enumByName(Niveau.values, j['niveau'], Niveau.intermediaire),
        activite: j['activite'] == null ? null : enumByName(NiveauActivite.values, j['activite'], NiveauActivite.modere),
        jours: (j['jours'] is List) ? (j['jours'] as List).map((e) => asInt(e)).whereType<int>().toSet() : null,
        dureeSeanceMin: asInt(j['dureeSeanceMin']) ?? 60,
        materielPreset: j['materielPreset'] == null ? null : enumByName(MaterielPreset.values, j['materielPreset'], MaterielPreset.salle),
        materiel: asStringList(j['materiel']).map((s) => enumByName(Materiel.values, s, Materiel.poidsDuCorps)).toSet(),
        muscles: asStringList(j['muscles']).map(Muscle.tryParse).whereType<Muscle>().toSet(),
        objectifsNutrition: asJson(j['objectifsNutrition']) == null ? null : NutritionGoals.fromJson(asJson(j['objectifsNutrition'])!),
        nutritionAuto: j['nutritionAuto'] == null ? true : asBool(j['nutritionAuto']),
        santeConnectee: asBool(j['santeConnectee']),
        rappels: asBool(j['rappels']),
        heureRappel: asString(j['heureRappel']) ?? '18:00',
        etape: asInt(j['etape']) ?? 0,
      );

  Json toJson() => compact({
        'prenom': prenom,
        'photo': photo,
        'sexe': sexe?.name,
        'naissance': dateOut(naissance),
        'tailleCm': tailleCm,
        'uniteTaille': uniteTaille.name,
        'poidsKg': poidsKg,
        'poidsCibleKg': poidsCibleKg,
        'unitePoids': unitePoids.name,
        'objectif': objectif?.name,
        'niveau': niveau?.name,
        'activite': activite?.name,
        'jours': (jours.toList()..sort()),
        'dureeSeanceMin': dureeSeanceMin,
        'materielPreset': materielPreset?.name,
        'materiel': materiel.map((m) => m.name).toList(),
        'muscles': muscles.map((m) => m.name).toList(),
        'objectifsNutrition': objectifsNutrition?.toJson(),
        'nutritionAuto': nutritionAuto,
        'santeConnectee': santeConnectee,
        'rappels': rappels,
        'heureRappel': heureRappel,
        'etape': etape,
      });
}
