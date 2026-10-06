import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Découpage de la semaine proposé par le programme conseillé.
enum Formule {
  corpsComplet('Corps complet', 'Tout le corps à chaque séance'),
  hautBas('Haut et bas', 'Haut du corps, puis jambes, en alternance'),
  ppl('Poussée, tirage, jambes', 'Pectoraux et épaules, dos et bras, jambes'),
  pplHautBas('Poussée, tirage, jambes + haut et bas', 'Cinq séances, chaque muscle deux fois'),
  pplDouble('Poussée, tirage, jambes, deux fois', 'Six séances, volume élevé');

  const Formule(this.label, this.description);
  final String label;
  final String description;
}

/// Une séance du programme proposé, encore modifiable avant d'être adoptée.
class ProposedRoutine {
  ProposedRoutine({required this.nom, required this.description, required this.exercices});

  String nom;
  final String description;
  List<RoutineExercise> exercices;

  int get nbSeries => exercices.fold(0, (a, e) => a + e.series.length);

  int get dureeEstimeeMin {
    var sec = 0;
    for (final e in exercices) {
      sec += e.series.length * (45 + e.reposSec);
    }
    return (sec / 60).round();
  }

  Set<Muscle> muscles(ExerciseRepo repo) => {
        for (final e in exercices) ...?repo.byId(e.exerciseId)?.musclesPrincipaux,
      };
}

/// Programme conseillé, calculé depuis le profil.
class Proposal {
  Proposal({
    required this.formule,
    required this.nom,
    required this.description,
    required this.semaines,
    required this.jours,
    required this.seances,
    required this.raisons,
  });

  final Formule formule;
  final String nom;
  final String description;
  final int semaines;
  final int jours;
  final List<ProposedRoutine> seances;

  /// Pourquoi ce programme : phrases courtes affichées à l'utilisateur.
  final List<String> raisons;

  int get nbSeries => seances.fold(0, (a, s) => a + s.nbSeries);
}

class _Dosage {
  const _Dosage(this.series, this.reps, this.repsMax, this.repos);
  final int series;
  final int reps;
  final int repsMax;
  final int repos;
}

/// Construit un programme à partir des réponses de l'inscription et du catalogue.
class ProgramGenerator {
  ProgramGenerator(this.repo);

  final ExerciseRepo repo;

  /// Mouvements types, avec des exercices classés du plus au moins conseillé.
  static const Map<String, List<String>> _slots = {
    'poussHoriz': ['developpe-couche', 'developpe-couche-halteres', 'developpe-couche-machine', 'developpe-au-sol-halteres', 'pompes', 'developpe-couche-a-l-elastique', 'pompes-sur-les-genoux'],
    'poussIncl': ['developpe-incline-halteres', 'developpe-incline', 'developpe-incline-machine', 'pompes-declinees', 'pompes-prise-large'],
    'ecarte': ['pec-deck', 'ecarte-a-la-poulie-vis-a-vis', 'ecarte-couche-halteres', 'pompes-prise-large', 'developpe-couche-a-l-elastique'],
    'poussVert': ['developpe-militaire', 'developpe-halteres-assis', 'developpe-epaules-machine', 'developpe-halteres-debout', 'developpe-arnold', 'developpe-kettlebell', 'developpe-epaules-a-l-elastique', 'pompes-declinees'],
    'elevLat': ['elevations-laterales', 'elevations-laterales-a-la-poulie', 'elevations-laterales-machine', 'elevations-laterales-a-l-elastique'],
    'tirVert': ['tractions', 'tirage-vertical', 'tirage-vertical-prise-serree', 'tractions-supination', 'tractions-assistees-a-l-elastique', 'tirage-vertical-a-l-elastique', 'tractions-australiennes', 'rowing-unilateral-debout-a-la-serviette', 'extensions-lombaires-au-sol'],
    'tirHoriz': ['rowing-barre', 'tirage-horizontal', 'rowing-haltere-unilateral', 'rowing-assis-machine', 'rowing-halteres-buste-penche', 'rowing-kettlebell', 'tirage-horizontal-a-l-elastique', 'tractions-australiennes', 'rowing-debout-a-la-serviette', 'rowing-accroupi-a-la-serviette', 'bird-dog'],
    'arriereEpaule': ['face-pull', 'oiseau', 'oiseau-machine', 'oiseau-sur-banc-incline', 'ecartes-a-l-elastique', 'pompes-inversees-sur-les-coudes', 'reverse-plank'],
    'squat': ['squat', 'presse-a-cuisses', 'hack-squat', 'squat-goblet', 'squat-halteres', 'squat-goblet-kettlebell', 'squat-a-l-elastique', 'squat-au-poids-du-corps'],
    'souleve': ['souleve-de-terre', 'souleve-de-terre-trap-bar', 'souleve-de-terre-halteres', 'kettlebell-swing', 'pont-fessier-unilateral'],
    'unilat': ['squat-bulgare', 'fentes-arriere', 'fentes-marchees', 'step-up', 'fentes-au-poids-du-corps'],
    'quadIso': ['leg-extension', 'presse-a-cuisses', 'fentes-avant', 'fente-statique', 'chaise-au-mur'],
    'hinge': ['souleve-de-terre-roumain', 'souleve-de-terre-roumain-halteres', 'good-morning', 'kettlebell-swing', 'souleve-de-terre-unilateral', 'pont-fessier-unilateral'],
    'ischioIso': ['leg-curl-assis', 'leg-curl-allonge', 'leg-curl-haltere-allonge', 'leg-curl-au-ballon', 'pont-fessier-pieds-sur-banc', 'pont-fessier-unilateral'],
    'fessiers': ['hip-thrust', 'machine-a-fessiers', 'pont-fessier-barre', 'kickback-fessier-a-la-poulie', 'pont-fessier', 'kickback-au-sol'],
    'mollets': ['mollets-debout-machine', 'mollets-assis-machine', 'mollets-debout-halteres', 'mollets-unilateral', 'mollets-au-poids-du-corps'],
    'biceps': ['curl-barre-ez', 'curl-halteres', 'curl-poulie-basse', 'curl-barre', 'curl-a-l-elastique', 'curl-au-poids-du-corps-allonge-sur-le-cote'],
    'biceps2': ['curl-marteau', 'curl-incline', 'curl-pupitre', 'curl-concentre', 'curl-marteau-a-la-corde', 'curl-concentre-jambe-en-appui'],
    'triceps': ['extension-triceps-a-la-corde', 'barre-au-front', 'extension-nuque-haltere', 'dips-triceps', 'dips-sur-banc', 'pompes-diamant'],
    'triceps2': ['extension-nuque-a-la-corde', 'extension-triceps-poulie-haute', 'kickback-haltere', 'extension-triceps-couche-halteres', 'pompes-diamant', 'dips-sur-banc'],
    'abdos': ['releves-de-jambes-suspendu', 'crunch-a-la-poulie', 'crunch-machine', 'releves-de-jambes-allonge', 'crunch', 'gainage'],
    'gainage': ['gainage', 'dead-bug', 'gainage-lateral', 'pallof-press'],
    'obliques': ['bucheron-a-la-poulie', 'gainage-lateral', 'russian-twist', 'flexion-laterale-haltere', 'crunch-oblique'],
    'trapezes': ['shrugs-barre', 'shrugs-halteres', 'shrugs-machine', 'marche-du-fermier', 'pompes-inversees-sur-les-coudes'],
    'avantBras': ['curl-poignets-haltere', 'curl-poignets', 'marche-du-fermier', 'curl-inverse', 'curl-marteau'],
    'lombaires': ['extensions-lombaires', 'extensions-lombaires-machine', 'good-morning', 'extensions-lombaires-au-sol', 'dead-bug'],
    'adducteurs': ['adducteurs-machine', 'adduction-a-la-poulie', 'squat-sumo-haltere', 'squat-cosaque'],
    'abducteurs': ['abducteurs-machine', 'marche-laterale-a-l-elastique', 'abduction-a-l-elastique-assis', 'abduction-debout'],
    'rhomboides': ['tirage-horizontal-prise-large', 'rowing-halteres-sur-banc-incline', 'face-pull', 'tractions-australiennes', 'ecartes-a-l-elastique', 'rowing-unilateral-debout-a-la-serviette', 'pompes-inversees-sur-les-coudes', 'reverse-tabletop-hold'],
    'cou': ['extension-de-la-nuque-au-disque', 'flexion-de-la-nuque-au-disque', 'etirement-lateral-du-cou'],
  };

  /// Mouvement dédié à un muscle mis en priorité.
  static const Map<Muscle, String> _slotDuMuscle = {
    Muscle.pectoraux: 'poussIncl',
    Muscle.deltoidesAnterieurs: 'poussVert',
    Muscle.deltoidesLateraux: 'elevLat',
    Muscle.deltoidesPosterieurs: 'arriereEpaule',
    Muscle.biceps: 'biceps2',
    Muscle.triceps: 'triceps2',
    Muscle.avantBras: 'avantBras',
    Muscle.trapezes: 'trapezes',
    Muscle.grandDorsal: 'tirVert',
    Muscle.rhomboides: 'rhomboides',
    Muscle.lombaires: 'lombaires',
    Muscle.abdominaux: 'abdos',
    Muscle.obliques: 'obliques',
    Muscle.fessiers: 'fessiers',
    Muscle.quadriceps: 'quadIso',
    Muscle.ischios: 'ischioIso',
    Muscle.adducteurs: 'adducteurs',
    Muscle.abducteurs: 'abducteurs',
    Muscle.mollets: 'mollets',
    Muscle.cou: 'cou',
  };

  /// Formules adaptées à un nombre de séances par semaine.
  static List<Formule> formulesPour(int jours) => switch (jours) {
        <= 2 => [Formule.corpsComplet],
        3 => [Formule.corpsComplet, Formule.ppl],
        4 => [Formule.hautBas, Formule.corpsComplet],
        5 => [Formule.pplHautBas, Formule.hautBas],
        _ => [Formule.pplDouble, Formule.pplHautBas],
      };

  static Formule formuleConseillee(UserProfile p) {
    final j = p.joursParSemaine;
    if (j == 3 && p.niveau == Niveau.debutant) return Formule.corpsComplet;
    if (j == 3) return p.objectif == Objectif.forme ? Formule.corpsComplet : Formule.ppl;
    return formulesPour(j).first;
  }

  /// Séances types d'une formule : (nom, description, mouvements).
  static List<(String, String, List<String>)> _modeles(Formule f, int jours, bool force) {
    const fullA = ('Corps complet A', 'Squat, développé, tirage', ['squat', 'poussHoriz', 'tirVert', 'hinge', 'elevLat', 'biceps', 'triceps', 'abdos']);
    const fullB = ('Corps complet B', 'Fentes, épaules, rowing', ['unilat', 'poussVert', 'tirHoriz', 'ischioIso', 'poussIncl', 'arriereEpaule', 'mollets', 'gainage']);
    const fullC = ('Corps complet C', 'Charnière, incliné, tractions', ['hinge', 'poussIncl', 'tirVert', 'quadIso', 'elevLat', 'triceps2', 'biceps2', 'mollets']);
    final hautA = ('Haut du corps A', 'Développé couché, rowing, épaules', ['poussHoriz', 'tirHoriz', 'poussVert', 'tirVert', 'elevLat', 'biceps', 'triceps', 'arriereEpaule']);
    const hautB = ('Haut du corps B', 'Incliné, tractions, bras', ['poussIncl', 'tirVert', 'tirHoriz', 'ecarte', 'elevLat', 'biceps2', 'triceps2', 'arriereEpaule']);
    final basA = ('Bas du corps A', force ? 'Squat et soulevé de terre' : 'Squat et ischio-jambiers', [force ? 'souleve' : 'squat', force ? 'squat' : 'hinge', 'quadIso', 'ischioIso', 'mollets', 'abdos', 'fessiers']);
    const basB = ('Bas du corps B', 'Fentes, fessiers, ischio-jambiers', ['hinge', 'unilat', 'fessiers', 'ischioIso', 'quadIso', 'mollets', 'gainage']);
    const push = ('Poussée', 'Pectoraux, épaules, triceps', ['poussHoriz', 'poussIncl', 'poussVert', 'elevLat', 'ecarte', 'triceps', 'triceps2']);
    const pull = ('Tirage', 'Dos, arrière d\'épaule, biceps', ['tirVert', 'tirHoriz', 'arriereEpaule', 'rhomboides', 'biceps', 'biceps2', 'trapezes']);
    final legs = ('Jambes', 'Quadriceps, ischio-jambiers, mollets', [force ? 'souleve' : 'squat', force ? 'squat' : 'hinge', 'unilat', 'ischioIso', 'quadIso', 'mollets', 'abdos']);
    return switch (f) {
      Formule.corpsComplet => [fullA, fullB, fullC].take(jours.clamp(1, 3)).toList(),
      Formule.hautBas => [hautA, basA, hautB, basB],
      Formule.ppl => [push, pull, legs],
      Formule.pplHautBas => [push, pull, legs, hautB, basB],
      Formule.pplDouble => [
          push,
          pull,
          legs,
          (push.$1, push.$2, ['poussIncl', 'poussHoriz', 'poussVert', 'ecarte', 'elevLat', 'triceps2', 'triceps']),
          (pull.$1, pull.$2, ['tirHoriz', 'tirVert', 'rhomboides', 'arriereEpaule', 'biceps2', 'biceps', 'avantBras']),
          (legs.$1, legs.$2, ['hinge', 'squat', 'fessiers', 'quadIso', 'ischioIso', 'mollets', 'gainage']),
        ],
    };
  }

  static _Dosage _dosage(Objectif o, bool principal) => switch (o) {
        Objectif.force => principal ? const _Dosage(5, 3, 5, 180) : const _Dosage(3, 6, 8, 120),
        Objectif.prendreDuMuscle || Objectif.recomposition => principal ? const _Dosage(4, 6, 10, 120) : const _Dosage(3, 10, 15, 75),
        Objectif.secher => principal ? const _Dosage(3, 8, 12, 90) : const _Dosage(3, 12, 15, 60),
        Objectif.forme => principal ? const _Dosage(3, 10, 12, 75) : const _Dosage(2, 12, 15, 60),
      };

  static int _nbExercices(int minutes, Objectif o) {
    final n = switch (minutes) {
      <= 30 => 4,
      <= 45 => 5,
      <= 60 => 6,
      <= 75 => 7,
      _ => 8,
    };
    return o == Objectif.force ? n - 1 : n;
  }

  /// Le matériel déclaré permet-il cet exercice ?
  static bool disponible(Exercise e, Set<Materiel> m) {
    if (m.contains(Materiel.salleComplete)) return true;
    final id = e.id;
    // Les identifiants sont en français (exercices historiques) ou en anglais.
    bool contient(List<String> mots) => mots.any(id.contains);
    final banc = !contient(const ['couche', 'incline', 'decline', 'hip-thrust', 'pupitre', 'pieds-sur-banc', 'bench', 'preacher', 'chest-supported']) ||
        contient(const ['au-sol', 'floor']) ||
        m.contains(Materiel.banc);
    final barreFixe = (id.contains('traction') && !id.contains('australiennes')) ||
        contient(const ['suspendu', 'pull-up', 'chin-up', 'hanging', 'dead-hang', 'muscle-up', 'ring-', 'rings-', 'trx-', 'rope-climb']) ||
        (contient(const ['dips']) && !contient(const ['banc', 'bench', 'crab', 'plank']));
    return switch (e.equipement) {
      'poids du corps' => barreFixe
          ? m.contains(Materiel.barreTraction)
          : (id.contains('pieds-sur-banc') ? m.contains(Materiel.banc) : true),
      'halteres' => m.contains(Materiel.halteres) && banc,
      'barre' || 'barre ez' || 'disque' => m.contains(Materiel.barre) && banc,
      'kettlebell' => m.contains(Materiel.kettlebell),
      'elastique' => m.contains(Materiel.elastiques),
      _ => false,
    };
  }

  /// Exercices qui peuvent remplacer [exerciseId] avec le matériel donné.
  List<Exercise> alternatives(String exerciseId, Set<Materiel> materiel, {int max = 30}) {
    final e = repo.byId(exerciseId);
    if (e == null) return [];
    final cibles = e.musclesPrincipaux.toSet();
    final out = <(Exercise, int)>[];
    for (final x in repo.all) {
      if (x.id == e.id || !disponible(x, materiel)) continue;
      if (x.categorie == 'etirements' || x.categorie == 'cardio') continue;
      final communs = x.musclesPrincipaux.where(cibles.contains).length;
      if (communs == 0) continue;
      var score = communs * 10 - (x.musclesPrincipaux.length - communs) * 4;
      if (x.categorie == e.categorie) score += 5;
      if (x.mecanique == e.mecanique) score += 3;
      if (x.equipement == e.equipement) score += 4;
      if (x.nom.split(' ').first == e.nom.split(' ').first) score += 4;
      if (x.conseils.isNotEmpty) score += 2;
      if (x.niveau == 'debutant' || x.niveau == 'intermediaire') score += 1;
      out.add((x, score));
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out.take(max).map((p) => p.$1).toList();
  }

  String? _choisir(String slot, Set<Materiel> m, Set<String> dejaPris, int variante) {
    final ids = _slots[slot] ?? const [];
    final dispo = <String>[];
    for (final id in ids) {
      final e = repo.byId(id);
      if (e == null || dejaPris.contains(id) || !disponible(e, m)) continue;
      dispo.add(id);
    }
    if (dispo.isEmpty) return null;
    return dispo[variante.clamp(0, dispo.length - 1)];
  }

  RoutineExercise _emplacement(String exerciseId, Objectif o, Niveau n, bool principal, bool prioritaire, int rang) {
    final e = repo.byId(exerciseId);
    final d = _dosage(o, principal);
    var series = d.series + (prioritaire ? 1 : 0) - (n == Niveau.debutant ? 1 : 0);
    series = series.clamp(2, 6);
    final suivi = e?.suivi ?? ExerciseTracking.poidsReps;
    final PlannedSet serie;
    if (suivi == ExerciseTracking.duree || suivi == ExerciseTracking.poidsDuree) {
      serie = PlannedSet(dureeSec: o == Objectif.force ? 30 : 45);
    } else if (suivi == ExerciseTracking.distanceDuree) {
      serie = const PlannedSet(dureeSec: 600);
    } else {
      serie = PlannedSet(reps: d.reps, repsMax: d.repsMax);
    }
    return RoutineExercise(
      id: 'e$rang-$exerciseId',
      exerciseId: exerciseId,
      series: List.filled(series, serie),
      reposSec: d.repos,
    );
  }

  /// Calcule le programme conseillé.
  Proposal generer(UserProfile p, Set<Muscle> prioritaires, {Formule? formule}) {
    final f = formule ?? formuleConseillee(p);
    final force = p.objectif == Objectif.force;
    final modeles = _modeles(f, p.joursParSemaine, force);
    final n = _nbExercices(p.dureeSeanceMin, p.objectif);
    final materiel = p.materiel.isEmpty ? {Materiel.poidsDuCorps} : p.materiel;

    // Deuxième passage d'une même séance type : variante des exercices.
    final vus = <String, int>{};
    final seances = <ProposedRoutine>[];
    final couverts = <Muscle>{};

    for (final (nom, description, slots) in modeles) {
      final variante = vus[nom] ?? 0;
      vus[nom] = variante + 1;
      final pris = <String>{};
      final choisis = <String>[];
      for (final s in slots) {
        final id = _choisir(s, materiel, pris, variante);
        if (id == null) continue;
        pris.add(id);
        choisis.add(id);
      }
      // Priorités : on remonte les exercices qui les travaillent.
      var garde = choisis.take(n).toList();
      final reste = choisis.skip(n).toList();
      for (final id in reste) {
        final e = repo.byId(id);
        if (e == null || !e.musclesPrincipaux.any(prioritaires.contains)) continue;
        final i = garde.lastIndexWhere((g) {
          final ge = repo.byId(g);
          return garde.indexOf(g) >= 2 && (ge == null || !ge.musclesPrincipaux.any(prioritaires.contains));
        });
        if (i >= 0) garde[i] = id;
      }
      garde = garde.toSet().toList();
      final exos = <RoutineExercise>[];
      for (var i = 0; i < garde.length; i++) {
        final e = repo.byId(garde[i]);
        final principal = e?.mecanique != 'isolation' && (i < 2 || (i < 4 && e?.mecanique == 'polyarticulaire'));
        final prio = e != null && e.musclesPrincipaux.any(prioritaires.contains);
        exos.add(_emplacement(garde[i], p.objectif, p.niveau, principal, prio, i));
        if (e != null) couverts.addAll(e.musclesPrincipaux);
      }
      seances.add(ProposedRoutine(
        nom: vus[nom]! > 1 || modeles.where((m) => m.$1 == nom).length > 1 ? '$nom ${String.fromCharCode(64 + vus[nom]!)}' : nom,
        description: description,
        exercices: exos,
      ));
    }

    // Muscle prioritaire absent de toutes les séances : on l'ajoute là où il y a le moins d'exercices.
    for (final m in prioritaires) {
      if (couverts.contains(m) || seances.isEmpty) continue;
      final slot = _slotDuMuscle[m];
      if (slot == null) continue;
      final cible = seances.reduce((a, b) => a.exercices.length <= b.exercices.length ? a : b);
      final id = _choisir(slot, materiel, cible.exercices.map((e) => e.exerciseId).toSet(), 0);
      if (id == null) continue;
      cible.exercices = [...cible.exercices, _emplacement(id, p.objectif, p.niveau, false, true, cible.exercices.length)];
      couverts.add(m);
    }

    final semaines = switch (p.niveau) {
      Niveau.debutant => 8,
      Niveau.intermediaire => force ? 6 : 8,
      Niveau.avance => 6,
    };
    final raisons = <String>[
      '${p.joursParSemaine} séance${p.joursParSemaine > 1 ? 's' : ''} par semaine de ${p.dureeSeanceMin} minutes environ',
      switch (p.objectif) {
        Objectif.force => 'Mouvements lourds en tête de séance, séries de 3 à 5 répétitions',
        Objectif.prendreDuMuscle => 'Volume soutenu, de 6 à 15 répétitions selon l\'exercice',
        Objectif.recomposition => 'Volume soutenu pour garder le muscle pendant que le gras baisse',
        Objectif.secher => 'Repos courts et séries de 8 à 15 répétitions pour garder le muscle',
        Objectif.forme => 'Séances équilibrées et accessibles, sans aller à l\'échec',
      },
      if (!materiel.contains(Materiel.salleComplete)) 'Exercices choisis pour ton matériel : ${materiel.map((m) => m.label.toLowerCase()).join(', ')}',
      if (prioritaires.isNotEmpty) 'Une série de plus sur ${prioritaires.map((m) => m.label.toLowerCase()).join(', ')}',
      if (p.niveau == Niveau.debutant) 'Une série de moins par exercice pour bien apprendre les mouvements',
    ];
    return Proposal(
      formule: f,
      nom: 'Programme ${f.label.toLowerCase()}',
      description: f.description,
      semaines: semaines,
      jours: p.joursParSemaine,
      seances: seances,
      raisons: raisons,
    );
  }

  /// Enregistre les séances dans un dossier et active le programme.
  static Future<Program> adopter(Proposal pr, UserProfile p, {required RoutineRepo routines, required ProgramRepo programmes}) async {
    final dossier = await routines.addFolder('Programme conseillé');
    final ids = <String>[];
    for (final s in pr.seances) {
      final r = await routines.save(Routine(
        id: '',
        nom: s.nom,
        folderId: dossier.id,
        notes: s.description,
        exercices: s.exercices,
        creeLe: DateTime.now(),
      ));
      ids.add(r.id);
    }
    // Le cycle suit l'ordre des séances ; il boucle si la semaine en compte plus.
    final prog = await programmes.save(Program(
      id: '',
      nom: pr.nom,
      description: '${pr.description}. ${pr.raisons.join('. ')}.',
      dureeSemaines: pr.semaines,
      joursParSemaine: pr.jours,
      routineIds: ids,
      niveau: p.niveau.label,
      objectif: p.objectif.label,
      creeLe: DateTime.now(),
    ));
    await programmes.activate(prog.id, restart: true);
    return prog;
  }
}
