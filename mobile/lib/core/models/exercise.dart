import 'json.dart';
import 'muscle.dart';

/// Façon de noter une série pour cet exercice.
enum ExerciseTracking {
  poidsReps('Poids et répétitions'),
  repsSeules('Répétitions seules'),
  poidsDuCorpsLeste('Poids du corps lesté'),
  poidsDuCorpsAssiste('Poids du corps assisté'),
  duree('Durée'),
  distanceDuree('Distance et durée'),
  poidsDuree('Poids et durée');

  const ExerciseTracking(this.label);
  final String label;

  bool get usesWeight =>
      this == poidsReps || this == poidsDuCorpsLeste || this == poidsDuCorpsAssiste || this == poidsDuree;
  bool get usesReps => this == poidsReps || this == repsSeules || this == poidsDuCorpsLeste || this == poidsDuCorpsAssiste;
  bool get usesDuration => this == duree || this == distanceDuree || this == poidsDuree;
  bool get usesDistance => this == distanceDuree;
}

/// Libellés du matériel, clés du catalogue.
abstract final class Equipements {
  static const labels = <String, String>{
    'barre': 'Barre',
    'halteres': 'Haltères',
    'machine': 'Machine',
    'poulie': 'Poulie',
    'poids du corps': 'Poids du corps',
    'kettlebell': 'Kettlebell',
    'elastique': 'Élastique',
    'barre ez': 'Barre EZ',
    'smith': 'Machine guidée',
    'banc': 'Banc',
    'ballon': 'Ballon',
    'disque': 'Disque',
    'cardio': 'Cardio',
    'autre': 'Autre',
  };

  /// Familles plus fines du catalogue (champ `materiel`), pour le filtre.
  static const fins = <String, String>{
    'barre trapeze': 'Barre trapèze',
    'presse': 'Presse',
    'barre de traction': 'Barre de traction',
    'suspension': 'Sangles et anneaux',
    'mini-bande': 'Mini-bande',
    'medecine-ball': 'Médecine-ball',
    'bosu': 'Bosu',
    'corde ondulatoire': 'Corde ondulatoire',
    'roue abdominale': 'Roue abdominale',
    'corde a sauter': 'Corde à sauter',
    'traineau': 'Traîneau',
  };

  static String label(String? key) {
    if (key == null || key.isEmpty) return 'Autre';
    final k = key.toLowerCase();
    return labels[k] ?? fins[k] ?? (key[0].toUpperCase() + key.substring(1));
  }
}

/// Médias d'un exercice : animation, vidéo ou images (URL ou asset).
class ExerciseMedia {
  const ExerciseMedia({this.gif, this.gifSecours, this.mp4, this.images = const [], this.imagesLocales = const [], this.credit});

  final String? gif;

  /// Même animation hébergée ailleurs, si la première adresse échoue.
  final String? gifSecours;
  final String? mp4;
  final List<String> images;

  /// Photos embarquées (assets/exercises/), disponibles hors ligne.
  final List<String> imagesLocales;

  /// Crédit à afficher en petit sous le média.
  final String? credit;

  bool get isEmpty => gif == null && gifSecours == null && mp4 == null && images.isEmpty && imagesLocales.isEmpty;

  /// Vignette : photo locale d'abord, puis animation, puis photo en ligne.
  String? get thumbnail =>
      imagesLocales.isNotEmpty ? imagesLocales.first : (gif ?? gifSecours ?? (images.isNotEmpty ? images.first : null));

  factory ExerciseMedia.fromJson(Json? j) {
    if (j == null) return const ExerciseMedia();
    return ExerciseMedia(
      gif: asString(j['gif']),
      gifSecours: asString(j['gifSecours']),
      mp4: asString(j['mp4']),
      images: asStringList(j['images']),
      imagesLocales: asStringList(j['imagesLocales']),
      credit: asString(j['credit']),
    );
  }

  Json toJson() => compact({
        'gif': gif,
        'gifSecours': gifSecours,
        'mp4': mp4,
        'images': images.isEmpty ? null : images,
        'imagesLocales': imagesLocales.isEmpty ? null : imagesLocales,
        'credit': credit,
      });
}

/// Libellés des catégories du catalogue.
abstract final class Categories {
  static const labels = <String, String>{
    'pectoraux': 'Pectoraux',
    'dos': 'Dos',
    'epaules': 'Épaules',
    'biceps': 'Biceps',
    'triceps': 'Triceps',
    'avantBras': 'Avant-bras',
    'jambes': 'Jambes',
    'ischios': 'Ischio-jambiers',
    'fessiers': 'Fessiers',
    'mollets': 'Mollets',
    'abdos': 'Abdos',
    'cardio': 'Cardio',
    'completCorps': 'Corps complet',
    'cou': 'Cou',
    'etirements': 'Étirements',
  };

  static String label(String? key) => labels[key] ?? (key == null || key.isEmpty ? 'Autre' : key[0].toUpperCase() + key.substring(1));
}

/// Exercice du catalogue ou créé par l'utilisateur.
class Exercise {
  const Exercise({
    required this.id,
    required this.nom,
    this.nomEn,
    this.alias = const [],
    this.musclesPrincipaux = const [],
    this.musclesSecondaires = const [],
    this.equipement = 'autre',
    this.materiel,
    this.categorie = 'force',
    this.mecanique,
    this.niveau,
    this.instructions = const [],
    this.conseils = const [],
    this.media = const ExerciseMedia(),
    this.source,
    this.perso = false,
    this.suiviExplicite,
    this.notes,
    this.creeLe,
  });

  final String id;
  final String nom;
  final String? nomEn;
  final List<String> alias;
  final List<Muscle> musclesPrincipaux;
  final List<Muscle> musclesSecondaires;
  final String equipement;

  /// Famille plus précise que [equipement] (presse, barre de traction...),
  /// quand le catalogue en donne une.
  final String? materiel;
  final String categorie;
  final String? mecanique;
  final String? niveau;
  final List<String> instructions;
  final List<String> conseils;
  final ExerciseMedia media;
  final String? source;
  final bool perso;
  /// Suivi choisi ; null pour le déduire du matériel.
  final ExerciseTracking? suiviExplicite;
  final String? notes;
  final DateTime? creeLe;

  /// Suivi explicite, sinon déduit du matériel et de la catégorie.
  ExerciseTracking get suivi {
    final s = suiviExplicite;
    if (s != null) return s;
    final c = categorie.toLowerCase();
    if (c.contains('cardio')) return ExerciseTracking.distanceDuree;
    if (c.contains('etirement') || c.contains('étirement') || c.contains('gainage')) {
      return ExerciseTracking.duree;
    }
    if (equipement.toLowerCase() == 'poids du corps') return ExerciseTracking.repsSeules;
    return ExerciseTracking.poidsReps;
  }

  static final _unCote = RegExp(
    r"unilat|unijambiste|\bun bras\b|\bune jambe\b|single[- ]arm|single[- ]leg|one[- ]arm|one[- ]leg|concentr|kickback|bulgar|split squat|fente statique|pistol|step[- ]?up",
    caseSensitive: false,
  );

  /// Vrai pour un exercice qui se fait un côté après l'autre (rowing à un
  /// bras, squat bulgare, curl concentré...) : ses séries se notent alors
  /// par paires, gauche puis droite. Déduit du nom, faute d'indication dans
  /// le catalogue ; les exercices chronométrés n'en font pas partie.
  bool get unilateral => suivi.usesReps && (_unCoteParId.contains(id) || _unCote.hasMatch(nom) || _unCote.hasMatch(nomEn ?? ''));

  /// Les exercices à un côté que leur nom ne trahit pas.
  static const _unCoteParId = {'elevations-laterales-a-la-poulie'};

  List<Muscle> get tousMuscles => [...musclesPrincipaux, ...musclesSecondaires];

  /// La famille du filtre « Matériel » : la plus précise connue.
  String get famille => materiel ?? equipement;

  String get equipementLabel => Equipements.label(famille);

  String get categorieLabel => Categories.label(categorie);

  /// Intensités 0..1 pour le personnage : principaux pleins, secondaires à moitié.
  Map<Muscle, double> get intensites => {
        for (final m in musclesSecondaires) m: 0.5,
        for (final m in musclesPrincipaux) m: 1.0,
      };

  Exercise copyWith({
    String? nom,
    String? nomEn,
    List<String>? alias,
    List<Muscle>? musclesPrincipaux,
    List<Muscle>? musclesSecondaires,
    String? equipement,
    String? categorie,
    String? mecanique,
    String? niveau,
    List<String>? instructions,
    List<String>? conseils,
    ExerciseMedia? media,
    ExerciseTracking? suivi,
    String? notes,
  }) =>
      Exercise(
        id: id,
        nom: nom ?? this.nom,
        nomEn: nomEn ?? this.nomEn,
        alias: alias ?? this.alias,
        musclesPrincipaux: musclesPrincipaux ?? this.musclesPrincipaux,
        musclesSecondaires: musclesSecondaires ?? this.musclesSecondaires,
        equipement: equipement ?? this.equipement,
        // Un matériel changé à la main efface la famille du catalogue.
        materiel: equipement == null || equipement == this.equipement ? materiel : null,
        categorie: categorie ?? this.categorie,
        mecanique: mecanique ?? this.mecanique,
        niveau: niveau ?? this.niveau,
        instructions: instructions ?? this.instructions,
        conseils: conseils ?? this.conseils,
        media: media ?? this.media,
        source: source,
        perso: perso,
        suiviExplicite: suivi ?? suiviExplicite,
        notes: notes ?? this.notes,
        creeLe: creeLe,
      );

  factory Exercise.fromJson(Json j) => Exercise(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? asString(j['nomEn']) ?? 'Exercice',
        nomEn: asString(j['nomEn']),
        alias: asStringList(j['alias']),
        musclesPrincipaux: Muscle.parseList(j['musclesPrincipaux']),
        musclesSecondaires: Muscle.parseList(j['musclesSecondaires']),
        equipement: asString(j['equipement']) ?? 'autre',
        materiel: asString(j['materiel']),
        categorie: asString(j['categorie']) ?? 'force',
        mecanique: asString(j['mecanique']),
        niveau: asString(j['niveau']),
        instructions: asStringList(j['instructions']),
        conseils: asStringList(j['conseils']),
        media: ExerciseMedia.fromJson(asJson(j['media'])),
        source: asString(j['source']),
        perso: asBool(j['perso']),
        suiviExplicite: j['suivi'] == null ? null : enumByName(ExerciseTracking.values, j['suivi'], ExerciseTracking.poidsReps),
        notes: asString(j['notes']),
        creeLe: asDate(j['creeLe']),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'nomEn': nomEn,
        'alias': alias,
        'musclesPrincipaux': musclesPrincipaux.map((m) => m.name).toList(),
        'musclesSecondaires': musclesSecondaires.map((m) => m.name).toList(),
        'equipement': equipement,
        'materiel': materiel,
        'categorie': categorie,
        'mecanique': mecanique,
        'niveau': niveau,
        'instructions': instructions,
        'conseils': conseils,
        'media': media.isEmpty ? null : media.toJson(),
        'source': source,
        'perso': perso ? true : null,
        'suivi': suiviExplicite?.name,
        'notes': notes,
        'creeLe': dateOut(creeLe),
      });
}
