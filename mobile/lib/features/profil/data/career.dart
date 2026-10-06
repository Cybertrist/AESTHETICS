
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Bilan d'une année d'entraînement.
class BilanAnnee {
  BilanAnnee(this.annee);
  final int annee;
  int seances = 0;
  double volume = 0;
  Duration duree = Duration.zero;
  int series = 0;
}

/// Statistiques de carrière, calculées à partir des séances terminées.
class CareerStats {
  CareerStats._({
    required this.seances,
    required this.volume,
    required this.duree,
    required this.series,
    required this.reps,
    required this.premiere,
    required this.derniere,
    required this.semainesConsecutives,
    required this.parAnnee,
    required this.parMois,
    required this.topExercices,
    required this.jourPrefere,
    required this.plusLongue,
    required this.plusGrosVolume,
    required this.nbRecords,
  });

  final int seances;
  final double volume;
  final Duration duree;
  final int series;
  final int reps;
  final DateTime? premiere;
  final DateTime? derniere;
  final int semainesConsecutives;
  final List<BilanAnnee> parAnnee;

  /// Séances des 12 derniers mois, du plus ancien au plus récent.
  final List<(DateTime, int)> parMois;

  /// Exercices les plus pratiqués : (id, séries faites).
  final List<(String, int)> topExercices;

  /// Jour de la semaine le plus fréquent (1 = lundi), null sans séance.
  final int? jourPrefere;
  final WorkoutSession? plusLongue;
  final WorkoutSession? plusGrosVolume;
  final int nbRecords;

  bool get vide => seances == 0;

  Duration get dureeMoyenne => seances == 0 ? Duration.zero : Duration(seconds: duree.inSeconds ~/ seances);

  /// Séances par semaine depuis la première.
  double get parSemaine {
    final p = premiere;
    if (p == null) return 0;
    final semaines = (DateTime.now().difference(p).inDays / 7).clamp(1, 100000);
    return seances / semaines;
  }

  static CareerStats from(List<WorkoutSession> all, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final sessions = all.where((s) => !s.enCours).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    var volume = 0.0;
    var duree = Duration.zero;
    var series = 0;
    var reps = 0;
    final annees = <int, BilanAnnee>{};
    final exos = <String, int>{};
    final jours = List.filled(8, 0);
    WorkoutSession? longue;
    WorkoutSession? lourde;
    for (final s in sessions) {
      final d = s.duree.inHours > 12 ? Duration.zero : s.duree;
      volume += s.volume;
      duree += d;
      series += s.nbSeriesFaites;
      reps += s.nbReps;
      final b = annees.putIfAbsent(s.debut.year, () => BilanAnnee(s.debut.year));
      b.seances++;
      b.volume += s.volume;
      b.duree += d;
      b.series += s.nbSeriesFaites;
      jours[s.debut.weekday]++;
      for (final e in s.exercices) {
        final nb = e.seriesFaites.where((x) => x.type.counts).length;
        if (nb > 0) exos[e.exerciseId] = (exos[e.exerciseId] ?? 0) + nb;
      }
      if (d > Duration.zero && (longue == null || d > longue.duree)) longue = s;
      if (lourde == null || s.volume > lourde.volume) lourde = s;
    }
    final mois = <(DateTime, int)>[];
    for (var i = 11; i >= 0; i--) {
      final m = DateTime(n.year, n.month - i);
      final count = sessions.where((s) => s.debut.year == m.year && s.debut.month == m.month).length;
      mois.add((m, count));
    }
    final top = exos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    int? jour;
    var max = 0;
    for (var i = 1; i <= 7; i++) {
      if (jours[i] > max) {
        max = jours[i];
        jour = i;
      }
    }
    var records = 0;
    for (final id in exos.keys) {
      final b = Strength.bests(id, sessions);
      if (b.poidsMax != null) records++;
    }
    return CareerStats._(
      seances: sessions.length,
      volume: volume,
      duree: duree,
      series: series,
      reps: reps,
      premiere: sessions.firstOrNull?.debut,
      derniere: sessions.lastOrNull?.debut,
      semainesConsecutives: Dates.semainesConsecutives(sessions.map((s) => s.debut), now: n),
      parAnnee: annees.values.toList()..sort((a, b) => b.annee.compareTo(a.annee)),
      parMois: mois,
      topExercices: [for (final e in top.take(5)) (e.key, e.value)],
      jourPrefere: jour,
      plusLongue: longue,
      plusGrosVolume: (lourde?.volume ?? 0) > 0 ? lourde : null,
      nbRecords: records,
    );
  }

  static const nomsJours = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
}
