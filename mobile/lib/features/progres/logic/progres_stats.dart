import 'dart:math' as math;

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Période du tableau de bord.
enum ProgresPeriode {
  semaines4('4 sem.', 'les 4 dernières semaines'),
  mois3('3 mois', 'les 3 derniers mois'),
  mois6('6 mois', 'les 6 derniers mois'),
  an1('1 an', 'la dernière année'),
  tout('Tout', 'depuis le début');

  const ProgresPeriode(this.label, this.phrase);
  final String label;
  final String phrase;

  /// Regroupement des barres : à la semaine jusqu'à 6 mois, au mois au-delà.
  bool get parSemaine => index <= ProgresPeriode.mois6.index;
}

/// Indicateur affiché dans les graphiques.
enum Indicateur {
  seances('Séances'),
  volume('Volume'),
  duree('Durée'),
  series('Séries');

  const Indicateur(this.label);
  final String label;
}

/// Intervalle de dates [debut, fin[.
class Intervalle {
  const Intervalle(this.debut, this.fin);
  final DateTime debut;
  final DateTime fin;

  int get jours => math.max(1, fin.difference(debut).inDays);
  double get semaines => jours / 7;
  bool contient(DateTime d) => !d.isBefore(debut) && d.isBefore(fin);

  /// Intervalle de même durée juste avant.
  Intervalle get precedent => Intervalle(debut.subtract(fin.difference(debut)), debut);

  String get libelle {
    final dernier = fin.subtract(const Duration(days: 1));
    if (Dates.memeJour(debut, dernier)) return Fmt.jourMois(debut);
    if (debut.year == dernier.year) return '${Fmt.jourMois(debut)} au ${Fmt.jourMois(dernier)} ${dernier.year}';
    return '${Fmt.dateCourte(debut)} au ${Fmt.dateCourte(dernier)}';
  }
}

/// Totaux d'un ensemble de séances.
class Resume {
  const Resume({
    this.seances = 0,
    this.volume = 0,
    this.duree = Duration.zero,
    this.series = 0,
    this.reps = 0,
    this.joursActifs = 0,
    this.semaines = 1,
  });

  final int seances;
  final double volume;
  final Duration duree;
  final int series;
  final int reps;
  final int joursActifs;
  final double semaines;

  double get seancesParSemaine => semaines <= 0 ? 0 : seances / semaines;
  Duration get dureeMoyenne => seances == 0 ? Duration.zero : Duration(seconds: duree.inSeconds ~/ seances);
  double get volumeMoyen => seances == 0 ? 0 : volume / seances;

  double valeur(Indicateur i) => switch (i) {
        Indicateur.seances => seances.toDouble(),
        Indicateur.volume => volume,
        Indicateur.duree => duree.inMinutes.toDouble(),
        Indicateur.series => series.toDouble(),
      };
}

/// Une barre d'un graphique regroupé par semaine ou par mois.
class Paquet {
  Paquet(this.intervalle, this.label);
  final Intervalle intervalle;
  final String label;
  int seances = 0;
  double volume = 0;
  int minutes = 0;
  int series = 0;

  double valeur(Indicateur i) => switch (i) {
        Indicateur.seances => seances.toDouble(),
        Indicateur.volume => volume,
        Indicateur.duree => minutes.toDouble(),
        Indicateur.series => series.toDouble(),
      };
}

/// Une ligne de la liste des records.
class LigneRecord {
  const LigneRecord({
    required this.exerciseId,
    required this.bests,
    required this.nbSeances,
    required this.derniereFois,
    this.premier1Rm,
    this.premierePoids,
    this.premiereFois,
  });

  final String exerciseId;
  final ExerciseBests bests;
  final int nbSeances;
  final DateTime derniereFois;
  final DateTime? premiereFois;

  /// Meilleur 1RM estimé de la toute première séance.
  final double? premier1Rm;
  final double? premierePoids;

  /// Exercice au poids du corps (aucune charge enregistrée).
  bool get sansCharge => bests.poidsMax == null;

  /// Record principal : 1RM estimé, sinon répétitions maximales.
  PersonalRecord? get principal => bests.unRm ?? bests.repsMax;

  /// Date du record principal.
  DateTime? get dateRecord => principal?.date;

  /// Gain du 1RM depuis la première séance (en kg).
  double? get gain {
    final u = bests.unRm?.valeur;
    if (u == null || premier1Rm == null) return null;
    return u - premier1Rm!;
  }

  /// Gain en pourcentage depuis la première séance.
  double? get gainPct {
    final g = gain;
    if (g == null || (premier1Rm ?? 0) <= 0) return null;
    return g / premier1Rm! * 100;
  }
}

/// Un point de la progression d'un exercice (une séance).
class PointExercice {
  const PointExercice({
    required this.session,
    required this.date,
    required this.unRm,
    required this.poidsMax,
    required this.volume,
    required this.repsMax,
    required this.series,
    this.meilleureSerie,
  });

  final WorkoutSession session;
  final DateTime date;
  final double unRm;
  final double poidsMax;
  final double volume;
  final int repsMax;
  final int series;
  final WorkoutSet? meilleureSerie;

  double valeur(IndicateurExercice i) => switch (i) {
        IndicateurExercice.unRm => unRm,
        IndicateurExercice.poidsMax => poidsMax,
        IndicateurExercice.volume => volume,
        IndicateurExercice.reps => repsMax.toDouble(),
      };
}

enum IndicateurExercice {
  unRm('1RM'),
  poidsMax('Charge'),
  volume('Volume'),
  reps('Rép.');

  const IndicateurExercice(this.label);
  final String label;
}

/// Statut d'un muscle au regard des 10 à 20 séries conseillées par semaine.
enum StatutMuscle {
  neglige('Sous la cible'),
  cible('Dans la cible'),
  auDessus('Au-dessus');

  const StatutMuscle(this.label);
  final String label;
}

/// Record battu pendant une séance, avec la séance.
typedef RecordDate = ({PersonalRecord record, WorkoutSession session});

/// Calculs du module Progrès, sans état ni widget.
abstract final class ProgresStats {
  static const seriesMin = 10.0;
  static const seriesMax = 20.0;

  /// Muscles pris en compte pour repérer les oublis (le cou s'entraîne rarement).
  static final musclesSuivis = Muscle.values.where((m) => m != Muscle.cou).toList();

  static StatutMuscle statut(double series) =>
      series < seriesMin ? StatutMuscle.neglige : (series > seriesMax ? StatutMuscle.auDessus : StatutMuscle.cible);

  /// Intervalle couvert par la période, jusqu'à demain minuit.
  static Intervalle intervalle(ProgresPeriode p, List<WorkoutSession> sessions, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final fin = DateTime(n.year, n.month, n.day + 1);
    final debut = switch (p) {
      ProgresPeriode.semaines4 => Dates.debutSemaine(n).subtract(const Duration(days: 21)),
      ProgresPeriode.mois3 => DateTime(n.year, n.month - 2),
      ProgresPeriode.mois6 => DateTime(n.year, n.month - 5),
      ProgresPeriode.an1 => DateTime(n.year, n.month - 11),
      ProgresPeriode.tout => sessions.isEmpty ? DateTime(n.year, n.month) : DateTime(sessions.last.debut.year, sessions.last.debut.month),
    };
    final d = p.parSemaine ? Dates.debutSemaine(debut) : debut;
    return Intervalle(d, fin);
  }

  static List<WorkoutSession> dans(List<WorkoutSession> sessions, Intervalle i) =>
      sessions.where((s) => i.contient(s.debut)).toList();

  static Resume resume(Iterable<WorkoutSession> sessions, {double semaines = 1}) {
    var n = 0, series = 0, reps = 0;
    double volume = 0;
    var sec = 0;
    final jours = <DateTime>{};
    for (final s in sessions) {
      n++;
      volume += s.volume;
      series += s.nbSeriesFaites;
      reps += s.nbReps;
      if (s.fin != null) sec += s.fin!.difference(s.debut).inSeconds.clamp(0, 6 * 3600);
      jours.add(Dates.jour(s.debut));
    }
    return Resume(
      seances: n,
      volume: volume,
      duree: Duration(seconds: sec),
      series: series,
      reps: reps,
      joursActifs: jours.length,
      semaines: semaines,
    );
  }

  /// Barres par semaine ou par mois sur l'intervalle.
  static List<Paquet> paquets(List<WorkoutSession> sessions, Intervalle i, {required bool parSemaine}) {
    final out = <Paquet>[];
    var d = parSemaine ? Dates.debutSemaine(i.debut) : DateTime(i.debut.year, i.debut.month);
    while (d.isBefore(i.fin)) {
      final f = parSemaine ? DateTime(d.year, d.month, d.day + 7) : DateTime(d.year, d.month + 1);
      final label = parSemaine ? '${d.day}/${d.month}' : _moisCourt(d);
      out.add(Paquet(Intervalle(d, f), label));
      d = f;
    }
    for (final s in sessions) {
      for (final p in out) {
        if (p.intervalle.contient(s.debut)) {
          p.seances++;
          p.volume += s.volume;
          p.series += s.nbSeriesFaites;
          if (s.fin != null) p.minutes += s.fin!.difference(s.debut).inMinutes.clamp(0, 360);
          break;
        }
      }
    }
    return out;
  }

  static const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  static const moisLongs = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
  static String _moisCourt(DateTime d) => _mois[d.month - 1];
  static String moisCourt(DateTime d) => _mois[d.month - 1];

  /// Séries effectives par jour (pour le calendrier).
  static Map<DateTime, double> seriesParJour(Iterable<WorkoutSession> sessions) {
    final out = <DateTime, double>{};
    for (final s in sessions) {
      final j = Dates.jour(s.debut);
      out[j] = (out[j] ?? 0) + math.max(1, s.nbSeriesFaites);
    }
    return out;
  }

  /// Niveau 0 à 4 d'un jour selon ses séries, par quartiles de l'historique.
  static int Function(double) niveaux(Iterable<double> valeurs) {
    final v = valeurs.where((x) => x > 0).toList()..sort();
    if (v.isEmpty) return (_) => 0;
    double q(double p) => v[((v.length - 1) * p).round()];
    final q1 = q(0.25), q2 = q(0.5), q3 = q(0.75);
    return (x) {
      if (x <= 0) return 0;
      if (x <= q1) return 1;
      if (x <= q2) return 2;
      if (x <= q3) return 3;
      return 4;
    };
  }

  /// Plus longue suite de semaines avec au moins une séance.
  static int plusLongueSerie(Iterable<DateTime> dates) {
    final semaines = dates.map((d) => Dates.debutSemaine(d)).toSet().toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final s in semaines) {
      if (prev != null && s.difference(prev).inDays <= 8 && s.difference(prev).inDays >= 6) {
        cur++;
      } else {
        cur = 1;
      }
      best = math.max(best, cur);
      prev = s;
    }
    return best;
  }

  /// Séries par muscle (principal 1, secondaire 0,5).
  static Map<Muscle, double> seriesParMuscle(Iterable<WorkoutSession> sessions, Exercise? Function(String) lookup) =>
      Strength.setsParMuscle(sessions, lookup);

  /// Intensité pour le personnage : 20 séries et plus = rouge plein.
  static Map<Muscle, double> intensites(Map<Muscle, double> series) => {
        for (final e in series.entries)
          if (e.value > 0) e.key: (0.2 + 0.8 * (e.value / seriesMax)).clamp(0.0, 1.0),
      };

  /// Exercices qui ont travaillé un muscle, avec les séries qu'ils lui apportent.
  static List<({String exerciseId, double series, bool principal})> exercicesDuMuscle(
      Iterable<WorkoutSession> sessions, Muscle m, Exercise? Function(String) lookup) {
    final acc = <String, double>{};
    final princ = <String, bool>{};
    for (final s in sessions) {
      for (final e in s.exercices) {
        final ex = lookup(e.exerciseId);
        if (ex == null) continue;
        final n = poidsDesSeries(e.seriesFaites.map((x) => x.type));
        if (n == 0) continue;
        if (ex.musclesPrincipaux.contains(m)) {
          acc[e.exerciseId] = (acc[e.exerciseId] ?? 0) + n;
          princ[e.exerciseId] = true;
        } else if (ex.musclesSecondaires.contains(m)) {
          acc[e.exerciseId] = (acc[e.exerciseId] ?? 0) + n * 0.5;
          princ.putIfAbsent(e.exerciseId, () => false);
        }
      }
    }
    final out = [for (final e in acc.entries) (exerciseId: e.key, series: e.value, principal: princ[e.key] ?? false)];
    out.sort((a, b) => b.series.compareTo(a.series));
    return out;
  }

  /// Une ligne par exercice déjà fait, avec ses records et sa progression.
  static List<LigneRecord> records(List<WorkoutSession> sessions) {
    final parExo = <String, List<WorkoutSession>>{};
    for (final s in sessions) {
      for (final id in s.exercices.where((e) => e.seriesFaites.isNotEmpty).map((e) => e.exerciseId).toSet()) {
        parExo.putIfAbsent(id, () => []).add(s);
      }
    }
    final out = <LigneRecord>[];
    for (final e in parExo.entries) {
      final list = e.value..sort((a, b) => a.debut.compareTo(b.debut));
      final bests = Strength.bests(e.key, list);
      if (bests.isEmpty) continue;
      final first = pointDe(e.key, list.first);
      out.add(LigneRecord(
        exerciseId: e.key,
        bests: bests,
        nbSeances: list.length,
        derniereFois: list.last.debut,
        premiereFois: list.first.debut,
        premier1Rm: first == null || first.unRm <= 0 ? null : first.unRm,
        premierePoids: first?.poidsMax,
      ));
    }
    return out;
  }

  /// Meilleurs résultats d'un exercice dans une séance.
  static PointExercice? pointDe(String exerciseId, WorkoutSession s) {
    double orm = 0, pmax = 0, vol = 0;
    var rmax = 0, n = 0;
    WorkoutSet? best;
    for (final e in s.exercices.where((e) => e.exerciseId == exerciseId)) {
      for (final set in e.series) {
        if (!set.fait || !set.type.counts) continue;
        n++;
        final o = Strength.setOneRm(set);
        if (o > orm || (orm == 0 && best == null)) {
          orm = math.max(orm, o);
          best = set;
        }
        pmax = math.max(pmax, set.poids ?? 0);
        rmax = math.max(rmax, set.reps ?? 0);
        vol += set.volume;
      }
    }
    if (n == 0) return null;
    return PointExercice(
      session: s,
      date: s.debut,
      unRm: orm,
      poidsMax: pmax,
      volume: vol,
      repsMax: rmax,
      series: n,
      meilleureSerie: best,
    );
  }

  /// Historique d'un exercice, du plus ancien au plus récent.
  static List<PointExercice> progression(String exerciseId, List<WorkoutSession> sessions) {
    final out = <PointExercice>[];
    for (final s in sessions) {
      final p = pointDe(exerciseId, s);
      if (p != null) out.add(p);
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Records battus par les séances de l'intervalle (chacune contre celles d'avant).
  static List<RecordDate> recordsBattus(List<WorkoutSession> sessions, Intervalle i) {
    final chrono = [...sessions]..sort((a, b) => a.debut.compareTo(b.debut));
    final out = <RecordDate>[
      for (final r in Strength.recordsAuFil(chrono))
        if (i.contient(r.session.debut)) (record: r.record, session: r.session),
    ];
    out.sort((a, b) => b.record.date.compareTo(a.record.date));
    return out;
  }

  /// Records battus par une séance précise.
  static List<PersonalRecord> recordsDeSeance(WorkoutSession s, List<WorkoutSession> sessions) {
    final avant = sessions.where((x) => x.id != s.id && x.debut.isBefore(s.debut));
    return Strength.newRecords(s, avant);
  }

  /// Exercices les plus travaillés (séries effectives et volume).
  static List<({String exerciseId, int series, double volume, int seances})> topExercices(Iterable<WorkoutSession> sessions) {
    final series = <String, int>{};
    final volume = <String, double>{};
    final seances = <String, int>{};
    for (final s in sessions) {
      final vus = <String>{};
      for (final e in s.exercices) {
        final n = compterSeries(e.seriesFaites.map((x) => x.type));
        if (n == 0) continue;
        series[e.exerciseId] = (series[e.exerciseId] ?? 0) + n;
        volume[e.exerciseId] = (volume[e.exerciseId] ?? 0) + e.volume;
        if (vus.add(e.exerciseId)) seances[e.exerciseId] = (seances[e.exerciseId] ?? 0) + 1;
      }
    }
    final out = [
      for (final id in series.keys) (exerciseId: id, series: series[id]!, volume: volume[id] ?? 0, seances: seances[id] ?? 0),
    ];
    out.sort((a, b) {
      final c = b.series.compareTo(a.series);
      return c != 0 ? c : b.volume.compareTo(a.volume);
    });
    return out;
  }

  /// Meilleur 1RM estimé d'un exercice sur un ensemble de séances.
  static double meilleur1Rm(String exerciseId, Iterable<WorkoutSession> sessions) =>
      Strength.bests(exerciseId, sessions).unRm?.valeur ?? 0;

  /// Variation relative en pour cent ; null si la base est nulle.
  static double? variation(num actuel, num avant) => avant == 0 ? null : (actuel - avant) / avant * 100;

  /// « +12 % », « -3 % », « = ».
  static String pct(double? v) {
    if (v == null) return 'nouveau';
    if (v.abs() < 0.5) return 'stable';
    return '${v > 0 ? '+' : ''}${Fmt.n(v, decimals: 0)} %';
  }

  /// Semaine lisible : « 22 au 28 sept. ».
  static String semaine(DateTime debut) {
    final fin = debut.add(const Duration(days: 6));
    if (debut.month == fin.month) return '${debut.day} au ${fin.day} ${moisCourt(fin)}';
    return '${debut.day} ${moisCourt(debut)} au ${fin.day} ${moisCourt(fin)}';
  }
}
