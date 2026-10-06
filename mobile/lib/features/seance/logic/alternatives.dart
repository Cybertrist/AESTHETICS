import '../../../core/models/models.dart';

/// Un exercice proposé à la place d'un autre, avec ce qui le rapproche.
class Alternative {
  const Alternative(this.exercise, this.score, this.raisons);

  final Exercise exercise;
  final double score;

  /// Étiquettes courtes : « Mêmes muscles », « Plus simple à installer »...
  final List<String> raisons;
}

/// Matériel qui ne demande aucune installation, du plus simple au moins simple.
const _simples = ['poids du corps', 'halteres', 'kettlebell', 'elastique', 'machine', 'poulie'];

/// Exercices proches de [actuel] : mêmes muscles principaux d'abord, même
/// mécanique ensuite ; le premier est l'alternative conseillée. [exclus] :
/// exercices déjà dans la séance.
List<Alternative> alternativesPour(Exercise actuel, Iterable<Exercise> catalogue, {Set<String> exclus = const {}, int max = 6}) {
  final principaux = actuel.musclesPrincipaux.toSet();
  if (principaux.isEmpty) return const [];
  final secondaires = actuel.musclesSecondaires.toSet();
  final out = <Alternative>[];
  for (final e in catalogue) {
    if (e.id == actuel.id || exclus.contains(e.id)) continue;
    final communs = e.musclesPrincipaux.toSet().intersection(principaux);
    if (communs.isEmpty) continue;
    // Le muscle visé en premier doit être le même.
    if (e.musclesPrincipaux.isEmpty || !principaux.contains(e.musclesPrincipaux.first)) continue;
    final memesMuscles = communs.length == principaux.length && e.musclesPrincipaux.length == principaux.length;
    final memeMecanique = actuel.mecanique != null && e.mecanique == actuel.mecanique;
    final autreMateriel = e.equipement != actuel.equipement;
    final plusSimple = _simples.contains(e.equipement) &&
        (!_simples.contains(actuel.equipement) || _simples.indexOf(e.equipement) < _simples.indexOf(actuel.equipement));
    var score = communs.length * 3.0;
    if (memesMuscles) score += 2;
    if (memeMecanique) score += 2;
    if (e.suivi == actuel.suivi) score += 1.5;
    if (e.categorie == actuel.categorie) score += 1;
    score += e.musclesSecondaires.toSet().intersection(secondaires).length * 0.5;
    // Une alternative sert quand le poste est pris : un autre matériel aide.
    if (autreMateriel) score += 1.5;
    if (plusSimple) score += 0.5;
    if (e.media.thumbnail != null) score += 0.5;
    out.add(Alternative(e, score, [
      if (memesMuscles) 'Mêmes muscles' else 'Muscles proches',
      if (plusSimple) 'Plus simple à installer' else if (autreMateriel) 'Autre matériel',
    ]));
  }
  out.sort((a, b) {
    final s = b.score.compareTo(a.score);
    return s != 0 ? s : a.exercise.nom.compareTo(b.exercise.nom);
  });
  return out.take(max).toList();
}

/// Libellé français d'un niveau du catalogue.
String? libelleNiveau(String? niveau) => switch (niveau) {
      'debutant' => 'Débutant',
      'intermediaire' => 'Intermédiaire',
      'avance' => 'Avancé',
      null || '' => null,
      _ => niveau[0].toUpperCase() + niveau.substring(1),
    };
