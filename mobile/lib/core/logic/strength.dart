import 'dart:math' as math;

import '../models/exercise.dart';
import '../models/muscle.dart';
import '../models/workout.dart';

/// Calculs de force : 1RM estimé, volume, records.
abstract final class Strength {
  /// Epley : poids × (1 + reps / 30).
  static double epley(double poids, int reps) => reps <= 0 ? 0 : (reps == 1 ? poids : poids * (1 + reps / 30));

  /// Brzycki : poids × 36 / (37 − reps), valable jusqu'à 12 reps environ.
  static double brzycki(double poids, int reps) {
    if (reps <= 0) return 0;
    if (reps == 1) return poids;
    if (reps >= 37) return epley(poids, reps);
    return poids * 36 / (37 - reps);
  }

  /// 1RM estimé : moyenne des deux formules sous 10 reps, Epley au-delà.
  static double oneRepMax(double poids, int reps) {
    if (poids <= 0 || reps <= 0) return 0;
    if (reps <= 10) return (epley(poids, reps) + brzycki(poids, reps)) / 2;
    return epley(poids, reps);
  }

  /// Charge conseillée pour un nombre de reps à partir d'un 1RM (inverse d'Epley).
  static double poidsPourReps(double unRm, int reps) => reps <= 1 ? unRm : unRm / (1 + reps / 30);

  /// Pourcentages usuels du 1RM, de 1 à 12 reps.
  static List<({int reps, double pct, double poids})> tablePourcentages(double unRm) => [
        for (var r = 1; r <= 12; r++)
          (reps: r, pct: poidsPourReps(unRm, r) / unRm, poids: poidsPourReps(unRm, r)),
      ];

  static double setOneRm(WorkoutSet s) =>
      s.fait && s.type.counts && (s.poids ?? 0) > 0 && (s.reps ?? 0) > 0 ? oneRepMax(s.poids!, s.reps!) : 0;

  static double sessionVolume(WorkoutSession s) => s.volume;

  /// Séries effectives par muscle : principal 1, secondaire 0,5.
  static Map<Muscle, double> setsParMuscle(Iterable<WorkoutSession> sessions, Exercise? Function(String id) lookup) {
    final out = <Muscle, double>{};
    for (final s in sessions) {
      for (final e in s.exercices) {
        final ex = lookup(e.exerciseId);
        if (ex == null) continue;
        final n = poidsDesSeries(e.seriesFaites.map((x) => x.type));
        if (n == 0) continue;
        for (final m in ex.musclesPrincipaux) {
          out[m] = (out[m] ?? 0) + n;
        }
        for (final m in ex.musclesSecondaires) {
          out[m] = (out[m] ?? 0) + n * 0.5;
        }
      }
    }
    return out;
  }

  /// Volume (kg) par muscle, même pondération.
  static Map<Muscle, double> volumeParMuscle(Iterable<WorkoutSession> sessions, Exercise? Function(String id) lookup) {
    final out = <Muscle, double>{};
    for (final s in sessions) {
      for (final e in s.exercices) {
        final ex = lookup(e.exerciseId);
        if (ex == null) continue;
        final v = e.volume;
        if (v == 0) continue;
        for (final m in ex.musclesPrincipaux) {
          out[m] = (out[m] ?? 0) + v;
        }
        for (final m in ex.musclesSecondaires) {
          out[m] = (out[m] ?? 0) + v * 0.5;
        }
      }
    }
    return out;
  }

  /// Meilleurs résultats sur un exercice, séances triées dans n'importe quel ordre.
  static ExerciseBests bests(String exerciseId, Iterable<WorkoutSession> sessions) {
    PersonalRecord? poidsMax, unRm, volSerie, repsMax, volSeance;
    for (final s in sessions) {
      final date = s.fin ?? s.debut;
      for (final e in s.exercices.where((e) => e.exerciseId == exerciseId)) {
        double vol = 0;
        for (final set in e.series) {
          if (!set.fait || !set.type.counts) continue;
          final p = set.poids ?? 0;
          final r = set.reps ?? 0;
          vol += p * r;
          PersonalRecord rec(RecordType t, double v) =>
              PersonalRecord(exerciseId: exerciseId, type: t, valeur: v, date: date, sessionId: s.id, poids: p, reps: r);
          if (p > 0 && (poidsMax == null || p > poidsMax.valeur)) poidsMax = rec(RecordType.poidsMax, p);
          final orm = setOneRm(set);
          if (orm > 0 && (unRm == null || orm > unRm.valeur)) unRm = rec(RecordType.unRmEstime, orm);
          if (p * r > 0 && (volSerie == null || p * r > volSerie.valeur)) volSerie = rec(RecordType.volumeSerie, p * r);
          if (r > 0 && (repsMax == null || r > repsMax.valeur)) repsMax = rec(RecordType.repsMax, r.toDouble());
        }
        if (vol > 0 && (volSeance == null || vol > volSeance.valeur)) {
          volSeance = PersonalRecord(exerciseId: exerciseId, type: RecordType.volumeSeance, valeur: vol, date: date, sessionId: s.id);
        }
      }
    }
    return ExerciseBests(poidsMax: poidsMax, unRm: unRm, volumeSerie: volSerie, repsMax: repsMax, volumeSeance: volSeance);
  }

  /// Records battus par [session] par rapport à l'historique [before].
  ///
  /// La règle, la même partout dans l'appli (séance en cours, bilan, accueil,
  /// progrès). Chaque série validée est comparée à ce qui a été fait AVANT la
  /// séance, et reçoit au plus une médaille, la plus haute :
  ///  - l'or : une charge jamais soulevée sur l'exercice ;
  ///  - l'argent : un meilleur 1RM estimé, sans charge record ;
  ///  - le bronze : plus de répétitions qu'on n'en a jamais fait à cette
  ///    charge ou plus lourd.
  /// Battre plusieurs fois le même record dans la séance ne compte qu'une
  /// fois, pour sa meilleure série : un or et un argent par exercice au plus,
  /// un bronze par charge. Un exercice fait pour la première fois ne donne
  /// aucun record. Sans charge (poids du corps), seul compte le plus grand
  /// nombre de répétitions.
  static List<PersonalRecord> newRecords(WorkoutSession session, Iterable<WorkoutSession> before) {
    final ids = session.exercices.map((e) => e.exerciseId).toSet();
    final reperes = <String, _Reperes>{};
    for (final s in before) {
      for (final e in s.exercices) {
        if (ids.contains(e.exerciseId)) reperes.putIfAbsent(e.exerciseId, _Reperes.new).integrer(e.series);
      }
    }
    return _recordsDe(session, reperes);
  }

  /// Tous les records battus au fil des séances [chrono] (de la plus ancienne
  /// à la plus récente), chacune comparée à celles d'avant : même règle que
  /// [newRecords], en un seul passage.
  static List<({PersonalRecord record, WorkoutSession session})> recordsAuFil(List<WorkoutSession> chrono) {
    final reperes = <String, _Reperes>{};
    final out = <({PersonalRecord record, WorkoutSession session})>[];
    for (final s in chrono) {
      for (final r in _recordsDe(s, reperes)) {
        out.add((record: r, session: s));
      }
      for (final e in s.exercices) {
        reperes.putIfAbsent(e.exerciseId, _Reperes.new).integrer(e.series);
      }
    }
    return out;
  }

  static List<PersonalRecord> _recordsDe(WorkoutSession session, Map<String, _Reperes> reperes) {
    final out = <PersonalRecord>[];
    final date = session.fin ?? session.debut;
    final vus = <String>{};
    for (final se in session.exercices) {
      final id = se.exerciseId;
      // Un exercice présent deux fois dans la séance est jugé en une fois.
      if (!vus.add(id)) continue;
      final avant = reperes[id];
      // Sans historique sur l'exercice, pas de « record » : c'est une première.
      if (avant == null || !avant.vu) continue;
      PersonalRecord rec(RecordType t, double v, double? p, int r) =>
          PersonalRecord(exerciseId: id, type: t, valeur: v, date: date, sessionId: session.id, poids: p, reps: r);
      PersonalRecord? or, argent;
      var rmOr = 0.0;
      final bronzes = <double, PersonalRecord>{};
      PersonalRecord? sansCharge;
      for (final e in session.exercices.where((e) => e.exerciseId == id)) {
        for (final x in e.series) {
          if (!x.fait || !x.type.counts) continue;
          final p = x.poids ?? 0, r = x.reps ?? 0;
          if (r <= 0) continue;
          if (p <= 0) {
            // Poids du corps : le plus de répétitions, si l'exercice n'a jamais été chargé.
            if (avant.poidsMax <= 0 && r > avant.repsSansCharge && (sansCharge == null || r > sansCharge.valeur)) {
              sansCharge = rec(RecordType.repsMax, r.toDouble(), null, r);
            }
            continue;
          }
          // Première fois avec une charge : rien à battre.
          if (avant.poidsMax <= 0) continue;
          final rm = oneRepMax(p, r);
          if (p > avant.poidsMax + 1e-9) {
            if (or == null || p > or.valeur + 1e-9 || ((p - or.valeur).abs() <= 1e-9 && r > (or.reps ?? 0))) or = rec(RecordType.poidsMax, p, p, r);
            if (rm > rmOr) rmOr = rm;
          } else if (rm > avant.unRm + 0.05) {
            if (argent == null || rm > argent.valeur) argent = rec(RecordType.unRmEstime, rm, p, r);
          } else if (r > avant.repsA(p)) {
            final b = bronzes[p];
            if (b == null || r > b.valeur) bronzes[p] = rec(RecordType.repsMax, r.toDouble(), p, r);
          }
        }
      }
      if (or != null) out.add(or);
      // Un 1RM estimé que la charge record dépasse déjà n'ajoute rien.
      if (argent != null && argent.valeur > rmOr + 0.05) out.add(argent);
      out.addAll((bronzes.keys.toList()..sort((a, b) => b.compareTo(a))).map((p) => bronzes[p]!));
      if (sansCharge != null) out.add(sansCharge);
    }
    return out;
  }

  /// Le plus de répétitions déjà faites sur [exerciseId] à la charge [poids]
  /// ou plus lourd, dans [sessions] (0 si jamais).
  static int repsA(String exerciseId, Iterable<WorkoutSession> sessions, double poids) {
    final r = _Reperes();
    for (final s in sessions) {
      for (final e in s.exercices.where((e) => e.exerciseId == exerciseId)) {
        r.integrer(e.series);
      }
    }
    return poids <= 0 ? r.repsSansCharge : r.repsA(poids);
  }

  /// L'haltère juste au-dessus de [kg] sur le râtelier d'une salle : un par
  /// kilo jusqu'à 10 kg (1, 2, 3... 10), puis de 2 en 2 (12, 14, 16...).
  static double haltereSuivant(double kg) => kg < 10 ? kg.floorToDouble() + 1 : (kg / 2).floorToDouble() * 2 + 2;

  /// L'haltère du râtelier le plus proche de [kg] : au kilo jusqu'à 10 kg,
  /// au nombre pair au-delà.
  static double arrondirHaltere(double kg) => kg <= 10 ? kg.roundToDouble().clamp(1, 10).toDouble() : (kg / 2).roundToDouble() * 2;

  /// Arrondi au pas du matériel (2,5 kg par défaut).
  static double arrondir(double poids, [double pas = 2.5]) => pas <= 0 ? poids : (poids / pas).round() * pas;

  /// Séries d'échauffement proposées avant une charge de travail.
  static List<({double poids, int reps})> echauffement(double poidsTravail, {double barre = 20, double pas = 2.5}) {
    if (poidsTravail <= barre) return const [];
    final paliers = [(0.0, 10), (0.4, 8), (0.6, 5), (0.8, 3)];
    final out = <({double poids, int reps})>[];
    for (final (pct, reps) in paliers) {
      final p = pct == 0 ? barre : math.max(barre, arrondir(poidsTravail * pct, pas));
      if (out.isEmpty || p > out.last.poids) out.add((poids: p, reps: reps));
    }
    return out.where((w) => w.poids < poidsTravail).toList();
  }
}

class ExerciseBests {
  const ExerciseBests({this.poidsMax, this.unRm, this.volumeSerie, this.repsMax, this.volumeSeance});
  final PersonalRecord? poidsMax;
  final PersonalRecord? unRm;
  final PersonalRecord? volumeSerie;
  final PersonalRecord? repsMax;
  final PersonalRecord? volumeSeance;

  List<PersonalRecord> get all => [poidsMax, unRm, volumeSerie, repsMax, volumeSeance].whereType<PersonalRecord>().toList();
  bool get isEmpty => all.isEmpty;
}

/// Ce qu'il faut battre sur un exercice : la charge la plus lourde, le
/// meilleur 1RM estimé, et le plus de répétitions faites à chaque charge.
class _Reperes {
  double poidsMax = 0;
  double unRm = 0;
  int repsSansCharge = 0;
  final _reps = <double, int>{};

  /// Vrai dès qu'une série a été faite sur l'exercice.
  bool vu = false;

  void integrer(Iterable<WorkoutSet> series) {
    for (final x in series) {
      if (!x.fait || !x.type.counts) continue;
      final p = x.poids ?? 0, r = x.reps ?? 0;
      if (r <= 0) continue;
      vu = true;
      if (p <= 0) {
        if (r > repsSansCharge) repsSansCharge = r;
        continue;
      }
      if (p > poidsMax) poidsMax = p;
      final rm = Strength.oneRepMax(p, r);
      if (rm > unRm) unRm = rm;
      if (r > (_reps[p] ?? 0)) _reps[p] = r;
    }
  }

  /// Le plus de répétitions déjà faites à cette charge ou plus lourd.
  int repsA(double poids) => _reps.entries.where((e) => e.key >= poids - 1e-9).fold(0, (m, e) => e.value > m ? e.value : m);
}
