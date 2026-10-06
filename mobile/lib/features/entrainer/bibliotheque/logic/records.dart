import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import 'exercise_stats.dart';
import 'formats.dart';

/// Records affichés sur la fiche d'un exercice.
enum TypeRecord {
  unRm('1RM estimé'),
  poidsMax('Poids maximal'),
  repsMax('Max. rép'),
  volumeSeance('Volume de séance maximal'),
  volumeSerie('Volume maximal en une série'),
  dureeMax('Durée maximale'),
  distanceMax('Distance maximale');

  const TypeRecord(this.label);
  final String label;

  /// Records qui ont un sens selon la façon de noter l'exercice.
  static List<TypeRecord> pour(ExerciseTracking t) => switch (t) {
        ExerciseTracking.poidsReps || ExerciseTracking.poidsDuCorpsLeste => [unRm, poidsMax, repsMax, volumeSeance, volumeSerie],
        ExerciseTracking.poidsDuCorpsAssiste || ExerciseTracking.repsSeules => [repsMax],
        ExerciseTracking.duree => [dureeMax],
        ExerciseTracking.poidsDuree => [poidsMax, dureeMax],
        ExerciseTracking.distanceDuree => [distanceMax, dureeMax],
      };
}

/// Un record : sa valeur, sa date et la série qui l'a établi.
class RecordFiche {
  const RecordFiche({required this.type, required this.valeur, required this.date, required this.sessionId, this.serie, this.nbSeries});

  final TypeRecord type;
  final double valeur;
  final DateTime date;
  final String sessionId;

  /// La série du record (absente pour un record de séance).
  final WorkoutSet? serie;

  /// Nombre de séries de la séance (records de séance).
  final int? nbSeries;

  /// « 17 kg », « 15 », « 554 kg »... : c'est ce texte qui dit si deux records sont égaux.
  String valeurTexte(UnitePoids u) => switch (type) {
        // Arrondi dans l'unité affichée (en livres, arrondir les kg d'abord donne des décimales).
        TypeRecord.unRm => '${Fmt.n(Fmt.poidsAffiche(valeur, u), decimals: 0)} ${u.label}',
        TypeRecord.poidsMax => ExFmt.kg(valeur, u),
        TypeRecord.repsMax => '${valeur.round()}',
        TypeRecord.volumeSeance || TypeRecord.volumeSerie => ExFmt.volumeColle(valeur, u),
        TypeRecord.dureeMax => ExFmt.secondes(valeur),
        TypeRecord.distanceMax => ExFmt.distance(valeur),
      };

  /// Valeur telle qu'elle se compare : arrondie comme elle s'affiche. Deux
  /// records qui s'écrivent pareil (« 85 kg ») sont égaux, et un record égal
  /// n'est pas un nouveau record.
  double get valeurComparee => switch (type) {
        TypeRecord.poidsMax => (valeur * 10).roundToDouble() / 10,
        TypeRecord.distanceMax => valeur,
        _ => valeur.roundToDouble(),
      };

  /// « 12 kg × 12 » ou « 4 séries ».
  String detail(ExerciseTracking t, UnitePoids u) {
    final s = serie;
    if (s != null) return ExFmt.serieFiche(s, t, u);
    final n = nbSeries;
    return n == null ? '' : Fmt.pluriel(n, 'série');
  }
}

Iterable<WorkoutSet> _valides(SessionPoint p) => p.exercise.series.where((s) => s.fait && s.type.counts);

/// Meilleure valeur d'une séance pour un type de record, avec sa série.
RecordFiche? _dansSeance(SessionPoint p, TypeRecord type) {
  double valeur = 0;
  WorkoutSet? serie;
  void garder(double v, WorkoutSet s, {double departage = 0, double departageActuel = 0}) {
    if (v > valeur || (v == valeur && v > 0 && departage > departageActuel)) {
      valeur = v;
      serie = s;
    }
  }

  switch (type) {
    case TypeRecord.unRm:
      for (final s in _valides(p)) {
        garder(Strength.setOneRm(s), s);
      }
    case TypeRecord.poidsMax:
      for (final s in _valides(p)) {
        garder(s.poids ?? 0, s, departage: (s.reps ?? 0).toDouble(), departageActuel: (serie?.reps ?? 0).toDouble());
      }
    case TypeRecord.repsMax:
      for (final s in _valides(p)) {
        garder((s.reps ?? 0).toDouble(), s, departage: s.poids ?? 0, departageActuel: serie?.poids ?? 0);
      }
    case TypeRecord.volumeSerie:
      for (final s in _valides(p)) {
        garder((s.poids ?? 0) * (s.reps ?? 0), s, departage: s.poids ?? 0, departageActuel: serie?.poids ?? 0);
      }
    case TypeRecord.dureeMax:
      for (final s in _valides(p)) {
        garder((s.dureeSec ?? 0).toDouble(), s);
      }
    case TypeRecord.volumeSeance:
      if (p.volume <= 0) return null;
      return RecordFiche(type: type, valeur: p.volume, date: p.date, sessionId: p.session.id, nbSeries: _valides(p).length);
    case TypeRecord.distanceMax:
      if (p.distance <= 0) return null;
      return RecordFiche(type: type, valeur: p.distance, date: p.date, sessionId: p.session.id, nbSeries: _valides(p).length);
  }
  if (valeur <= 0) return null;
  return RecordFiche(type: type, valeur: valeur, date: p.date, sessionId: p.session.id, serie: serie);
}

/// Toutes les fois où un record a été battu, de la plus ancienne à la plus
/// récente : la dernière ligne est le record en cours.
List<RecordFiche> progressionRecord(ExerciseStats stats, TypeRecord type) {
  final out = <RecordFiche>[];
  for (final p in stats.points) {
    final r = _dansSeance(p, type);
    // Battre un record, c'est faire mieux à l'affichage : 85,2 après 84,9
    // s'écrivent tous deux « 85 kg » et ne font pas un nouveau record.
    if (r != null && (out.isEmpty || r.valeurComparee > out.last.valeurComparee)) out.add(r);
  }
  return out;
}

/// Ce que vaut la meilleure série d'une séance face aux records.
enum RangRecord {
  /// Une bonne série, mais pas un record : aucune médaille.
  aucun,

  /// Un record à l'époque, battu depuis : médaille grise.
  ancien,

  /// Le record en cours : médaille dorée.
  enCours,
}

/// Les records en cours d'un exercice, dans l'ordre de la fiche.
List<RecordFiche> recordsDe(ExerciseStats stats, ExerciseTracking suivi) => [
      for (final t in TypeRecord.pour(suivi)) ?progressionRecord(stats, t).lastOrNull,
    ];

/// Série mise en avant dans l'historique d'une séance, et ce qui la distingue.
({WorkoutSet serie, String label})? meilleureDeSeance(SessionPoint p, ExerciseTracking suivi) {
  final (type, label) = switch (suivi) {
    ExerciseTracking.poidsReps || ExerciseTracking.poidsDuCorpsLeste || ExerciseTracking.poidsDuree => (TypeRecord.poidsMax, 'Poids'),
    ExerciseTracking.poidsDuCorpsAssiste || ExerciseTracking.repsSeules => (TypeRecord.repsMax, 'Réps'),
    ExerciseTracking.duree || ExerciseTracking.distanceDuree => (TypeRecord.dureeMax, 'Durée'),
  };
  var r = _dansSeance(p, type);
  var texte = label;
  // Un exercice lesté fait sans charge : on retombe sur les répétitions.
  if (r == null && type == TypeRecord.poidsMax) {
    r = _dansSeance(p, TypeRecord.repsMax);
    texte = 'Réps';
  }
  final s = r?.serie;
  return s == null ? null : (serie: s, label: texte);
}

/// Vrai si la meilleure série de cette séance tient encore le record.
bool tientLeRecord(ExerciseStats stats, SessionPoint p, ExerciseTracking suivi) {
  final type = switch (suivi) {
    ExerciseTracking.poidsReps || ExerciseTracking.poidsDuCorpsLeste || ExerciseTracking.poidsDuree => TypeRecord.poidsMax,
    ExerciseTracking.poidsDuCorpsAssiste || ExerciseTracking.repsSeules => TypeRecord.repsMax,
    ExerciseTracking.duree || ExerciseTracking.distanceDuree => TypeRecord.dureeMax,
  };
  // Le record comparé est celui que la séance met en avant : une séance au
  // poids du corps, sans lest, se juge sur ses répétitions.
  final vu = _dansSeance(p, type) != null ? type : TypeRecord.repsMax;
  return rangRecord(stats, p, suivi, type: vu) == RangRecord.enCours;
}

/// Rang de la meilleure série de la séance : une séance ne porte une
/// médaille que si elle a battu le record ce jour-là.
RangRecord rangRecord(ExerciseStats stats, SessionPoint p, ExerciseTracking suivi, {TypeRecord? type}) {
  final t = type ??
      switch (suivi) {
        ExerciseTracking.poidsReps || ExerciseTracking.poidsDuCorpsLeste || ExerciseTracking.poidsDuree => TypeRecord.poidsMax,
        ExerciseTracking.poidsDuCorpsAssiste || ExerciseTracking.repsSeules => TypeRecord.repsMax,
        ExerciseTracking.duree || ExerciseTracking.distanceDuree => TypeRecord.dureeMax,
      };
  final vu = type ?? (_dansSeance(p, t) != null ? t : TypeRecord.repsMax);
  final progression = progressionRecord(stats, vu);
  final i = progression.indexWhere((r) => r.sessionId == p.session.id);
  if (i < 0) return RangRecord.aucun;
  return i == progression.length - 1 ? RangRecord.enCours : RangRecord.ancien;
}
