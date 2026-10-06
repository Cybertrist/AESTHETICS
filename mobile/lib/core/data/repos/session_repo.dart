import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../logic/dates.dart';
import '../../logic/strength.dart';
import '../../logic/unilateral.dart';
import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Une apparition d'un exercice dans l'historique.
typedef ExerciseHistoryEntry = ({WorkoutSession session, SessionExercise exercise});

/// Résultat de la fin d'une séance.
typedef FinishResult = ({WorkoutSession session, List<PersonalRecord> records});

/// Historique des séances et séance en cours (gardée sur disque pour
/// survivre à la fermeture de l'appli).
class SessionRepo extends ChangeNotifier {
  SessionRepo(this.store)
      : _sessions = JsonCollection(store: store, name: 'seances', fromJson: WorkoutSession.fromJson, toJson: (s) => s.toJson(), idOf: (s) => s.id);

  final Store store;
  final JsonCollection<WorkoutSession> _sessions;
  static const _activeFile = 'seance_active';

  List<WorkoutSession> _sorted = [];
  WorkoutSession? _active;

  /// Séances terminées, la plus récente d'abord.
  List<WorkoutSession> get sessions => _sorted;
  WorkoutSession? get active => _active;
  bool get hasActive => _active != null;

  Future<void> load() async {
    await _sessions.load();
    final a = await store.readObject(_activeFile);
    try {
      _active = a == null ? null : WorkoutSession.fromJson(a);
    } catch (_) {
      // Une séance en cours illisible ne doit pas cacher tout l'historique.
      _active = null;
    }
    _resort();
    notifyListeners();
  }

  void _resort() {
    _sorted = [..._sessions.items]..sort((a, b) => b.debut.compareTo(a.debut));
  }

  WorkoutSession? byId(String id) => _active?.id == id ? _active : _sessions.byId(id);

  // Historique

  Future<void> save(WorkoutSession s) async {
    await _sessions.upsert(s);
    _resort();
    notifyListeners();
  }

  Future<void> addAll(List<WorkoutSession> list) async {
    await _sessions.upsertAll(list);
    _resort();
    notifyListeners();
  }

  /// Supprime une séance et les fichiers de ses photos et vidéos. Avec
  /// [garderMedias], les fichiers restent (suppression annulable) : à
  /// l'appelant de finir par [supprimerMedias].
  Future<void> delete(String id, {bool garderMedias = false}) async {
    final s = _sessions.byId(id);
    await _sessions.remove(id);
    _resort();
    notifyListeners();
    if (s != null && !garderMedias) await supprimerMedias(s);
  }

  /// Supprime les fichiers des médias de [s], séance supprimée ou
  /// abandonnée. Ne touche qu'aux copies gardées par l'appli (dossier
  /// `medias_seances`), jamais à un fichier de la galerie, et laisse ceux
  /// qu'une autre séance (ou [s] elle-même, si elle a été restaurée) utilise.
  Future<void> supprimerMedias(WorkoutSession s) async {
    if (s.medias.isEmpty) return;
    final gardes = {
      for (final x in [..._sessions.items, ?_active])
        for (final m in x.medias) m.chemin,
    };
    for (final m in s.medias) {
      if (gardes.contains(m.chemin) || !m.chemin.replaceAll(r'\', '/').contains('/medias_seances/')) continue;
      try {
        final f = File(m.chemin);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    await _sessions.clear();
    await store.delete(_activeFile);
    _active = null;
    _resort();
    notifyListeners();
  }

  List<WorkoutSession> sessionsOn(DateTime day) => _sorted.where((s) => Dates.memeJour(s.debut, day)).toList();

  List<WorkoutSession> sessionsBetween(DateTime from, DateTime to) =>
      _sorted.where((s) => !s.debut.isBefore(from) && s.debut.isBefore(to)).toList();

  List<WorkoutSession> sessionsThisWeek({DateTime? now, int premierJour = DateTime.monday}) {
    final start = Dates.debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
    return sessionsBetween(start, Dates.finSemaine(start, premierJour: premierJour));
  }

  /// Semaines d'affilée avec au moins une séance.
  int streakWeeks({DateTime? now}) => Dates.semainesConsecutives(_sorted.map((s) => s.debut), now: now);

  WorkoutSession? lastForRoutine(String routineId) => _sorted.firstWhereOrNull((s) => s.routineId == routineId);

  /// Toutes les fois où l'exercice a été fait, la plus récente d'abord.
  List<ExerciseHistoryEntry> historyFor(String exerciseId) => [
        for (final s in _sorted)
          for (final e in s.exercices)
            if (e.exerciseId == exerciseId && e.seriesFaites.isNotEmpty) (session: s, exercise: e),
      ];

  /// Dernière performance, pour la colonne « Précédent » pendant la séance.
  /// Avec [routineId], la dernière fois dans cette routine passe d'abord ;
  /// faute de quoi on retombe sur la dernière fois tout court.
  SessionExercise? lastFor(String exerciseId, {String? routineId}) {
    if (routineId != null) {
      for (final s in _sorted) {
        if (s.routineId != routineId) continue;
        for (final e in s.exercices) {
          if (e.exerciseId == exerciseId && e.seriesFaites.isNotEmpty) return e;
        }
      }
    }
    for (final s in _sorted) {
      for (final e in s.exercices) {
        if (e.exerciseId == exerciseId && e.seriesFaites.isNotEmpty) return e;
      }
    }
    return null;
  }

  ExerciseBests bestsFor(String exerciseId) => Strength.bests(exerciseId, _sorted);

  /// Identifiants des exercices déjà faits, du plus récent au plus ancien.
  List<String> recentExerciseIds({int limit = 30}) {
    final seen = <String>{};
    for (final s in _sorted) {
      for (final e in s.exercices) {
        seen.add(e.exerciseId);
        if (seen.length >= limit) return seen.toList();
      }
    }
    return seen.toList();
  }

  // Séance en cours

  Future<void> _persistActive() async {
    final a = _active;
    if (a == null) {
      await store.delete(_activeFile);
    } else {
      await store.write(_activeFile, a.toJson());
    }
  }

  /// Démarre une séance vide.
  Future<WorkoutSession> startEmpty({String nom = 'Séance libre'}) async {
    _active = WorkoutSession(id: newId(), nom: nom, debut: DateTime.now());
    notifyListeners();
    await _persistActive();
    return _active!;
  }

  /// Démarre une séance depuis une routine : séries prévues, complétées par la
  /// dernière performance quand la routine ne précise pas de charge.
  /// Dit si un exercice se fait un côté après l'autre (branché par `AppData`
  /// sur le catalogue) : ses séries partent alors par paires gauche, droite.
  bool Function(String exerciseId) estUnilateral = (_) => false;

  Future<WorkoutSession> startFromRoutine(Routine r, {String? programId}) async {
    final exercices = <SessionExercise>[];
    for (final re in r.exercices) {
      final prevues = estUnilateral(re.exerciseId) ? Unilateral.prevues(re.series) : re.series;
      final last = lastFor(re.exerciseId);
      final lastSets = last?.series.where((s) => s.fait).toList() ?? const <WorkoutSet>[];
      final sets = <WorkoutSet>[];
      for (var i = 0; i < prevues.length; i++) {
        final p = prevues[i];
        final prev = i < lastSets.length ? lastSets[i] : (lastSets.isNotEmpty ? lastSets.last : null);
        sets.add(WorkoutSet(
          id: newId(),
          type: p.type.aReprendre,
          poids: p.poids ?? prev?.poids,
          reps: p.reps ?? prev?.reps,
          rpe: p.rpe,
          dureeSec: p.dureeSec ?? prev?.dureeSec,
          distanceM: p.distanceM ?? prev?.distanceM,
        ));
      }
      exercices.add(SessionExercise(
        id: newId(),
        exerciseId: re.exerciseId,
        series: sets,
        reposSec: re.reposSec,
        supersetId: re.supersetId,
        notes: re.notes,
      ));
    }
    _active = WorkoutSession(
      id: newId(),
      nom: r.nom,
      debut: DateTime.now(),
      routineId: r.id,
      programId: programId,
      exercices: exercices,
    );
    notifyListeners();
    await _persistActive();
    return _active!;
  }

  /// Remplace la séance en cours (chaque modification est enregistrée).
  Future<void> updateActive(WorkoutSession s) async {
    _active = s;
    notifyListeners();
    await _persistActive();
  }

  Future<void> mutateActive(WorkoutSession Function(WorkoutSession s) change) async {
    final a = _active;
    if (a == null) return;
    await updateActive(change(a));
  }

  /// Ajoute un exercice avec [sets] séries vides (reprend la dernière performance).
  Future<SessionExercise?> addExerciseToActive(String exerciseId, {int sets = 3, int reposSec = 90}) async {
    final a = _active;
    if (a == null) return null;
    final last = lastFor(exerciseId)?.series.where((s) => s.fait).toList() ?? const <WorkoutSet>[];
    final se = SessionExercise(
      id: newId(),
      exerciseId: exerciseId,
      reposSec: reposSec,
      series: [
        for (var i = 0; i < sets; i++)
          WorkoutSet(
            id: newId(),
            poids: i < last.length ? last[i].poids : null,
            reps: i < last.length ? last[i].reps : null,
          ),
      ],
    );
    await updateActive(a.copyWith(exercices: [...a.exercices, se]));
    return se;
  }

  /// Modifie un exercice de la séance en cours.
  Future<void> updateActiveExercise(String sessionExerciseId, SessionExercise Function(SessionExercise e) change) =>
      mutateActive((s) => s.copyWith(exercices: [
            for (final e in s.exercices) e.id == sessionExerciseId ? change(e) : e,
          ]));

  Future<void> removeActiveExercise(String sessionExerciseId) =>
      mutateActive((s) => s.copyWith(exercices: s.exercices.where((e) => e.id != sessionExerciseId).toList()));

  /// Ajoute une série copiée sur la dernière de l'exercice.
  Future<void> addSet(String sessionExerciseId) => updateActiveExercise(sessionExerciseId, (e) {
        final last = e.series.isNotEmpty ? e.series.last : null;
        return e.copyWith(series: [
          ...e.series,
          WorkoutSet(id: newId(), type: SetType.normale, poids: last?.poids, reps: last?.reps, dureeSec: last?.dureeSec, distanceM: last?.distanceM),
        ]);
      });

  Future<void> updateSet(String sessionExerciseId, WorkoutSet set) => updateActiveExercise(
      sessionExerciseId, (e) => e.copyWith(series: [for (final s in e.series) s.id == set.id ? set : s]));

  Future<void> removeSet(String sessionExerciseId, String setId) => updateActiveExercise(
      sessionExerciseId, (e) => e.copyWith(series: e.series.where((s) => s.id != setId).toList()));

  /// Coche ou décoche une série.
  Future<void> toggleSetDone(String sessionExerciseId, String setId) => updateActiveExercise(sessionExerciseId, (e) {
        return e.copyWith(series: [
          for (final s in e.series)
            s.id == setId ? s.copyWith(fait: !s.fait, faitLe: DateTime.now()) : s,
        ]);
      });

  /// Termine la séance : garde les séries faites, calcule les records battus.
  /// [debut], [type] et [medias] corrigent la séance au moment de la clore.
  Future<FinishResult?> finishActive({
    String? nom,
    String? notes,
    int? ressenti,
    DateTime? debut,
    DateTime? fin,
    TypeSeance? type,
    List<SessionMedia>? medias,
  }) async {
    final a = _active;
    if (a == null) return null;
    final exercices = [
      for (final e in a.exercices)
        if (e.seriesFaites.isNotEmpty) e.copyWith(series: e.seriesFaites),
    ];
    final done = a.copyWith(
      nom: nom,
      notes: notes,
      ressenti: ressenti,
      debut: debut,
      fin: fin ?? DateTime.now(),
      type: type,
      medias: medias,
      exercices: exercices,
    );
    final records = Strength.newRecords(done, _sorted);
    _active = null;
    await _sessions.upsert(done);
    _resort();
    notifyListeners();
    await _persistActive();
    return (session: done, records: records);
  }

  /// Abandonne la séance en cours sans rien garder.
  Future<void> discardActive() async {
    final a = _active;
    _active = null;
    notifyListeners();
    await _persistActive();
    if (a != null) await supprimerMedias(a);
  }
}
