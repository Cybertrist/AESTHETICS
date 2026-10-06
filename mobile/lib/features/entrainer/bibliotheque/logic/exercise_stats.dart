import 'dart:math' as math;

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';

/// Période des graphiques.
enum StatPeriod {
  mois1('1 mois', 31),
  mois3('3 mois', 92),
  mois6('6 mois', 183),
  an1('1 an', 366),
  tout('Tout', 0);

  const StatPeriod(this.label, this.jours);
  final String label;
  final int jours;

  DateTime? debut(DateTime now) => jours == 0 ? null : now.subtract(Duration(days: jours));
}

/// Courbe proposée dans l'onglet Graphiques.
enum StatMetric {
  unRm('1RM estimé'),
  chargeMax('Charge max'),
  volume('Volume'),
  meilleureSerie('Meilleure série'),
  repsMax('Reps max'),
  repsTotal('Reps totales'),
  dureeMax('Durée max'),
  distance('Distance');

  const StatMetric(this.label);
  final String label;

  bool get estPoids => this == unRm || this == chargeMax || this == volume || this == meilleureSerie;

  /// Courbes pertinentes selon la façon de noter l'exercice.
  static List<StatMetric> pour(ExerciseTracking t) => switch (t) {
        ExerciseTracking.poidsReps || ExerciseTracking.poidsDuCorpsLeste => [unRm, chargeMax, volume, meilleureSerie, repsMax],
        ExerciseTracking.poidsDuCorpsAssiste => [repsMax, repsTotal, chargeMax],
        ExerciseTracking.repsSeules => [repsMax, repsTotal],
        ExerciseTracking.duree => [dureeMax],
        ExerciseTracking.poidsDuree => [chargeMax, dureeMax],
        ExerciseTracking.distanceDuree => [distance, dureeMax],
      };
}

/// Une séance vue depuis un exercice.
class SessionPoint {
  SessionPoint({required this.session, required this.exercise}) {
    for (final s in exercise.series) {
      if (!s.fait || !s.type.counts) continue;
      final p = s.poids ?? 0;
      final r = s.reps ?? 0;
      unRm = math.max(unRm, Strength.setOneRm(s));
      chargeMax = math.max(chargeMax, p);
      volume += p * r;
      repsTotal += r;
      repsMax = math.max(repsMax, r);
      dureeMax = math.max(dureeMax, s.dureeSec ?? 0);
      distance += s.distanceM ?? 0;
      if (p * r > meilleureSerieVolume || (p * r == meilleureSerieVolume && p > (meilleureSerie?.poids ?? 0))) {
        meilleureSerieVolume = p * r;
        meilleureSerie = s;
      }
    }
  }

  final WorkoutSession session;
  final SessionExercise exercise;
  double unRm = 0;
  double chargeMax = 0;
  double volume = 0;
  int repsTotal = 0;
  int repsMax = 0;
  int dureeMax = 0;
  double distance = 0;
  double meilleureSerieVolume = 0;
  WorkoutSet? meilleureSerie;

  DateTime get date => session.debut;

  List<WorkoutSet> get seriesFaites => exercise.series.where((s) => s.fait).toList();

  double valeur(StatMetric m) => switch (m) {
        StatMetric.unRm => unRm,
        StatMetric.chargeMax => chargeMax,
        StatMetric.volume => volume,
        StatMetric.meilleureSerie => meilleureSerieVolume,
        StatMetric.repsMax => repsMax.toDouble(),
        StatMetric.repsTotal => repsTotal.toDouble(),
        StatMetric.dureeMax => dureeMax.toDouble(),
        StatMetric.distance => distance,
      };
}

/// Un record avec sa date et la série qui l'a établi.
class RecordLine {
  const RecordLine({required this.titre, required this.valeur, required this.date, this.detail, this.sessionId, this.explication});

  final String titre;
  final double valeur;
  final DateTime date;

  /// « 100 kg × 5 », « 3 séries »...
  final String? detail;
  final String? sessionId;
  final String? explication;
}

/// Statistiques d'un exercice à partir de l'historique.
class ExerciseStats {
  ExerciseStats(List<ExerciseHistoryEntry> history)
      : points = [for (final h in history) SessionPoint(session: h.session, exercise: h.exercise)]
          ..sort((a, b) => a.date.compareTo(b.date));

  /// Du plus ancien au plus récent.
  final List<SessionPoint> points;

  bool get vide => points.isEmpty;

  List<SessionPoint> dans(StatPeriod p, {DateTime? now}) {
    final d = p.debut(now ?? DateTime.now());
    return d == null ? points : points.where((x) => !x.date.isBefore(d)).toList();
  }

  /// Plus lourde charge soulevée pour au moins [n] répétitions (vrai nRM).
  RecordLine? nRm(int n) {
    RecordLine? best;
    for (final p in points) {
      for (final s in p.seriesFaites) {
        if (!s.type.counts) continue;
        final w = s.poids ?? 0;
        if (w <= 0 || (s.reps ?? 0) < n) continue;
        if (best == null || w > best.valeur) {
          best = RecordLine(titre: '${n}RM', valeur: w, date: p.date, detail: '${s.reps} reps', sessionId: p.session.id);
        }
      }
    }
    return best;
  }

  RecordLine? _max(String titre, double Function(SessionPoint) f, {String? Function(SessionPoint)? detail, String? explication}) {
    SessionPoint? best;
    for (final p in points) {
      final v = f(p);
      if (v > 0 && (best == null || v > f(best))) best = p;
    }
    if (best == null) return null;
    return RecordLine(titre: titre, valeur: f(best), date: best.date, detail: detail?.call(best), sessionId: best.session.id, explication: explication);
  }

  RecordLine? get unRmEstime => _max('1RM estimé', (p) => p.unRm,
      detail: (p) {
        final s = p.exercise.series.where((s) => s.fait && s.type.counts).fold<WorkoutSet?>(
            null, (a, s) => a == null || Strength.setOneRm(s) > Strength.setOneRm(a) ? s : a);
        return s == null ? null : '${Fmt.n(s.poids ?? 0)} × ${s.reps}';
      },
      explication: 'Estimé à partir de ta meilleure série (formules d\'Epley et de Brzycki).');

  RecordLine? get chargeMax => _max('Charge max', (p) => p.chargeMax);
  RecordLine? get volumeSeance => _max('Volume en une séance', (p) => p.volume,
      detail: (p) => Fmt.pluriel(compterSeries(p.exercise.series.where((s) => s.fait).map((s) => s.type)), 'série'));
  RecordLine? get meilleureSerie => _max('Meilleure série', (p) => p.meilleureSerieVolume,
      detail: (p) => p.meilleureSerie == null ? null : '${Fmt.n(p.meilleureSerie!.poids ?? 0)} × ${p.meilleureSerie!.reps}');
  RecordLine? get repsMax => _max('Reps max en une série', (p) => p.repsMax.toDouble());
  RecordLine? get repsSeance => _max('Reps en une séance', (p) => p.repsTotal.toDouble());
  RecordLine? get dureeMax => _max('Durée max', (p) => p.dureeMax.toDouble());
  RecordLine? get distanceMax => _max('Distance en une séance', (p) => p.distance);

  int get nbSeances => points.length;
  int get nbSeries => points.fold(0, (a, p) => a + compterSeries(p.seriesFaites.map((s) => s.type)));
  double get volumeTotal => points.fold(0.0, (a, p) => a + p.volume);
  DateTime? get derniere => points.isEmpty ? null : points.last.date;
  DateTime? get premiere => points.isEmpty ? null : points.first.date;
}
