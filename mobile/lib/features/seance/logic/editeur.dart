import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Modifie une séance : la séance en cours (enregistrée à chaque geste dans
/// le SessionRepo) ou une copie de travail d'une séance passée.
abstract class SeanceEditeur extends ChangeNotifier {
  SeanceEditeur(this.repo);

  final SessionRepo repo;

  WorkoutSession? get session;

  /// Vrai pour la séance en cours (chrono, minuteur de repos).
  bool get enDirect;

  Future<void> commit(WorkoutSession s);

  Future<void> mutate(WorkoutSession Function(WorkoutSession s) change) async {
    final s = session;
    if (s == null) return;
    await commit(change(s));
  }

  SessionExercise? exercice(String seId) {
    for (final e in session?.exercices ?? const <SessionExercise>[]) {
      if (e.id == seId) return e;
    }
    return null;
  }

  Future<void> updateExercise(String seId, SessionExercise Function(SessionExercise e) change) =>
      mutate((s) => s.copyWith(exercices: [for (final e in s.exercices) e.id == seId ? change(e) : e]));

  /// Séries préremplies avec la dernière performance de l'exercice.
  List<WorkoutSet> seriesDepart(String exerciseId, {int nombre = 3}) {
    final last = repo.lastFor(exerciseId)?.series.where((s) => s.fait).toList() ?? const <WorkoutSet>[];
    final series = last.isEmpty
        ? [for (var i = 0; i < nombre; i++) WorkoutSet(id: newId())]
        : [
            for (final s in last)
              WorkoutSet(id: newId(), type: s.type, poids: s.poids, reps: s.reps, dureeSec: s.dureeSec, distanceM: s.distanceM),
          ];
    // Un exercice unilatéral : une série à gauche, une à droite.
    return repo.estUnilateral(exerciseId) ? Unilateral.series(series, newId) : series;
  }

  Future<void> ajouterExercices(List<String> ids, {int reposSec = 90}) => mutate((s) => s.copyWith(exercices: [
        ...s.exercices,
        for (final id in ids) SessionExercise(id: newId(), exerciseId: id, reposSec: reposSec, series: seriesDepart(id)),
      ]));

  /// Remplace l'exercice en gardant le nombre de séries et leurs types.
  ///
  /// Les séries déjà validées appartiennent à l'ancien exercice : avec
  /// [garderFaites], il reste dans la séance avec elles seules et le nouvel
  /// exercice prend la suite avec les séries qui restaient à faire. Sinon
  /// tout est remplacé et les séries validées sont perdues.
  Future<void> remplacerExercice(String seId, String nouvelId, {bool garderFaites = false}) => mutate((s) {
        final e = s.exercices.where((x) => x.id == seId).firstOrNull;
        if (e == null) return s;
        final faites = e.seriesFaites;
        final scinder = garderFaites && faites.isNotEmpty;
        final aRefaire = scinder ? e.series.where((x) => !x.fait).toList() : e.series;
        final depart = seriesDepart(nouvelId, nombre: aRefaire.isEmpty ? 1 : aRefaire.length);
        final series = <WorkoutSet>[
          for (var i = 0; i < aRefaire.length; i++)
            WorkoutSet(
              id: aRefaire[i].id,
              type: aRefaire[i].type,
              poids: i < depart.length ? depart[i].poids : null,
              reps: i < depart.length ? depart[i].reps : null,
              dureeSec: i < depart.length ? depart[i].dureeSec : null,
              distanceM: i < depart.length ? depart[i].distanceM : null,
            ),
        ];
        final nouveau = SessionExercise(
          id: scinder ? newId() : e.id,
          exerciseId: nouvelId,
          series: series.isEmpty ? depart : series,
          reposSec: e.reposSec,
          supersetId: e.supersetId,
          notes: scinder ? null : e.notes,
        );
        return s.copyWith(exercices: [
          for (final x in s.exercices)
            if (x.id != seId) x else ...[if (scinder) e.copyWith(series: faites), nouveau],
        ]);
      });

  Future<void> supprimerExercice(String seId) => mutate((s) {
        final restants = s.exercices.where((e) => e.id != seId).toList();
        return s.copyWith(exercices: _nettoyerSupersets(restants));
      });

  Future<void> reordonner(List<String> seIds) => mutate((s) {
        final par = {for (final e in s.exercices) e.id: e};
        final liste = [for (final id in seIds) if (par[id] != null) par[id]!];
        for (final e in s.exercices) {
          if (!seIds.contains(e.id)) liste.add(e);
        }
        return s.copyWith(exercices: _nettoyerSupersets(liste));
      });

  Future<void> deplacer(String seId, int delta) async {
    final ids = session?.exercices.map((e) => e.id).toList() ?? [];
    final i = ids.indexOf(seId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= ids.length) return;
    ids.insert(j, ids.removeAt(i));
    await reordonner(ids);
  }

  /// Un superset n'a de sens qu'entre exercices voisins : on retire l'id des
  /// exercices isolés après un déplacement ou une suppression.
  static List<SessionExercise> _nettoyerSupersets(List<SessionExercise> liste) {
    final out = <SessionExercise>[];
    for (var i = 0; i < liste.length; i++) {
      final e = liste[i];
      final id = e.supersetId;
      if (id == null) {
        out.add(e);
        continue;
      }
      final avant = i > 0 && liste[i - 1].supersetId == id;
      final apres = i < liste.length - 1 && liste[i + 1].supersetId == id;
      out.add(avant || apres ? e : e.copyWith(clearSuperset: true));
    }
    return out;
  }

  /// Relie l'exercice au suivant en superset.
  Future<void> lierAuSuivant(String seId) => mutate((s) {
        final i = s.exercices.indexWhere((e) => e.id == seId);
        if (i < 0 || i >= s.exercices.length - 1) return s;
        final a = s.exercices[i];
        final b = s.exercices[i + 1];
        final id = a.supersetId ?? b.supersetId ?? newId();
        final ancienB = b.supersetId;
        final liste = [
          for (final e in s.exercices)
            if (e.id == a.id || e.id == b.id || (ancienB != null && e.supersetId == ancienB))
              e.copyWith(supersetId: id)
            else
              e,
        ];
        return s.copyWith(exercices: _nettoyerSupersets(liste));
      });

  Future<void> sortirDuSuperset(String seId) => mutate((s) => s.copyWith(
      exercices: _nettoyerSupersets([for (final e in s.exercices) e.id == seId ? e.copyWith(clearSuperset: true) : e])));

  /// Lettre du superset (A, B…) dans l'ordre d'apparition.
  String? lettreSuperset(String? supersetId) => lettreSupersetDans(session?.exercices ?? const [], supersetId);

  /// Dernier exercice de son superset (le repos démarre après lui).
  bool finDeSuperset(String seId) {
    final l = session?.exercices ?? const <SessionExercise>[];
    final i = l.indexWhere((e) => e.id == seId);
    if (i < 0) return true;
    final id = l[i].supersetId;
    if (id == null) return true;
    return i == l.length - 1 || l[i + 1].supersetId != id;
  }

  Future<void> notes(String seId, String? texte) =>
      updateExercise(seId, (e) => SessionExercise(
            id: e.id,
            exerciseId: e.exerciseId,
            series: e.series,
            reposSec: e.reposSec,
            supersetId: e.supersetId,
            notes: (texte ?? '').trim().isEmpty ? null : texte!.trim(),
          ));

  Future<void> repos(String seId, int sec) => updateExercise(seId, (e) => e.copyWith(reposSec: sec));

  Future<void> ajouterSerie(String seId) => updateExercise(seId, (e) {
        final last = e.series.isNotEmpty ? e.series.last : null;
        return e.copyWith(series: [
          ...e.series,
          WorkoutSet(
            id: newId(),
            type: last?.type == SetType.echauffement ? SetType.normale : (last?.type ?? SetType.normale),
            poids: last?.poids,
            reps: last?.reps,
            dureeSec: last?.dureeSec,
            distanceM: last?.distanceM,
            fait: !enDirect,
          ),
        ]);
      });

  Future<void> supprimerSerie(String seId, String setId) =>
      updateExercise(seId, (e) => e.copyWith(series: e.series.where((x) => x.id != setId).toList()));

  /// Remet une série supprimée à sa place (annulation).
  Future<void> restaurerSerie(String seId, WorkoutSet set, int index) => updateExercise(seId, (e) {
        final l = [...e.series];
        l.insert(index.clamp(0, l.length), set);
        return e.copyWith(series: l);
      });

  Future<void> majSerie(String seId, WorkoutSet set) =>
      updateExercise(seId, (e) => e.copyWith(series: [for (final x in e.series) x.id == set.id ? set : x]));

  /// Change le type d'une série sans toucher à ses autres valeurs, lues au
  /// dernier moment : un repos noté entre-temps n'est pas écrasé.
  Future<void> changerType(String seId, String setId, SetType type) => updateExercise(
      seId, (e) => e.copyWith(series: [for (final x in e.series) x.id == setId ? x.copyWith(type: type) : x]));

  /// Enregistre les valeurs de [set] et son état, validé ou non, en une seule
  /// écriture. Rend vrai si l'état a changé : deux appuis coup sur coup sur la
  /// coche ne valident (et ne lancent le repos) qu'une fois et ne dévalident
  /// jamais par accident.
  Future<bool> validerSerie(String seId, WorkoutSet set, {required bool fait}) async {
    var change = false;
    await updateExercise(seId, (e) => e.copyWith(series: [
          for (final x in e.series)
            if (x.id == set.id) () {
              change = x.fait != fait;
              return WorkoutSet(
                id: x.id,
                type: x.type,
                poids: set.poids,
                reps: set.reps,
                rpe: set.rpe,
                fait: fait,
                tempsReposSec: fait ? x.tempsReposSec : null,
                dureeSec: set.dureeSec,
                distanceM: set.distanceM,
                faitLe: fait ? (x.fait ? x.faitLe : DateTime.now()) : null,
              );
            }()
            else
              x,
        ]));
    return change;
  }

  /// Coche ou décoche ; rend le nouvel état.
  Future<bool> basculerSerie(String seId, String setId) async {
    var fait = false;
    await updateExercise(seId, (e) => e.copyWith(series: [
          for (final x in e.series)
            if (x.id == setId) () {
              fait = !x.fait;
              return WorkoutSet(
                id: x.id,
                type: x.type,
                poids: x.poids,
                reps: x.reps,
                rpe: x.rpe,
                fait: fait,
                tempsReposSec: x.tempsReposSec,
                dureeSec: x.dureeSec,
                distanceM: x.distanceM,
                faitLe: fait ? DateTime.now() : null,
              );
            }()
            else
              x,
        ]));
    return fait;
  }

  /// Ajoute des séries d'échauffement en tête de l'exercice.
  Future<void> ajouterEchauffement(String seId, List<({double poids, int reps})> paliers) => updateExercise(
      seId,
      (e) => e.copyWith(series: [
            for (final p in paliers)
              WorkoutSet(id: newId(), type: SetType.echauffement, poids: p.poids, reps: p.reps, fait: !enDirect),
            ...e.series.where((x) => x.type != SetType.echauffement || x.fait),
          ]));

  /// Coche toutes les séries remplies (poids, reps ou durée saisis).
  Future<int> cocherRemplies() async {
    var n = 0;
    await mutate((s) => s.copyWith(exercices: [
          for (final e in s.exercices)
            e.copyWith(series: [
              for (final x in e.series)
                if (!x.fait && ((x.reps ?? 0) > 0 || (x.dureeSec ?? 0) > 0 || (x.distanceM ?? 0) > 0)) () {
                  n++;
                  return x.copyWith(fait: true, faitLe: DateTime.now());
                }()
                else
                  x,
            ]),
        ]));
    return n;
  }
}

/// Séance en cours : chaque geste est gardé sur disque par le SessionRepo.
class EditeurDirect extends SeanceEditeur {
  EditeurDirect(super.repo) {
    repo.addListener(notifyListeners);
  }

  @override
  WorkoutSession? get session => repo.active;

  @override
  bool get enDirect => true;

  @override
  Future<void> commit(WorkoutSession s) => repo.updateActive(s);

  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Copie de travail d'une séance passée, enregistrée à la demande.
class EditeurBrouillon extends SeanceEditeur {
  EditeurBrouillon(super.repo, WorkoutSession depart) : _s = depart, _depart = depart;

  WorkoutSession _s;
  final WorkoutSession _depart;
  bool _modifie = false;

  bool get modifie => _modifie;
  WorkoutSession get depart => _depart;

  @override
  WorkoutSession get session => _s;

  @override
  bool get enDirect => false;

  @override
  Future<void> commit(WorkoutSession s) async {
    _s = s;
    _modifie = true;
    notifyListeners();
  }

  /// Enregistre dans l'historique ; les séries non cochées sont retirées.
  Future<WorkoutSession> enregistrer() async {
    final propre = _s.copyWith(exercices: [
      for (final e in _s.exercices)
        if (e.seriesFaites.isNotEmpty) e.copyWith(series: e.seriesFaites),
    ]);
    await repo.save(propre);
    _modifie = false;
    return propre;
  }
}

/// Petits calculs d'affichage sur une série.
extension SerieTexte on WorkoutSet {
  String resume(ExerciseTracking suivi, UnitePoids u) {
    final parts = <String>[];
    if (suivi.usesWeight && poids != null) {
      final signe = suivi == ExerciseTracking.poidsDuCorpsAssiste ? '-' : (suivi == ExerciseTracking.poidsDuCorpsLeste && (poids ?? 0) > 0 ? '+' : '');
      parts.add('$signe${Fmt.poids(poids, u)}');
    }
    if (suivi.usesReps && reps != null) parts.add('$reps');
    if (suivi.usesDistance && distanceM != null) parts.add(Affichage.distance(distanceM!));
    if (suivi.usesDuration && dureeSec != null) parts.add(Fmt.chrono(Duration(seconds: dureeSec!)));
    if (parts.isEmpty) return '-';
    if (suivi.usesWeight && suivi.usesReps && parts.length == 2) return '${parts[0]} × ${parts[1]}';
    if (!suivi.usesWeight && suivi.usesReps && parts.length == 1) return Fmt.pluriel(reps!, 'rép.', 'rép.');
    return parts.join(' · ');
  }
}

/// Lettre du superset (A, B…) dans l'ordre d'apparition.
String? lettreSupersetDans(List<SessionExercise> exercices, String? supersetId) {
  if (supersetId == null) return null;
  final vus = <String>[];
  for (final e in exercices) {
    final id = e.supersetId;
    if (id != null && !vus.contains(id)) vus.add(id);
  }
  final i = vus.indexOf(supersetId);
  return i < 0 ? null : String.fromCharCode(65 + i % 26);
}
