import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../entrainer/routines/logic/suggestion.dart' show rangDansCycle;

/// Salutation selon l'heure.
String salutation(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 12) return 'Bonjour';
  if (h >= 12 && h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

/// D'où vient la séance proposée.
enum OrigineProposition { programme, suggestion }

/// Séance proposée pour aujourd'hui.
class PropositionSeance {
  const PropositionSeance({required this.routine, required this.origine, required this.raison, this.programme});

  final Routine routine;
  final Program? programme;
  final OrigineProposition origine;

  /// Pourquoi celle-ci (« Semaine 3 sur 8 », « Muscles reposés »).
  final String raison;
}

/// Muscles d'une routine pour le personnage : principaux pleins, secondaires à moitié.
Map<Muscle, double> musclesRoutine(Routine r, ExerciseRepo ex) {
  final out = <Muscle, double>{};
  for (final re in r.exercices) {
    final e = ex.byId(re.exerciseId);
    if (e == null) continue;
    for (final m in e.intensites.entries) {
      out[m.key] = math.max(out[m.key] ?? 0, m.value);
    }
  }
  return out;
}

/// Muscles travaillés par une séance.
Map<Muscle, double> musclesSeance(WorkoutSession s, ExerciseRepo ex) {
  final out = <Muscle, double>{};
  for (final se in s.exercices) {
    final e = ex.byId(se.exerciseId);
    if (e == null) continue;
    for (final m in e.intensites.entries) {
      out[m.key] = math.max(out[m.key] ?? 0, m.value);
    }
  }
  return out;
}

/// Prochaine routine du programme actif, sinon la routine dont les muscles
/// sont le plus reposés.
PropositionSeance? proposerSeance({
  required RoutineRepo routines,
  required ProgramRepo programs,
  required SessionRepo sessions,
  required ExerciseRepo exercises,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final p = programs.active;
  if (p != null && p.routineIds.isNotEmpty) {
    final rang = rangDansCycle(p.routineIds, sessions.sessions, depuis: p.debuteLe);
    for (var i = 0; i < p.routineIds.length; i++) {
      final id = p.routineIds[(rang + i) % p.routineIds.length];
      final r = routines.byId(id);
      if (r != null) {
        final semaine = math.min(p.semaineCourante + 1, p.dureeSemaines);
        return PropositionSeance(
          routine: r,
          programme: p,
          origine: OrigineProposition.programme,
          raison: p.termine ? 'Programme terminé, nouveau cycle' : 'Semaine $semaine sur ${p.dureeSemaines}',
        );
      }
    }
  }
  final candidates = routines.routines.where((r) => r.exercices.isNotEmpty).toList();
  if (candidates.isEmpty) return null;
  final fatigue = Recovery.fatigue(sessions.sessions.take(40), exercises.byId, now: t);
  Routine? best;
  var bestScore = -1e9;
  var bestRepos = 0.0;
  for (final r in candidates) {
    final muscles = musclesRoutine(r, exercises);
    final principaux = muscles.entries.where((e) => e.value >= 1).map((e) => e.key).toList();
    final repos = principaux.isEmpty ? 1.0 : principaux.map((m) => 1 - (fatigue[m] ?? 0)).average;
    final derniere = sessions.lastForRoutine(r.id);
    final jours = derniere == null ? 30 : t.difference(derniere.debut).inHours / 24;
    final score = repos * 10 + math.min(jours, 14) * 0.4;
    if (score > bestScore) {
      bestScore = score;
      best = r;
      bestRepos = repos;
    }
  }
  if (best == null) return null;
  final derniere = sessions.lastForRoutine(best.id);
  final raison = derniere == null
      ? 'Jamais faite, à découvrir'
      : bestRepos >= 0.8
          ? 'Muscles reposés, faite ${Fmt.ilYa(derniere.debut, now: t)}'
          : 'Faite ${Fmt.ilYa(derniere.debut, now: t)}';
  return PropositionSeance(routine: best, origine: OrigineProposition.suggestion, raison: raison);
}

/// Chiffres d'une semaine d'entraînement.
class ResumeSemaine {
  const ResumeSemaine({
    required this.debut,
    required this.jours,
    required this.seances,
    required this.objectif,
  });

  final DateTime debut;
  final List<DateTime> jours;
  final List<WorkoutSession> seances;
  final int objectif;

  DateTime get fin => DateTime(debut.year, debut.month, debut.day + 7);
  int get nbSeances => seances.length;
  double get volume => seances.fold(0.0, (a, s) => a + s.volume);
  int get series => seances.fold(0, (a, s) => a + s.nbSeriesFaites);
  Duration get duree => seances.fold(Duration.zero, (a, s) => a + (s.fin == null ? Duration.zero : s.duree));
  bool entraine(DateTime jour) => seances.any((s) => Dates.memeJour(s.debut, jour));
  double get avancement => objectif <= 0 ? 0 : (nbSeances / objectif).clamp(0.0, 1.0);

  static ResumeSemaine pour(SessionRepo sessions, DateTime ref, {int premierJour = DateTime.monday, int objectif = 3}) {
    final debut = Dates.debutSemaine(ref, premierJour: premierJour);
    return ResumeSemaine(
      debut: debut,
      jours: Dates.joursSemaine(ref, premierJour: premierJour),
      // Sept jours de calendrier : 168 heures perdraient ou doubleraient une
      // heure la semaine du changement d'heure.
      seances: sessions.sessionsBetween(debut, DateTime(debut.year, debut.month, debut.day + 7)),
      objectif: objectif,
    );
  }
}

/// Un record battu, avec la séance où il l'a été.
typedef RecordBattu = ({PersonalRecord record, WorkoutSession session});

final _cacheRecords = Expando<List<RecordBattu>>();

/// Tous les records battus au fil de l'historique, le plus récent d'abord.
/// Même règle que la fin de séance (`Strength.newRecords`).
List<RecordBattu> historiqueRecords(List<WorkoutSession> sessions) {
  final cached = _cacheRecords[sessions];
  if (cached != null) return cached;
  final chrono = [...sessions]..sort((a, b) => a.debut.compareTo(b.debut));
  final out = Strength.recordsAuFil(chrono);
  final result = out.reversed.toList();
  _cacheRecords[sessions] = result;
  return result;
}

/// Texte d'un record : « 100 kg × 5 », « 1RM estimé 112,5 kg ».
String valeurRecord(PersonalRecord r, UnitePoids u) => switch (r.type) {
      RecordType.poidsMax => r.reps != null && r.reps! > 0 ? '${Fmt.poids(r.valeur, u)} × ${r.reps}' : Fmt.poids(r.valeur, u),
      RecordType.unRmEstime => Fmt.poids(r.valeur, u),
      RecordType.volumeSerie => '${Fmt.poids(r.poids, u)} × ${r.reps ?? 0}',
      RecordType.repsMax => Fmt.pluriel(r.valeur, 'rép.', 'rép.'),
      RecordType.volumeSeance => Fmt.volume(r.valeur, u),
    };

/// Heures avant qu'un muscle soit prêt (récupéré à 80 %), 0 s'il l'est déjà.
int heuresAvantPret(Muscle m, Iterable<WorkoutSession> sessions, Exercise? Function(String) lookup, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final recent = sessions.where((s) => t.difference(s.fin ?? s.debut).inHours <= 96).toList();
  if (recent.isEmpty) return 0;
  for (var h = 0; h <= 96; h += 1) {
    final f = Recovery.fatigue(recent, lookup, now: t.add(Duration(hours: h)))[m] ?? 0;
    if (f <= 0.2) return h;
  }
  return 96;
}

/// Dernière séance qui a travaillé un muscle (principal ou secondaire).
WorkoutSession? derniereSeancePour(Muscle m, List<WorkoutSession> sessions, Exercise? Function(String) lookup) {
  for (final s in sessions) {
    for (final e in s.exercices) {
      final ex = lookup(e.exerciseId);
      if (ex != null && ex.tousMuscles.contains(m) && e.seriesFaites.isNotEmpty) return s;
    }
  }
  return null;
}

/// Phrase du coach affichée sur l'accueil.
class PhraseCoach {
  const PhraseCoach({required this.texte, this.conversationId, this.titre = 'Le mot du coach'});
  final String texte;
  final String? conversationId;
  final String titre;
}

const _conseils = [
  'La progression se joue sur des semaines, pas sur une séance. Note tout, même les jours moyens.',
  'Garde deux répétitions en réserve sur la plupart des séries, et va à l\'échec seulement sur la dernière.',
  'Vise 1,6 à 2 g de protéines par kilo de poids de corps, réparties sur la journée.',
  'Un bon échauffement : quelques séries légères qui montent vers ta charge de travail, pas vingt minutes de tapis.',
  'Le sommeil est ton meilleur complément. Sept heures et plus, c\'est de la récupération gratuite.',
  'Quand une charge passe facilement sur toutes les séries, ajoute un peu de poids la fois suivante.',
  'Contrôle la descente : deux à trois secondes sur la phase excentrique, c\'est là que le muscle travaille.',
  'Bois un grand verre d\'eau au réveil, et un autre pendant ta séance.',
  'Une séance courte vaut mieux que pas de séance. Même trente minutes comptent.',
  'Photos et mensurations disent souvent plus que la balance. Prends-en une par mois.',
  'Varie les angles pour un même muscle : un mouvement lourd, un mouvement en étirement, un en contraction.',
  'Si une articulation tire, change d\'exercice plutôt que de forcer. Le muscle ne fait pas la différence.',
];

/// Phrase du jour : dernier message du coach s'il date de moins d'un jour,
/// sinon un conseil tiré de ta situation.
PhraseCoach phraseDuJour({
  required String prenom,
  required CoachRepo coach,
  required SessionRepo sessions,
  required HealthRepo health,
  required NutritionRepo nutrition,
  required NutritionGoals objectifs,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  for (final c in coach.conversations) {
    final m = c.messages.lastWhereOrNull((m) => m.role == CoachRole.coach && !m.enErreur && m.texte.trim().isNotEmpty);
    if (m != null && t.difference(m.date).inHours < 24) {
      return PhraseCoach(texte: m.texte.trim(), conversationId: c.id, titre: 'Dernier message du coach');
    }
  }
  if (sessions.hasActive) {
    return const PhraseCoach(texte: 'Ta séance est toujours ouverte. Reprends où tu t\'étais arrêté, tes séries sont gardées.');
  }
  final all = sessions.sessions;
  if (all.isEmpty) {
    final nom = prenom.trim().isEmpty ? '' : ' $prenom';
    return PhraseCoach(texte: 'Bienvenue$nom. Commence par une séance simple : on ajustera les charges ensemble au fil des semaines.');
  }
  if (sessions.sessionsOn(t).isNotEmpty) {
    final reste = objectifs.proteinesG - nutrition.totalsFor(t).proteines;
    if (reste > 10) {
      return PhraseCoach(texte: 'Belle séance aujourd\'hui. Il te reste ${Fmt.n(reste, decimals: 0)} g de protéines pour bien récupérer.');
    }
    return const PhraseCoach(texte: 'Séance faite et protéines au rendez-vous. Maintenant, place au repos et au sommeil.');
  }
  final nuit = health.sleepFor(t);
  if (nuit != null && nuit.duree.inMinutes < 390) {
    return PhraseCoach(
      texte: 'Nuit courte (${Fmt.sommeil(nuit.duree)}). Garde tes charges mais retire une série si la forme n\'y est pas.',
    );
  }
  final jours = t.difference(all.first.debut).inDays;
  if (jours >= 4) {
    return PhraseCoach(texte: 'Ta dernière séance date de $jours jours. Une séance courte suffit pour relancer la machine.');
  }
  final streak = sessions.streakWeeks(now: t);
  if (streak >= 3 && t.weekday == DateTime.monday) {
    return PhraseCoach(texte: '$streak semaines d\'affilée. C\'est la régularité qui construit le physique, continue.');
  }
  final jourAn = t.difference(DateTime(t.year)).inDays;
  return PhraseCoach(texte: _conseils[jourAn % _conseils.length], titre: 'Conseil du jour');
}
