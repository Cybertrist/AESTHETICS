import 'package:flutter/material.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import 'program_catalogue.dart';
import 'program_plan.dart';
import 'routine_stats.dart';

/// Exercice d'un modèle : premier identifiant trouvé dans le catalogue.
class ModeleExercice {
  const ModeleExercice(
    this.ids, {
    this.series = 3,
    this.reps = 8,
    this.repsMax,
    this.repos = 90,
    this.rpe,
    this.echauffements = 0,
    this.superset,
    this.dureeSec,
  });

  final List<String> ids;
  final int series;
  final int reps;
  final int? repsMax;
  final int repos;
  final double? rpe;
  final int echauffements;

  /// Même lettre = même superset dans la routine.
  final String? superset;

  /// Pour le gainage et les exercices en durée.
  final int? dureeSec;
}

class ModeleRoutine {
  const ModeleRoutine(this.nom, this.exercices);
  final String nom;
  final List<ModeleExercice> exercices;
}

class ModeleProgramme {
  const ModeleProgramme({
    required this.id,
    required this.nom,
    required this.resume,
    required this.description,
    required this.niveau,
    required this.objectif,
    required this.joursParSemaine,
    required this.semaines,
    required this.progression,
    required this.routines,
    required this.cycle,
    required this.icon,
    this.increment = 2.5,
    this.decharge = 0,
    this.conseils = const [],
  });

  final String id;
  final String nom;
  final String resume;
  final String description;
  final Niveau niveau;
  final String objectif;
  final int joursParSemaine;
  final int semaines;
  final ProgressionType progression;
  final double increment;
  final int decharge;
  final List<ModeleRoutine> routines;

  /// Ordre des routines dans le cycle (indices de [routines]).
  final List<int> cycle;
  final IconData icon;
  final List<String> conseils;

  int get nbSeries => routines.fold(0, (a, r) => a + r.exercices.fold(0, (b, e) => b + e.series + e.echauffements));
}

const _e = ModeleExercice.new;

/// Les modèles fournis : les classiques écrits à la main, puis le catalogue.
final List<ModeleProgramme> modelesProgrammes = [..._modelesDeBase, for (final f in fiches) f.modele];

final Map<String, ModeleProgramme> _modelesParId = {for (final m in modelesProgrammes) m.id: m};

final _modelesDeBase = <ModeleProgramme>[
  ModeleProgramme(
    id: 'debutant-3j',
    nom: 'Débutant 3 jours',
    resume: 'Deux séances en alternance, machines et bases',
    description:
        'Pour apprendre les mouvements et installer l\'habitude. Deux séances corps entier qui alternent (A, B, A puis B, A, B), des charges qui montent dès que toutes les répétitions passent.',
    niveau: Niveau.debutant,
    objectif: 'Découvrir et prendre de la force',
    joursParSemaine: 3,
    semaines: 6,
    progression: ProgressionType.charge,
    icon: Icons.school_rounded,
    conseils: [
      'Garde deux ou trois répétitions en réserve au début : la technique d\'abord.',
      'Un jour de repos entre deux séances, par exemple lundi, mercredi, vendredi.',
    ],
    routines: [
      ModeleRoutine('Débutant A', [
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['developpe-couche-machine'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['tirage-vertical'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['elevations-laterales'], series: 2, reps: 12, repsMax: 15, repos: 60),
        _e(['leg-curl-assis', 'leg-curl-allonge'], series: 2, reps: 12, repos: 60),
        _e(['gainage'], series: 3, reps: 1, dureeSec: 30, repos: 45),
      ]),
      ModeleRoutine('Débutant B', [
        _e(['squat-goblet', 'squat'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['developpe-incline-halteres'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['tirage-horizontal'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['souleve-de-terre-roumain-halteres', 'souleve-de-terre-roumain'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['curl-halteres'], series: 2, reps: 12, repos: 60, superset: 'a'),
        _e(['extension-triceps-poulie-haute'], series: 2, reps: 12, repos: 60, superset: 'a'),
        _e(['crunch'], series: 2, reps: 15, repos: 45),
      ]),
    ],
    cycle: [0, 1],
  ),
  ModeleProgramme(
    id: 'full-body-3j',
    nom: 'Full body 3 jours',
    resume: 'Trois séances corps entier par semaine',
    description:
        'Chaque muscle travaillé trois fois par semaine avec trois séances différentes : un mouvement de base lourd en tête, puis du volume. Idéal quand on ne peut venir que trois fois.',
    niveau: Niveau.intermediaire,
    objectif: 'Force et masse',
    joursParSemaine: 3,
    semaines: 8,
    progression: ProgressionType.charge,
    decharge: 4,
    icon: Icons.accessibility_new_rounded,
    conseils: ['Toutes les quatre semaines, une semaine plus légère pour récupérer.'],
    routines: [
      ModeleRoutine('Full body A', [
        _e(['squat'], series: 3, reps: 6, repsMax: 8, repos: 180, echauffements: 2),
        _e(['developpe-couche'], series: 3, reps: 6, repsMax: 8, repos: 150, echauffements: 1),
        _e(['rowing-barre'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['developpe-militaire'], series: 2, reps: 8, repsMax: 10, repos: 120),
        _e(['curl-halteres'], series: 2, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
        _e(['extension-triceps-poulie-haute'], series: 2, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
        _e(['gainage'], series: 3, reps: 1, dureeSec: 45, repos: 45),
      ]),
      ModeleRoutine('Full body B', [
        _e(['souleve-de-terre'], series: 3, reps: 5, repos: 180, echauffements: 2),
        _e(['developpe-incline-halteres'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['tirage-vertical'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['fentes-marchees', 'fentes-avant'], series: 2, reps: 10, repsMax: 12, repos: 90),
        _e(['elevations-laterales'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['crunch'], series: 3, reps: 15, repos: 45),
      ]),
      ModeleRoutine('Full body C', [
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['dips-pectoraux'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['rowing-haltere-unilateral'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['souleve-de-terre-roumain'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['face-pull'], series: 3, reps: 15, repsMax: 20, repos: 60),
        _e(['mollets-debout-machine'], series: 3, reps: 12, repsMax: 15, repos: 60),
      ]),
    ],
    cycle: [0, 1, 2],
  ),
  ModeleProgramme(
    id: 'cinq-par-cinq',
    nom: '5x5',
    resume: 'Trois mouvements lourds, cinq séries de cinq',
    description:
        'Le grand classique de la force : deux séances A et B qui alternent, trois exercices polyarticulaires, cinq séries de cinq répétitions et 2,5 kg de plus à chaque séance réussie.',
    niveau: Niveau.debutant,
    objectif: 'Force',
    joursParSemaine: 3,
    semaines: 12,
    progression: ProgressionType.charge,
    icon: Icons.fitness_center_rounded,
    conseils: [
      'Commence léger : la moitié de ce que tu peux faire pour cinq répétitions.',
      'Trois échecs de suite sur un mouvement : baisse la charge de 10 % et remonte.',
    ],
    routines: [
      ModeleRoutine('5x5 A', [
        _e(['squat'], series: 5, reps: 5, repos: 180, echauffements: 2),
        _e(['developpe-couche'], series: 5, reps: 5, repos: 180, echauffements: 1),
        _e(['rowing-barre', 'rowing-pendlay'], series: 5, reps: 5, repos: 180),
      ]),
      ModeleRoutine('5x5 B', [
        _e(['squat'], series: 5, reps: 5, repos: 180, echauffements: 2),
        _e(['developpe-militaire'], series: 5, reps: 5, repos: 180, echauffements: 1),
        _e(['souleve-de-terre'], series: 1, reps: 5, repos: 180, echauffements: 2),
      ]),
    ],
    cycle: [0, 1],
  ),
  ModeleProgramme(
    id: 'haut-bas-4j',
    nom: 'Haut/Bas 4 jours',
    resume: 'Haut du corps et bas du corps, force puis volume',
    description:
        'Quatre séances : haut et bas orientés force en début de semaine, haut et bas orientés volume ensuite (la méthode PHUL). Chaque muscle deux fois par semaine, un bon équilibre entre force et hypertrophie.',
    niveau: Niveau.intermediaire,
    objectif: 'Force et hypertrophie',
    joursParSemaine: 4,
    semaines: 10,
    progression: ProgressionType.doubleProgression,
    decharge: 5,
    icon: Icons.swap_vert_rounded,
    routines: [
      ModeleRoutine('Haut force', [
        _e(['developpe-couche'], series: 4, reps: 5, repsMax: 7, repos: 180, echauffements: 2),
        _e(['rowing-barre'], series: 4, reps: 6, repsMax: 8, repos: 150),
        _e(['developpe-militaire'], series: 3, reps: 6, repsMax: 8, repos: 150),
        _e(['tractions'], series: 3, reps: 6, repsMax: 10, repos: 150),
        _e(['curl-barre'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
        _e(['extension-triceps-poulie-haute'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
      ]),
      ModeleRoutine('Bas force', [
        _e(['squat'], series: 4, reps: 5, repsMax: 7, repos: 180, echauffements: 2),
        _e(['souleve-de-terre'], series: 3, reps: 3, repsMax: 5, repos: 180, echauffements: 2),
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['leg-curl-allonge', 'leg-curl-assis'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['mollets-debout-machine'], series: 4, reps: 8, repsMax: 12, repos: 60),
        _e(['gainage'], series: 3, reps: 1, dureeSec: 60, repos: 45),
      ]),
      ModeleRoutine('Haut volume', [
        _e(['developpe-incline-halteres'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['tirage-vertical'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['rowing-haltere-unilateral'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['elevations-laterales'], series: 4, reps: 12, repsMax: 15, repos: 60),
        _e(['ecarte-a-la-poulie-vis-a-vis'], series: 3, reps: 12, repsMax: 15, repos: 60, superset: 'a'),
        _e(['oiseau'], series: 3, reps: 12, repsMax: 15, repos: 60, superset: 'a'),
        _e(['curl-incline'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
        _e(['extension-nuque-barre-ez', 'extension-nuque-haltere'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
      ]),
      ModeleRoutine('Bas volume', [
        _e(['souleve-de-terre-roumain'], series: 3, reps: 8, repsMax: 10, repos: 150, echauffements: 1),
        _e(['fentes-marchees', 'fentes-avant'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['hip-thrust'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['leg-extension'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['leg-curl-assis', 'leg-curl-allonge'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['mollets-assis-machine', 'mollets-debout-machine'], series: 4, reps: 12, repsMax: 15, repos: 60),
        _e(['crunch-inverse', 'crunch'], series: 3, reps: 15, repos: 45),
      ]),
    ],
    cycle: [0, 1, 2, 3],
  ),
  ModeleProgramme(
    id: 'push-pull-legs-6j',
    nom: 'Push Pull Legs 6 jours',
    resume: 'Pousser, tirer, jambes, deux fois par semaine',
    description:
        'La répartition la plus répandue pour l\'hypertrophie : poussée (pectoraux, épaules, triceps), tirage (dos, biceps) et jambes, chaque séance faite deux fois par semaine.',
    niveau: Niveau.avance,
    objectif: 'Hypertrophie',
    joursParSemaine: 6,
    semaines: 8,
    progression: ProgressionType.doubleProgression,
    decharge: 6,
    icon: Icons.sync_alt_rounded,
    conseils: ['Un jour de repos par semaine, après les jambes par exemple.'],
    routines: [
      ModeleRoutine('Push', [
        _e(['developpe-couche'], series: 4, reps: 6, repsMax: 8, repos: 180, echauffements: 2),
        _e(['developpe-incline-halteres'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['developpe-militaire-assis', 'developpe-militaire'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['elevations-laterales'], series: 4, reps: 12, repsMax: 15, repos: 60),
        _e(['ecarte-a-la-poulie-vis-a-vis', 'ecarte-couche-halteres'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['extension-triceps-poulie-haute'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
        _e(['extension-nuque-haltere'], series: 2, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
      ]),
      ModeleRoutine('Pull', [
        _e(['tractions'], series: 4, reps: 6, repsMax: 10, repos: 150),
        _e(['rowing-barre'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['tirage-horizontal'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['face-pull'], series: 3, reps: 15, repsMax: 20, repos: 60),
        _e(['shrugs-halteres', 'shrugs-barre'], series: 3, reps: 10, repsMax: 12, repos: 60),
        _e(['curl-barre-ez', 'curl-barre'], series: 3, reps: 8, repsMax: 12, repos: 60, superset: 'a'),
        _e(['curl-marteau'], series: 2, reps: 10, repsMax: 12, repos: 60, superset: 'a'),
      ]),
      ModeleRoutine('Legs', [
        _e(['squat'], series: 4, reps: 6, repsMax: 8, repos: 180, echauffements: 2),
        _e(['souleve-de-terre-roumain'], series: 3, reps: 8, repsMax: 10, repos: 150),
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['leg-curl-assis', 'leg-curl-allonge'], series: 3, reps: 10, repsMax: 12, repos: 60),
        _e(['leg-extension'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['mollets-debout-machine'], series: 4, reps: 10, repsMax: 15, repos: 60),
        _e(['crunch-a-la-poulie', 'crunch'], series: 3, reps: 12, repsMax: 15, repos: 45),
      ]),
    ],
    cycle: [0, 1, 2],
  ),
  ModeleProgramme(
    id: 'arnold-split',
    nom: 'Arnold split',
    resume: 'Pecs et dos, épaules et bras, jambes',
    description:
        'La répartition de l\'âge d\'or du culturisme : pectoraux et dos ensemble, épaules et bras ensemble, puis jambes, chaque séance deux fois par semaine. Beaucoup de volume et de supersets antagonistes.',
    niveau: Niveau.avance,
    objectif: 'Hypertrophie',
    joursParSemaine: 6,
    semaines: 8,
    progression: ProgressionType.doubleProgression,
    decharge: 6,
    icon: Icons.emoji_events_rounded,
    routines: [
      ModeleRoutine('Pectoraux et dos', [
        _e(['developpe-couche'], series: 4, reps: 6, repsMax: 10, repos: 150, echauffements: 2),
        _e(['tractions-prise-large', 'tractions'], series: 4, reps: 6, repsMax: 10, repos: 150),
        _e(['developpe-incline-halteres'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['rowing-barre'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['dips-pectoraux'], series: 3, reps: 8, repsMax: 12, repos: 90),
        _e(['ecarte-couche-halteres'], series: 3, reps: 10, repsMax: 12, repos: 75, superset: 'a'),
        _e(['pull-over-haltere'], series: 3, reps: 10, repsMax: 12, repos: 75, superset: 'a'),
      ]),
      ModeleRoutine('Épaules et bras', [
        _e(['developpe-arnold'], series: 4, reps: 8, repsMax: 10, repos: 120, echauffements: 1),
        _e(['elevations-laterales'], series: 4, reps: 12, repsMax: 15, repos: 60),
        _e(['oiseau'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['curl-barre'], series: 3, reps: 8, repsMax: 10, repos: 75, superset: 'a'),
        _e(['extension-nuque-barre-ez', 'extension-nuque-haltere'], series: 3, reps: 8, repsMax: 10, repos: 75, superset: 'a'),
        _e(['curl-incline'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
        _e(['extension-triceps-poulie-haute'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
      ]),
      ModeleRoutine('Jambes', [
        _e(['squat'], series: 4, reps: 8, repsMax: 10, repos: 180, echauffements: 2),
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['souleve-de-terre-jambes-tendues', 'souleve-de-terre-roumain'], series: 3, reps: 10, repos: 120),
        _e(['leg-curl-allonge', 'leg-curl-assis'], series: 4, reps: 10, repsMax: 12, repos: 60),
        _e(['leg-extension'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['mollets-debout-machine'], series: 5, reps: 12, repsMax: 15, repos: 60),
        _e(['crunch'], series: 3, reps: 20, repos: 45),
      ]),
    ],
    cycle: [0, 1, 2],
  ),
  ModeleProgramme(
    id: 'split-5j',
    nom: 'Split 5 jours',
    resume: 'Un groupe musculaire par jour',
    description:
        'Cinq séances, un groupe par jour : pectoraux, dos, épaules, jambes, bras. Chaque muscle a sa séance entière, avec beaucoup de volume et une semaine pour récupérer.',
    niveau: Niveau.intermediaire,
    objectif: 'Prise de muscle',
    joursParSemaine: 5,
    semaines: 8,
    progression: ProgressionType.doubleProgression,
    decharge: 6,
    icon: Icons.view_week_rounded,
    conseils: ['Garde une ou deux répétitions en réserve sur les premières séries, va au bout sur la dernière.'],
    routines: [
      ModeleRoutine('Pectoraux', [
        _e(['developpe-couche'], series: 4, reps: 6, repsMax: 10, repos: 150, echauffements: 2),
        _e(['developpe-incline-halteres'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['dips-pectoraux'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['ecarte-a-la-poulie-vis-a-vis', 'ecarte-couche-halteres'], series: 3, reps: 12, repsMax: 15, repos: 75),
        _e(['pec-deck', 'ecarte-incline-halteres'], series: 3, reps: 12, repsMax: 15, repos: 60),
      ]),
      ModeleRoutine('Dos', [
        _e(['tractions'], series: 4, reps: 6, repsMax: 10, repos: 150),
        _e(['rowing-barre'], series: 4, reps: 8, repsMax: 10, repos: 120),
        _e(['tirage-vertical'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['tirage-horizontal'], series: 3, reps: 10, repsMax: 12, repos: 90),
        _e(['shrugs-halteres'], series: 3, reps: 12, repsMax: 15, repos: 60),
      ]),
      ModeleRoutine('Épaules', [
        _e(['developpe-militaire'], series: 4, reps: 6, repsMax: 10, repos: 150, echauffements: 1),
        _e(['developpe-arnold'], series: 3, reps: 8, repsMax: 12, repos: 120),
        _e(['elevations-laterales'], series: 4, reps: 12, repsMax: 15, repos: 60),
        _e(['oiseau'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['face-pull'], series: 3, reps: 15, repsMax: 20, repos: 60),
      ]),
      ModeleRoutine('Jambes', [
        _e(['squat'], series: 4, reps: 6, repsMax: 10, repos: 180, echauffements: 2),
        _e(['presse-a-cuisses'], series: 3, reps: 10, repsMax: 12, repos: 120),
        _e(['souleve-de-terre-roumain'], series: 3, reps: 8, repsMax: 10, repos: 120),
        _e(['leg-extension'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['leg-curl-allonge', 'leg-curl-assis'], series: 3, reps: 10, repsMax: 12, repos: 60),
        _e(['mollets-debout-machine'], series: 4, reps: 12, repsMax: 15, repos: 60),
      ]),
      ModeleRoutine('Bras', [
        _e(['curl-barre'], series: 4, reps: 8, repsMax: 10, repos: 75, superset: 'a'),
        _e(['barre-au-front', 'extension-triceps-couche-halteres'], series: 4, reps: 8, repsMax: 10, repos: 75, superset: 'a'),
        _e(['curl-incline'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
        _e(['extension-triceps-poulie-haute'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'b'),
        _e(['curl-marteau'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'c'),
        _e(['extension-nuque-haltere'], series: 3, reps: 10, repsMax: 12, repos: 60, superset: 'c'),
      ]),
    ],
    cycle: [0, 1, 2, 3, 4],
  ),
  ModeleProgramme(
    id: 'maison-3j',
    nom: 'À la maison',
    resume: 'Trois séances au poids du corps, sans matériel',
    description:
        'Trois séances corps entier à faire chez soi, sans rien d\'autre que le sol. On progresse en gagnant des répétitions, puis en passant à une variante plus dure.',
    niveau: Niveau.debutant,
    objectif: 'Forme et tonus',
    joursParSemaine: 3,
    semaines: 6,
    progression: ProgressionType.doubleProgression,
    icon: Icons.home_rounded,
    conseils: ['Quand le haut de la fourchette passe sur toutes les séries, ralentis la descente ou prends la variante suivante.'],
    routines: [
      ModeleRoutine('Maison A', [
        _e(['pompes'], series: 3, reps: 8, repsMax: 15, repos: 90),
        _e(['squat-au-poids-du-corps'], series: 3, reps: 15, repsMax: 20, repos: 60),
        _e(['pont-fessier'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['pike-push-ups', 'pompes-declinees'], series: 3, reps: 6, repsMax: 10, repos: 90),
        _e(['gainage'], series: 3, reps: 1, dureeSec: 40, repos: 45),
      ]),
      ModeleRoutine('Maison B', [
        _e(['fentes-au-poids-du-corps', 'fentes-marchees'], series: 3, reps: 10, repsMax: 12, repos: 75),
        _e(['pompes-inclinees'], series: 3, reps: 8, repsMax: 12, repos: 90),
        _e(['squat-saute'], series: 3, reps: 10, repsMax: 12, repos: 75),
        _e(['extensions-lombaires-au-sol', 'bird-dog'], series: 3, reps: 12, repsMax: 15, repos: 60),
        _e(['crunch-velo', 'crunch'], series: 3, reps: 15, repsMax: 20, repos: 45),
      ]),
      ModeleRoutine('Maison C', [
        _e(['pompes-prise-large'], series: 3, reps: 8, repsMax: 12, repos: 90),
        _e(['fentes-laterales', 'fentes-au-poids-du-corps'], series: 3, reps: 8, repsMax: 12, repos: 90),
        _e(['dips-sur-banc'], series: 3, reps: 8, repsMax: 15, repos: 75),
        _e(['mollets-au-poids-du-corps'], series: 3, reps: 15, repsMax: 20, repos: 45),
        _e(['mountain-climbers'], series: 3, reps: 20, repos: 45),
        _e(['gainage-lateral'], series: 2, reps: 1, dureeSec: 30, repos: 45),
      ]),
    ],
    cycle: [0, 1, 2],
  ),
];

ModeleProgramme? modeleParId(String id) => _modelesParId[id];

/// Premier identifiant du modèle présent dans le catalogue.
String? resoudreExercice(ModeleExercice e, ExerciseRepo repo) {
  for (final id in e.ids) {
    if (repo.byId(id) != null) return id;
  }
  return null;
}

/// Routine d'un modèle, prête à enregistrer (id vide).
Routine routineDepuisModele(ModeleRoutine m, ExerciseRepo repo, {String? folderId, int reposEchauffement = 60}) {
  final ss = <String, String>{};
  final exercices = <RoutineExercise>[];
  for (final e in m.exercices) {
    final id = resoudreExercice(e, repo);
    if (id == null) continue;
    final suivi = repo.byId(id)?.suivi ?? ExerciseTracking.poidsReps;
    final duree = suivi.usesDuration && !suivi.usesReps;
    exercices.add(RoutineExercise(
      id: newId(),
      exerciseId: id,
      reposSec: e.repos,
      supersetId: e.superset == null ? null : (ss[e.superset!] ??= newId()),
      series: [
        for (var i = 0; i < e.echauffements; i++)
          PlannedSet(type: SetType.echauffement, reps: i == 0 ? 10 : 5),
        for (var i = 0; i < e.series; i++)
          duree
              ? PlannedSet(dureeSec: e.dureeSec ?? 45, rpe: e.rpe)
              : PlannedSet(reps: e.reps, repsMax: e.repsMax, rpe: e.rpe, dureeSec: suivi.usesDuration ? e.dureeSec : null),
      ],
    ));
  }
  return Routine(
    id: '',
    nom: m.nom,
    folderId: folderId,
    exercices: normaliserSupersets(exercices),
    creeLe: DateTime.now(),
  );
}

/// Exercices du modèle absents du catalogue (affichés en avertissement).
List<String> exercicesManquants(ModeleProgramme m, ExerciseRepo repo) => [
      for (final r in m.routines)
        for (final e in r.exercices)
          if (resoudreExercice(e, repo) == null) e.ids.first,
    ];

/// Crée les routines, le programme et son plan à partir d'un modèle.
Future<Program> creerProgrammeDepuisModele({
  required ModeleProgramme modele,
  required ExerciseRepo exercices,
  required RoutineRepo routines,
  required ProgramRepo programmes,
  required ProgramPlanRepo plans,
  int? semaines,
  bool activer = true,

  /// Nom du programme, quand celui du modèle est déjà pris.
  String? nom,
  List<int> jours = const [],
}) async {
  final crees = <Routine>[];
  for (final m in modele.routines) {
    crees.add(await routines.save(routineDepuisModele(m, exercices)));
  }
  final prog = await programmes.save(Program(
    id: '',
    nom: nom ?? modele.nom,
    description: modele.description,
    dureeSemaines: semaines ?? modele.semaines,
    joursParSemaine: modele.joursParSemaine,
    routineIds: [for (final i in modele.cycle) crees[i].id],
    niveau: modele.niveau.name,
    objectif: modele.objectif,
    creeLe: DateTime.now(),
  ));
  await plans.save(ProgramPlan(
    programId: prog.id,
    progression: modele.progression,
    incrementKg: modele.increment,
    dechargeToutesLes: modele.decharge,
    jours: jours,
  ).copyWithModele(modele.id));
  if (activer) await programmes.activate(prog.id, restart: true);
  return programmes.byId(prog.id) ?? prog;
}

extension on ProgramPlan {
  ProgramPlan copyWithModele(String id) => ProgramPlan(
        programId: programId,
        progression: progression,
        incrementKg: incrementKg,
        dechargeToutesLes: dechargeToutesLes,
        jours: jours,
        modeleId: id,
        photo: photo,
      );
}
