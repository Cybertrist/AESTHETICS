import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/body/body_images.dart';

/// Récupération d'un groupe musculaire.
class EtatRecup {
  const EtatRecup(this.muscle, this.pourcentage);
  final Muscle muscle;

  /// 100 = entièrement récupéré.
  final int pourcentage;

  /// Vert à partir de 90 %, ambre en dessous.
  bool get pret => pourcentage >= Recup.seuilPret;
}

/// Groupe conseillé du jour.
typedef ConseilRecup = ({MuscleRegion groupe, Muscle phare, int pourcentage});

/// Calculs de l'écran Récupération, sans état ni widget.
abstract final class Recup {
  static const seuilPret = 90;

  /// Les dix-huit groupes suivis (ni le cou ni les abducteurs, qu'on ne
  /// cible presque jamais seuls).
  static final suivis = Muscle.values.where((m) => m != Muscle.cou && m != Muscle.abducteurs).toList();

  /// Les six vignettes de l'écran principal.
  static const principaux = [
    Muscle.pectoraux,
    Muscle.deltoidesLateraux,
    Muscle.triceps,
    Muscle.grandDorsal,
    Muscle.biceps,
    Muscle.quadriceps,
  ];

  static const _epaules = [Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.deltoidesPosterieurs];

  /// Libellé court d'une vignette.
  static String label(Muscle m) => switch (m) {
        Muscle.deltoidesAnterieurs => 'Épaules avant',
        Muscle.deltoidesLateraux => 'Épaules côté',
        Muscle.deltoidesPosterieurs => 'Épaules arrière',
        Muscle.ischios => 'Ischios',
        _ => m.label,
      };

  /// Vue et cadrage du personnage où le muscle se voit le mieux.
  static (BodyView, BodyFraming) cadrage(Muscle m) => switch (m) {
        Muscle.quadriceps || Muscle.adducteurs => (BodyView.front, BodyFraming.jambes),
        Muscle.ischios || Muscle.fessiers || Muscle.mollets || Muscle.abducteurs => (BodyView.back, BodyFraming.jambes),
        Muscle.deltoidesPosterieurs ||
        Muscle.triceps ||
        Muscle.trapezes ||
        Muscle.grandDorsal ||
        Muscle.rhomboides ||
        Muscle.lombaires =>
          (BodyView.back, BodyFraming.buste),
        _ => (BodyView.front, BodyFraming.buste),
      };

  /// Grossissement de la vignette et point fixe vertical (de -1 en haut à 1
  /// en bas) : chaque vignette est resserrée sur son muscle.
  static (double, double) zoom(Muscle m) => switch (m) {
        Muscle.quadriceps || Muscle.adducteurs => (1.9, -0.86),
        Muscle.ischios => (1.9, -0.8),
        Muscle.fessiers || Muscle.abducteurs => (2.2, -1),
        Muscle.mollets => (2, 0.68),
        // Haut du corps : resserré sur le muscle, sans perdre les bras.
        Muscle.pectoraux || Muscle.rhomboides => (1.5, -0.55),
        Muscle.deltoidesAnterieurs || Muscle.deltoidesLateraux || Muscle.deltoidesPosterieurs => (1.45, -0.7),
        Muscle.trapezes => (1.55, -0.85),
        Muscle.grandDorsal => (1.35, -0.3),
        Muscle.lombaires => (1.5, 0.35),
        Muscle.abdominaux || Muscle.obliques => (1.4, 0.15),
        Muscle.biceps || Muscle.triceps => (1.3, -0.25),
        Muscle.avantBras => (1.3, 0.4),
        _ => (1, 0),
      };

  /// État de chaque muscle suivi, dans l'ordre de l'enum.
  static Map<Muscle, EtatRecup> etats(
    Iterable<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
  }) {
    final fatigue = Recovery.fatigue(sessions.where((s) => !s.enCours), lookup, now: now);
    final pct = Recovery.pourcentages(fatigue);
    return {for (final m in suivis) m: EtatRecup(m, pct[m] ?? 100)};
  }

  /// Anneau global : la moyenne des groupes suivis.
  static int global(Map<Muscle, EtatRecup> etats) {
    if (etats.isEmpty) return 100;
    return (etats.values.fold(0, (a, e) => a + e.pourcentage) / etats.length).round();
  }

  /// Du moins au plus récupéré (à égalité, l'ordre de l'enum).
  static List<EtatRecup> tries(Map<Muscle, EtatRecup> etats) {
    final l = etats.values.toList();
    l.sort((a, b) {
      final c = a.pourcentage.compareTo(b.pourcentage);
      return c != 0 ? c : a.muscle.index.compareTo(b.muscle.index);
    });
    return l;
  }

  /// Les six vignettes : la vignette « Épaules » prend le faisceau le moins
  /// récupéré des trois.
  static List<(String, EtatRecup)> vignettes(Map<Muscle, EtatRecup> etats) => [
        for (final m in principaux)
          if (m == Muscle.deltoidesLateraux)
            ('Épaules', _epaules.map((x) => etats[x]!).reduce((a, b) => b.pourcentage < a.pourcentage ? b : a))
          else
            (label(m), etats[m]!),
      ];

  static const _phares = {
    MuscleRegion.jambes: Muscle.quadriceps,
    MuscleRegion.poitrine: Muscle.pectoraux,
    MuscleRegion.dos: Muscle.grandDorsal,
    MuscleRegion.epaules: Muscle.deltoidesLateraux,
    MuscleRegion.bras: Muscle.biceps,
    MuscleRegion.abdos: Muscle.abdominaux,
  };

  /// Groupe à travailler aujourd'hui : celui dont le muscle le moins
  /// récupéré l'est le plus ; à égalité, celui qui n'a pas été travaillé
  /// depuis le plus longtemps.
  static ConseilRecup conseil(
    Map<Muscle, EtatRecup> etats,
    Iterable<WorkoutSession> sessions,
    Exercise? Function(String) lookup,
  ) {
    final derniere = <MuscleRegion, DateTime>{};
    for (final s in sessions) {
      if (s.enCours) continue;
      for (final e in s.exercices) {
        if (e.seriesFaites.isEmpty) continue;
        final r = lookup(e.exerciseId)?.musclesPrincipaux.firstOrNull?.region;
        if (r == null) continue;
        final d = derniere[r];
        if (d == null || s.debut.isAfter(d)) derniere[r] = s.debut;
      }
    }
    final jamais = DateTime(1970);
    MuscleRegion? choix;
    var noteChoix = -1;
    for (final r in _phares.keys) {
      final l = etats.values.where((e) => e.muscle.region == r).toList();
      if (l.isEmpty) continue;
      // Un groupe vaut son muscle le moins récupéré : une moyenne conseillait
      // les bras avec des biceps à plat, parce que les triceps étaient frais,
      // et la carte annonçait alors « Biceps récupérés à 0 % ».
      final note = l.fold(100, (a, e) => e.pourcentage < a ? e.pourcentage : a);
      final mieux = note > noteChoix || (note == noteChoix && (derniere[r] ?? jamais).isBefore(derniere[choix] ?? jamais));
      if (choix == null || mieux) {
        choix = r;
        noteChoix = note;
      }
    }
    final g = choix ?? MuscleRegion.jambes;
    final phare = _phares[g]!;
    return (groupe: g, phare: phare, pourcentage: etats[phare]?.pourcentage ?? 100);
  }

  /// « Jambes », « Pectoraux », « Dos »...
  static String groupeLabel(MuscleRegion r) => r == MuscleRegion.poitrine ? 'Pectoraux' : r.label;

  /// « Prêt pour les jambes ».
  static String pretPour(MuscleRegion r) => switch (r) {
        MuscleRegion.jambes => 'Prêt pour les jambes',
        MuscleRegion.poitrine => 'Prêt pour les pectoraux',
        MuscleRegion.dos => 'Prêt pour le dos',
        MuscleRegion.epaules => 'Prêt pour les épaules',
        MuscleRegion.bras => 'Prêt pour les bras',
        MuscleRegion.abdos => 'Prêt pour les abdos',
        MuscleRegion.cou => 'Prêt pour le cou',
      };

  /// « Quadriceps récupérés à 100 % », accordé.
  static String phrase(ConseilRecup c) {
    final sujet = switch (c.phare) {
      Muscle.grandDorsal => 'Grand dorsal récupéré',
      Muscle.deltoidesLateraux => 'Épaules récupérées',
      _ => '${c.phare.label} récupérés',
    };
    return '$sujet à ${c.pourcentage} %';
  }
}
