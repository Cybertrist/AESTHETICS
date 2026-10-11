import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../aujourdhui/logic/accueil.dart' show nomSeance, recordsParSeance;
import '../../profil/data/career.dart';
import '../../profil/pages/grades_page.dart' show gradesDe;
import '../../progres/logic/progres_stats.dart';
import 'social_repo.dart';

/// Mon profil public : moi, décrit comme une personne de la communauté, avec
/// mes vraies séances. C'est ce que les autres recevront le jour où le
/// serveur existe ; ici, il sert à me le montrer.
class MoiPublic {
  const MoiPublic({required this.personne, required this.publications, required this.jours});
  final Ami personne;
  final List<Publication> publications;
  final Set<DateTime> jours;

  /// À lire dans un `build` : suit le profil, les séances et les réglages.
  static MoiPublic? de(BuildContext context) {
    final p = context.watch<ProfileRepo>().profile;
    if (p == null) return null;
    final sessions = context.watch<SessionRepo>().sessions.where((s) => !s.enCours).toList();
    final stats = CareerStats.from(sessions);
    final grades = gradesDe(context, stats: stats);
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
        amis: context.watch<SocialRepo>().amis.length,
      ),
      publications: [
        for (final s in sessions.take(5))
          Publication(
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
            }.take(3).toList(),
            records: records[s.id] ?? 0,
          ),
      ],
      jours: {for (final s in sessions) DateTime(s.debut.year, s.debut.month, s.debut.day)},
    );
  }
}
