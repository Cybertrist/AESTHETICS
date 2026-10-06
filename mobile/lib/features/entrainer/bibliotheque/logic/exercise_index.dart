import '../../../../core/logic/text_search.dart';
import '../../../../core/models/models.dart';

/// Filtre de liste rapide (onglets de la bibliothèque).
enum LibraryScope {
  tous('Tous'),
  recents('Récents'),

  /// Les exercices déjà faits : ceux de l'historique, avec au moins une série validée.
  effectues('Effectués'),
  favoris('Favoris'),
  perso('Mes exercices');

  const LibraryScope(this.label);
  final String label;
}

/// Ordre de la liste.
enum LibrarySort {
  nom('Nom'),
  frequence('Les plus faits'),
  recent('Faits récemment');

  const LibrarySort(this.label);
  final String label;
}

/// Filtres combinables de la bibliothèque et du sélecteur.
class LibraryFilters {
  const LibraryFilters({
    this.query = '',
    this.scope = LibraryScope.tous,
    this.muscles = const {},
    this.equipements = const {},
    this.categories = const {},
    this.principauxSeulement = false,
    this.sort = LibrarySort.frequence,
  });

  final String query;
  final LibraryScope scope;
  final Set<Muscle> muscles;
  final Set<String> equipements;
  final Set<String> categories;

  /// Muscles ciblés en principal seulement (sinon principal ou secondaire).
  final bool principauxSeulement;

  /// Par défaut : les exercices les plus faits d'abord, puis l'alphabet.
  final LibrarySort sort;

  /// Nombre de filtres actifs hors recherche et onglet.
  int get actifs => muscles.length + equipements.length + categories.length;

  bool get vide => actifs == 0 && query.trim().isEmpty && scope == LibraryScope.tous;

  LibraryFilters copyWith({
    String? query,
    LibraryScope? scope,
    Set<Muscle>? muscles,
    Set<String>? equipements,
    Set<String>? categories,
    bool? principauxSeulement,
    LibrarySort? sort,
  }) =>
      LibraryFilters(
        query: query ?? this.query,
        scope: scope ?? this.scope,
        muscles: muscles ?? this.muscles,
        equipements: equipements ?? this.equipements,
        categories: categories ?? this.categories,
        principauxSeulement: principauxSeulement ?? this.principauxSeulement,
        sort: sort ?? this.sort,
      );

  LibraryFilters sansFiltres() => LibraryFilters(query: query, scope: scope, sort: sort);
}

/// Mots courants qu'on tape pour un muscle sans qu'ils soient dans son nom
/// (« pecs », « ischios »...), ajoutés au texte cherché.
const _motsMuscle = <Muscle, String>{
  Muscle.pectoraux: 'pecs poitrine',
  Muscle.deltoidesAnterieurs: 'epaules',
  Muscle.deltoidesLateraux: 'epaules',
  Muscle.deltoidesPosterieurs: 'epaules',
  Muscle.grandDorsal: 'dos dorsaux',
  Muscle.trapezes: 'dos',
  Muscle.rhomboides: 'dos',
  Muscle.lombaires: 'dos bas du dos',
  Muscle.abdominaux: 'abdos',
  Muscle.obliques: 'abdos',
  Muscle.quadriceps: 'cuisses quads jambes',
  Muscle.ischios: 'ischios jambes',
  Muscle.adducteurs: 'cuisses jambes',
  Muscle.abducteurs: 'jambes',
  Muscle.mollets: 'jambes',
  Muscle.cou: 'nuque',
};

/// Entrée indexée : textes déjà normalisés, pour une recherche instantanée
/// sur plus de 1 300 exercices.
class _Entry {
  _Entry(this.exercise)
      : titre = TextSearch.normalize(exercise.nom),
        mots = TextSearch.normalize(exercise.nom).split(' '),
        autresNoms = [
          for (final a in [exercise.nomEn, ...exercise.alias].whereType<String>()) TextSearch.normalize(a),
        ],
        premierMuscle = exercise.musclesPrincipaux.isEmpty
            ? ''
            : ' ${TextSearch.normalize([
                exercise.musclesPrincipaux.first.label,
                exercise.musclesPrincipaux.first.region.name,
                ?_motsMuscle[exercise.musclesPrincipaux.first],
              ].join(' '))}',
        muscles = ' ${TextSearch.normalize([
          for (final m in exercise.musclesPrincipaux) ...[m.label, m.region.name, ?_motsMuscle[m]],
        ].join(' '))}',
        // Une espace en tête : on cherche des débuts de mot, pas des morceaux
        // (« dos » ne doit pas trouver « abdos »).
        reste = ' ${TextSearch.normalize([
          exercise.nomEn,
          ...exercise.alias,
          exercise.equipementLabel,
          exercise.categorieLabel,
          for (final m in exercise.musclesPrincipaux) ...[m.label, ?_motsMuscle[m]],
        ].whereType<String>().join(' '))}';

  final Exercise exercise;
  final String titre;
  final List<String> mots;

  /// Nom anglais et alias, un par un.
  final List<String> autresNoms;

  /// Muscles principaux et leurs noms courants (« dos », « pecs »).
  final String muscles;

  /// Les mêmes mots pour le premier muscle principal seulement.
  final String premierMuscle;
  final String reste;

  int score(String q, List<String> qMots) {
    if (titre == q) return 100;
    if (titre.startsWith(q)) return 80;
    // Un alias exact (« bench », « dc ») vaut presque le nom lui-même.
    if (autresNoms.contains(q)) return 70;
    // Le muscle principal passe avant un mot du nom : « dos » donne les
    // tractions et les rowings avant le « shrug derrière le dos ».
    if (q.length >= 3 && premierMuscle.contains(' $q')) return 67;
    if (q.length >= 3 && muscles.contains(' $q')) return 65;
    if (mots.any((w) => w.startsWith(q))) return 60;
    if (titre.contains(q)) return 50;
    if (qMots.every(titre.contains)) return 40;
    if (autresNoms.any((a) => a.startsWith(q))) return 35;
    if (reste.contains(' $q')) return 30;
    if (qMots.every((m) => titre.contains(m) || reste.contains(' $m'))) return 20;
    return 0;
  }
}

/// Index de recherche : le catalogue est indexé une fois, les exercices
/// perso à chaque changement (ils sont peu nombreux).
class ExerciseIndex {
  List<Exercise>? _catalogueRef;
  List<_Entry> _catalogue = const [];

  List<_Entry> _entries(List<Exercise> catalogue, List<Exercise> perso) {
    if (!identical(catalogue, _catalogueRef)) {
      _catalogueRef = catalogue;
      _catalogue = [for (final e in catalogue) _Entry(e)];
    }
    return [for (final e in perso) _Entry(e), ..._catalogue];
  }

  /// Applique recherche, onglet, filtres et tri.
  List<Exercise> filtrer({
    required List<Exercise> catalogue,
    required List<Exercise> perso,
    required LibraryFilters filtres,
    required Set<String> favoris,
    required List<String> recents,
    required Map<String, int> frequences,
  }) {
    Iterable<_Entry> it = _entries(catalogue, perso);
    switch (filtres.scope) {
      case LibraryScope.tous:
        break;
      case LibraryScope.favoris:
        it = it.where((e) => favoris.contains(e.exercise.id));
      case LibraryScope.perso:
        it = it.where((e) => e.exercise.perso);
      case LibraryScope.recents:
        final set = recents.toSet();
        it = it.where((e) => set.contains(e.exercise.id));
      case LibraryScope.effectues:
        it = it.where((e) => (frequences[e.exercise.id] ?? 0) > 0);
    }
    if (filtres.muscles.isNotEmpty) {
      it = it.where((e) => (filtres.principauxSeulement ? e.exercise.musclesPrincipaux : e.exercise.tousMuscles)
          .any(filtres.muscles.contains));
    }
    if (filtres.equipements.isNotEmpty) {
      it = it.where((e) => filtres.equipements.contains(e.exercise.famille));
    }
    if (filtres.categories.isNotEmpty) {
      it = it.where((e) => filtres.categories.contains(e.exercise.categorie));
    }

    final q = TextSearch.normalize(filtres.query);
    if (q.isNotEmpty) {
      final qMots = q.split(' ');
      final scored = <(Exercise, int)>[];
      for (final e in it) {
        final s = e.score(q, qMots);
        if (s > 0) scored.add((e.exercise, s));
      }
      scored.sort((a, b) {
        if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
        final fa = frequences[a.$1.id] ?? 0, fb = frequences[b.$1.id] ?? 0;
        if (fa != fb) return fb.compareTo(fa);
        return a.$1.nom.length.compareTo(b.$1.nom.length);
      });
      return scored.map((e) => e.$1).toList();
    }

    if (filtres.sort == LibrarySort.nom && filtres.scope != LibraryScope.recents) {
      final ents = it.toList()..sort((a, b) => a.titre.compareTo(b.titre));
      return ents.map((e) => e.exercise).toList();
    }
    // À égalité, l'ordre alphabétique sans accents (« Écarté » avec les E).
    final titres = {for (final e in it) e.exercise.id: e.titre};
    int parNom(Exercise a, Exercise b) => (titres[a.id] ?? a.nom).compareTo(titres[b.id] ?? b.nom);
    final list = it.map((e) => e.exercise).toList();
    if (filtres.scope == LibraryScope.recents) {
      final rang = {for (var i = 0; i < recents.length; i++) recents[i]: i};
      list.sort((a, b) => (rang[a.id] ?? 1 << 20).compareTo(rang[b.id] ?? 1 << 20));
      return list;
    }
    switch (filtres.sort) {
      case LibrarySort.nom:
        break;
      case LibrarySort.frequence:
        list.sort((a, b) {
          final d = (frequences[b.id] ?? 0).compareTo(frequences[a.id] ?? 0);
          return d != 0 ? d : parNom(a, b);
        });
      case LibrarySort.recent:
        final rang = {for (var i = 0; i < recents.length; i++) recents[i]: i};
        list.sort((a, b) {
          final d = (rang[a.id] ?? 1 << 20).compareTo(rang[b.id] ?? 1 << 20);
          return d != 0 ? d : parNom(a, b);
        });
    }
    return list;
  }
}

/// Nombre de séances où chaque exercice apparaît (séries faites).
Map<String, int> frequencesExercices(Iterable<WorkoutSession> sessions) {
  final out = <String, int>{};
  for (final s in sessions) {
    for (final id in s.exercices.where((e) => e.seriesFaites.isNotEmpty).map((e) => e.exerciseId).toSet()) {
      out[id] = (out[id] ?? 0) + 1;
    }
  }
  return out;
}

/// Première lettre pour les intertitres de la liste alphabétique.
String initialeDe(String nom) {
  final n = TextSearch.normalize(nom);
  if (n.isEmpty) return '#';
  final c = n[0].toUpperCase();
  return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
}
