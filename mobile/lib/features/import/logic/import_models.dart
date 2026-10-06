// Modèle intermédiaire de l'import : ce que le fichier contient, avant
// conversion vers les modèles de l'appli. Dart pur, sans Flutter.

/// Formats reconnus. Les libellés restent neutres : l'interface ne nomme
/// jamais l'application d'origine.
enum ImportFormat {
  /// Export principal : ` Title,Date,Duration,Exercise,"Superset id",...`.
  legacy('Historique d\'application (format A)'),

  /// Export à colonne « Set Order » et « Workout Name ».
  ordreSeries('Historique d\'application (format B)'),

  /// Export en snake_case : `title,start_time,...,exercise_title,...`.
  snakeCase('Historique d\'application (format C)'),

  /// Tableau quelconque, colonnes associées automatiquement ou à la main.
  generique('Tableau CSV');

  const ImportFormat(this.libelle);
  final String libelle;
}

/// Nature d'une série.
enum SetKind {
  normale('Normale'),
  echauffement('Échauffement'),
  degressive('Dégressive'),
  echec('Jusqu\'à l\'échec'),
  negative('Négatives'),
  retour('Série de retour'),
  lourde('Série lourde'),
  partielle('Partielles'),
  unilaterale('Unilatérale'),
  gauche('Côté gauche'),
  droite('Côté droit'),
  myoReps('Myo-reps'),
  feeder('Montée en charge');

  const SetKind(this.libelle);
  final String libelle;

  /// Une série d'échauffement ne compte ni dans le volume ni dans les records.
  bool get compte => this != SetKind.echauffement;

  static SetKind? byName(String? n) {
    for (final k in values) {
      if (k.name == n) return k;
    }
    return null;
  }
}

class ImportedSet {
  ImportedSet({
    required this.index,
    this.type = SetKind.normale,
    this.poidsKg,
    this.reps,
    this.dureeSec,
    this.distanceM,
    this.rpe,
    this.rir,
    this.notes,
    this.ligne,
  });

  /// Rang dans l'exercice, à partir de 1.
  int index;
  final SetKind type;

  /// Charge en kilogrammes. 0 ou null : poids du corps.
  final double? poidsKg;
  final int? reps;
  final int? dureeSec;
  final double? distanceM;
  final double? rpe;
  final double? rir;
  final String? notes;

  /// Ligne du fichier (1 = en-tête), utile pour les messages.
  final int? ligne;

  /// Volume de la série (charge x répétitions), 0 si l'une manque.
  double get volume => (poidsKg ?? 0) * (reps ?? 0);

  /// Série sans aucune donnée exploitable.
  bool get vide =>
      (poidsKg == null || poidsKg == 0) &&
      (reps == null || reps == 0) &&
      (dureeSec == null || dureeSec == 0) &&
      (distanceM == null || distanceM == 0);

  Map<String, dynamic> toJson() => {
        'index': index,
        'type': type.name,
        if (poidsKg != null) 'poidsKg': poidsKg,
        if (reps != null) 'reps': reps,
        if (dureeSec != null) 'dureeSec': dureeSec,
        if (distanceM != null) 'distanceM': distanceM,
        if (rpe != null) 'rpe': rpe,
        if (rir != null) 'rir': rir,
        if (notes != null) 'notes': notes,
      };

  factory ImportedSet.fromJson(Map<String, dynamic> j) => ImportedSet(
        index: (j['index'] as num?)?.toInt() ?? 1,
        type: SetKind.byName(j['type'] as String?) ?? SetKind.normale,
        poidsKg: (j['poidsKg'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
        dureeSec: (j['dureeSec'] as num?)?.toInt(),
        distanceM: (j['distanceM'] as num?)?.toDouble(),
        rpe: (j['rpe'] as num?)?.toDouble(),
        rir: (j['rir'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );
}

class ImportedExercise {
  ImportedExercise({
    required this.nomSource,
    this.supersetGroupe,
    this.notes,
    List<ImportedSet>? series,
  }) : series = series ?? [];

  /// Nom tel qu'écrit dans le fichier.
  final String nomSource;

  /// Identifiant de superset du fichier (les exercices qui partagent la même
  /// valeur dans une séance sont enchaînés).
  final String? supersetGroupe;
  String? notes;
  final List<ImportedSet> series;

  /// Rempli par le rapprochement : identifiant du catalogue, ou null.
  String? exerciceId;

  Map<String, dynamic> toJson() => {
        'nomSource': nomSource,
        if (exerciceId != null) 'exerciceId': exerciceId,
        if (supersetGroupe != null) 'supersetGroupe': supersetGroupe,
        if (notes != null) 'notes': notes,
        'series': [for (final s in series) s.toJson()],
      };

  factory ImportedExercise.fromJson(Map<String, dynamic> j) =>
      ImportedExercise(
        nomSource: j['nomSource'] as String? ?? '',
        supersetGroupe: j['supersetGroupe'] as String?,
        notes: j['notes'] as String?,
        series: [
          for (final s in (j['series'] as List? ?? const []))
            ImportedSet.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      )..exerciceId = j['exerciceId'] as String?;
}

class ImportedSession {
  ImportedSession({
    required this.titre,
    required this.debut,
    this.duree,
    this.notes,
    List<ImportedExercise>? exercices,
  }) : exercices = exercices ?? [];

  final String titre;

  /// Heure locale de début, telle qu'écrite dans le fichier.
  final DateTime debut;
  Duration? duree;
  String? notes;
  final List<ImportedExercise> exercices;

  /// Vrai si une séance existe déjà à cette heure dans l'appli.
  bool doublon = false;

  DateTime get fin => debut.add(dureeRetenue);

  /// Au-delà, le chronomètre a été oublié.
  static const dureeMax = Duration(hours: 6);

  /// Durée du fichier qui ne peut pas être vraie : plus de six heures, plus
  /// courte, nettement, que le temps des séries chronométrées, ou moins de
  /// cinq minutes pour trois séries et plus.
  bool get dureeInvraisemblable {
    final d = duree;
    if (d == null) return false;
    if (d > dureeMax) return true;
    final chrono = exercices.fold(
        0, (n, e) => n + e.series.fold(0, (m, s) => m + ((s.dureeSec ?? 0) > 0 ? s.dureeSec! : 0)));
    if (d.inSeconds < chrono * 0.8) return true;
    return d < const Duration(minutes: 5) && nombreSeries >= 3;
  }

  /// Durée estimée quand le fichier n'en donne pas de crédible : le temps
  /// des séries chronométrées, plus trois minutes par autre série.
  Duration get dureeEstimee {
    var sec = 0;
    for (final e in exercices) {
      for (final s in e.series) {
        sec += (s.dureeSec ?? 0) > 0 ? s.dureeSec! : 180;
      }
    }
    return Duration(seconds: sec.clamp(600, 4 * 3600));
  }

  /// Durée du fichier, sinon durée estimée.
  Duration get dureeRetenue => duree ?? dureeEstimee;

  int get nombreSeries =>
      exercices.fold(0, (n, e) => n + e.series.length);

  Map<String, dynamic> toJson() => {
        'titre': titre,
        'debut': debut.toIso8601String(),
        if (duree != null) 'dureeSec': duree!.inSeconds,
        if (notes != null) 'notes': notes,
        if (doublon) 'doublon': true,
        'exercices': [for (final e in exercices) e.toJson()],
      };

  factory ImportedSession.fromJson(Map<String, dynamic> j) => ImportedSession(
        titre: j['titre'] as String? ?? 'Séance',
        debut: DateTime.parse(j['debut'] as String),
        duree: j['dureeSec'] == null
            ? null
            : Duration(seconds: (j['dureeSec'] as num).toInt()),
        notes: j['notes'] as String?,
        exercices: [
          for (final e in (j['exercices'] as List? ?? const []))
            ImportedExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      )..doublon = j['doublon'] == true;
}

/// Gravité d'un message de lecture.
enum Gravite { info, avertissement, erreur }

class ImportMessage {
  const ImportMessage(this.texte, {this.ligne, this.gravite = Gravite.avertissement});
  final String texte;
  final int? ligne;
  final Gravite gravite;

  @override
  String toString() => ligne == null ? texte : 'Ligne $ligne : $texte';
}

/// Résultat brut d'un parseur.
class ParseResult {
  ParseResult({
    required this.format,
    required this.seances,
    required this.lignesLues,
    List<ImportMessage>? messages,
  }) : messages = messages ?? [];

  final ImportFormat format;
  final List<ImportedSession> seances;
  final int lignesLues;
  final List<ImportMessage> messages;

  bool get aDesErreurs => messages.any((m) => m.gravite == Gravite.erreur);
}

/// Unité des charges quand le fichier ne la précise pas.
enum UniteCharge { kg, lb }

class ImportOptions {
  const ImportOptions({
    this.uniteParDefaut = UniteCharge.kg,
    this.ignorerSeriesVides = true,
  });

  final UniteCharge uniteParDefaut;

  /// Écarte les séries sans charge, répétitions, durée ni distance.
  final bool ignorerSeriesVides;
}
