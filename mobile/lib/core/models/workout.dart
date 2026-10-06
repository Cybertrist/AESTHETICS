import 'dart:ui' show Color;

import 'json.dart';

/// Type de série : les douze types du panneau « Type de série ».
///
/// Les quatre premiers noms sont ceux des fichiers déjà enregistrés : ne pas
/// les renommer. Un nom inconnu est relu comme une série normale.
enum SetType {
  echauffement('Échauffement', 'É', 0xFFFFC857, 'Série légère pour préparer le mouvement. Elle ne compte ni dans le volume ni dans les records.'),
  normale('Normale', '', 0xFFFFFFFF, 'Série de travail classique.'),
  degressive('Dégressive', 'DG', 0xFF1E9BE9, 'Tu baisses la charge sans repos et tu repars aussitôt.'),
  echec('Échec', 'X', 0xFFFF453A, 'Série menée jusqu\'à ne plus pouvoir faire une répétition propre.'),
  gauche('Gauche', 'G', 0xFF4CD137, 'Série faite du côté gauche seulement.'),
  droite('Droite', 'D', 0xFFC77DFF, 'Série faite du côté droit seulement.'),
  negative('Négative', 'N', 0xFFFFA928, 'Seule la descente compte : charge lourde, freinée lentement.'),
  partielles('Partielles', 'P', 0xFF9CCC3C, 'Répétitions sur une partie de l\'amplitude, souvent en fin de série.'),
  myoReps('Myo-reps', 'M', 0xFFFF7043, 'Une série d\'activation, puis des mini séries séparées par quelques respirations.'),
  feeder('Feeder', 'F', 0xFFFFD54F, 'Série de montée en charge, loin de l\'échec, avant la série lourde.'),
  topSet('Top set', 'T', 0xFF7986FF, 'La série la plus lourde du jour, celle qui compte.'),
  backOff('Back-off', 'B', 0xFF3CE0FF, 'Série plus légère après le top set, pour ajouter du volume.');

  const SetType(this.label, this.short, this.argb, this.aide);

  /// Le type à reprendre quand une série faite sert de modèle à la suivante
  /// (un exercice ajouté d'après la dernière fois, une séance refaite, une
  /// routine tirée d'une séance). « Échec » dit comment une série s'est
  /// finie, pas ce qui est prévu : elle redevient une série normale. Une
  /// routine qui prévoit elle-même une série en échec la garde, elle.
  SetType get aReprendre => this == SetType.echec ? SetType.normale : this;
  final String label;

  /// Lettre affichée à la place du numéro de série (vide pour une normale).
  final String short;

  /// Couleur de la lettre (0xAARRGGBB), celle de la maquette.
  final int argb;

  /// Explication courte, montrée par le « ? » du panneau.
  final String aide;

  /// Lettre du panneau « Type de série » : « # » pour une normale.
  String get lettre => short.isEmpty ? '#' : short;

  /// Couleur de la lettre.
  Color get couleur => Color(argb);

  /// Ordre d'affichage du panneau (deux colonnes, ligne par ligne).
  static const List<SetType> ordrePanneau = [
    normale, echauffement, echec, degressive, gauche, droite,
    negative, partielles, myoReps, feeder, topSet, backOff,
  ];

  /// Les échauffements ne comptent ni dans le volume ni dans les records.
  bool get counts => this != echauffement;

  /// Ce que pèse une série de ce type dans un compte de séries : rien pour
  /// un échauffement, une demie pour un côté (une gauche et une droite font
  /// une série), une sinon.
  double get poidsSerie => switch (this) {
        echauffement => 0,
        gauche || droite => 0.5,
        _ => 1,
      };
}

/// Le nombre de séries de travail parmi ces types, en fraction : une paire
/// gauche, droite compte pour une série, un côté seul pour une demie.
double poidsDesSeries(Iterable<SetType> types) => types.fold(0.0, (a, t) => a + t.poidsSerie);

/// Le même compte, pour l'affichage : arrondi à la série entière du dessus
/// (un côté fait sans l'autre compte déjà pour une série).
int compterSeries(Iterable<SetType> types) => poidsDesSeries(types).ceil();

/// Photo ou vidéo jointe à une séance (chemin d'un fichier local).
class SessionMedia {
  const SessionMedia({required this.chemin, this.video = false, this.dureeSec});

  final String chemin;
  final bool video;

  /// Durée d'une vidéo, quand elle est connue.
  final int? dureeSec;

  factory SessionMedia.fromJson(Json j) => SessionMedia(
        chemin: asString(j['chemin']) ?? '',
        video: asBool(j['video']),
        dureeSec: asInt(j['dureeSec']),
      );

  Json toJson() => compact({'chemin': chemin, 'video': video ? true : null, 'dureeSec': dureeSec});

  @override
  bool operator ==(Object other) =>
      other is SessionMedia && other.chemin == chemin && other.video == video && other.dureeSec == dureeSec;

  @override
  int get hashCode => Object.hash(chemin, video, dureeSec);
}

/// Type d'activité d'une séance (panneau « Type d'activité », pastilles
/// de la semaine et du calendrier). L'icône est dans `IconeTypeSeance`.
enum TypeSeance {
  musculation('Musculation'),
  cardio('Cardio'),
  hiit('HIIT'),
  hybride('Hybride'),
  crossTraining('Cross-training'),
  aviron('Aviron');

  const TypeSeance(this.label);
  final String label;
}

/// Série prévue dans une routine.
class PlannedSet {
  const PlannedSet({
    this.type = SetType.normale,
    this.poids,
    this.reps,
    this.repsMax,
    this.dureeSec,
    this.distanceM,
    this.rpe,
  });

  final SetType type;
  final double? poids;

  /// Répétitions visées ; avec [repsMax], une fourchette (8 à 12).
  final int? reps;
  final int? repsMax;
  final int? dureeSec;
  final double? distanceM;
  final double? rpe;

  String get repsLabel {
    if (reps == null) return '';
    if (repsMax != null && repsMax != reps) return '$reps à $repsMax';
    return '$reps';
  }

  PlannedSet copyWith({SetType? type, double? poids, int? reps, int? repsMax, int? dureeSec, double? distanceM, double? rpe}) =>
      PlannedSet(
        type: type ?? this.type,
        poids: poids ?? this.poids,
        reps: reps ?? this.reps,
        repsMax: repsMax ?? this.repsMax,
        dureeSec: dureeSec ?? this.dureeSec,
        distanceM: distanceM ?? this.distanceM,
        rpe: rpe ?? this.rpe,
      );

  factory PlannedSet.fromJson(Json j) => PlannedSet(
        type: enumByName(SetType.values, j['type'], SetType.normale),
        poids: asDouble(j['poids']),
        reps: asInt(j['reps']),
        repsMax: asInt(j['repsMax']),
        dureeSec: asInt(j['dureeSec']),
        distanceM: asDouble(j['distanceM']),
        rpe: asDouble(j['rpe']),
      );

  Json toJson() => compact({
        'type': type.name,
        'poids': poids,
        'reps': reps,
        'repsMax': repsMax,
        'dureeSec': dureeSec,
        'distanceM': distanceM,
        'rpe': rpe,
      });
}

/// Exercice placé dans une routine, avec ses séries prévues.
class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.exerciseId,
    this.series = const [],
    this.reposSec = 90,
    this.supersetId,
    this.notes,
  });

  /// Identifiant de l'emplacement (un même exercice peut revenir deux fois).
  final String id;
  final String exerciseId;
  final List<PlannedSet> series;
  final int reposSec;

  /// Les exercices qui partagent cet identifiant s'enchaînent en superset.
  final String? supersetId;
  final String? notes;

  RoutineExercise copyWith({List<PlannedSet>? series, int? reposSec, String? supersetId, bool clearSuperset = false, String? notes, String? exerciseId}) =>
      RoutineExercise(
        id: id,
        exerciseId: exerciseId ?? this.exerciseId,
        series: series ?? this.series,
        reposSec: reposSec ?? this.reposSec,
        supersetId: clearSuperset ? null : (supersetId ?? this.supersetId),
        notes: notes ?? this.notes,
      );

  factory RoutineExercise.fromJson(Json j) => RoutineExercise(
        id: asString(j['id']) ?? '',
        exerciseId: asString(j['exerciseId']) ?? '',
        series: asList(j['series'], PlannedSet.fromJson),
        reposSec: asInt(j['reposSec']) ?? 90,
        supersetId: asString(j['supersetId']),
        notes: asString(j['notes']),
      );

  Json toJson() => compact({
        'id': id,
        'exerciseId': exerciseId,
        'series': series.map((s) => s.toJson()).toList(),
        'reposSec': reposSec,
        'supersetId': supersetId,
        'notes': notes,
      });
}

/// Routine : modèle de séance que l'on relance.
class Routine {
  const Routine({
    required this.id,
    required this.nom,
    this.folderId,
    this.notes,
    this.exercices = const [],
    required this.creeLe,
    this.modifieLe,
    this.ordre = 0,
  });

  final String id;
  final String nom;
  final String? folderId;
  final String? notes;
  final List<RoutineExercise> exercices;
  final DateTime creeLe;
  final DateTime? modifieLe;
  final int ordre;

  int get nbSeries => exercices.fold(0, (a, e) => a + e.series.length);

  /// Durée estimée en minutes : 45 s d'effort par série plus le repos.
  int get dureeEstimeeMin {
    var sec = 0;
    for (final e in exercices) {
      sec += e.series.length * (45 + e.reposSec);
    }
    return (sec / 60).round();
  }

  Routine copyWith({String? nom, String? folderId, bool clearFolder = false, String? notes, List<RoutineExercise>? exercices, DateTime? modifieLe, int? ordre}) =>
      Routine(
        id: id,
        nom: nom ?? this.nom,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        notes: notes ?? this.notes,
        exercices: exercices ?? this.exercices,
        creeLe: creeLe,
        modifieLe: modifieLe ?? this.modifieLe,
        ordre: ordre ?? this.ordre,
      );

  factory Routine.fromJson(Json j) => Routine(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Routine',
        folderId: asString(j['folderId']),
        notes: asString(j['notes']),
        exercices: asList(j['exercices'], RoutineExercise.fromJson),
        creeLe: asDate(j['creeLe']) ?? DateTime.now(),
        modifieLe: asDate(j['modifieLe']),
        ordre: asInt(j['ordre']) ?? 0,
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'folderId': folderId,
        'notes': notes,
        'exercices': exercices.map((e) => e.toJson()).toList(),
        'creeLe': dateOut(creeLe),
        'modifieLe': dateOut(modifieLe),
        'ordre': ordre,
      });
}

/// Dossier qui range des routines.
class Folder {
  const Folder({required this.id, required this.nom, this.ordre = 0, this.replie = false});

  final String id;
  final String nom;
  final int ordre;

  /// Replié dans la liste des routines.
  final bool replie;

  Folder copyWith({String? nom, int? ordre, bool? replie}) =>
      Folder(id: id, nom: nom ?? this.nom, ordre: ordre ?? this.ordre, replie: replie ?? this.replie);

  factory Folder.fromJson(Json j) => Folder(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Dossier',
        ordre: asInt(j['ordre']) ?? 0,
        replie: asBool(j['replie']),
      );

  Json toJson() => {'id': id, 'nom': nom, 'ordre': ordre, 'replie': replie};
}

/// Programme : un cycle de routines sur plusieurs semaines.
class Program {
  const Program({
    required this.id,
    required this.nom,
    this.description,
    this.dureeSemaines = 8,
    this.joursParSemaine = 3,
    this.routineIds = const [],
    this.actif = false,
    this.debuteLe,
    this.semaineCourante = 0,
    this.prochainIndex = 0,
    this.seancesFaites = 0,
    this.niveau,
    this.objectif,
    required this.creeLe,
  });

  final String id;
  final String nom;
  final String? description;
  final int dureeSemaines;
  final int joursParSemaine;

  /// Routines dans l'ordre du cycle (A, B, C, A, B, C…).
  final List<String> routineIds;
  final bool actif;
  final DateTime? debuteLe;

  /// Position courante : semaine (0 = première) et prochaine routine du cycle.
  final int semaineCourante;
  final int prochainIndex;
  final int seancesFaites;
  final String? niveau;
  final String? objectif;
  final DateTime creeLe;

  String? get prochaineRoutineId =>
      routineIds.isEmpty ? null : routineIds[prochainIndex % routineIds.length];

  int get seancesTotal => dureeSemaines * joursParSemaine;

  double get avancement => seancesTotal == 0 ? 0 : (seancesFaites / seancesTotal).clamp(0, 1);

  bool get termine => seancesFaites >= seancesTotal && seancesTotal > 0;

  Program copyWith({
    String? nom,
    String? description,
    int? dureeSemaines,
    int? joursParSemaine,
    List<String>? routineIds,
    bool? actif,
    DateTime? debuteLe,
    int? semaineCourante,
    int? prochainIndex,
    int? seancesFaites,
    String? niveau,
    String? objectif,
  }) =>
      Program(
        id: id,
        nom: nom ?? this.nom,
        description: description ?? this.description,
        dureeSemaines: dureeSemaines ?? this.dureeSemaines,
        joursParSemaine: joursParSemaine ?? this.joursParSemaine,
        routineIds: routineIds ?? this.routineIds,
        actif: actif ?? this.actif,
        debuteLe: debuteLe ?? this.debuteLe,
        semaineCourante: semaineCourante ?? this.semaineCourante,
        prochainIndex: prochainIndex ?? this.prochainIndex,
        seancesFaites: seancesFaites ?? this.seancesFaites,
        niveau: niveau ?? this.niveau,
        objectif: objectif ?? this.objectif,
        creeLe: creeLe,
      );

  factory Program.fromJson(Json j) => Program(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Programme',
        description: asString(j['description']),
        dureeSemaines: asInt(j['dureeSemaines']) ?? 8,
        joursParSemaine: asInt(j['joursParSemaine']) ?? 3,
        routineIds: asStringList(j['routineIds']),
        actif: asBool(j['actif']),
        debuteLe: asDate(j['debuteLe']),
        semaineCourante: asInt(j['semaineCourante']) ?? 0,
        prochainIndex: asInt(j['prochainIndex']) ?? 0,
        seancesFaites: asInt(j['seancesFaites']) ?? 0,
        niveau: asString(j['niveau']),
        objectif: asString(j['objectif']),
        creeLe: asDate(j['creeLe']) ?? DateTime.now(),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'description': description,
        'dureeSemaines': dureeSemaines,
        'joursParSemaine': joursParSemaine,
        'routineIds': routineIds,
        'actif': actif,
        'debuteLe': dateOut(debuteLe),
        'semaineCourante': semaineCourante,
        'prochainIndex': prochainIndex,
        'seancesFaites': seancesFaites,
        'niveau': niveau,
        'objectif': objectif,
        'creeLe': dateOut(creeLe),
      });
}

/// Série réalisée pendant une séance.
class WorkoutSet {
  const WorkoutSet({
    required this.id,
    this.type = SetType.normale,
    this.poids,
    this.reps,
    this.rpe,
    this.fait = false,
    this.tempsReposSec,
    this.dureeSec,
    this.distanceM,
    this.faitLe,
  });

  final String id;
  final SetType type;
  final double? poids;
  final int? reps;
  final double? rpe;
  final bool fait;

  /// Repos réellement pris après la série.
  final int? tempsReposSec;
  final int? dureeSec;
  final double? distanceM;
  final DateTime? faitLe;

  /// Tonnage de la série (0 si échauffement ou non faite).
  double get volume => fait && type.counts ? (poids ?? 0) * (reps ?? 0) : 0;

  WorkoutSet copyWith({
    SetType? type,
    double? poids,
    bool clearPoids = false,
    int? reps,
    bool clearReps = false,
    double? rpe,
    bool clearRpe = false,
    bool? fait,
    int? tempsReposSec,
    int? dureeSec,
    double? distanceM,
    DateTime? faitLe,
  }) =>
      WorkoutSet(
        id: id,
        type: type ?? this.type,
        poids: clearPoids ? null : (poids ?? this.poids),
        reps: clearReps ? null : (reps ?? this.reps),
        rpe: clearRpe ? null : (rpe ?? this.rpe),
        fait: fait ?? this.fait,
        tempsReposSec: tempsReposSec ?? this.tempsReposSec,
        dureeSec: dureeSec ?? this.dureeSec,
        distanceM: distanceM ?? this.distanceM,
        faitLe: faitLe ?? this.faitLe,
      );

  factory WorkoutSet.fromJson(Json j) => WorkoutSet(
        id: asString(j['id']) ?? '',
        type: enumByName(SetType.values, j['type'], SetType.normale),
        poids: asDouble(j['poids']),
        reps: asInt(j['reps']),
        rpe: asDouble(j['rpe']),
        fait: asBool(j['fait']),
        tempsReposSec: asInt(j['tempsReposSec']),
        dureeSec: asInt(j['dureeSec']),
        distanceM: asDouble(j['distanceM']),
        faitLe: asDate(j['faitLe']),
      );

  Json toJson() => compact({
        'id': id,
        'type': type.name,
        'poids': poids,
        'reps': reps,
        'rpe': rpe,
        'fait': fait,
        'tempsReposSec': tempsReposSec,
        'dureeSec': dureeSec,
        'distanceM': distanceM,
        'faitLe': dateOut(faitLe),
      });
}

/// Exercice fait pendant une séance.
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.exerciseId,
    this.series = const [],
    this.reposSec = 90,
    this.supersetId,
    this.notes,
  });

  final String id;
  final String exerciseId;
  final List<WorkoutSet> series;
  final int reposSec;
  final String? supersetId;
  final String? notes;

  /// Note de l'exercice (« Ajouter une note… ») : alias de [notes].
  String? get note => notes;

  List<WorkoutSet> get seriesFaites => series.where((s) => s.fait).toList();
  double get volume => series.fold(0.0, (a, s) => a + s.volume);

  SessionExercise copyWith({List<WorkoutSet>? series, int? reposSec, String? supersetId, bool clearSuperset = false, String? notes, String? exerciseId}) =>
      SessionExercise(
        id: id,
        exerciseId: exerciseId ?? this.exerciseId,
        series: series ?? this.series,
        reposSec: reposSec ?? this.reposSec,
        supersetId: clearSuperset ? null : (supersetId ?? this.supersetId),
        notes: notes ?? this.notes,
      );

  factory SessionExercise.fromJson(Json j) => SessionExercise(
        id: asString(j['id']) ?? '',
        exerciseId: asString(j['exerciseId']) ?? '',
        series: asList(j['series'], WorkoutSet.fromJson),
        reposSec: asInt(j['reposSec']) ?? 90,
        supersetId: asString(j['supersetId']),
        notes: asString(j['notes']),
      );

  Json toJson() => compact({
        'id': id,
        'exerciseId': exerciseId,
        'series': series.map((s) => s.toJson()).toList(),
        'reposSec': reposSec,
        'supersetId': supersetId,
        'notes': notes,
      });
}

/// Séance réalisée (ou en cours tant que [fin] est nul).
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.nom,
    required this.debut,
    this.fin,
    this.routineId,
    this.programId,
    this.exercices = const [],
    this.notes,
    this.ressenti,
    this.photo,
    this.source,
    this.type = TypeSeance.musculation,
    this.medias = const [],
  });

  final String id;
  final String nom;
  final DateTime debut;
  final DateTime? fin;
  final String? routineId;
  final String? programId;
  final List<SessionExercise> exercices;
  final String? notes;

  /// Ressenti de 1 (dur) à 5 (excellent).
  final int? ressenti;
  final String? photo;

  /// Origine : null pour une séance faite dans l'appli, « import », « demo ».
  final String? source;

  /// Type d'activité, musculation par défaut.
  final TypeSeance type;

  /// Photos et vidéos jointes à la séance.
  final List<SessionMedia> medias;

  bool get enCours => fin == null;

  Duration get duree => (fin ?? DateTime.now()).difference(debut);

  double get volume => exercices.fold(0.0, (a, e) => a + e.volume);

  int get nbSeriesFaites => exercices.fold(0, (a, e) => a + compterSeries(e.seriesFaites.map((s) => s.type)));

  int get nbReps => exercices.fold(
      0, (a, e) => a + e.seriesFaites.where((s) => s.type.counts).fold(0, (b, s) => b + (s.reps ?? 0)));

  WorkoutSession copyWith({
    String? nom,
    DateTime? debut,
    DateTime? fin,
    String? routineId,
    String? programId,
    List<SessionExercise>? exercices,
    String? notes,
    int? ressenti,
    String? photo,
    String? source,
    TypeSeance? type,
    List<SessionMedia>? medias,
  }) =>
      WorkoutSession(
        id: id,
        nom: nom ?? this.nom,
        debut: debut ?? this.debut,
        fin: fin ?? this.fin,
        routineId: routineId ?? this.routineId,
        programId: programId ?? this.programId,
        exercices: exercices ?? this.exercices,
        notes: notes ?? this.notes,
        ressenti: ressenti ?? this.ressenti,
        photo: photo ?? this.photo,
        source: source ?? this.source,
        type: type ?? this.type,
        medias: medias ?? this.medias,
      );

  /// Date de repli d'une séance dont le début est illisible : fixe, pour que
  /// la séance ne change pas de jour à chaque lancement et ne passe jamais
  /// pour une séance d'aujourd'hui.
  static final debutInconnu = DateTime(2000);

  factory WorkoutSession.fromJson(Json j) {
    final exercices = asList(j['exercices'], SessionExercise.fromJson);
    var debut = asDate(j['debut']) ?? asDate(j['fin']);
    if (debut == null) {
      for (final e in exercices) {
        for (final s in e.series) {
          final d = s.faitLe;
          if (d != null && (debut == null || d.isBefore(debut))) debut = d;
        }
      }
    }
    return WorkoutSession(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Séance',
        debut: debut ?? debutInconnu,
        fin: asDate(j['fin']),
        routineId: asString(j['routineId']),
        programId: asString(j['programId']),
        exercices: exercices,
        notes: asString(j['notes']),
        ressenti: asInt(j['ressenti']),
        photo: asString(j['photo']),
        source: asString(j['source']),
        type: enumByName(TypeSeance.values, j['type'], TypeSeance.musculation),
        medias: asList(j['medias'], SessionMedia.fromJson),
      );
  }

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'debut': dateOut(debut),
        'fin': dateOut(fin),
        'routineId': routineId,
        'programId': programId,
        'exercices': exercices.map((e) => e.toJson()).toList(),
        'notes': notes,
        'ressenti': ressenti,
        'photo': photo,
        'source': source,
        'type': type == TypeSeance.musculation ? null : type.name,
        'medias': medias.isEmpty ? null : medias.map((m) => m.toJson()).toList(),
      });
}

enum RecordType {
  poidsMax('Charge maximale'),
  unRmEstime('1RM estimé'),
  volumeSerie('Meilleure série (volume)'),
  repsMax('Répétitions maximales'),
  volumeSeance('Volume en une séance');

  const RecordType(this.label);
  final String label;

  /// La médaille d'un record de ce type : l'or pour une charge jamais
  /// soulevée, l'argent pour un meilleur 1RM estimé, le bronze pour plus de
  /// répétitions à une charge déjà faite.
  MedailleRecord get medaille => switch (this) {
        RecordType.poidsMax => MedailleRecord.or,
        RecordType.unRmEstime => MedailleRecord.argent,
        _ => MedailleRecord.bronze,
      };
}

/// Les trois médailles d'un record personnel, de la plus haute à la plus basse.
enum MedailleRecord {
  or('Or', 0xFFFFBE0B),
  argent('Argent', 0xFFB9C3CE),
  bronze('Bronze', 0xFFCB7F45);

  const MedailleRecord(this.label, this.couleur);
  final String label;

  /// Couleur de l'écusson (ARGB).
  final int couleur;
}

/// Record personnel sur un exercice.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.type,
    required this.valeur,
    required this.date,
    this.sessionId,
    this.poids,
    this.reps,
  });

  final String exerciseId;
  final RecordType type;
  final double valeur;
  final DateTime date;
  final String? sessionId;
  final double? poids;
  final int? reps;

  factory PersonalRecord.fromJson(Json j) => PersonalRecord(
        exerciseId: asString(j['exerciseId']) ?? '',
        type: enumByName(RecordType.values, j['type'], RecordType.poidsMax),
        valeur: asDouble(j['valeur']) ?? 0,
        date: asDate(j['date']) ?? DateTime.now(),
        sessionId: asString(j['sessionId']),
        poids: asDouble(j['poids']),
        reps: asInt(j['reps']),
      );

  Json toJson() => compact({
        'exerciseId': exerciseId,
        'type': type.name,
        'valeur': valeur,
        'date': dateOut(date),
        'sessionId': sessionId,
        'poids': poids,
        'reps': reps,
      });
}
