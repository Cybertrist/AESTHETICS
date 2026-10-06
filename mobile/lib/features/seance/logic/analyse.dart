import 'dart:math' as math;

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'editeur.dart';

/// Bilan d'une séance terminée : records, muscles, suggestions.
class BilanSeance {
  BilanSeance._(this.session, this.records, this.seriesParMuscle, this._avant);

  final WorkoutSession session;
  final List<PersonalRecord> records;
  final List<WorkoutSession> _avant;
  final Map<Muscle, double> seriesParMuscle;

  /// Records battus, comparés aux séances d'avant celle-ci.
  factory BilanSeance.calculer(WorkoutSession s, SessionRepo repo, ExerciseRepo exos) {
    final avant = repo.sessions.where((x) => x.id != s.id && x.debut.isBefore(s.debut)).toList();
    final records = Strength.newRecords(s, avant);
    final parMuscle = Strength.setsParMuscle([s], exos.byId);
    return BilanSeance._(s, records, parMuscle, avant);
  }

  /// Valeur du record qui tenait avant cette séance, null si c'est le premier.
  double? ancienne(PersonalRecord r) {
    // Un record de répétitions se compare aux répétitions déjà faites à
    // cette charge ou plus lourd.
    if (r.type == RecordType.repsMax) {
      final n = Strength.repsA(r.exerciseId, _avant, r.poids ?? 0);
      return n <= 0 ? null : n.toDouble();
    }
    final b = Strength.bests(r.exerciseId, _avant);
    return switch (r.type) {
      RecordType.poidsMax => b.poidsMax,
      RecordType.unRmEstime => b.unRm,
      RecordType.volumeSerie => b.volumeSerie,
      RecordType.repsMax => b.repsMax,
      RecordType.volumeSeance => b.volumeSeance,
    }
        ?.valeur;
  }

  /// Intensités 0..1 pour le personnage (la plus travaillée à 1).
  Map<Muscle, double> get intensites {
    if (seriesParMuscle.isEmpty) return const {};
    final max = seriesParMuscle.values.fold(0.0, math.max);
    if (max <= 0) return const {};
    return {for (final e in seriesParMuscle.entries) e.key: (0.25 + 0.75 * e.value / max).clamp(0.0, 1.0)};
  }

  List<MapEntry<Muscle, double>> get musclesTries =>
      seriesParMuscle.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  Set<String> get exercicesAvecRecord => records.map((r) => r.exerciseId).toSet();

  /// Le record le plus parlant de chaque exercice (la charge d'abord), dans
  /// l'ordre de la séance : une ligne par exercice dans le bilan.
  List<PersonalRecord> get recordsPrincipaux {
    const ordre = [RecordType.poidsMax, RecordType.unRmEstime, RecordType.repsMax, RecordType.volumeSerie, RecordType.volumeSeance];
    final par = <String, PersonalRecord>{};
    for (final r in records) {
      final a = par[r.exerciseId];
      if (a == null || ordre.indexOf(r.type) < ordre.indexOf(a.type)) par[r.exerciseId] = r;
    }
    return par.values.toList();
  }

  List<PersonalRecord> recordsDe(String exerciseId) => records.where((r) => r.exerciseId == exerciseId).toList();

  /// La plus haute médaille gagnée sur un exercice, null sans record.
  PersonalRecord? meilleurDe(String exerciseId) {
    PersonalRecord? m;
    for (final r in recordsDe(exerciseId)) {
      if (m == null || r.type.medaille.index < m.type.medaille.index) m = r;
    }
    return m;
  }
}

/// Ce que dit un record : « Charge maximale », « 1RM estimé »,
/// « Répétitions à 30 kg ».
String titreRecord(PersonalRecord r, UnitePoids u) =>
    r.type == RecordType.repsMax && (r.poids ?? 0) > 0 ? 'Répétitions à ${Fmt.poids(r.poids, u)}' : (r.type == RecordType.repsMax ? 'Répétitions' : r.type.label);

/// Texte d'un record : « 100 kg × 5 », « 1RM estimé 112,5 kg ».
String texteRecord(PersonalRecord r, UnitePoids u) => switch (r.type) {
      RecordType.poidsMax => '${Fmt.poids(r.valeur, u)}${r.reps != null ? ' × ${r.reps}' : ''}',
      RecordType.unRmEstime => Fmt.poids(r.valeur, u),
      RecordType.volumeSerie => '${Fmt.poids(r.poids, u)} × ${r.reps ?? 0}',
      RecordType.repsMax => (r.poids ?? 0) > 0 ? '${Fmt.poids(r.poids, u)} × ${r.valeur.round()}' : Fmt.pluriel(r.valeur.round(), 'répétition'),
      RecordType.volumeSeance => Fmt.volume(r.valeur, u),
    };

/// Ce qu'il faut battre sur un exercice pour qu'une série soit un record,
/// d'après les séances d'avant : la charge la plus lourde, le meilleur 1RM
/// estimé, et le plus de répétitions faites à chaque charge.
class ReperesRecord {
  ReperesRecord._(this.poidsMax, this.unRmMax, this._repsParCharge);

  final double poidsMax;
  final double unRmMax;
  final Map<double, int> _repsParCharge;

  factory ReperesRecord.de(String exerciseId, Iterable<WorkoutSession> avant) {
    var poids = 0.0, unRm = 0.0;
    final reps = <double, int>{};
    for (final s in avant) {
      for (final e in s.exercices.where((e) => e.exerciseId == exerciseId)) {
        for (final x in e.seriesFaites.where((x) => x.type.counts)) {
          final p = x.poids ?? 0, r = x.reps ?? 0;
          if (p <= 0 || r <= 0) continue;
          if (p > poids) poids = p;
          final rm = Strength.oneRepMax(p, r);
          if (rm > unRm) unRm = rm;
          if (r > (reps[p] ?? 0)) reps[p] = r;
        }
      }
    }
    return ReperesRecord._(poids, unRm, reps);
  }

  /// Exercice jamais fait avec une charge : rien à battre, donc pas de record.
  bool get vide => poidsMax <= 0;

  /// Le plus de répétitions déjà faites à cette charge ou plus lourd.
  int repsA(double poids) => _repsParCharge.entries.where((e) => e.key >= poids - 1e-9).fold(0, (m, e) => e.value > m ? e.value : m);

  /// Tous les records que bat cette série, une ligne chacun :
  /// « Charge maximale · 35 kg », « 1RM estimé · 41 kg ».
  List<String> recordsDe(WorkoutSet x, UnitePoids u) {
    final p = x.poids ?? 0, r = x.reps ?? 0;
    if (vide || !x.type.counts || p <= 0 || r <= 0) return const [];
    final rm = Strength.oneRepMax(p, r);
    return [
      if (p > poidsMax + 1e-9) 'Charge maximale · ${Fmt.poids(p, u)}',
      if (rm > unRmMax + 0.05) '1RM estimé · ${Fmt.poids(rm, u)}',
      if (p <= poidsMax + 1e-9 && r > repsA(p)) 'Répétitions à ${Fmt.poids(p, u)} · $r',
    ];
  }

  /// Nature du record que bat cette série, null si elle n'en bat aucun.
  String? recordDe(WorkoutSet x) {
    final p = x.poids ?? 0, r = x.reps ?? 0;
    if (vide || !x.type.counts || p <= 0 || r <= 0) return null;
    if (p > poidsMax + 1e-9) return 'charge maximale';
    if (r > repsA(p)) return 'répétitions à cette charge';
    if (Strength.oneRepMax(p, r) > unRmMax + 0.05) return '1RM estimé';
    return null;
  }
}

/// De combien un record dépasse l'ancien : « +2,5 kg », « +2 répétitions ».
/// Null sans ancien record ou quand l'écart ne se voit pas.
String? texteGainRecord(PersonalRecord r, double? ancienne, UnitePoids u) {
  if (ancienne == null) return null;
  final gain = r.valeur - ancienne;
  if (r.type == RecordType.repsMax) {
    final n = gain.round();
    return n <= 0 ? null : '+${Fmt.pluriel(n, 'répétition')}';
  }
  final affiche = Fmt.poidsAffiche(gain, u);
  if (affiche < 0.05) return null;
  return '+${Fmt.n(affiche)} ${u.label}';
}

/// Conseil pour la prochaine fois sur un exercice : la charge et les
/// répétitions à viser, et la raison de ce choix, écrite en clair.
class Suggestion {
  const Suggestion({
    required this.exerciseId,
    required this.seId,
    required this.titre,
    required this.raison,
    this.poids,
    this.reps,
    this.hausse = false,
  });

  final String exerciseId;
  final String seId;
  final String titre;
  final String raison;
  final double? poids;
  final int? reps;

  /// Vrai quand on monte la charge ou les reps.
  final bool hausse;
}

/// La progression proposée après une séance.
///
/// Le principe : à charge égale, on gagne d'abord des répétitions, une par
/// séance, jusqu'en haut de la fourchette ; alors seulement la charge monte
/// d'un pas et l'on repart du bas. 30 kg × 5 puis 30 kg × 6 donne donc
/// 30 kg × 7, pas 32,5 kg. Chaque proposition regarde aussi les séances
/// d'[avant] sur l'exercice (progrès, recul, stagnation) et dit pourquoi.
abstract final class Surcharge {
  static List<Suggestion> calculer(
    WorkoutSession s, {
    required ExerciseRepo exos,
    Routine? routine,
    double increment = 2.5,
    UnitePoids unite = UnitePoids.kg,
    Iterable<WorkoutSession> avant = const [],
  }) {
    final out = <Suggestion>[];
    for (final e in s.exercices) {
      final ex = exos.byId(e.exerciseId);
      final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
      final travail = e.seriesFaites.where((x) => x.type.counts && (x.reps ?? 0) > 0).toList();
      if (travail.isEmpty || !suivi.usesReps) continue;
      final prevu = routine?.exercices.where((r) => r.exerciseId == e.exerciseId).firstOrNull;
      final planNormales = prevu?.series.where((p) => p.type.counts).toList() ?? const <PlannedSet>[];
      final cibleBas = planNormales.isNotEmpty ? planNormales.first.reps : null;
      final cibleHaut = planNormales.isNotEmpty ? (planNormales.first.repsMax ?? planNormales.first.reps) : null;
      final echec = travail.any((x) => x.type == SetType.echec);
      final rpes = travail.map((x) => x.rpe).whereType<double>().toList();
      final rpeMoy = rpes.isEmpty ? null : rpes.reduce((a, b) => a + b) / rpes.length;

      if (!suivi.usesWeight || suivi == ExerciseTracking.poidsDuCorpsAssiste) {
        final best = travail.map((x) => x.reps!).reduce(math.max);
        final assiste = suivi == ExerciseTracking.poidsDuCorpsAssiste;
        final poidsTop = travail.first.poids;
        if (assiste && poidsTop != null && poidsTop > 0 && (cibleHaut == null || best >= cibleHaut)) {
          final p = math.max(0.0, poidsTop - increment);
          out.add(Suggestion(
            exerciseId: e.exerciseId,
            seId: e.id,
            titre: '-${Fmt.poids(p, unite)} × ${cibleBas ?? best}',
            raison: 'Séries tenues : réduis l\'assistance.',
            poids: p,
            reps: cibleBas ?? best,
            hausse: true,
          ));
        } else {
          out.add(Suggestion(
            exerciseId: e.exerciseId,
            seId: e.id,
            titre: Fmt.pluriel(best + 1, 'répétition'),
            raison: 'Vise une répétition de plus sur ta meilleure série.',
            poids: poidsTop,
            reps: best + 1,
            hausse: true,
          ));
        }
        continue;
      }

      final top = travail.map((x) => x.poids ?? 0).reduce(math.max);
      if (top <= 0) continue;
      final aTop = travail.where((x) => (x.poids ?? 0) >= top - 1e-6).toList();
      final repsTop = aTop.map((x) => x.reps!).toList();
      final minReps = repsTop.reduce(math.min);
      final maxReps = repsTop.reduce(math.max);
      final signe = suivi == ExerciseTracking.poidsDuCorpsLeste ? '+' : '';
      final jambes = ex != null &&
          ex.musclesPrincipaux.any((m) => m == Muscle.quadriceps || m == Muscle.ischios || m == Muscle.fessiers) &&
          (ex.equipement == 'barre' || ex.equipement == 'machine' || ex.equipement == 'smith');
      final pas = jambes ? increment * 2 : increment;
      String charge(double p) => '$signe${Fmt.poids(p, unite)}';

      // La fourchette de répétitions : celle de la routine si elle en donne
      // une ; sinon celle où tombent les répétitions faites. Un nombre fixe
      // noté dans la routine n'est pas un plafond : il vient souvent de la
      // séance d'avant.
      // Ce que disent les séances d'avant sur cet exercice.
      final passe = _passe(e.exerciseId, avant);
      final derniere = passe.firstOrNull;
      // Les répétitions de la première séance faite à cette charge : c'est de
      // là qu'on est parti.
      var depart = minReps;
      for (final p in passe) {
        if ((p.top - top).abs() > 1e-6) break;
        depart = p.minReps;
      }
      // La fourchette reste celle du départ à cette charge tant qu'on n'est
      // pas retombé dessous : parti de 5, on vise 8 ; arrivé à 8, la charge monte.
      var (bas, haut) = cibleBas != null && cibleHaut != null && cibleHaut > cibleBas ? (cibleBas, cibleHaut) : fourchette(math.min(depart, minReps));
      // Un pas qui pèse plus de 10 % de la charge (2,5 kg sur 10 kg) se
      // gagne avec deux répétitions de plus avant de monter.
      final grosPas = pas / top > 0.10;
      if (grosPas) haut += 2;

      final String constat;
      if (derniere == null) {
        constat = 'Première séance notée sur cet exercice.';
      } else if (top > derniere.top + 1e-6) {
        constat = 'Charge montée de ${charge(derniere.top)} à ${charge(top)}.';
      } else if (top < derniere.top - 1e-6) {
        constat = 'Charge plus légère que la dernière fois (${charge(derniere.top)}).';
      } else if (maxReps > derniere.maxReps) {
        constat = '${charge(top)} × ${derniere.maxReps} la dernière fois, × $maxReps aujourd\'hui : tu progresses.';
      } else if (maxReps < derniere.maxReps) {
        constat = '${Fmt.pluriel(derniere.maxReps - maxReps, 'répétition')} de moins que la dernière fois à ${charge(top)}.';
      } else {
        constat = 'Comme la dernière fois : ${charge(top)} × $maxReps.';
      }
      // Séances d'affilée au même point (même charge, mêmes répétitions), celle-ci comprise.
      var auMemePoint = 1;
      for (final p in passe) {
        if ((p.top - top).abs() > 1e-6 || p.maxReps != maxReps || p.minReps != minReps) break;
        auMemePoint++;
      }

      Suggestion proposer(double p, int r, String suite, {bool hausse = false}) => Suggestion(
            exerciseId: e.exerciseId,
            seId: e.id,
            titre: '${charge(p)} × $r',
            raison: '$constat $suite',
            poids: p,
            reps: r,
            hausse: hausse,
          );

      final dur = echec || (rpeMoy != null && rpeMoy >= 9.5);
      if (aTop.length * 2 < travail.length) {
        // La charge la plus lourde n'a tenu que sur une minorité de séries :
        // elle n'est pas encore acquise.
        out.add(proposer(top, minReps, '${charge(top)} n\'a tenu que sur ${Fmt.pluriel(aTop.length, 'série')} : tiens-la sur toutes avant d\'aller plus loin.'));
      } else if (minReps < bas || (dur && minReps < haut)) {
        final r = math.max(bas, minReps);
        out.add(proposer(top, r, dur ? 'Séries poussées à bout : garde la charge et consolide.' : 'Sous la fourchette de $bas à $haut : garde la charge et consolide.'));
      } else if (minReps >= haut && (rpeMoy == null || rpeMoy <= 8.5)) {
        final p = Strength.arrondir(top + pas, increment);
        out.add(proposer(p, bas, '$haut répétitions sur toutes tes séries : monte à ${charge(p)} et repars à $bas.', hausse: true));
      } else if (maxReps > minReps) {
        // Des séries inégales (8, 7, 6) : d'abord les amener au niveau de la meilleure.
        final r = math.min(haut, maxReps);
        out.add(proposer(top, r, 'Amène toutes tes séries à $r ; la charge montera à $haut partout.', hausse: true));
      } else if (auMemePoint >= 3) {
        final r = math.min(haut, minReps + 1);
        out.add(proposer(top, r, '$auMemePoint séances au même point : vise $r sur la première série seulement, sans forcer les autres.', hausse: true));
      } else {
        final r = math.min(haut, minReps + 1);
        final seuil = grosPas ? 'la charge montera à $haut, le pas de ${Fmt.poids(pas, unite)} étant gros pour cette charge' : 'la charge montera à $haut';
        out.add(proposer(top, r, 'Même charge, une répétition de plus par série ; $seuil.', hausse: true));
      }
    }
    return out;
  }

  static const _fourchettes = [(3, 5), (5, 8), (8, 12), (12, 15), (15, 20)];

  /// La fourchette qui part de [reps] répétitions : 3 à 5, 5 à 8, 8 à 12,
  /// 12 à 15 ou 15 à 20. On y gagne des répétitions jusqu'en haut, puis la
  /// charge monte et l'on repart du bas. Une valeur charnière (5, 8, 12, 15)
  /// ouvre la fourchette du dessus : qui commence à 8 vise 12.
  static (int, int) fourchette(int reps) => _fourchettes.lastWhere((f) => reps >= f.$1, orElse: () => _fourchettes.first);

  /// Les séances d'avant sur un exercice, de la plus récente à la plus
  /// ancienne : la charge de travail la plus lourde, et les répétitions
  /// faites à cette charge.
  static List<({double top, int minReps, int maxReps})> _passe(String exerciseId, Iterable<WorkoutSession> avant) {
    final seances = avant.where((s) => !s.enCours).toList()..sort((a, b) => b.debut.compareTo(a.debut));
    final out = <({double top, int minReps, int maxReps})>[];
    for (final s in seances) {
      final travail = [
        for (final e in s.exercices.where((e) => e.exerciseId == exerciseId))
          ...e.seriesFaites.where((x) => x.type.counts && (x.reps ?? 0) > 0 && (x.poids ?? 0) > 0),
      ];
      if (travail.isEmpty) continue;
      final top = travail.map((x) => x.poids!).reduce(math.max);
      final reps = travail.where((x) => x.poids! >= top - 1e-6).map((x) => x.reps!).toList();
      out.add((top: top, minReps: reps.reduce(math.min), maxReps: reps.reduce(math.max)));
    }
    return out;
  }
}

/// Changement d'un exercice de la routine après la séance.
class ChangementRoutine {
  const ChangementRoutine(this.exerciseId, this.avant, this.apres, {this.ajout = false, this.retrait = false});
  final String exerciseId;
  final String avant;
  final String apres;
  final bool ajout;
  final bool retrait;
}

/// Mise à jour d'une routine avec ce qui a été fait (ou suggéré).
abstract final class MajRoutine {
  /// Vrai si la séance a été modifiée par rapport à la routine : un exercice
  /// remplacé ou ajouté, ou des exercices changés d'ordre. Un exercice
  /// simplement sauté ce jour-là ne compte pas.
  static bool exercicesChanges(Routine r, WorkoutSession s) {
    final prevus = [for (final e in r.exercices) e.exerciseId];
    final faits = [for (final e in s.exercices) e.exerciseId];
    if (faits.any((id) => !prevus.contains(id))) return true;
    // Les exercices communs, dans l'ordre de la routine puis de la séance.
    final ordreRoutine = prevus.where(faits.contains).toList();
    for (var i = 0; i < faits.length; i++) {
      if (i >= ordreRoutine.length || faits[i] != ordreRoutine[i]) return true;
    }
    return false;
  }

  /// [calquer] : la routine reprend la séance telle qu'elle a été faite,
  /// mêmes exercices dans le même ordre (un exercice remplacé prend la
  /// place de l'ancien, un exercice retiré disparaît).
  static Routine appliquer(
    Routine r,
    WorkoutSession s, {
    bool ajouterNouveaux = true,
    bool retirerAbsents = false,
    bool calquer = false,
    List<Suggestion> suggestions = const [],
  }) {
    if (calquer) {
      final anciens = [...r.exercices];
      final supersets = <String, String>{};
      final exercices = <RoutineExercise>[];
      for (final e in s.exercices) {
        final sug = suggestions.where((x) => x.seId == e.id).firstOrNull;
        final i = anciens.indexWhere((re) => re.exerciseId == e.exerciseId);
        final superset = e.supersetId == null ? null : (supersets[e.supersetId!] ??= newId());
        final ancien = i >= 0 ? anciens.removeAt(i) : null;
        // Exercice nouveau et aucune série cochée : on garde les séries prévues.
        final prevues = ancien?.series ??
            [for (final x in e.series) PlannedSet(type: x.type, poids: x.poids, reps: x.reps, dureeSec: x.dureeSec, distanceM: x.distanceM)];
        exercices.add(RoutineExercise(
          id: ancien?.id ?? newId(),
          exerciseId: e.exerciseId,
          series: _series(e, prevues, sug),
          reposSec: e.reposSec,
          supersetId: superset,
          notes: ancien?.notes ?? e.notes,
        ));
      }
      return r.copyWith(exercices: exercices, modifieLe: DateTime.now());
    }
    final restants = [...s.exercices];
    final nouveaux = <RoutineExercise>[];
    for (final re in r.exercices) {
      final i = restants.indexWhere((e) => e.exerciseId == re.exerciseId);
      if (i < 0) {
        if (!retirerAbsents) nouveaux.add(re);
        continue;
      }
      final e = restants.removeAt(i);
      final sug = suggestions.where((x) => x.seId == e.id).firstOrNull;
      nouveaux.add(re.copyWith(series: _series(e, re.series, sug), reposSec: e.reposSec));
    }
    if (ajouterNouveaux) {
      for (final e in restants) {
        final sug = suggestions.where((x) => x.seId == e.id).firstOrNull;
        nouveaux.add(RoutineExercise(
          id: newId(),
          exerciseId: e.exerciseId,
          series: _series(e, const [], sug),
          reposSec: e.reposSec,
          supersetId: e.supersetId,
          notes: e.notes,
        ));
      }
    }
    return r.copyWith(exercices: nouveaux, modifieLe: DateTime.now());
  }

  static List<PlannedSet> _series(SessionExercise e, List<PlannedSet> plan, Suggestion? sug) {
    final faites = e.seriesFaites;
    final out = <PlannedSet>[];
    for (var i = 0; i < faites.length; i++) {
      final f = faites[i];
      final p = i < plan.length ? plan[i] : null;
      final travail = f.type.counts;
      final poids = travail && sug?.poids != null ? sug!.poids : f.poids;
      final gardeFourchette = p?.repsMax != null && f.reps != null && f.reps! >= (p!.reps ?? 0) && f.reps! <= p.repsMax!;
      out.add(PlannedSet(
        type: f.type,
        poids: poids,
        reps: gardeFourchette ? p.reps : (travail && sug?.reps != null ? sug!.reps : f.reps),
        repsMax: gardeFourchette ? p.repsMax : null,
        dureeSec: f.dureeSec,
        distanceM: f.distanceM,
        rpe: p?.rpe,
      ));
    }
    return out.isEmpty ? plan : out;
  }

  /// Lignes « avant, après » par exercice ; vide si rien ne change.
  static List<ChangementRoutine> differences(Routine avant, Routine apres, ExerciseRepo exos, UnitePoids u) {
    String resume(List<PlannedSet> l, String exId) {
      final travail = l.where((p) => p.type.counts).toList();
      if (travail.isEmpty) return Fmt.pluriel(l.length, 'série');
      final suivi = exos.byId(exId)?.suivi ?? ExerciseTracking.poidsReps;
      final top = travail.first;
      final charge = suivi.usesWeight && top.poids != null ? '${Fmt.poids(top.poids, u)} × ' : '';
      return '${travail.length} × $charge${top.repsLabel.isEmpty ? '-' : top.repsLabel}';
    }

    final out = <ChangementRoutine>[];
    final restants = [...apres.exercices];
    for (final a in avant.exercices) {
      final i = restants.indexWhere((b) => b.exerciseId == a.exerciseId);
      if (i < 0) {
        out.add(ChangementRoutine(a.exerciseId, resume(a.series, a.exerciseId), 'Retiré', retrait: true));
        continue;
      }
      final b = restants.removeAt(i);
      final ra = resume(a.series, a.exerciseId);
      final rb = resume(b.series, b.exerciseId);
      final memes = a.series.length == b.series.length &&
          [for (var k = 0; k < a.series.length; k++) a.series[k].poids == b.series[k].poids && a.series[k].reps == b.series[k].reps && a.series[k].type == b.series[k].type]
              .every((x) => x);
      if (!memes) out.add(ChangementRoutine(a.exerciseId, ra, rb));
    }
    for (final b in restants) {
      out.add(ChangementRoutine(b.exerciseId, 'Absent', resume(b.series, b.exerciseId), ajout: true));
    }
    return out;
  }
}

/// Routine créée à partir d'une séance (« Enregistrer comme routine »).
Routine routineDepuisSeance(WorkoutSession s, String nom) => Routine(
      id: '',
      nom: nom,
      creeLe: DateTime.now(),
      exercices: [
        for (final e in s.exercices)
          RoutineExercise(
            id: newId(),
            exerciseId: e.exerciseId,
            reposSec: e.reposSec,
            supersetId: e.supersetId,
            notes: e.notes,
            series: [
              for (final x in e.series)
                PlannedSet(type: x.type, poids: x.poids, reps: x.reps, dureeSec: x.dureeSec, distanceM: x.distanceM),
            ],
          ),
      ],
    );

/// Texte à partager d'une séance.
String texteSeance(WorkoutSession s, ExerciseRepo exos, UnitePoids u, {List<PersonalRecord> records = const []}) {
  final b = StringBuffer()
    ..writeln(s.nom)
    ..writeln('${Fmt.jourCap(s.debut)} · ${Fmt.duree(s.duree)} · ${Fmt.volume(s.volume, u)} · ${Fmt.pluriel(s.nbSeriesFaites, 'série')}')
    ..writeln();
  for (final e in s.exercices) {
    final ex = exos.byId(e.exerciseId);
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    b.writeln(exos.nameOf(e.exerciseId));
    var n = 0;
    for (final x in e.seriesFaites) {
      final label = x.type == SetType.normale ? '${++n}' : x.type.label;
      b.writeln('  $label : ${x.resume(suivi, u)}${x.rpe != null ? ' @ RPE ${Fmt.n(x.rpe)}' : ''}');
    }
    if (e.notes != null) b.writeln('  Note : ${e.notes}');
  }
  if (records.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Records battus :');
    for (final r in records) {
      b.writeln('  ${exos.nameOf(r.exerciseId)} : ${r.type.label}, ${texteRecord(r, u)}');
    }
  }
  if (s.notes != null && s.notes!.isNotEmpty) {
    b
      ..writeln()
      ..writeln(s.notes);
  }
  b
    ..writeln()
    ..write('Entraînement noté avec Aesthetics');
  return b.toString();
}

/// Libellés du ressenti, de 1 à 5.
const ressentis = ['Très dur', 'Difficile', 'Correct', 'Bien', 'Excellent'];

/// Écart de volume avec la séance précédente du même nom ou de la même routine.
class Comparaison {
  const Comparaison(this.pourcent, this.reference, {this.aSeriesEgales = false});

  /// Écart arrondi, jamais nul (une séance au même volume ne donne rien).
  final int pourcent;

  /// Nom de la séance de référence (« Push »).
  final String reference;

  /// Vrai quand la séance compte moins de séries que la référence : l'écart
  /// ne porte alors que sur les séries faites des deux côtés.
  final bool aSeriesEgales;

  /// « +4 % », « -3 % » (signe moins ordinaire, pas de tiret long).
  String get texte => '${pourcent > 0 ? '+' : '-'}${pourcent.abs()} %';

  /// « vs dernier Push », « vs dernier Push, à séries égales ».
  String get legende => aSeriesEgales ? 'vs dernier $reference, à séries égales' : 'vs dernier $reference';
}

/// Compare le volume de [s] à la dernière séance d'avant faite avec la même
/// routine (à défaut, du même nom). Null sans référence, sans volume ou sans
/// écart visible.
///
/// Une séance écourtée (moins de séries que la référence) n'est pas comparée
/// en bloc : deux séries contre vingt donneraient « -79 % », qui ne dit rien
/// de la séance. On compare alors série pour série, sur les exercices faits
/// les deux fois : les n premières séries de travail de chacun, n étant le
/// nombre de séries faites aujourd'hui.
Comparaison? comparerAuPrecedent(WorkoutSession s, Iterable<WorkoutSession> toutes) {
  WorkoutSession? ref;
  for (final x in toutes) {
    if (x.id == s.id || x.enCours || !x.debut.isBefore(s.debut) || x.volume <= 0) continue;
    final meme = s.routineId != null ? x.routineId == s.routineId : (x.routineId == null && x.nom == s.nom);
    if (!meme) continue;
    if (ref == null || x.debut.isAfter(ref.debut)) ref = x;
  }
  if (ref == null || s.volume <= 0) return null;
  if (s.nbSeriesFaites >= ref.nbSeriesFaites) {
    final p = ((s.volume - ref.volume) / ref.volume * 100).round();
    return p == 0 ? null : Comparaison(p, ref.nom);
  }
  // Les séries de travail faites, exercice par exercice, dans l'ordre.
  Map<String, List<double>> volumes(WorkoutSession x) {
    final out = <String, List<double>>{};
    for (final e in x.exercices) {
      out.putIfAbsent(e.exerciseId, () => []).addAll(e.seriesFaites.where((w) => w.type.counts).map((w) => w.volume));
    }
    return out;
  }

  final ici = volumes(s), avant = volumes(ref);
  var a = 0.0, b = 0.0;
  for (final e in ici.entries) {
    final r = avant[e.key];
    if (r == null) continue;
    final n = math.min(e.value.length, r.length);
    for (var i = 0; i < n; i++) {
      a += e.value[i];
      b += r[i];
    }
  }
  if (b <= 0) return null;
  final p = ((a - b) / b * 100).round();
  return p == 0 ? null : Comparaison(p, ref.nom, aSeriesEgales: true);
}
