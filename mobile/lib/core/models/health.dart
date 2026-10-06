import 'json.dart';

/// Nuit de sommeil.
class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.coucher,
    required this.lever,
    this.qualite,
    this.profondMin,
    this.legerMin,
    this.paradoxalMin,
    this.eveilMin,
    this.notes,
    this.source,
  });

  final String id;
  final DateTime coucher;
  final DateTime lever;

  /// Qualité ressentie de 1 à 5.
  final int? qualite;
  final int? profondMin;
  final int? legerMin;
  final int? paradoxalMin;
  final int? eveilMin;
  final String? notes;

  /// « manuel », « health connect », « demo ».
  final String? source;

  Duration get duree => lever.difference(coucher);

  /// Jour auquel la nuit est rattachée : celui du réveil.
  DateTime get jour => DateTime(lever.year, lever.month, lever.day);

  bool get aDesPhases => profondMin != null || legerMin != null || paradoxalMin != null;

  SleepEntry copyWith({DateTime? coucher, DateTime? lever, int? qualite, int? profondMin, int? legerMin, int? paradoxalMin, int? eveilMin, String? notes}) =>
      SleepEntry(
        id: id,
        coucher: coucher ?? this.coucher,
        lever: lever ?? this.lever,
        qualite: qualite ?? this.qualite,
        profondMin: profondMin ?? this.profondMin,
        legerMin: legerMin ?? this.legerMin,
        paradoxalMin: paradoxalMin ?? this.paradoxalMin,
        eveilMin: eveilMin ?? this.eveilMin,
        notes: notes ?? this.notes,
        source: source,
      );

  factory SleepEntry.fromJson(Json j) => SleepEntry(
        id: asString(j['id']) ?? '',
        coucher: asDate(j['coucher']) ?? DateTime.now(),
        lever: asDate(j['lever']) ?? DateTime.now(),
        qualite: asInt(j['qualite']),
        profondMin: asInt(j['profondMin']),
        legerMin: asInt(j['legerMin']),
        paradoxalMin: asInt(j['paradoxalMin']),
        eveilMin: asInt(j['eveilMin']),
        notes: asString(j['notes']),
        source: asString(j['source']),
      );

  Json toJson() => compact({
        'id': id,
        'coucher': dateOut(coucher),
        'lever': dateOut(lever),
        'qualite': qualite,
        'profondMin': profondMin,
        'legerMin': legerMin,
        'paradoxalMin': paradoxalMin,
        'eveilMin': eveilMin,
        'notes': notes,
        'source': source,
      });
}

/// Tours mesurés au mètre ruban, en cm.
enum TourCorps {
  cou('Cou'),
  epaules('Épaules'),
  poitrine('Poitrine'),
  taille('Taille'),
  hanches('Hanches'),
  brasGauche('Bras gauche'),
  brasDroit('Bras droit'),
  avantBrasGauche('Avant-bras gauche'),
  avantBrasDroit('Avant-bras droit'),
  cuisseGauche('Cuisse gauche'),
  cuisseDroite('Cuisse droite'),
  molletGauche('Mollet gauche'),
  molletDroit('Mollet droit');

  const TourCorps(this.label);
  final String label;
}

/// Mesure corporelle d'un jour : poids, masse grasse, tours.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.date,
    this.poidsKg,
    this.masseGrassePct,
    this.masseMusculaireKg,
    this.tours = const {},
    this.source,
  });

  final String id;
  final DateTime date;
  final double? poidsKg;
  final double? masseGrassePct;
  final double? masseMusculaireKg;
  final Map<TourCorps, double> tours;
  final String? source;

  BodyMeasurement copyWith({DateTime? date, double? poidsKg, double? masseGrassePct, double? masseMusculaireKg, Map<TourCorps, double>? tours}) =>
      BodyMeasurement(
        id: id,
        date: date ?? this.date,
        poidsKg: poidsKg ?? this.poidsKg,
        masseGrassePct: masseGrassePct ?? this.masseGrassePct,
        masseMusculaireKg: masseMusculaireKg ?? this.masseMusculaireKg,
        tours: tours ?? this.tours,
        source: source,
      );

  factory BodyMeasurement.fromJson(Json j) {
    final t = asJson(j['tours']) ?? const {};
    return BodyMeasurement(
      id: asString(j['id']) ?? '',
      date: asDate(j['date']) ?? DateTime.now(),
      poidsKg: asDouble(j['poidsKg']),
      masseGrassePct: asDouble(j['masseGrassePct']),
      masseMusculaireKg: asDouble(j['masseMusculaireKg']),
      tours: {
        for (final e in t.entries)
          if (asDouble(e.value) != null) enumByName(TourCorps.values, e.key, TourCorps.taille): asDouble(e.value)!,
      },
      source: asString(j['source']),
    );
  }

  Json toJson() => compact({
        'id': id,
        'date': dateOut(date),
        'poidsKg': poidsKg,
        'masseGrassePct': masseGrassePct,
        'masseMusculaireKg': masseMusculaireKg,
        'tours': tours.isEmpty ? null : {for (final e in tours.entries) e.key.name: e.value},
        'source': source,
      });
}

enum PhotoVue {
  face('Face'),
  profil('Profil'),
  dos('Dos');

  const PhotoVue(this.label);
  final String label;
}

/// Photo de progression, gardée dans le dossier privé de l'appli.
class ProgressPhoto {
  const ProgressPhoto({required this.id, required this.date, required this.chemin, this.vue = PhotoVue.face, this.poidsKg, this.note});

  final String id;
  final DateTime date;
  final String chemin;
  final PhotoVue vue;
  final double? poidsKg;
  final String? note;

  factory ProgressPhoto.fromJson(Json j) => ProgressPhoto(
        id: asString(j['id']) ?? '',
        date: asDate(j['date']) ?? DateTime.now(),
        chemin: asString(j['chemin']) ?? '',
        vue: enumByName(PhotoVue.values, j['vue'], PhotoVue.face),
        poidsKg: asDouble(j['poidsKg']),
        note: asString(j['note']),
      );

  Json toJson() => compact({
        'id': id,
        'date': dateOut(date),
        'chemin': chemin,
        'vue': vue.name,
        'poidsKg': poidsKg,
        'note': note,
      });
}

/// Complément alimentaire suivi (créatine, whey, vitamine D…).
class Supplement {
  const Supplement({
    required this.id,
    required this.nom,
    this.dose = 1,
    this.unite = 'g',
    this.heures = const [],
    this.actif = true,
    this.notes,
  });

  final String id;
  final String nom;
  final double dose;
  final String unite;

  /// Heures de prise conseillées, au format « 08:00 ».
  final List<String> heures;
  final bool actif;
  final String? notes;

  Supplement copyWith({String? nom, double? dose, String? unite, List<String>? heures, bool? actif, String? notes}) => Supplement(
        id: id,
        nom: nom ?? this.nom,
        dose: dose ?? this.dose,
        unite: unite ?? this.unite,
        heures: heures ?? this.heures,
        actif: actif ?? this.actif,
        notes: notes ?? this.notes,
      );

  factory Supplement.fromJson(Json j) => Supplement(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Complément',
        dose: asDouble(j['dose']) ?? 1,
        unite: asString(j['unite']) ?? 'g',
        heures: asStringList(j['heures']),
        actif: asBool(j['actif'], true),
        notes: asString(j['notes']),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'dose': dose,
        'unite': unite,
        'heures': heures,
        'actif': actif,
        'notes': notes,
      });
}

/// Prise d'un complément.
class SupplementIntake {
  const SupplementIntake({required this.id, required this.supplementId, required this.date, this.dose});

  final String id;
  final String supplementId;
  final DateTime date;
  final double? dose;

  factory SupplementIntake.fromJson(Json j) => SupplementIntake(
        id: asString(j['id']) ?? '',
        supplementId: asString(j['supplementId']) ?? '',
        date: asDate(j['date']) ?? DateTime.now(),
        dose: asDouble(j['dose']),
      );

  Json toJson() => compact({'id': id, 'supplementId': supplementId, 'date': dateOut(date), 'dose': dose});
}
