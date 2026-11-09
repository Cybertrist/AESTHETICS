import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../aujourdhui/logic/accueil.dart' show nomSeance, recordsParSeance;
import '../../profil/data/career.dart';
import '../../profil/data/grades.dart';
import '../../progres/logic/progres_stats.dart';
import 'social_repo.dart';

/// Mon profil public : moi, décrit comme une personne de la communauté, avec
/// mes vraies séances. Il sert à me le montrer, et c'est ce qui part sur le
/// serveur (voir `SynchroSociale`), filtré par ce que je montre.
class MoiPublic {
  const MoiPublic({required this.personne, required this.publications, required this.jours});
  final Ami personne;
  final List<Publication> publications;
  final Set<DateTime> jours;

  /// À lire dans un `build` : suit le profil, les séances et les réglages.
  static MoiPublic? de(BuildContext context) {
    final p = context.watch<ProfileRepo>().profile;
    if (p == null) return null;
    return calculer(
      p,
      context.watch<SessionRepo>().sessions,
      nbRoutines: context.watch<RoutineRepo>().routines.length,
      premierJour: context.watch<SettingsRepo>().settings.premierJourSemaine,
      nbAmis: context.watch<SocialRepo>().amis.length,
    );
  }

  /// Le même calcul hors d'un écran : c'est ce qui part sur le serveur.
  static MoiPublic calculer(UserProfile p, List<WorkoutSession> toutes, {required int nbRoutines, int premierJour = DateTime.monday, int nbAmis = 0}) {
    final sessions = toutes.where((s) => !s.enCours).toList();
    final stats = CareerStats.from(sessions);
    final grades = Grades.from(toutes, nbRoutines: nbRoutines, nbRecords: stats.nbRecords, objectifSemaine: p.joursParSemaine, premierJour: premierJour);
    final records = recordsParSeance(sessions);
    final barres = [
      for (final l in ProgresStats.records(sessions))
        if ((l.bests.poidsMax?.poids ?? 0) > 0) l.bests.poidsMax!,
    ]..sort((a, b) => b.poids!.compareTo(a.poids!));
    return MoiPublic(
      personne: Ami(
        id: 'moi',
        prenom: p.prenom.trim(),
        pseudo: p.pseudo,
        couleur: 0xFF2C5676,
        photo: p.photo,
        phrase: p.phrase,
        ville: p.ville,
        salle: p.salle,
        depuis: stats.premiere?.year,
        acces: p.acces,
        montre: p.montre,
        serieSemaines: stats.semainesConsecutives,
        seances: stats.seances,
        heures: stats.duree.inHours,
        objectif: p.objectif.label,
        niveau: p.niveau.label,
        records: [for (final r in barres.take(4)) RecordAmi(r.exerciseId, r.poids!, r.reps ?? 1)],
        badges: grades.valeurs,
        fetiches: [for (final (id, _) in stats.topExercices.take(3)) id],
        amis: nbAmis,
      ),
      publications: [for (final s in sessions.take(5)) publicationDe(s, records: records[s.id] ?? 0)],
      jours: {for (final s in sessions) DateTime(s.debut.year, s.debut.month, s.debut.day)},
    );
  }

  /// Une de mes séances terminées, telle que mes amis la voient dans le fil
  /// (le serveur en garde six exercices, l'écran en montre trois).
  static Publication publicationDe(WorkoutSession s, {int records = 0}) => Publication(
        id: s.id,
        amiId: 'moi',
        titre: nomSeance(s),
        date: s.fin ?? s.debut,
        duree: s.duree,
        volumeKg: s.volume,
        series: s.nbSeriesFaites,
        exercices: {
          for (final e in s.exercices)
            if (e.seriesFaites.isNotEmpty) e.exerciseId,
        }.take(6).toList(),
        records: records,
        seanceId: s.id,
      );
}
