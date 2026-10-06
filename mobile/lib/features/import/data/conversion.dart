import '../../../core/data/store.dart' show newId;
import '../../../core/models/models.dart';
import '../logic/logic.dart';

/// Brouillon d'un exercice personnel créé pendant l'import.
class PersoDraft {
  PersoDraft({required this.nom, Set<Muscle>? muscles, String? equipement})
      : muscles = muscles ?? {},
        equipement = equipement ?? 'autre';

  String nom;
  Set<Muscle> muscles;
  String equipement;

  /// Brouillon tiré de la table de synonymes : nom français, muscles et
  /// matériel déjà remplis.
  factory PersoDraft.depuisModele(ModelePerso m, String nomSource) => PersoDraft(
        nom: m.nom,
        muscles: {
          for (final n in m.muscles)
            if (Muscle.tryParse(n) != null) Muscle.tryParse(n)!,
        },
        equipement: m.equipement ?? PersoDraft.depuisNom(nomSource).equipement,
      );

  /// Brouillon déduit du nom du fichier : matériel reconnu dans le nom.
  factory PersoDraft.depuisNom(String nomSource) {
    final n = sansAccents(nomSource.toLowerCase());
    String eq = 'autre';
    const indices = <String, List<String>>{
      'barre ez': ['ez bar', 'ez-bar', 'barre ez', 'ez curl'],
      'smith': ['smith', 'guidee'],
      'halteres': ['dumbbell', 'haltere', 'halteres'],
      'kettlebell': ['kettlebell'],
      'poulie': ['cable', 'poulie', 'pulley'],
      'machine': ['machine', 'lever', 'hammer strength', 'presse', 'press machine'],
      'elastique': ['band', 'elastique', 'resistance'],
      'poids du corps': ['bodyweight', 'poids du corps', 'pull up', 'push up', 'dips', 'traction', 'pompe'],
      'barre': ['barbell', 'barre'],
    };
    for (final e in indices.entries) {
      if (e.value.any(n.contains)) {
        eq = e.key;
        break;
      }
    }
    return PersoDraft(nom: nomSource.trim(), equipement: eq);
  }

  /// Façon de noter les séries, déduite des données du fichier.
  ExerciseTracking? suivi;

  /// Exercice personnel prêt à enregistrer (identifiant fourni).
  Exercise versExercice(String id, DateTime maintenant) => Exercise(
        id: id,
        nom: nom.trim().isEmpty ? 'Exercice importé' : nom.trim(),
        musclesPrincipaux: muscles.toList(),
        equipement: equipement,
        source: 'import',
        perso: true,
        suiviExplicite: suivi,
        creeLe: maintenant,
      );
}

/// Suivi le plus probable d'après les séries lues.
ExerciseTracking? deduireSuivi(Iterable<ImportedSet> series) {
  var poids = 0, reps = 0, duree = 0, distance = 0, n = 0;
  for (final s in series) {
    n++;
    if ((s.poidsKg ?? 0) > 0) poids++;
    if ((s.reps ?? 0) > 0) reps++;
    if ((s.dureeSec ?? 0) > 0) duree++;
    if ((s.distanceM ?? 0) > 0) distance++;
  }
  if (n == 0) return null;
  if (distance > n / 2) return ExerciseTracking.distanceDuree;
  if (duree > n / 2 && poids > n / 2) return ExerciseTracking.poidsDuree;
  if (duree > n / 2 && reps < n / 2) return ExerciseTracking.duree;
  if (reps > 0 && poids == 0) return ExerciseTracking.repsSeules;
  return ExerciseTracking.poidsReps;
}

/// Type de série de l'appli pour un type lu dans le fichier. Chacun des
/// douze types a son équivalent ; seule une série « unilatérale » sans côté
/// précisé reste une série normale.
SetType typeDepuis(SetKind k) => switch (k) {
      SetKind.normale => SetType.normale,
      SetKind.echauffement => SetType.echauffement,
      SetKind.degressive => SetType.degressive,
      SetKind.echec => SetType.echec,
      SetKind.negative => SetType.negative,
      SetKind.retour => SetType.backOff,
      SetKind.lourde => SetType.topSet,
      SetKind.partielle => SetType.partielles,
      SetKind.unilaterale => SetType.normale,
      SetKind.gauche => SetType.gauche,
      SetKind.droite => SetType.droite,
      SetKind.myoReps => SetType.myoReps,
      SetKind.feeder => SetType.feeder,
    };

/// Une charge ou une distance négative ou non finie n'a pas de sens : elle
/// fausserait le volume et les records. Elle est lue comme absente.
double? _positif(double? v) => v == null || !v.isFinite || v < 0 ? null : v;

/// Durée estimée quand le fichier n'en donne pas de crédible.
Duration dureeEstimee(ImportedSession s) => s.dureeEstimee;

/// Convertit une séance importée en séance de l'appli.
/// [idPour] donne l'identifiant d'exercice pour un nom du fichier
/// (catalogue, perso existant ou perso créé), null pour ignorer l'exercice.
/// [garderEchauffements] garde ou écarte les séries d'échauffement.
/// [estCardio] dit si un exercice est du cardio : une séance qui n'a que du
/// cardio (marche, elliptique) devient une activité cardio.
WorkoutSession convertirSeance(
  ImportedSession s, {
  required String? Function(String nomSource) idPour,
  bool garderEchauffements = true,
  bool Function(String exerciseId)? estCardio,
}) {
  final id = newId();
  final exercices = <SessionExercise>[];
  // Un superset d'un seul exercice n'en est pas un (son partenaire n'avait
  // que des séries vides, ou l'identifiant est resté sur un exercice isolé).
  final tailleGroupe = <String, int>{};
  for (final e in s.exercices) {
    final g = e.supersetGroupe;
    if (g != null && idPour(e.nomSource) != null) tailleGroupe[g] = (tailleGroupe[g] ?? 0) + 1;
  }
  for (final e in s.exercices) {
    final exId = idPour(e.nomSource);
    if (exId == null) continue;
    final series = <WorkoutSet>[
      for (final set in e.series)
        if (garderEchauffements || set.type != SetKind.echauffement)
          WorkoutSet(
            id: newId(),
            type: typeDepuis(set.type),
            poids: _positif(set.poidsKg),
            reps: (set.reps ?? 0) < 0 ? null : set.reps,
            rpe: set.rpe ?? (set.rir == null ? null : (10 - set.rir!).clamp(1, 10).toDouble()),
            fait: true,
            dureeSec: (set.dureeSec ?? 0) < 0 ? null : set.dureeSec,
            distanceM: _positif(set.distanceM),
            faitLe: s.debut,
          ),
    ];
    if (series.isEmpty) continue;
    exercices.add(SessionExercise(
      id: newId(),
      exerciseId: exId,
      series: series,
      supersetId: (tailleGroupe[e.supersetGroupe] ?? 0) < 2 ? null : '$id-${e.supersetGroupe}',
      notes: e.notes,
    ));
  }
  final duree = s.dureeRetenue;
  final cardio = estCardio != null && exercices.isNotEmpty && exercices.every((e) => estCardio(e.exerciseId));
  return WorkoutSession(
    id: id,
    nom: s.titre.trim().isEmpty ? 'Séance' : s.titre.trim(),
    debut: s.debut,
    fin: s.debut.add(duree),
    exercices: exercices,
    notes: s.notes,
    source: 'import',
    type: cardio ? TypeSeance.cardio : TypeSeance.musculation,
  );
}
