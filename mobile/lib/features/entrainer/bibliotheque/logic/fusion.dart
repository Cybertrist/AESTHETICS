import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../import/data/import_journal.dart';
import '../../../import/logic/exercise_matcher.dart';
import '../../../progres/logic/objectifs.dart';
import 'exercise_notes.dart';

/// Fusion d'un exercice perso avec un exercice du catalogue : l'identifiant
/// du perso est remplacé partout par celui du catalogue (séances, séance en
/// cours, routines, objectifs, favori, note, mémoire de l'import), puis le
/// perso est supprimé. Les records se recalculent depuis les séances : ils
/// suivent d'eux-mêmes. Les programmes ne citent que des routines, ils
/// suivent avec elles.

/// Fusion refusée : perso introuvable, cible absente du catalogue...
class FusionImpossible implements Exception {
  const FusionImpossible(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Ce que la fusion déplace, compté avant de demander l'accord.
class BilanFusion {
  const BilanFusion({
    this.seances = 0,
    this.seanceEnCours = false,
    this.routines = 0,
    this.objectifs = 0,
    this.favori = false,
    this.note = false,
  });

  /// Séances terminées où l'exercice perso apparaît.
  final int seances;
  final bool seanceEnCours;
  final int routines;
  final int objectifs;
  final bool favori;
  final bool note;

  /// « 23 séances, 3 routines » ; vide si l'exercice n'a servi nulle part.
  String get resume => [
        if (seances > 0) Fmt.pluriel(seances, 'séance'),
        if (seanceEnCours) 'la séance en cours',
        if (routines > 0) Fmt.pluriel(routines, 'routine'),
        if (objectifs > 0) Fmt.pluriel(objectifs, 'objectif'),
      ].join(', ');
}

/// Texte de la confirmation : ce qui passe sur l'exercice du catalogue, et
/// la disparition du perso.
String messageFusion(BilanFusion b, {required String perso, required String catalogue}) {
  final r = b.resume;
  final deplace = r.isEmpty
      ? '« $perso » n’a encore servi dans aucune séance ni routine.'
      : 'Ses $r passent sur « $catalogue », avec toutes leurs séries : historique, records et progression ne perdent rien.';
  return '$deplace « $perso » disparaîtra de tes exercices.';
}

/// Les remplacements, sans dépôt : chaque fonction ne rend que ce qui change.
abstract final class FusionExercices {
  /// La séance avec [vers] à la place de [de], ou null si elle ne le contient
  /// pas. Une séance qui contenait les deux garde les deux entrées à leur
  /// place, avec toutes leurs séries.
  static WorkoutSession? seance(WorkoutSession s, String de, String vers) {
    if (!s.exercices.any((e) => e.exerciseId == de)) return null;
    return s.copyWith(exercices: [for (final e in s.exercices) e.exerciseId == de ? e.copyWith(exerciseId: vers) : e]);
  }

  static List<WorkoutSession> seances(Iterable<WorkoutSession> l, String de, String vers) => [
        for (final s in l) ?seance(s, de, vers),
      ];

  static List<Routine> routines(Iterable<Routine> l, String de, String vers) => [
        for (final r in l)
          if (r.exercices.any((e) => e.exerciseId == de))
            r.copyWith(exercices: [for (final e in r.exercices) e.exerciseId == de ? e.copyWith(exerciseId: vers) : e]),
      ];

  static List<ObjectifPerso> objectifs(Iterable<ObjectifPerso> l, String de, String vers) => [
        for (final o in l)
          if (o.exerciseId == de)
            ObjectifPerso(
              id: o.id,
              type: o.type,
              cible: o.cible,
              creeLe: o.creeLe,
              depart: o.depart,
              exerciseId: vers,
              zone: o.zone,
              atteintLe: o.atteintLe,
            ),
      ];

  /// Notes par exercice : celle du perso (et le texte de sa fiche,
  /// [notesPerso]) rejoint celle du catalogue, à la suite.
  static Map<String, String> notes(Map<String, String> notes, String de, String vers, {String? notesPerso}) {
    final out = Map.of(notes);
    final duPerso = out.remove(de);
    var texte = out[vers]?.trim() ?? '';
    for (final t in [duPerso, notesPerso]) {
      final x = t?.trim() ?? '';
      if (x.isEmpty || texte.contains(x)) continue;
      texte = texte.isEmpty ? x : '$texte\n\n$x';
    }
    if (texte.isNotEmpty) out[vers] = texte;
    return out;
  }

  /// Mémoire de l'import (nom du fichier vers identifiant) : ce qui menait
  /// au perso, ou le créait (valeur vide) sous son nom, mène au catalogue.
  static Map<String, String> correspondances(Map<String, String> m, String de, String vers, {String? nomPerso}) {
    final cle = nomPerso == null ? null : cleNom(nomPerso);
    return {
      for (final e in m.entries) e.key: e.value == de || (e.value.isEmpty && e.key == cle) ? vers : e.value,
    };
  }

  /// Bilan de ce qui sera déplacé.
  static BilanFusion bilan({
    required String de,
    required List<WorkoutSession> seances,
    WorkoutSession? active,
    required List<Routine> routines,
    List<ObjectifPerso> objectifs = const [],
    bool favori = false,
    bool note = false,
  }) =>
      BilanFusion(
        seances: seances.where((s) => s.exercices.any((e) => e.exerciseId == de)).length,
        seanceEnCours: active?.exercices.any((e) => e.exerciseId == de) ?? false,
        routines: routines.where((r) => r.exercices.any((e) => e.exerciseId == de)).length,
        objectifs: objectifs.where((o) => o.exerciseId == de).length,
        favori: favori,
        note: note,
      );

  /// Refuse une fusion qui n'a pas de sens ; rend le perso et la cible.
  static (Exercise, Exercise) verifier(ExerciseRepo exercices, String de, String vers) {
    final perso = exercices.byId(de);
    final cible = exercices.byId(vers);
    if (perso == null || !perso.perso) throw const FusionImpossible('Cet exercice perso n’existe plus.');
    if (de == vers) throw const FusionImpossible('Un exercice ne se fusionne pas avec lui-même.');
    if (cible == null || cible.perso) throw const FusionImpossible('Cet exercice n’est pas dans le catalogue.');
    return (perso, cible);
  }

  /// Bilan compté sur les dépôts.
  static Future<BilanFusion> bilanDe(AppData data, String de) async {
    final objectifs = await ObjectifsRepo.ensure(data.store);
    final notes = ExerciseNotes.of(data.store);
    await notes.pret;
    return bilan(
      de: de,
      seances: data.sessions.sessions,
      active: data.sessions.active,
      routines: data.routines.routines,
      objectifs: objectifs.liste,
      favori: data.exercises.isFavori(de),
      note: notes.noteOf(de) != null,
    );
  }

  /// Applique la fusion à tous les dépôts. Lève [FusionImpossible] avant
  /// d'avoir rien touché si elle n'a pas de sens.
  static Future<BilanFusion> appliquer(AppData data, {required String de, required String vers}) async {
    final (perso, _) = verifier(data.exercises, de, vers);
    final b = await bilanDe(data, de);

    final sessions = data.sessions;
    final changees = seances(sessions.sessions, de, vers);
    if (changees.isNotEmpty) await sessions.addAll(changees);
    final active = sessions.active;
    final enCours = active == null ? null : seance(active, de, vers);
    if (enCours != null) await sessions.updateActive(enCours);

    final routinesChangees = routines(data.routines.routines, de, vers);
    if (routinesChangees.isNotEmpty) await data.routines.saveAll(routinesChangees);

    final repoObjectifs = await ObjectifsRepo.ensure(data.store);
    for (final o in objectifs(repoObjectifs.liste, de, vers)) {
      await repoObjectifs.remplacer(o);
    }

    final notesRepo = ExerciseNotes.of(data.store);
    await notesRepo.pret;
    final avant = notesRepo.toutes;
    final apres = notes(avant, de, vers, notesPerso: perso.notes);
    if (apres.length != avant.length || apres.entries.any((e) => avant[e.key] != e.value)) await notesRepo.remplacer(apres);

    final memoire = await ImportJournal.lireCorrespondances(data.store);
    final memoireApres = correspondances(memoire, de, vers, nomPerso: perso.nom);
    if (memoireApres.entries.any((e) => memoire[e.key] != e.value)) await ImportJournal.ecrireCorrespondances(data.store, memoireApres);

    final exercices = data.exercises;
    if (exercices.isFavori(de) && !exercices.isFavori(vers)) await exercices.toggleFavori(vers);
    // Supprimé en dernier : rien ne doit plus le citer.
    await exercices.deleteCustom(de);
    return b;
  }
}

/// Équivalents dans le catalogue des exercices perso, par le rapprochement
/// de noms de l'import. Gardé tant que le catalogue ne change pas.
abstract final class EquivalentsCatalogue {
  static final _matchers = Expando<ExerciseMatcher>();

  static ExerciseMatcher _matcher(List<Exercise> catalogue) => _matchers[catalogue] ??= ExerciseMatcher([
        for (final e in catalogue)
          CatalogueEntry(id: e.id, nom: e.nom, nomEn: e.nomEn, alias: e.alias, equipement: e.equipement),
      ]);

  /// L'équivalent quasi certain d'un perso, ou null. Une variante faite à
  /// partir d'un exercice du catalogue n'en a pas : elle s'en écarte exprès.
  static String? sur(List<Exercise> catalogue, Exercise perso) {
    if (!perso.perso || catalogue.isEmpty || (perso.source?.startsWith('copie:') ?? false)) return null;
    final m = _matcher(catalogue);
    for (final nom in [perso.nom, ?perso.nomEn]) {
      final r = m.rapprocher(nom);
      final certain = r.choisi != null && (r.statut == StatutRapprochement.exact || r.statut == StatutRapprochement.automatique);
      if (certain) return r.choisi!.id;
      if (r.suggestionSure) return r.candidats.first.entree.id;
    }
    return null;
  }

  /// Les exercices du catalogue les plus proches par le nom, du plus proche
  /// au moins proche (tête du sélecteur de fusion).
  static List<String> proches(List<Exercise> catalogue, Exercise perso, {int max = 6}) {
    if (catalogue.isEmpty) return const [];
    final m = _matcher(catalogue);
    final ids = <String>{};
    for (final nom in [perso.nom, ?perso.nomEn]) {
      for (final c in m.rapprocher(nom).candidats) {
        ids.add(c.entree.id);
      }
    }
    for (final c in m.rechercher(perso.nom, max: max)) {
      if (c.score >= 0.4) ids.add(c.entree.id);
    }
    return ids.take(max).toList();
  }

  static final _cache = Expando<Map<String, String?>>();

  /// Les persos qui ont un équivalent sûr, avec l'identifiant de cet
  /// équivalent. Le calcul est gardé par catalogue et par nom.
  static List<(Exercise, String)> suggestions(List<Exercise> catalogue, List<Exercise> perso) {
    final cache = _cache[catalogue] ??= {};
    return [
      for (final p in perso)
        if (cache.putIfAbsent('${p.id}|${p.nom}|${p.nomEn}', () => sur(catalogue, p)) case final id?) (p, id),
    ];
  }
}
