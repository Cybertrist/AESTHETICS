import '../../../../core/models/models.dart';
import '../../commun/palette.dart';

/// Routine proposée en tête du volet Routines.
/// Ce qui fait proposer une routine.
enum MotifSuggestion {
  /// Elle est faite d'habitude ce jour de la semaine.
  habitude,

  /// C'est la suivante dans le cycle du programme en cours.
  suite,

  /// C'est celle qui attend depuis le plus longtemps.
  attente,
}

class SuggestionRoutine {
  const SuggestionRoutine({required this.routineId, required this.fois, required this.sur, required this.jour, required this.derniere, this.motif = MotifSuggestion.habitude});

  final MotifSuggestion motif;

  final String routineId;

  /// Nombre de semaines, parmi les [sur] dernières, où la routine a été
  /// faite ce jour de la semaine.
  final int fois;
  final int sur;

  /// Jour de la semaine concerné (1 = lundi).
  final int jour;

  /// Dernière fois que la routine a été faite, tous jours confondus (null :
  /// jamais faite).
  final DateTime? derniere;
}

/// Le jour local d'une date (une séance importée peut être en temps universel).
DateTime _jour(DateTime date) {
  final d = date.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// La règle : l'appli ne propose une routine que si elle est sûre d'elle,
/// c'est-à-dire si la même routine a été faite ce jour de la semaine au
/// moins [seuil] fois sur les [semaines] dernières semaines (6 sur 8).
///
/// Les [semaines] dates regardées sont celles du même jour, de la semaine
/// passée à il y a [semaines] semaines ; aujourd'hui ne compte pas. Rien
/// n'est proposé si la routine a déjà été faite aujourd'hui, si elle
/// n'existe plus ([routinesConnues]), ou si aucune n'atteint le seuil.
/// À égalité, la routine faite le plus récemment l'emporte.
SuggestionRoutine? suggererRoutine({
  required DateTime maintenant,
  required Iterable<WorkoutSession> seances,
  Set<String>? routinesConnues,
  int semaines = 8,
  int seuil = 6,
}) {
  final aujourdhui = _jour(maintenant);
  // Les dates passent par le calendrier (et non par des durées de 24 h) pour
  // rester justes aux changements d'heure.
  final dates = {for (var k = 1; k <= semaines; k++) DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 7 * k)};
  final joursFaits = <String, Set<DateTime>>{};
  final derniere = <String, DateTime>{};
  final faitesAujourdhui = <String>{};
  for (final s in seances) {
    final id = s.routineId;
    if (id == null) continue;
    final j = _jour(s.debut);
    if (j == aujourdhui) {
      faitesAujourdhui.add(id);
      continue;
    }
    if (j.isAfter(aujourdhui)) continue;
    final d = derniere[id];
    if (d == null || s.debut.isAfter(d)) derniere[id] = s.debut;
    if (dates.contains(j)) (joursFaits[id] ??= {}).add(j);
  }
  SuggestionRoutine? choix;
  for (final e in joursFaits.entries) {
    final id = e.key;
    final n = e.value.length;
    if (n < seuil) continue;
    if (faitesAujourdhui.contains(id)) continue;
    if (routinesConnues != null && !routinesConnues.contains(id)) continue;
    final d = derniere[id]!;
    final mieux = choix == null ||
        n > choix.fois ||
        (n == choix.fois && d.isAfter(choix.derniere!)) ||
        (n == choix.fois && d == choix.derniere && id.compareTo(choix.routineId) < 0);
    if (mieux) choix = SuggestionRoutine(routineId: id, fois: n, sur: semaines, jour: aujourdhui.weekday, derniere: d);
  }
  return choix;
}

/// Rang, dans le [cycle] d'un programme, de la prochaine routine à faire :
/// celle qui suit la dernière routine du cycle réellement faite depuis
/// [depuis] (le début du programme). Rien de fait : la première.
///
/// Le rang se lit dans les séances et non dans un compteur : une séance
/// supprimée ne compte plus, une routine du cycle lancée hors du programme
/// compte. Une routine présente deux fois dans le cycle est suivie à son
/// tour (haut, bas, haut, bas).
int rangDansCycle(List<String> cycle, Iterable<WorkoutSession> seances, {DateTime? depuis}) {
  if (cycle.isEmpty) return 0;
  final faites = [
    for (final s in seances)
      if (!s.enCours && s.routineId != null && cycle.contains(s.routineId) && (depuis == null || !s.debut.isBefore(depuis))) s,
  ]..sort((a, b) => a.debut.compareTo(b.debut));
  var rang = 0;
  for (final s in faites) {
    // La prochaine occurrence de cette routine à partir du rang courant.
    for (var k = 0; k < cycle.length; k++) {
      final i = (rang + k) % cycle.length;
      if (cycle[i] == s.routineId) {
        rang = (i + 1) % cycle.length;
        break;
      }
    }
  }
  return rang;
}

const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// « 25 septembre », avec « 1er » pour le premier du mois.
String jourEtMois(DateTime date) {
  final d = date.toLocal();
  return '${d.day == 1 ? '1er' : d.day} ${_mois[d.month - 1]}';
}

/// Toutes les routines proposables aujourd'hui, de la plus plausible à la
/// moins plausible : c'est la file que « Une autre » fait avancer.
///
/// D'abord celles faites ce jour de la semaine (les plus régulières en
/// tête), puis la suivante dans le cycle du programme en cours ([cycle]),
/// puis les autres, celle qui attend depuis le plus longtemps d'abord et
/// les jamais faites à la fin. Une routine déjà faite aujourd'hui n'est pas
/// proposée. [routines] donne les routines existantes, dans leur ordre.
List<SuggestionRoutine> suggestionsRoutines({
  required DateTime maintenant,
  required Iterable<WorkoutSession> seances,
  required List<String> routines,
  List<String> cycle = const [],
  int semaines = 8,
}) {
  final aujourdhui = _jour(maintenant);
  final dates = {for (var k = 1; k <= semaines; k++) DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 7 * k)};
  final fois = <String, Set<DateTime>>{};
  final derniere = <String, DateTime>{};
  final faitesAujourdhui = <String>{};
  for (final s in seances) {
    final id = s.routineId;
    if (id == null) continue;
    final j = _jour(s.debut);
    if (j == aujourdhui) {
      faitesAujourdhui.add(id);
      continue;
    }
    if (j.isAfter(aujourdhui)) continue;
    final d = derniere[id];
    if (d == null || s.debut.isAfter(d)) derniere[id] = s.debut;
    if (dates.contains(j)) (fois[id] ??= {}).add(j);
  }
  final libres = [for (final id in routines) if (!faitesAujourdhui.contains(id)) id];
  SuggestionRoutine faire(String id, MotifSuggestion motif) => SuggestionRoutine(
        routineId: id,
        fois: fois[id]?.length ?? 0,
        sur: semaines,
        jour: aujourdhui.weekday,
        derniere: derniere[id],
        motif: motif,
      );
  int parDate(String a, String b) {
    final da = derniere[a], db = derniere[b];
    if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
    return da.compareTo(db);
  }

  final out = <SuggestionRoutine>[];
  final pris = <String>{};
  // 1. L'habitude du jour, même partielle.
  final habitudes = [for (final id in libres) if ((fois[id]?.length ?? 0) > 0) id]
    ..sort((a, b) {
      final n = fois[b]!.length.compareTo(fois[a]!.length);
      if (n != 0) return n;
      final d = derniere[b]!.compareTo(derniere[a]!);
      return d != 0 ? d : a.compareTo(b);
    });
  for (final id in habitudes) {
    out.add(faire(id, MotifSuggestion.habitude));
    pris.add(id);
  }
  // 2. La suite du programme : la routine qui suit la dernière faite du cycle.
  final tour = [for (final id in cycle) if (routines.contains(id)) id];
  if (tour.isNotEmpty) {
    String? faite;
    for (final id in tour) {
      final d = derniere[id];
      if (d != null && (faite == null || d.isAfter(derniere[faite]!))) faite = id;
    }
    final suivante = tour[faite == null ? 0 : (tour.indexOf(faite) + 1) % tour.length];
    if (libres.contains(suivante) && pris.add(suivante)) out.add(faire(suivante, MotifSuggestion.suite));
  }
  // 3. Les autres : celle qui attend depuis le plus longtemps d'abord.
  final reste = [for (final id in libres) if (!pris.contains(id)) id];
  final rang = {for (final (i, id) in reste.indexed) id: i};
  reste.sort((a, b) {
    final d = parDate(a, b);
    return d != 0 ? d : rang[a]!.compareTo(rang[b]!);
  });
  for (final id in reste) {
    out.add(faire(id, MotifSuggestion.attente));
  }
  return out;
}

/// La raison écrite sous la suggestion.
String raisonSuggestion(SuggestionRoutine s) {
  final d = s.derniere;
  return switch (s.motif) {
    MotifSuggestion.habitude =>
      'Tu as fait cette séance ${s.fois} des ${s.sur} derniers ${joursEntiers[s.jour - 1]}s.${d == null ? '' : ' Dernière fois : le ${jourEtMois(d)}.'}',
    MotifSuggestion.suite => d == null ? 'La suite de ton programme. Pas encore faite.' : 'La suite de ton programme. Dernière fois : le ${jourEtMois(d)}.',
    MotifSuggestion.attente => d == null ? 'Pas encore faite.' : 'Pas faite depuis le ${jourEtMois(d)}.',
  };
}

/// Ce qui s'écrit quand « Une autre » a épuisé les propositions.
const plusDeSuggestion = 'Pas d’autre suggestion pour aujourd’hui : choisis une routine ci-dessous.';

/// « Suggéré pour ce vendredi ».
String titreSuggestion(int jour) => 'Suggéré pour ce ${joursEntiers[jour - 1]}';

/// « Il y a 3 jours », « Avant-hier », « Hier », « Aujourd'hui », puis la date.
String derniereFois(DateTime d, {DateTime? maintenant}) {
  final n = maintenant ?? DateTime.now();
  final ecart = _jour(n).difference(_jour(d)).inHours / 24;
  final jours = ecart.round();
  if (jours <= 0) return 'Aujourd\'hui';
  if (jours == 1) return 'Hier';
  if (jours == 2) return 'Avant-hier';
  if (jours < 7) return 'Il y a $jours jours';
  final annee = d.toLocal().year;
  return annee == n.year ? jourEtMois(d) : '${jourEtMois(d)} $annee';
}
