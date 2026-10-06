import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import 'idees.dart';
import 'program_blocs.dart';
import 'program_plan.dart';
import 'program_templates.dart';

/// Séries, répétitions et repos d'un rôle dans une formule.
class _Dose {
  const _Dose(this.series, this.reps, this.max, this.repos, {this.w = 0, this.sec = 40});
  final int series;
  final int reps;
  final int? max;
  final int repos;

  /// Séries d'échauffement.
  final int w;

  /// Durée d'une série pour les exercices tenus ou chronométrés.
  final int sec;
}

/// Façon de doser une séance : la même séance type devient une séance de
/// force, de volume ou de sèche selon la formule du programme.
class Formule {
  const Formule(this.objectif, this.progression, this._doses);
  final String objectif;
  final ProgressionType progression;
  final Map<String, _Dose> _doses;

  _Dose _dose(String role) => _doses[role] ?? _commun[role] ?? _doses['S']!;

  /// Rôles dosés pareil partout.
  static const _commun = {
    'G': _Dose(3, 1, null, 45, sec: 40),
    'P': _Dose(4, 5, null, 90),
    'H': _Dose(4, 12, 15, 30, sec: 30),
    'C': _Dose(1, 1, null, 60, sec: 600),
    'E': _Dose(2, 1, null, 15, sec: 40),
  };
}

/// Dosage propre à un exercice, quelle que soit la formule : un soulevé de
/// terre ne se fait pas en quinze répétitions, une figure ne se tient pas
/// quarante secondes. Les champs absents laissent faire la formule.
class _Regle {
  const _Regle({this.series, this.seriesMax, this.reps, this.max, this.plafond, this.repos, this.reposMin, this.w, this.sec});
  final int? series;
  final int? seriesMax;
  final int? reps;
  final int? max;

  /// Nombre de répétitions à ne pas dépasser : au-delà, on retombe sur [reps] à [plafond].
  final int? plafond;
  final int? repos;
  final int? reposMin;
  final int? w;
  final int? sec;
}

const _terre = _Regle(seriesMax: 3, reps: 5, plafond: 8, reposMin: 150);
const _traction = _Regle(reps: 5, max: 10, reposMin: 90, w: 0);
const _fente = _Regle(reps: 10, max: 15, repos: 75, w: 0);
const _olympique = _Regle(series: 4, reps: 3, max: 3, repos: 120, w: 2);
const _statique = _Regle(series: 5, sec: 10, repos: 120);

const _regles = <String, _Regle>{
  // Soulevés de terre et squats techniques : jamais de séries longues.
  'souleve-de-terre': _terre,
  'souleve-de-terre-sumo': _terre,
  'souleve-de-terre-trap-bar': _terre,
  'squat-avant': _Regle(reps: 5, plafond: 8),
  'pause-squat': _Regle(reps: 4, plafond: 6),
  'barre-au-front': _Regle(reps: 10, plafond: 12),
  // Poids du corps : pas d'échauffement chargé, des fourchettes tenables.
  'tractions': _traction,
  'tractions-prise-large': _traction,
  'tractions-supination': _traction,
  'tractions-prise-neutre': _traction,
  'dips-pectoraux': _Regle(reps: 6, max: 12, reposMin: 90, w: 0),
  'dips-aux-anneaux': _Regle(reps: 5, max: 10, reposMin: 120, w: 0),
  'tractions-lestees': _Regle(w: 1),
  'dips-lestes': _Regle(w: 1),
  'tractions-australiennes': _Regle(reps: 8, max: 12, w: 0),
  'tractions-scapulaires': _Regle(reps: 8, max: 12, w: 0),
  'tractions-assistees-a-l-elastique': _Regle(series: 3, reps: 5, max: 8, repos: 120, w: 0),
  'negative-pull-ups': _Regle(series: 4, reps: 3, max: 5, repos: 120, w: 0),
  // Sans charge : beaucoup de répétitions, peu de repos.
  'squat-au-poids-du-corps': _Regle(reps: 15, max: 25, repos: 60, w: 0),
  'fentes-au-poids-du-corps': _fente,
  'fentes-marchees': _fente,
  'fentes-laterales': _fente,
  'bodyweight-reverse-lunge': _fente,
  'fente-statique': _fente,
  'squat-cosaque': _Regle(reps: 8, max: 12, repos: 75, w: 0),
  'step-up': _Regle(reps: 10, max: 12, repos: 75, w: 0),
  'pont-fessier': _Regle(reps: 12, max: 20, repos: 60, w: 0),
  'pont-fessier-unilateral': _Regle(reps: 10, max: 15, repos: 60, w: 0),
  'mollets-au-poids-du-corps': _Regle(reps: 15, max: 25, repos: 45, w: 0),
  'mollets-unilateral': _Regle(reps: 10, max: 15, repos: 45, w: 0),
  // Mouvements durs : peu de répétitions, du repos.
  'muscle-up': _Regle(series: 5, reps: 2, max: 5, repos: 180, w: 0),
  'pompes-en-equilibre': _Regle(series: 3, reps: 3, max: 8, repos: 120, w: 0),
  'tractions-archer': _Regle(series: 3, reps: 4, max: 8, repos: 120, w: 0),
  'pistol-squat': _Regle(series: 4, reps: 4, max: 8, repos: 120, w: 0),
  'pseudo-planche-push-ups': _Regle(series: 3, reps: 6, max: 10, repos: 90, w: 0),
  'pompes-archer': _Regle(reps: 5, max: 10, w: 0),
  'pompes-claquees': _Regle(series: 4, reps: 5, max: 8, repos: 90, w: 0),
  'nordic-curl': _Regle(series: 3, reps: 4, max: 8, repos: 120, w: 0),
  'toes-to-bar': _Regle(series: 3, reps: 6, max: 10, repos: 75),
  'roue-abdominale': _Regle(series: 3, reps: 6, max: 12, repos: 75),
  'releves-de-jambes-suspendu': _Regle(reps: 8, max: 15, repos: 60),
  'turkish-get-up': _Regle(series: 3, reps: 2, max: 3, repos: 90, w: 0),
  'kettlebell-swing': _Regle(series: 4, reps: 12, max: 15, repos: 90, w: 0),
  'one-arm-kettlebell-swing': _Regle(series: 3, reps: 10, max: 12, repos: 75, w: 0),
  'box-jump': _Regle(series: 4, reps: 5, max: 5, repos: 90, w: 0),
  // Haltérophilie : la vitesse d'abord.
  'epaule-jete': _Regle(series: 5, reps: 2, max: 3, repos: 150, w: 3),
  'arrache': _Regle(series: 5, reps: 2, max: 3, repos: 150, w: 3),
  'epaule': _olympique,
  'hang-power-clean': _olympique,
  'hang-clean': _olympique,
  'push-jerk': _olympique,
  'muscle-snatch': _olympique,
  'squat-bras-tendus': _Regle(series: 3, reps: 5, max: 5, repos: 120, w: 1),
  // Tenues.
  'front-lever': _statique,
  'planche': _statique,
  'back-lever': _statique,
  'l-sit': _Regle(sec: 15, repos: 60),
  'hollow-body-hold': _Regle(sec: 25),
  'reverse-plank': _Regle(sec: 20),
  'trx-side-plank': _Regle(sec: 20),
  'chin-tuck-hold': _Regle(series: 3, sec: 10, repos: 15),
  'savasana': _Regle(series: 1, sec: 180, repos: 0),
  'mountain-pose': _Regle(series: 1),
};

/// Exercices sans barre à charger : pas de série d'échauffement.
const _sansEchauffement = [
  'pompes', 'tractions', 'trx-', 'ring', 'dips', 'kettlebell', 'one-arm-kettlebell', 'double-kettlebell',
  'squat-goblet', 'squat-saute', 'burpees', 'banded', 'squat-a-l-elastique', 'curl-a-l-elastique', 'ecartes-a-l', 'pike-push',
];

const _double = ProgressionType.doubleProgression;

const debut = Formule('Apprendre les mouvements', ProgressionType.charge, {
  'B': _Dose(3, 8, 10, 120, w: 1),
  'S': _Dose(3, 10, 12, 90),
  'I': _Dose(2, 12, 15, 60),
  'U': _Dose(2, 12, 15, 45),
  'G': _Dose(3, 1, null, 45, sec: 30),
});
const muscle = Formule('Prise de muscle', _double, {
  'B': _Dose(4, 6, 10, 150, w: 2),
  'S': _Dose(3, 8, 12, 120),
  'I': _Dose(3, 10, 15, 60),
  'U': _Dose(3, 12, 20, 45),
  'G': _Dose(3, 1, null, 45, sec: 45),
});
const volume = Formule('Hypertrophie', _double, {
  'B': _Dose(4, 6, 10, 150, w: 2),
  'S': _Dose(4, 8, 12, 90),
  'I': _Dose(3, 12, 15, 60),
  'U': _Dose(3, 15, 20, 45),
  'G': _Dose(3, 1, null, 45, sec: 60),
});
const force = Formule('Force', ProgressionType.charge, {
  'B': _Dose(5, 3, 5, 210, w: 3),
  'S': _Dose(3, 5, 8, 150),
  'I': _Dose(3, 8, 12, 75),
  'U': _Dose(3, 10, 15, 60),
  'G': _Dose(3, 1, null, 60, sec: 45),
});
const competition = Formule('Force maximale', ProgressionType.charge, {
  'B': _Dose(5, 2, 4, 240, w: 3),
  'S': _Dose(3, 4, 6, 180),
  'I': _Dose(3, 8, 12, 90),
  'U': _Dose(3, 10, 15, 60),
});
const frequence = Formule('Force et masse', ProgressionType.charge, {
  'B': _Dose(3, 4, 6, 150, w: 2),
  'S': _Dose(2, 6, 8, 90),
  'I': _Dose(2, 10, 12, 60),
  'U': _Dose(2, 12, 15, 45),
  'G': _Dose(2, 1, null, 45, sec: 40),
});
const maintien = Formule('Garder ses acquis', ProgressionType.aucune, {
  'B': _Dose(3, 5, 8, 150, w: 2),
  'S': _Dose(2, 8, 10, 90),
  'I': _Dose(2, 10, 12, 60),
  'U': _Dose(2, 12, 15, 45),
});
const seche = Formule('Perte de gras', _double, {
  'B': _Dose(3, 10, 12, 90, w: 1),
  'S': _Dose(3, 12, 15, 60),
  'I': _Dose(3, 15, 20, 45),
  'U': _Dose(3, 15, 20, 30),
  'G': _Dose(3, 1, null, 30, sec: 45),
  'C': _Dose(1, 1, null, 60, sec: 900),
});
const express = Formule('Rester en forme', _double, {
  'B': _Dose(3, 8, 10, 90, w: 1),
  'S': _Dose(2, 10, 12, 60),
  'I': _Dose(2, 12, 15, 45),
  'U': _Dose(2, 15, null, 30),
  'G': _Dose(2, 1, null, 30, sec: 40),
});
const corps = Formule('Force au poids du corps', _double, {
  'B': _Dose(4, 6, 12, 90),
  'S': _Dose(3, 8, 15, 75),
  'I': _Dose(3, 12, 20, 45),
  'U': _Dose(3, 15, 20, 45),
});
const corpsDebut = Formule('Forme et tonus', _double, {
  'B': _Dose(3, 6, 12, 75),
  'S': _Dose(2, 8, 12, 60),
  'I': _Dose(2, 10, 15, 45),
  'U': _Dose(2, 10, 15, 30),
  'G': _Dose(2, 1, null, 30, sec: 25),
  'H': _Dose(3, 10, 12, 40, sec: 20),
});
const court = Formule('Sangle abdominale', _double, {
  'U': _Dose(2, 12, 15, 30),
  'S': _Dose(2, 12, 15, 30),
  'G': _Dose(2, 1, null, 30, sec: 30),
});
const circuit = Formule('Brûler des calories', ProgressionType.aucune, {
  'B': _Dose(3, 12, 15, 45),
  'S': _Dose(3, 12, 15, 30),
  'I': _Dose(3, 15, 20, 30),
  'U': _Dose(3, 20, null, 30),
  'G': _Dose(3, 1, null, 30, sec: 40),
});
const doux = Formule('Forme et santé', ProgressionType.aucune, {
  'B': _Dose(2, 10, 12, 90),
  'S': _Dose(2, 10, 12, 90),
  'I': _Dose(2, 12, 15, 60),
  'U': _Dose(2, 10, 12, 45),
  'G': _Dose(2, 1, null, 45, sec: 20),
  'E': _Dose(2, 1, null, 15, sec: 30),
});
const explosif = Formule('Puissance', ProgressionType.charge, {
  'B': _Dose(4, 3, 5, 180, w: 2),
  'S': _Dose(3, 6, 8, 120),
  'I': _Dose(3, 10, 12, 60),
  'U': _Dose(3, 10, 15, 45),
});
const souple = Formule('Mobilité', ProgressionType.aucune, {
  'B': _Dose(2, 10, 12, 45),
  'S': _Dose(2, 10, 12, 30),
  'I': _Dose(2, 12, 15, 30),
  'U': _Dose(2, 10, 12, 30),
  'G': _Dose(2, 1, null, 30, sec: 30),
});
const eclair = Formule('Mobilité', ProgressionType.aucune, {
  'S': _Dose(1, 10, 15, 30),
  'E': _Dose(1, 1, null, 10, sec: 40),
  'G': _Dose(2, 1, null, 15, sec: 10),
});
const tenue = Formule('Souplesse et équilibre', ProgressionType.aucune, {
  'S': _Dose(2, 10, 12, 30),
  'E': _Dose(2, 1, null, 15, sec: 60),
});
const longue = Formule('Souplesse', ProgressionType.aucune, {
  'S': _Dose(2, 10, 12, 30),
  'E': _Dose(2, 1, null, 20, sec: 90),
});
const endurance = Formule('Souffle et endurance', ProgressionType.aucune, {
  'S': _Dose(3, 15, 20, 45),
  'C': _Dose(1, 1, null, 60, sec: 900),
});
const cardioDoux = Formule('Souffle et endurance', ProgressionType.aucune, {
  'S': _Dose(3, 15, 20, 45),
});
const dixParDix = Formule('Hypertrophie', ProgressionType.charge, {
  'B': _Dose(10, 10, null, 90, w: 1),
  'S': _Dose(3, 10, 12, 60),
  'I': _Dose(3, 10, 15, 60),
  'U': _Dose(3, 15, 20, 60),
});

final _superset = RegExp(r'^[a-d]$');
final _impose = RegExp(r'^=(\d+)x(\d+)(?:-(\d+))?$');
final _nombre = RegExp(r'^([xrw@])(\d+)$');

/// Un programme du catalogue, écrit en peu de mots : ses séances types et
/// la formule qui les dose.
class Fiche {
  const Fiche(
    this.id,
    this.nom,
    this.rayon,
    this.niveau,
    this.jours,
    this.semaines,
    this.formule,
    this.blocs,
    this.resume,
    this.description, {
    this.cycle,
    this.formules,
    this.noms,
    this.gros,
    this.bandeau,
    this.pose,
    this.objectif,
    this.decharge = 0,
    this.conseils = const [],
  });

  final String id;
  final String nom;
  final Rayon rayon;
  final Niveau niveau;
  final int jours;
  final int semaines;
  final Formule formule;
  final List<Bloc> blocs;
  final String resume;
  final String description;

  /// Ordre des séances ; à défaut, chacune une fois.
  final List<int>? cycle;

  /// Une formule par séance, quand elles ne sont pas toutes dosées pareil.
  final List<Formule>? formules;

  /// Nom de chaque séance dans ce programme, quand celui de la séance type
  /// ne convient pas.
  final List<String>? noms;

  /// Couverture : titre, bandeau et exercice dont on montre la pose.
  final String? gros;
  final String? bandeau;
  final String? pose;
  final String? objectif;
  final int decharge;
  final List<String> conseils;

  static ModeleExercice _exercice(String ligne, Formule f) {
    final t = ligne.split(' ');
    final role = t[0];
    final id = t[1];
    final d = f._dose(role);
    var series = d.series;
    var reps = d.reps;
    var max = d.max;
    var repos = d.repos;
    var w = d.w;
    var sec = d.sec;
    if (_sansEchauffement.any(id.startsWith)) w = 0;
    final r = _regles[id];
    if (r != null) {
      // En intervalles, c'est le rythme de la séance qui commande.
      final dosable = role != 'H';
      if (dosable && r.plafond != null) {
        if ((max ?? reps) > r.plafond!) {
          reps = r.reps!;
          max = r.plafond;
        }
      } else if (dosable && r.reps != null) {
        reps = r.reps!;
        max = r.max;
      }
      if (dosable && r.series != null) series = r.series!;
      if (r.seriesMax != null && series > r.seriesMax!) series = r.seriesMax!;
      if (dosable && r.repos != null) repos = r.repos!;
      if (r.reposMin != null && repos < r.reposMin!) repos = r.reposMin!;
      if (r.w != null) w = r.w!;
      if (r.sec != null) sec = r.sec!;
    }
    if (max != null && max <= reps) max = null;
    String? superset;
    for (final x in t.skip(2)) {
      final impose = _impose.firstMatch(x);
      final n = _nombre.firstMatch(x);
      if (_superset.hasMatch(x)) {
        superset = x;
      } else if (impose != null) {
        series = int.parse(impose.group(1)!);
        reps = int.parse(impose.group(2)!);
        max = impose.group(3) == null ? null : int.parse(impose.group(3)!);
      } else if (n != null) {
        final v = int.parse(n.group(2)!);
        switch (n.group(1)) {
          case 'x':
            series = v;
          case 'r':
            repos = v;
          case 'w':
            w = v;
          case '@':
            sec = v;
        }
      }
    }
    return ModeleExercice([id], series: series, reps: reps, repsMax: max, repos: repos, echauffements: w, superset: superset, dureeSec: sec);
  }

  ModeleProgramme get modele => ModeleProgramme(
        id: id,
        nom: nom,
        resume: resume,
        description: description,
        niveau: niveau,
        objectif: objectif ?? formule.objectif,
        joursParSemaine: jours,
        semaines: semaines,
        progression: formule.progression,
        decharge: decharge,
        icon: Icons.fitness_center_rounded,
        conseils: conseils,
        routines: [
          for (final (i, b) in blocs.indexed)
            ModeleRoutine(noms?[i] ?? b.nom, [for (final l in b.lignes) _exercice(l, formules?[i] ?? formule)]),
        ],
        cycle: cycle ?? [for (var i = 0; i < blocs.length; i++) i],
      );

  /// Exercices du programme, les têtes de séance d'abord : les candidats
  /// à la pose de la couverture.
  Iterable<String> get _candidats sync* {
    final plusLongue = blocs.fold(0, (n, b) => b.lignes.length > n ? b.lignes.length : n);
    for (var rang = 0; rang < plusLongue; rang++) {
      for (final b in blocs) {
        if (rang < b.lignes.length) yield b.lignes[rang].split(' ')[1];
      }
    }
  }

  IdeeProgramme _idee(String pose) => IdeeProgramme(
        modeleId: id,
        gros: gros ?? nom,
        bandeau: bandeau ?? '$jours jours',
        titre: nom,
        rayon: rayon,
        poses: [pose],
      );
}

/// Les couvertures du catalogue. Chaque programme montre une pose qu'aucun
/// autre n'a déjà prise : celle qu'il demande, sinon son premier exercice
/// encore libre.
final List<IdeeProgramme> ideesCatalogue = () {
  final prises = <String>{for (final f in fiches) ?f.pose};
  return [
    for (final f in fiches)
      f._idee(f.pose ?? () {
        final pose = f._candidats.firstWhere((p) => !prises.contains(p), orElse: () => f._candidats.first);
        prises.add(pose);
        return pose;
      }()),
  ];
}();

const _deb = Niveau.debutant;
const _int = Niveau.intermediaire;
const _av = Niveau.avance;

/// Le catalogue, rayon par rayon.
const fiches = <Fiche>[
  // Débuter.
  Fiche('premiers-pas-2j', 'Premiers pas', Rayon.debuter, _deb, 2, 4, debut, [machinesA, machinesB],
      'Deux séances aux machines pour démarrer',
      'Deux séances par semaine, uniquement sur des machines guidées. Le but : prendre ses repères dans la salle et installer l’habitude sans se faire mal.',
      bandeau: 'Aux machines', conseils: ['Règle chaque machine à ta taille avant de charger.']),
  Fiche('debutant-machines-3j', 'Débutant machines', Rayon.debuter, _deb, 3, 6, debut, [machinesHaut, machinesBas, machinesA],
      'Haut, bas, puis corps entier, tout aux machines',
      'Trois séances guidées : le haut du corps, le bas, puis une séance qui reprend tout. Les machines tiennent la trajectoire, tu te concentres sur l’effort. Convient aussi pour se raffermir.',
      gros: 'Machines', bandeau: 'Débutant', noms: ['Haut du corps', 'Bas du corps', 'Corps entier']),
  Fiche('debutant-halteres-3j', 'Débutant haltères', Rayon.debuter, _deb, 3, 6, debut, [halteresA, halteresB],
      'Deux séances corps entier, des haltères et un banc',
      'Deux séances en alternance avec des haltères et un banc réglable. Les charges libres apprennent l’équilibre et font travailler chaque côté autant que l’autre.',
      gros: 'Haltères', bandeau: 'Débutant', cycle: [0, 1]),
  Fiche('debutant-haut-bas-4j', 'Débutant haut/bas', Rayon.debuter, _deb, 4, 8, debut, [machinesHaut, machinesBas, halteresHaut, halteresBas],
      'Quatre séances : machines puis haltères',
      'Le haut et le bas deux fois par semaine : d’abord aux machines pour charger en sécurité, puis aux haltères pour gagner en contrôle.',
      gros: 'Haut / Bas', bandeau: 'Débutant'),
  Fiche('debutant-ppl-3j', 'Débutant Push Pull Legs', Rayon.debuter, _deb, 3, 8, debut, [machinesPush, machinesPull, machinesLegs],
      'Pousser, tirer, jambes, version guidée',
      'La répartition la plus connue, en version débutant : une séance pour pousser, une pour tirer, une pour les jambes, sur machines et poulies. Chaque muscle travaille une fois par semaine.',
      gros: 'Pousser · Tirer · Jambes', bandeau: 'Débutant'),
  Fiche('reprise-3j', 'Reprise en douceur', Rayon.debuter, _deb, 3, 4, doux, [machinesA, halteresA, machinesB],
      'Revenir après une longue pause',
      'Quatre semaines pour reprendre : deux séries par exercice, des charges légères et du repos. On réveille le corps avant de repartir sur un vrai programme.',
      gros: 'Reprise', bandeau: '4 semaines', noms: ['Reprise A', 'Reprise B', 'Reprise C'],
      conseils: ['Reste loin de l’échec : tu dois finir chaque série en pouvant en faire trois de plus.', 'À partir de la troisième semaine, ajoute une série aux deux premiers exercices.']),
  Fiche('debutant-barre-guidee-3j', 'Débutant barre guidée', Rayon.debuter, _deb, 3, 6, debut, [guideeA, guideeB],
      'Les grands mouvements à la barre guidée',
      'Squat, développé couché et soulevé de terre roumain à la barre guidée : le geste des barres libres sans avoir à gérer l’équilibre. Deux séances en alternance.',
      gros: 'Barre guidée', bandeau: 'Débutant', cycle: [0, 1]),
  Fiche('apprendre-les-barres-3j', 'Apprendre les barres', Rayon.debuter, _deb, 3, 8, debut, [fbA, fbB],
      'Squat, développé couché, soulevé de terre',
      'Deux séances corps entier construites autour des barres libres. On commence léger, on soigne la technique, et la charge monte à chaque séance réussie.',
      gros: 'Les barres', bandeau: 'Technique', cycle: [0, 1], noms: ['Squat et développé couché', 'Soulevé de terre'],
      conseils: ['Filme-toi de profil sur le squat et le soulevé de terre pour vérifier ton dos.']),

  // Prise de muscle.
  Fiche('ppl-3j', 'Push Pull Legs 3 jours', Rayon.muscle, _int, 3, 8, muscle, [pushA, pullA, legsA],
      'Pousser, tirer, jambes, une fois chacun',
      'Les trois séances du Push Pull Legs une fois par semaine : assez de volume par muscle pour progresser, et quatre jours pour récupérer. Tu peux aussi faire tourner le cycle sur quatre séances par semaine.',
      gros: 'PPL', bandeau: '3 jours', decharge: 6, noms: ['Push', 'Pull', 'Legs']),
  Fiche('ppl-haut-bas-5j', 'PPL + Haut/Bas', Rayon.muscle, _int, 5, 8, muscle, [pushB, pullB, legsB, hautB, basA],
      'Trois séances PPL, puis haut et bas',
      'Le meilleur des deux répartitions : Push, Pull, Legs en début de semaine, puis une séance haut et une séance bas pour toucher chaque muscle deux fois.',
      gros: 'PPL + Haut/Bas', bandeau: '5 jours', decharge: 6, noms: ['Push', 'Pull', 'Legs', 'Haut', 'Bas']),
  Fiche('ppl-ab-6j', 'Push Pull Legs A/B', Rayon.muscle, _av, 6, 8, volume, [pushA, pullA, legsA, pushB, pullB, legsB],
      'Six séances différentes par semaine',
      'Deux versions de chaque séance : la première autour du développé couché, des tractions et du squat, la seconde autour du développé militaire, du soulevé de terre et du hack squat.',
      gros: 'PPL A/B', bandeau: '6 jours', decharge: 6, pose: 'developpe-incline'),
  Fiche('full-body-4j', 'Full body 4 jours', Rayon.muscle, _int, 4, 8, muscle, [fbA, fbB, fbC, fbD],
      'Quatre séances corps entier, toutes différentes',
      'Chaque muscle est travaillé quatre fois par semaine avec un mouvement différent à chaque fois. Compte une bonne heure par séance.',
      gros: 'Full body', bandeau: '4 jours', decharge: 4, pose: 'hip-thrust'),
  Fiche('full-body-5j', 'Full body haute fréquence', Rayon.muscle, _av, 5, 6, frequence, [fbA, fbB, fbC, fbD],
      'Cinq séances, tout le corps chaque jour',
      'Tout le corps cinq fois par semaine : les mouvements de base en trois séries lourdes, les accessoires en deux séries. La répétition fréquente des gestes fait progresser vite en technique et en force.',
      gros: 'Haute fréquence', bandeau: '5 jours', cycle: [0, 1, 2, 3, 0], pose: 'squat-avant'),
  Fiche('split-3j', 'Split 3 jours', Rayon.muscle, _int, 3, 8, muscle, [pecsDos, jambes, epaulesBras],
      'Pecs et dos, jambes, épaules et bras',
      'Trois grosses séances : pectoraux et dos en supersets, jambes, puis épaules et bras. Idéal pour qui aime sentir un muscle bien travaillé.',
      gros: 'Split', bandeau: '3 jours'),
  Fiche('split-4j', 'Split 4 jours', Rayon.muscle, _int, 4, 8, muscle, [pecsTriceps, dosBiceps, jambes, epaulesAbdos],
      'Pecs-triceps, dos-biceps, jambes, épaules-abdos',
      'Le split classique en quatre jours : chaque séance associe un grand groupe et le petit muscle qui l’aide. Une semaine entière pour récupérer.',
      gros: 'Split', bandeau: '4 jours', decharge: 6),
  Fiche('split-6j', 'Split 6 jours', Rayon.muscle, _av, 6, 8, volume, [pecs, dos, quads, epaules, bras, ischiosFessiers],
      'Un groupe par jour, les jambes en deux fois',
      'Six séances, une par groupe : pectoraux, dos, quadriceps, épaules, bras, puis ischios et fessiers. Beaucoup de volume par muscle, pour pratiquants confirmés.',
      gros: 'Split', bandeau: '6 jours', decharge: 6, pose: 'developpe-arnold'),
  Fiche('torse-membres-4j', 'Torse / Membres', Rayon.muscle, _int, 4, 8, muscle, [torse, membres],
      'Le tronc un jour, bras et jambes le lendemain',
      'Une répartition peu connue et très efficace : pectoraux et dos ensemble, puis bras, épaules et jambes. Les bras arrivent frais à leur séance.',
      gros: 'Torse / Membres', bandeau: '4 jours', cycle: [0, 1, 0, 1]),
  Fiche('anterieur-posterieur-4j', 'Antérieur / Postérieur', Rayon.muscle, _int, 4, 8, muscle, [anterieur, posterieur, posterieurB],
      'Les muscles de devant, puis ceux de derrière',
      'Un jour pour tout ce qui pousse (quadriceps, pectoraux, épaules, triceps), un jour pour tout ce qui tire (ischios, dos, biceps). Chaque chaîne deux fois par semaine, le soulevé de terre lourd une seule fois.',
      gros: 'Avant / Arrière', bandeau: '4 jours', cycle: [0, 1, 0, 2]),
  Fiche('volume-allemand', 'Volume allemand 10 × 10', Rayon.muscle, _av, 3, 6, dixParDix, [dixA, dixB, dixC],
      'Dix séries de dix sur les mouvements de base',
      'La méthode du volume allemand : dix séries de dix répétitions à charge fixe sur deux mouvements par séance. Simple, brutal, et réservé à ceux qui récupèrent bien.',
      gros: '10 × 10', bandeau: 'Volume allemand', conseils: ['Prends une charge que tu pourrais faire vingt fois : les dernières séries seront dures.', 'Quand les dix séries de dix passent, ajoute 2,5 kg.']),
  Fiche('machines-4j', '100 % machines', Rayon.muscle, _int, 4, 8, muscle, [machinesHaut, machinesBasB, machinesHautB, machinesBas],
      'Prendre du muscle sans barre libre',
      'Quatre séances entièrement sur machines et poulies : deux pour le haut, deux pour le bas, toutes différentes. Aucun mouvement technique, tu peux pousser chaque série très près de l’échec en sécurité.',
      gros: 'Machines', bandeau: '4 jours', noms: ['Haut A', 'Bas A', 'Haut B', 'Bas B'], pose: 'hack-squat'),
  Fiche('gros-volume-5j', 'Gros volume', Rayon.muscle, _av, 5, 8, volume, [pecsDos, legsA, epaulesBras, legsB, hautB],
      'Supersets et deux jours de jambes',
      'Cinq séances chargées : pectoraux et dos en supersets, épaules et bras, deux séances de jambes et un rappel du haut du corps en fin de semaine.',
      gros: 'Gros volume', bandeau: '5 jours', decharge: 4, noms: ['Pectoraux et dos', 'Jambes, squat', 'Épaules et bras', 'Jambes, fessiers', 'Rappel du haut']),
  Fiche('salle-a-la-maison-3j', 'Salle à la maison', Rayon.muscle, _int, 3, 8, muscle, [rackA, rackB, rackC],
      'Une barre, un banc, un support, rien d’autre',
      'Trois séances corps entier pour ceux qui s’entraînent dans leur garage : uniquement des mouvements à la barre, sans machine ni poulie.',
      gros: 'Home gym', bandeau: 'Barre et banc', pose: 'rowing-pendlay'),

  // Force.
  Fiche('cycle-force-4j', 'Cycle force 4 jours', Rayon.force, _int, 4, 12, force, [jourSquat, jourCouche, jourTerre, jourMilitaire],
      'Un grand mouvement par séance',
      'Quatre séances, chacune centrée sur un mouvement : squat, développé couché, soulevé de terre, développé militaire. Le mouvement du jour se travaille lourd, le reste l’assiste.',
      gros: 'Cycle force', bandeau: '4 mouvements', decharge: 4),
  Fiche('force-minimaliste-3j', 'Force minimaliste', Rayon.force, _int, 3, 10, force, [forceA, forceB],
      'Trois exercices par séance, rien de plus',
      'Deux séances de trois mouvements lourds. Pas d’accessoires : toute l’énergie va dans les barres. Compte une heure, les repos sont longs.',
      gros: 'Minimaliste', bandeau: 'Force', cycle: [0, 1]),
  Fiche('force-haut-bas-4j', 'Force haut/bas', Rayon.force, _int, 4, 10, force, [hautA, basA, hautLourd, basLourd],
      'Quatre séances lourdes, quatre mouvements rois',
      'Développé couché et squat en début de semaine, développé militaire et soulevé de terre ensuite. Chaque séance s’ouvre sur des séries de trois à cinq répétitions.',
      gros: 'Haut / Bas', bandeau: 'Force', decharge: 5, pose: 'tractions-lestees'),
  Fiche('powerlifting-4j', 'Force athlétique', Rayon.force, _av, 4, 12, competition, [jourSquat, jourCouche, jourTerre, coucheVolume],
      'Squat, couché, terre, comme en compétition',
      'Préparer les trois mouvements de la force athlétique : des séries de deux à quatre répétitions très lourdes, cinq minutes de repos, et le développé couché deux fois par semaine.',
      gros: 'Powerlifting', bandeau: '3 mouvements', formules: [competition, competition, competition, muscle], decharge: 4, pose: 'paused-bench-press',
      conseils: ['Les dernières semaines, passe à trois séries de deux, puis teste ton maximum.']),
  Fiche('special-developpe-couche', 'Spécial développé couché', Rayon.force, _int, 3, 8, muscle, [jourCouche, coucheVolume, pecsTriceps],
      'Trois séances pour débloquer ton couché',
      'Le développé couché trois fois par semaine sous trois formes : lourd, avec pause sur la poitrine, puis en volume avec les triceps. Programme de spécialisation : garde une séance de jambes à côté.',
      gros: 'Développé couché', bandeau: 'Spécial', formules: [force, muscle, muscle], objectif: 'Force', pose: 'developpe-couche-prise-serree'),
  Fiche('special-squat', 'Spécial squat', Rayon.force, _int, 3, 8, muscle, [jourSquat, squatVolume, quads],
      'Trois séances pour monter ton squat',
      'Le squat lourd avec un squat en pause, une séance autour du squat avant, puis une séance de volume pour les quadriceps. Programme de spécialisation : garde une séance pour le haut du corps à côté.',
      gros: 'Squat', bandeau: 'Spécial', formules: [force, muscle, muscle], objectif: 'Force', pose: 'pause-squat'),
  Fiche('special-souleve-de-terre', 'Spécial soulevé de terre', Rayon.force, _int, 3, 8, muscle, [jourTerre, dosSansTerre, basA],
      'Trois séances pour ton soulevé de terre',
      'Le soulevé de terre lourd une fois par semaine, une séance pour le dos qui verrouille la barre, et une séance de jambes pour le départ du sol. Programme de spécialisation : garde une séance de poussée à côté.',
      gros: 'Soulevé de terre', bandeau: 'Spécial', formules: [force, muscle, muscle], objectif: 'Force', noms: ['Jour soulevé de terre', 'Dos', 'Jambes']),
  Fiche('halterophilie-3j', 'Initiation haltérophilie', Rayon.force, _int, 3, 8, explosif, [halteroA, halteroB],
      'Épaulé-jeté et arraché',
      'Découvrir les deux mouvements olympiques : une séance autour de l’épaulé-jeté, une autour de l’arraché, en séries de deux ou trois répétitions rapides.',
      gros: 'Haltérophilie', bandeau: 'Initiation', cycle: [0, 1],
      conseils: ['N’ajoute de la charge que si toutes les répétitions sont propres et rapides.', 'Idéalement, fais-toi montrer les mouvements par un entraîneur au début.']),
  Fiche('porter-soulever-3j', 'Porter et soulever', Rayon.force, _int, 3, 8, force, [porterA, porterB],
      'Barres lourdes, marches lestées et poigne',
      'Chaque séance commence par deux mouvements lourds et finit par des portés : marche du fermier, valise, haltère au-dessus de la tête. Une force utile, celle qui sert à déménager.',
      gros: 'Costaud', bandeau: 'Porter · Soulever', cycle: [0, 1], pose: 'marche-du-fermier'),

  // Sèche et tonus.
  Fiche('seche-full-body-3j', 'Sèche full body', Rayon.seche, _int, 3, 8, seche, [secheA, secheB, secheC],
      'Supersets et finition cardio',
      'Trois séances corps entier : un mouvement de jambes, un superset pousser-tirer, puis quatre intervalles de cardio pour finir. On garde le muscle pendant que le régime fait fondre le gras.',
      gros: 'Sèche', bandeau: 'Full body'),
  Fiche('seche-ppl-cardio-5j', 'Sèche PPL + cardio', Rayon.seche, _int, 5, 8, seche, [pushA, pullA, legsA, cardioA, circuitA],
      'Trois séances de muscu, une de cardio, un circuit',
      'Push, Pull, Legs pour garder le muscle, une séance de cardio doux pour la dépense, et une séance complète à repos courts pour finir la semaine.',
      gros: 'Sèche', bandeau: 'PPL + cardio', noms: ['Push', 'Pull', 'Legs', 'Cardio doux', 'Corps entier à repos courts'], pose: 'velo-elliptique'),
  Fiche('circuit-brule-graisse-3j', 'Circuit brûle-graisse', Rayon.seche, _int, 3, 6, circuit, [circuitA, circuitB],
      'Tout le corps, trente secondes de repos',
      'Deux séances de sept exercices avec des repos très courts. Le cœur monte, tout le corps travaille, la séance dure quarante minutes.',
      gros: 'Circuit', bandeau: 'Brûle-graisse', cycle: [0, 1],
      conseils: ['Fais les trois séries d’un exercice, puis passe au suivant sans traîner.']),
  Fiche('seche-haut-bas-4j', 'Sèche haut/bas', Rayon.seche, _int, 4, 8, seche, [hautB, intervallesSalle, basB, fbC],
      'Haut, intervalles, bas, corps entier',
      'Quatre séances pour sécher sans perdre de muscle : le haut, une séance d’intervalles sur les appareils, le bas, puis un rappel de tout le corps.',
      gros: 'Sèche', bandeau: 'Haut / Bas', noms: ['Haut du corps', 'Intervalles', 'Bas du corps', 'Corps entier']),
  Fiche('metabolique-halteres-3j', 'Métabolique haltères', Rayon.seche, _int, 3, 6, circuit, [halteresCircuit, halteresCircuitB],
      'Une paire d’haltères, beaucoup de sueur',
      'Des enchaînements d’haltères qui mobilisent tout le corps : squats, poussées, tirages, fentes. Aucun banc nécessaire, à faire chez soi ou en salle.',
      gros: 'Métabolique', bandeau: 'Haltères', cycle: [0, 1]),
  Fiche('affutage-6j', 'Affûtage', Rayon.seche, _av, 6, 6, maintien, [hautA, basA, cardioA, hautB, basB, intervallesSalle],
      'Quatre séances lourdes, deux séances de cardio',
      'Pour finir une sèche : on garde des charges lourdes avec peu de séries pour conserver le muscle, et on ajoute une séance de cardio doux et une séance d’intervalles.',
      gros: 'Affûtage', bandeau: '6 jours', objectif: 'Perte de gras', formules: [maintien, maintien, seche, maintien, maintien, seche],
      noms: ['Haut lourd', 'Bas lourd', 'Cardio doux', 'Haut volume', 'Bas volume', 'Intervalles'], pose: 'ecarte-a-la-poulie-vis-a-vis'),
  Fiche('muscu-cardio-4j', 'Moitié muscu, moitié cardio', Rayon.seche, _deb, 4, 8, seche, [guideA, cardioA, guideB, cardioB],
      'Deux séances de muscu, deux séances de cardio',
      'Un jour de musculation guidée, un jour de cardio, et on recommence. L’équilibre le plus simple pour perdre du gras en restant en forme.',
      gros: 'Muscu + cardio', bandeau: '4 jours', formules: [seche, cardioDoux, seche, cardioDoux], pose: 'rameur'),

  // À la maison.
  Fiche('maison-debutant-2j', 'Maison débutant', Rayon.maison, _deb, 2, 4, doux, [maisonDebutA, maisonDebutB],
      'Deux séances faciles, sans matériel',
      'Pompes sur les genoux ou mains surélevées, squats, ponts et gainage : deux séances d’un quart d’heure pour se remettre à bouger chez soi. Un rebord de canapé suffit.',
      gros: 'Chez soi', bandeau: 'Débutant'),
  Fiche('maison-haut-bas-4j', 'Maison haut/bas', Rayon.maison, _int, 4, 8, corps, [maisonHaut, maisonBas],
      'Quatre séances au poids du corps',
      'Le haut du corps avec des pompes sous tous les angles, le bas avec des fentes, des squats sautés et des ponts sur une jambe. Il te faut une chaise solide pour les dips ; sans barre, le dos travaille surtout en gainage.',
      gros: 'Haut / Bas', bandeau: 'Sans matériel', cycle: [0, 1, 0, 1]),
  Fiche('maison-5j', 'Maison 5 jours', Rayon.maison, _int, 5, 8, corps, [maisonHaut, maisonBas, maisonAbdosA, maisonIntervalles, maisonDos],
      'Cinq séances courtes et variées',
      'Haut, bas, abdos, intervalles, puis dos et gainage : cinq séances différentes pour ne jamais s’ennuyer, avec une chaise pour seul matériel.',
      gros: 'Chez soi', bandeau: '5 jours', pose: 'pont-fessier-unilateral'),
  Fiche('maison-barre-de-traction-3j', 'Maison avec barre de traction', Rayon.maison, _int, 3, 8, corps, [porteA, maisonBas, porteB],
      'Pousser, tirer et jambes avec une barre de porte',
      'La barre de traction change tout : le dos travaille enfin autant que les pectoraux. Deux séances pour le haut, une pour les jambes.',
      gros: 'Barre de porte', bandeau: 'Tractions + pompes', noms: ['Tractions et pompes A', 'Jambes', 'Tractions et pompes B'], objectif: 'Force au poids du corps', pose: 'tractions-supination',
      conseils: ['Les tractions australiennes se font sous une table solide ou avec la barre réglée bas.']),
  Fiche('hiit-maison-3j', 'Intervalles à la maison', Rayon.maison, _int, 3, 6, circuit, [maisonIntervalles, maisonRafales],
      'Vingt minutes, le cœur à fond',
      'Une séance au chronomètre (trente secondes d’effort, trente de repos) et une séance de séries rapides avec burpees et squats sautés. Fais deux minutes de montées de genoux tranquilles avant de commencer.',
      gros: 'HIIT', bandeau: 'Sans matériel', cycle: [0, 1], objectif: 'Perte de gras'),
  Fiche('defi-pompes', 'Défi pompes', Rayon.maison, _int, 3, 6, corps, [maisonPompes],
      'Six semaines pour progresser aux pompes',
      'Une séance de pompes sous cinq formes, trois fois par semaine. Teste ton maximum avant de commencer, gagne une répétition sur au moins une série à chaque séance, et reteste au bout de six semaines.',
      gros: 'Défi pompes', bandeau: '6 semaines', cycle: [0, 0, 0]),
  Fiche('defi-squats', 'Défi squats', Rayon.maison, _deb, 3, 6, corps, [maisonSquats],
      'Des jambes solides sans matériel',
      'Squats, squats sautés, fentes et chaise : la même séance trois fois par semaine. Gagne une répétition sur au moins une série à chaque séance.',
      gros: 'Défi squats', bandeau: '6 semaines', cycle: [0, 0, 0]),
  Fiche('abdos-maison-4j', 'Abdos à la maison', Rayon.maison, _deb, 4, 6, court, [maisonAbdosA, maisonAbdosB],
      'Un quart d’heure d’abdos, quatre fois par semaine',
      'Deux séances de cinq exercices : crunchs, relevés de jambes, rotations et gainage. À faire seules ou à la fin d’une autre séance.',
      gros: 'Abdos', bandeau: 'Chez soi', cycle: [0, 1, 0, 1]),
  Fiche('sans-bruit-3j', 'Sans saut, sans bruit', Rayon.maison, _deb, 3, 6, corpsDebut, [maisonSilence, maisonSilenceB],
      'Pour les appartements et les voisins',
      'Aucun saut, aucun impact : des squats, des fentes arrière, des pompes et du gainage. On transpire sans réveiller l’étage du dessous.',
      gros: 'Sans bruit', bandeau: 'En appartement', cycle: [0, 1]),
  Fiche('vingt-minutes-5j', '20 minutes par jour', Rayon.maison, _deb, 5, 6, corpsDebut, [vingtA, vingtB, vingtC, maisonAbdosA, mobiliteMatin],
      'Une petite séance cinq jours par semaine',
      'Quatre exercices, deux séries, vingt minutes : trois séances de renforcement, une d’abdos et une de mobilité. L’idée : en faire peu, mais ne jamais sauter un jour.',
      gros: '20 minutes', bandeau: 'Par jour', noms: ['Renforcement A', 'Renforcement B', 'Renforcement C', 'Abdos', 'Mobilité']),
  Fiche('fessiers-maison-3j', 'Fessiers à la maison', Rayon.maison, _deb, 3, 8, corpsDebut, [maisonFessiers, maisonBasDebut],
      'Ponts, fentes et abductions au sol',
      'Deux séances pour les fessiers et les cuisses, sans matériel : ponts sur une jambe, fentes arrière, élévations de jambe et tenues.',
      gros: 'Fessiers', bandeau: 'Sans matériel', cycle: [0, 1], objectif: 'Fessiers et cuisses'),

  // Haltères.
  Fiche('halteres-full-body-3j', 'Haltères full body', Rayon.halteres, _int, 3, 8, muscle, [halteresA, halteresB, halteresC],
      'Trois séances avec des haltères et un banc',
      'Tout le corps trois fois par semaine avec des haltères réglables et un banc inclinable. De quoi construire un vrai physique à la maison.',
      gros: 'Haltères', bandeau: 'Full body'),
  Fiche('halteres-haut-bas-4j', 'Haltères haut/bas', Rayon.halteres, _int, 4, 8, muscle, [halteresHaut, halteresBas],
      'Haut et bas, deux fois par semaine',
      'Quatre séances aux haltères, avec un banc : développés, rowings et bras pour le haut ; squats, fentes et soulevés de terre roumains pour le bas.',
      gros: 'Haut / Bas', bandeau: 'Haltères', cycle: [0, 1, 0, 1]),
  Fiche('halteres-ppl-3j', 'Haltères Push Pull Legs', Rayon.halteres, _int, 3, 8, muscle, [halteresPush, halteresPull, halteresLegs],
      'Le PPL avec des haltères et un banc',
      'Pousser, tirer, jambes : la répartition classique adaptée aux haltères. Quand tu veux plus, fais tourner le cycle deux fois dans la semaine.',
      gros: 'PPL', bandeau: 'Haltères'),
  Fiche('halteres-sans-banc-3j', 'Haltères sans banc', Rayon.halteres, _deb, 3, 6, debut, [sansBancA, sansBancB],
      'Seulement une paire d’haltères',
      'Deux séances corps entier qui se font debout ou au sol : squat avant, développé au sol, rowing buste penché, fentes. Rien d’autre que deux haltères.',
      gros: 'Sans banc', bandeau: 'Deux haltères', cycle: [0, 1]),

  // Kettlebell.
  Fiche('kettlebell-3j', 'Kettlebell complet', Rayon.kettlebell, _int, 3, 8, muscle, [kettlebellA, kettlebellB, kettlebellC],
      'Trois séances avec une seule kettlebell',
      'Balancés, squats gobelet, développés et relevés turcs : trois séances qui mêlent force, souffle et gainage. Avec un seul poids, on progresse en ajoutant des répétitions.',
      gros: 'Kettlebell', bandeau: '3 jours'),
  Fiche('kettlebell-debutant-2j', 'Kettlebell débutant', Rayon.kettlebell, _deb, 2, 6, debut, [kettlebellDebutA, kettlebellDebutB],
      'Apprendre le soulevé, puis le balancé',
      'Deux séances pour apprivoiser la kettlebell : d’abord le soulevé de terre et le squat gobelet, puis le balancé, qui part du même geste de hanches.',
      gros: 'Kettlebell', bandeau: 'Débutant', conseils: ['Sur le balancé, ce sont les hanches qui lancent le poids, pas les bras.']),
  Fiche('kettlebell-brule-graisse-3j', 'Kettlebell brûle-graisse', Rayon.kettlebell, _int, 3, 6, circuit, [kettlebellComplexeA, kettlebellComplexeB],
      'Quatre tours, quarante-cinq secondes de repos',
      'Balancés, squats, développés et rowings enchaînés avec très peu de repos. Une des façons les plus efficaces de dépenser beaucoup en peu de temps.',
      gros: 'Kettlebell', bandeau: 'Brûle-graisse', cycle: [0, 1], objectif: 'Perte de gras', pose: 'kettlebell-swing-clean'),
  Fiche('double-kettlebell-3j', 'Double kettlebell', Rayon.kettlebell, _av, 3, 8, muscle, [kettlebellDouble, kettlebellC],
      'Deux kettlebells, des mouvements lourds',
      'Épaulés-développés, squats avant et rowings avec deux kettlebells, complétés par une séance à un bras. Pour ceux qui maîtrisent déjà les bases.',
      gros: 'Double KB', bandeau: 'Force', cycle: [0, 1], objectif: 'Force'),

  // Élastiques.
  Fiche('elastiques-3j', 'Élastiques complet', Rayon.elastiques, _deb, 3, 6, corpsDebut, [elastiquesA, elastiquesB],
      'Tout le corps avec des bandes élastiques',
      'Squats, soulevés de terre, écartés et curls à l’élastique, complétés par des pompes. Il te faut une bande longue et une mini-bande ; le tout tient dans une valise, idéal en déplacement.',
      gros: 'Élastiques', bandeau: 'Corps entier', cycle: [0, 1]),
  Fiche('elastiques-fessiers-3j', 'Fessiers à l’élastique', Rayon.elastiques, _deb, 3, 8, corpsDebut, [elastiquesFessiers, elastiquesCuisses],
      'Deux séances fessiers et cuisses avec un élastique',
      'Ponts, marches latérales, abductions, puis squats et soulevés de terre à l’élastique : le muscle reste sous tension du début à la fin du geste.',
      gros: 'Fessiers', bandeau: 'Élastique', cycle: [0, 1], objectif: 'Fessiers et cuisses'),

  // Barres et anneaux.
  Fiche('barre-debutant-3j', 'Street workout débutant', Rayon.barres, _deb, 3, 8, corpsDebut, [barreDebut, maisonBasDebut],
      'Les bases à la barre et au sol',
      'Tractions négatives, tractions australiennes, pompes et dips sur banc : tout ce qu’il faut pour aller vers la première vraie traction.',
      gros: 'Street workout', bandeau: 'Débutant', cycle: [0, 1, 0], noms: ['Bases à la barre', 'Jambes']),
  Fiche('barre-ppl-3j', 'Street workout PPL', Rayon.barres, _int, 3, 8, corps, [barrePush, barrePull, barreLegs],
      'Pousser, tirer, jambes, au poids du corps',
      'Dips et pompes pour pousser, tractions pour tirer, pistols et nordic curls pour les jambes. Il te faut une barre, deux barres parallèles et de quoi bloquer tes pieds.',
      gros: 'Street workout', bandeau: 'Push · Pull · Legs'),
  Fiche('barre-et-dips-3j', 'Barre et dips', Rayon.barres, _int, 3, 8, corps, [barreComplet, barreLegs],
      'Tractions et dips, la base de tout',
      'Une séance complète autour des tractions et des dips, une séance de jambes. Le programme le plus simple pour un physique d’athlète.',
      gros: 'Barre et dips', bandeau: '3 jours', cycle: [0, 1, 0]),
  Fiche('premiere-traction', 'Première traction', Rayon.barres, _deb, 3, 8, corpsDebut, [barreTractions],
      'Huit semaines pour passer ta première traction',
      'Tractions négatives, tractions aidées par un élastique, tractions australiennes et suspensions : la même séance trois fois par semaine jusqu’à monter le menton au-dessus de la barre.',
      gros: 'Première traction', bandeau: '8 semaines', cycle: [0, 0, 0], pose: 'negative-pull-ups',
      conseils: ['Sur les négatives, mets cinq secondes à descendre.', 'Chaque semaine, tente une vraie traction en début de séance.']),
  Fiche('figures-3j', 'Figures', Rayon.barres, _av, 3, 12, corps, [barreFigures, figuresTirer, figuresPousser],
      'Muscle-up, front lever, planche',
      'Une séance de figures quand tu es frais, puis un tirage lourd et une poussée lourde pour construire la force qui les rend possibles. Programme de spécialisation : garde une séance de jambes à côté.',
      gros: 'Figures', bandeau: 'Muscle-up · Lever', pose: 'front-lever',
      conseils: ['Si la figure complète ne passe pas, fais la version groupée, genoux repliés.', 'Les tenues sont courtes : cinq à douze secondes propres valent mieux que trente bâclées.']),
  Fiche('sangles-3j', 'Sangles de suspension', Rayon.barres, _deb, 3, 6, corpsDebut, [sanglesA, sanglesB],
      'Tout le corps avec une paire de sangles',
      'Poussées, tirages, squats et gainage suspendus. Plus tu t’inclines, plus c’est dur : les sangles s’adaptent à tous les niveaux.',
      gros: 'Sangles', bandeau: 'Suspension', cycle: [0, 1]),
  Fiche('anneaux-3j', 'Anneaux', Rayon.barres, _av, 3, 8, corps, [anneaux, barreLegs],
      'Dips, tractions et pompes aux anneaux',
      'Les anneaux bougent, et tout le corps doit les stabiliser. Une séance aux anneaux, une séance de jambes au poids du corps.',
      gros: 'Anneaux', bandeau: '3 jours', cycle: [0, 1, 0],
      conseils: ['Avant les dips, tiens dix secondes bras tendus en appui sur les anneaux.']),
  Fiche('leste-3j', 'Tractions et dips lestés', Rayon.barres, _av, 3, 10, force, [barreLeste, jambesAthlete],
      'Ajouter du poids au poids du corps',
      'Quand quinze tractions passent, on ajoute du lest. Séries courtes, repos longs, et la ceinture qui s’alourdit de séance en séance.',
      gros: 'Lesté', bandeau: 'Force', cycle: [0, 1, 0]),

  // Cibler une zone.
  Fiche('fessiers-3j', 'Fessiers 3 jours', Rayon.cible, _int, 3, 10, muscle, [fessiersA, fessiersB, fessiersC],
      'Trois séances centrées sur les fessiers',
      'Hip thrust, squat sumo et soulevé de terre sumo en tête de séance, puis fentes, abductions et extensions. Les fessiers sous tous les angles.',
      gros: 'Fessiers', bandeau: '3 jours', objectif: 'Fessiers et cuisses'),
  Fiche('fessiers-jambes-4j', 'Fessiers et jambes', Rayon.cible, _int, 4, 10, muscle, [fessiersA, quads, fessiersB, ischiosFessiers],
      'Quatre séances pour le bas du corps',
      'Deux séances pour les fessiers, une pour les quadriceps, une pour les ischios. Pour celles et ceux qui veulent tout miser sur les jambes.',
      gros: 'Fessiers + jambes', bandeau: '4 jours', objectif: 'Fessiers et cuisses', pose: 'squat-bulgare'),
  Fiche('special-bras-4j', 'Spécial bras', Rayon.cible, _int, 4, 8, muscle, [brasA, basA, brasB, torse],
      'Deux séances de bras par semaine',
      'Biceps, triceps et avant-bras travaillés deux fois par semaine, frais, en début de séance. Le reste du corps est entretenu en deux séances.',
      gros: 'Bras', bandeau: 'Spécial', objectif: 'Biceps et triceps', noms: ['Bras, biceps d’abord', 'Jambes', 'Bras, triceps d’abord', 'Pectoraux et dos']),
  Fiche('epaules-larges-4j', 'Épaules larges', Rayon.cible, _int, 4, 8, muscle, [epaules, basA, epaulesB, pecsDos],
      'Élargir la carrure',
      'Deux séances d’épaules avec beaucoup d’élévations latérales et de travail arrière, une séance de jambes, une séance pectoraux et dos.',
      gros: 'Épaules', bandeau: 'Spécial', objectif: 'Épaules', pose: 'elevations-laterales', noms: ['Épaules', 'Jambes', 'Épaules, arrière et côtés', 'Pectoraux et dos']),
  Fiche('special-pectoraux-4j', 'Spécial pectoraux', Rayon.cible, _int, 4, 8, muscle, [pecs, basA, pecsB, dos],
      'Deux séances de pectoraux par semaine',
      'Une séance autour du développé couché, une autour du développé incliné, avec écartés et pull-over. Le dos et les jambes complètent la semaine.',
      gros: 'Pectoraux', bandeau: 'Spécial', objectif: 'Pectoraux', noms: ['Pectoraux', 'Jambes', 'Pectoraux, haut du torse', 'Dos']),
  Fiche('dos-large-4j', 'Dos large', Rayon.cible, _int, 4, 8, muscle, [dos, basA, dosB, pushB],
      'Largeur et épaisseur du dos',
      'Tractions et tirages pour la largeur, rowings et soulevé de terre pour l’épaisseur. Deux séances de dos, une de jambes, une de poussée.',
      gros: 'Dos', bandeau: 'Spécial', objectif: 'Dos', noms: ['Dos, largeur', 'Jambes', 'Dos, épaisseur', 'Poussée']),
  Fiche('abdos-salle-3j', 'Abdos en salle', Rayon.cible, _int, 3, 6, muscle, [abdosSalle, maisonAbdosB],
      'Des abdos chargés, comme les autres muscles',
      'Crunchs à la poulie, roue, relevés de jambes suspendus : les abdominaux grossissent quand on les charge. Une séance chargée, une séance au sol, à faire en fin d’entraînement ou les jours sans musculation.',
      gros: 'Abdos', bandeau: 'En salle', cycle: [0, 1, 0], objectif: 'Sangle abdominale', noms: ['Abdos chargés', 'Abdos au sol']),
  Fiche('carrure-en-v-4j', 'Carrure en V', Rayon.cible, _int, 4, 8, muscle, [carrure, jambes, carrureB, pecsTriceps],
      'Dos large, épaules rondes, taille fine',
      'Le dos et les épaules en priorité : tractions larges, rowings et élévations latérales sur deux séances, plus une séance de jambes et une séance pectoraux et triceps.',
      gros: 'Carrure en V', bandeau: '4 jours', objectif: 'Dos et épaules'),
  Fiche('chaine-posterieure-2j', 'Chaîne postérieure', Rayon.cible, _int, 2, 8, muscle, [ischiosFessiers, dosB],
      'Ischios, fessiers et dos, en complément',
      'Tout ce qu’on ne voit pas dans le miroir : soulevés de terre, hip thrust, nordic curl, tractions et rowings. Deux séances à ajouter à ta semaine quand l’arrière du corps est en retard.',
      gros: 'Postérieur', bandeau: 'En complément', objectif: 'Ischios, fessiers et dos'),
  Fiche('poigne-2j', 'Poigne et avant-bras', Rayon.cible, _deb, 2, 6, muscle, [poigne],
      'Une poigne qui ne lâche plus',
      'Flexions de poignets, curls inversés, marche du fermier et suspensions. Un quart d’heure, deux fois par semaine, à la fin d’une séance.',
      gros: 'Poigne', bandeau: 'Avant-bras', cycle: [0, 0], objectif: 'Avant-bras'),

  // Express.
  Fiche('express-full-body-3j', 'Express full body', Rayon.express, _int, 3, 8, express, [expressA, expressB, expressC],
      'Tout le corps en trente-cinq minutes',
      'Trois séances de cinq exercices : un mouvement de jambes, puis deux supersets qui font travailler deux muscles opposés sans temps mort.',
      gros: 'Express', bandeau: 'Full body'),
  Fiche('express-haut-bas-4j', 'Express haut/bas', Rayon.express, _int, 4, 8, express, [hautA, basA, hautB, basB],
      'Quatre séances de quarante-cinq minutes',
      'Le haut et le bas deux fois par semaine, avec moins de séries et des repos courts. Parfait avant le travail.',
      gros: 'Express', bandeau: 'Haut / Bas', noms: ['Haut A', 'Bas A', 'Haut B', 'Bas B'], pose: 'rowing-barre'),
  Fiche('pause-dejeuner-3j', 'Pause déjeuner', Rayon.express, _deb, 3, 6, express, [midiA, midiB],
      'Trente minutes aux machines',
      'Six exercices dont deux supersets, deux séries chacun, et retour au bureau. Deux séances en alternance, sans échauffement compliqué.',
      gros: 'Pause déjeuner', bandeau: '30 minutes', cycle: [0, 1]),
  Fiche('maintien-2j', 'Maintien 2 jours', Rayon.express, _int, 2, 8, maintien, [maintienA, maintienB],
      'Le minimum pour ne rien perdre',
      'Deux séances corps entier avec des charges lourdes et peu de séries. Pour les périodes chargées, les examens ou les vacances : tu gardes ta force et ton muscle en deux heures par semaine.',
      gros: 'Maintien', bandeau: '2 jours'),

  // Pour ton sport.
  Fiche('coureur-2j', 'Renfort du coureur', Rayon.sport, _deb, 2, 8, muscle, [courseA, courseB],
      'Des jambes solides pour courir plus longtemps',
      'Deux séances de renforcement à placer entre tes sorties : squats, fentes, mollets, fessiers et gainage. Moins de blessures, une foulée plus efficace.',
      gros: 'Coureur', bandeau: 'Renfort', objectif: 'Course à pied', pose: 'fentes-marchees'),
  Fiche('football-2j', 'Football', Rayon.sport, _int, 2, 8, explosif, [footballA, footballB],
      'Appuis, détente et ischios protégés',
      'Sauts, squats et fentes latérales pour les appuis, nordic curls pour protéger les ischios, adducteurs pour protéger l’aine. Deux séances hors terrain.',
      gros: 'Football', bandeau: 'Préparation', objectif: 'Préparation physique', pose: 'fentes-laterales'),
  Fiche('sports-de-combat-3j', 'Sports de combat', Rayon.sport, _int, 3, 8, explosif, [combat, explosifA, combatCircuit],
      'Explosivité, gainage et souffle',
      'Pompes claquées, rotations et corde ondulatoire pour frapper fort, une séance de barres pour la puissance, et une séance à repos courts avec trois rounds de corde à sauter pour tenir la distance.',
      gros: 'Combat', bandeau: 'Préparation', objectif: 'Préparation physique', pose: 'battle-rope', noms: ['Frapper fort', 'Puissance', 'Tenir les rounds']),
  Fiche('natation-2j', 'Natation', Rayon.sport, _int, 2, 8, muscle, [natationA, natationB],
      'Tirage, épaules solides et gainage',
      'Le grand dorsal et les triceps qui propulsent, les rotateurs qui protègent l’épaule, et un gainage qui garde le corps à plat dans l’eau.',
      gros: 'Natation', bandeau: 'Renfort', objectif: 'Natation', pose: 'pull-over-poulie-haute'),
  Fiche('cyclisme-2j', 'Cyclisme', Rayon.sport, _int, 2, 8, muscle, [cyclismeA, cyclismeB],
      'De la force dans les jambes, un dos qui tient',
      'Presse, squats bulgares et soulevés de terre roumains pour la puissance, puis une séance pour les hanches et le tronc, qui tiennent la position des heures.',
      gros: 'Cyclisme', bandeau: 'Renfort', objectif: 'Cyclisme'),
  Fiche('ski-2j', 'Prêt pour le ski', Rayon.sport, _deb, 2, 6, muscle, [skiA, skiB],
      'Six semaines avant les pistes',
      'Squats, fentes latérales, chaise et gainage latéral : des cuisses qui tiennent toute la journée et des genoux protégés.',
      gros: 'Ski', bandeau: 'Préparation', objectif: 'Préparation au ski', pose: 'chaise-au-mur'),
  Fiche('sports-de-raquette-2j', 'Sports de raquette', Rayon.sport, _int, 2, 8, muscle, [raquetteA, raquetteB],
      'Rotation, appuis et épaule',
      'Tennis, padel, badminton : la force de rotation du tronc et une épaule solide dans la première séance, les appuis et les déplacements latéraux dans la seconde.',
      gros: 'Raquette', bandeau: 'Tennis · Padel', objectif: 'Préparation physique', pose: 'pallof-press'),
  Fiche('escalade-2j', 'Escalade', Rayon.sport, _int, 2, 8, corps, [escaladeA, escaladeB],
      'Tirage, avant-bras et muscles opposés',
      'Tractions, suspensions et avant-bras pour grimper, puis une séance de poussée et de coiffe des rotateurs pour équilibrer les épaules et éviter les blessures.',
      gros: 'Escalade', bandeau: 'Renfort', objectif: 'Escalade', pose: 'dead-hang'),
  Fiche('rugby-3j', 'Rugby', Rayon.sport, _av, 3, 10, force, [rugbyA, explosifA, rugbyB],
      'Force, puissance et épaules blindées',
      'Épaulé, soulevé de terre et développé couché pour la force, des sauts pour la puissance, et un haut du corps solide, arrière d’épaule compris, pour le contact.',
      gros: 'Rugby', bandeau: 'Préparation', objectif: 'Préparation physique', pose: 'epaule', noms: ['Contact', 'Puissance', 'Haut du corps']),
  Fiche('explosivite-2j', 'Explosivité', Rayon.sport, _int, 2, 8, explosif, [explosifA, explosifB],
      'Sauter plus haut, partir plus vite',
      'Chaque séance commence par des sauts et des mouvements rapides, quand le système nerveux est frais, puis passe aux barres lourdes.',
      gros: 'Explosivité', bandeau: 'Détente · Puissance', pose: 'box-jump'),

  // Mobilité et bien-être.
  Fiche('reveil-5j', 'Réveil du matin', Rayon.mobilite, _deb, 5, 4, eclair, [mobiliteMatin],
      'Sept postures, cinq minutes',
      'Dos rond, chien tête en bas, fente basse : une courte routine pour délier le corps au saut du lit, cinq matins par semaine.',
      gros: 'Réveil', bandeau: '5 minutes', cycle: [0, 0, 0, 0, 0]),
  Fiche('echauffement', 'Échauffement avant la séance', Rayon.mobilite, _deb, 3, 4, eclair, [echauffement],
      'Sept mouvements avant de charger',
      'Dos, hanches, épaules, puis quelques squats et pompes faciles : six minutes pour arriver prêt sous la barre.',
      gros: 'Échauffement', bandeau: 'Avant la séance', cycle: [0, 0, 0], pose: 'leg-swing-front-to-back'),
  Fiche('etirements-3j', 'Étirements après la séance', Rayon.mobilite, _deb, 3, 6, souple, [etirementsHaut, etirementsBas],
      'Une routine pour le haut, une pour le bas',
      'Quarante secondes par posture, deux fois. Prends la routine qui correspond à ce que tu viens de travailler, peu importe l’ordre proposé.',
      gros: 'Étirements', bandeau: 'Haut · Bas', cycle: [0, 1], objectif: 'Souplesse'),
  Fiche('yoga-debutant-3j', 'Yoga débutant', Rayon.mobilite, _deb, 3, 6, souple, [yogaA, yogaB],
      'Les postures de base',
      'Montagne, guerriers, triangle, chien tête en bas : deux séances pour apprendre les postures fondamentales, tenues quarante secondes, deux fois.',
      gros: 'Yoga', bandeau: 'Débutant', cycle: [0, 1], objectif: 'Souplesse et équilibre', pose: 'warrior-two'),
  Fiche('yoga-4j', 'Yoga équilibre', Rayon.mobilite, _int, 4, 8, tenue, [yogaD, yogaE, yogaC],
      'Des postures tenues une minute',
      'Des enchaînements debout plus exigeants, des ouvertures du dos et une séance d’équilibres (guerrier trois, demi-lune). Force, souplesse et calme.',
      gros: 'Yoga', bandeau: 'Équilibre', pose: 'half-moon-pose'),
  Fiche('dos-en-forme-3j', 'Dos en forme', Rayon.mobilite, _deb, 3, 6, souple, [dosSante, dosSanteB],
      'Renforcer et délier le bas du dos',
      'Bird-dog, dead bug, pont et gainage latéral : les exercices recommandés pour un dos solide, avec les étirements des hanches qui le soulagent.',
      gros: 'Dos', bandeau: 'En forme', cycle: [0, 1], objectif: 'Dos et posture', pose: 'bird-dog',
      conseils: ['Si une douleur persiste ou descend dans la jambe, vois un professionnel de santé avant de continuer.']),
  Fiche('posture-bureau-3j', 'Posture de bureau', Rayon.mobilite, _deb, 3, 6, eclair, [postureDebout, posture],
      'Rouvrir les épaules après l’écran',
      'Une pause de cinq minutes debout, à faire entre deux réunions, et une routine un peu plus longue au sol avec un élastique pour renforcer le haut du dos.',
      gros: 'Posture', bandeau: 'Bureau', cycle: [0, 1, 0], objectif: 'Dos et posture', formules: [eclair, souple], noms: ['Pause au bureau', 'À la maison']),
  Fiche('epaules-en-bonne-sante', 'Épaules en bonne santé', Rayon.mobilite, _deb, 2, 6, doux, [epaulesSante],
      'Coiffe des rotateurs et omoplates',
      'Rotations externes, face pull, écartés à l’élastique : dix minutes de prévention, deux fois par semaine, pour des épaules qui encaissent les développés.',
      gros: 'Épaules', bandeau: 'Prévention', cycle: [0, 0], objectif: 'Prévention des blessures',
      conseils: ['Charges très légères : on cherche la sensation, pas la fatigue.']),
  Fiche('souplesse-3j', 'Gagner en souplesse', Rayon.mobilite, _int, 3, 8, longue, [souplesse, souplesseB],
      'Hanches, ischios et adducteurs',
      'Des postures tenues une minute et demie, du plus doux au plus intense, après quelques balancements de jambes pour s’échauffer. Le chemin vers le grand écart, sans forcer.',
      gros: 'Souplesse', bandeau: 'Hanches · Jambes', cycle: [0, 1], pose: 'pigeon-stretch'),
  Fiche('pilates-3j', 'Pilates au sol', Rayon.mobilite, _deb, 3, 6, souple, [pilates, maisonAbdosA],
      'Un centre fort et un dos mobile',
      'Des exercices de Pilates sur tapis accessibles à tous, complétés par une séance d’abdos. Contrôle, respiration et précision.',
      gros: 'Pilates', bandeau: 'Au sol', cycle: [0, 1, 0], objectif: 'Sangle abdominale et posture', noms: ['Pilates', 'Abdos'], pose: 'pilates-leg-pull-front'),
  Fiche('recuperation-2j', 'Jour de récupération', Rayon.mobilite, _deb, 2, 4, souple, [recuperation],
      'Bouger doucement les jours sans séance',
      'Balancements de jambes, rotations, sphinx et trois minutes de relaxation. Huit mouvements pour faire circuler le sang sans fatiguer.',
      gros: 'Récupération', bandeau: 'Jour off', cycle: [0, 0], objectif: 'Récupération', pose: 'sphinx'),
  Fiche('forme-et-equilibre-2j', 'Forme et équilibre', Rayon.mobilite, _deb, 2, 8, doux, [douceurA, douceurB],
      'Rester fort et stable à tout âge',
      'Se lever d’un banc, monter une marche, pousser, tirer, tenir sur une jambe : deux séances douces à faire en salle, pour garder force et équilibre.',
      gros: 'Forme', bandeau: 'Équilibre', conseils: ['Fais la posture de l’arbre près d’un mur ou d’une chaise.']),

  // Cardio.
  Fiche('cardio-debutant-3j', 'Cardio débutant', Rayon.cardio, _deb, 3, 6, cardioDoux, [cardioA],
      'Trente minutes à allure tranquille',
      'Dix minutes de marche inclinée, dix de vélo, dix d’elliptique. Une allure où tu peux encore parler, trois fois par semaine.',
      gros: 'Cardio', bandeau: 'Débutant', cycle: [0, 0, 0]),
  Fiche('endurance-3j', 'Endurance', Rayon.cardio, _int, 3, 8, endurance, [cardioC, cardioB, cardioLong],
      'Trois séances de quarante-cinq minutes',
      'Une séance variée sur trois appareils, une séance soutenue, une séance longue sur deux appareils. Ajoute une à deux minutes par appareil chaque semaine.',
      gros: 'Endurance', bandeau: '3 jours', pose: 'stepper'),
  Fiche('marche-inclinee-4j', 'Marche inclinée', Rayon.cardio, _deb, 4, 6, cardioDoux, [marcheInclinee],
      'Trente minutes de marche en pente',
      'Tapis incliné, pas rapide, trente minutes. Très peu de chocs, une vraie dépense : la séance de cardio la plus facile à tenir dans le temps.',
      gros: 'Marche inclinée', bandeau: '30 minutes', cycle: [0, 0, 0, 0], objectif: 'Perte de gras'),
  Fiche('intervalles-cardio-3j', 'Intervalles et fond', Rayon.cardio, _int, 3, 6, endurance, [intervallesSalle, cardioLong, cardioA],
      'Un jour très dur, un jour long, un jour doux',
      'La semaine type des sports d’endurance : une séance d’intervalles sur les appareils après cinq minutes d’échauffement, une séance longue, une séance facile pour récupérer.',
      gros: 'Intervalles', bandeau: 'Cardio', pose: 'air-bike', formules: [endurance, endurance, cardioDoux]),
  Fiche('courir-30-minutes', 'Courir 30 minutes', Rayon.cardio, _deb, 3, 8, cardioDoux, [courseFacile, courseFractionnee, courseLongue],
      'Un footing, un fractionné, une sortie longue',
      'Trois sorties par semaine : vingt minutes de footing, six fois une minute rapide, puis une sortie longue. Si trente minutes d’affilée ne passent pas encore, alterne course et marche.',
      gros: 'Courir', bandeau: '30 minutes', objectif: 'Course à pied', pose: 'course'),
];
