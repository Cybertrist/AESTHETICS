import 'dart:io';
import 'dart:math' as math;

import '../data/app_data.dart';
import '../data/store.dart';
import '../logic/nutrition_calc.dart';
import '../models/models.dart';
import 'demo_images.dart';

/// Exercice de la démo, rattaché au catalogue quand le nom y figure.
class _DemoEx {
  const _DemoEx(this.slug, this.nom, this.alias, this.principaux, this.secondaires, this.equipement, this.debut, this.repsMin, this.repsMax,
      {this.pas = 2.5, this.pdc = false});

  final String slug;
  final String nom;
  final List<String> alias;
  final List<Muscle> principaux;
  final List<Muscle> secondaires;
  final String equipement;

  /// Charge de départ il y a six mois (kg ; lest pour le poids du corps).
  final double debut;
  final int repsMin;
  final int repsMax;
  final double pas;
  final bool pdc;
}

const _push = [
  _DemoEx('developpe-couche', 'Développé couché', ['Développé couché barre', 'Bench press', 'Barbell bench press'], [Muscle.pectoraux],
      [Muscle.deltoidesAnterieurs, Muscle.triceps], 'barre', 62.5, 6, 8),
  _DemoEx('developpe-incline-halteres', 'Développé incliné aux haltères', ['Développé incliné haltères', 'Incline dumbbell press'], [Muscle.pectoraux],
      [Muscle.deltoidesAnterieurs, Muscle.triceps], 'halteres', 22, 8, 10, pas: 2),
  _DemoEx('developpe-militaire', 'Développé militaire', ['Développé militaire barre', 'Overhead press', 'Military press'], [Muscle.deltoidesAnterieurs],
      [Muscle.deltoidesLateraux, Muscle.triceps], 'barre', 40, 6, 8),
  _DemoEx('elevations-laterales', 'Élévations latérales', ['Élévations latérales haltères', 'Lateral raise', 'Dumbbell lateral raise'],
      [Muscle.deltoidesLateraux], [Muscle.trapezes], 'halteres', 8, 12, 15, pas: 1),
  _DemoEx('ecarte-poulie', 'Écarté à la poulie', ['Écarté poulie vis-à-vis', 'Cable fly', 'Cable crossover'], [Muscle.pectoraux],
      [Muscle.deltoidesAnterieurs], 'poulie', 12.5, 12, 15, pas: 1.25),
  _DemoEx('extension-triceps-poulie', 'Extension des triceps à la poulie haute', ['Pushdown', 'Triceps pushdown', 'Extension triceps poulie'],
      [Muscle.triceps], [], 'poulie', 22.5, 10, 12),
];

const _pull = [
  _DemoEx('tractions', 'Tractions', ['Traction pronation', 'Pull-up', 'Pull up'], [Muscle.grandDorsal], [Muscle.biceps, Muscle.rhomboides],
      'poids du corps', 0, 6, 10, pdc: true),
  _DemoEx('rowing-barre', 'Rowing barre', ['Rowing buste penché', 'Barbell row', 'Bent over row'], [Muscle.grandDorsal, Muscle.rhomboides],
      [Muscle.biceps, Muscle.lombaires, Muscle.deltoidesPosterieurs], 'barre', 55, 8, 10),
  _DemoEx('tirage-vertical', 'Tirage vertical', ['Tirage poitrine', 'Lat pulldown'], [Muscle.grandDorsal], [Muscle.biceps], 'poulie', 50, 10, 12),
  _DemoEx('face-pull', 'Face pull', ['Face pull à la poulie'], [Muscle.deltoidesPosterieurs], [Muscle.trapezes, Muscle.rhomboides], 'poulie', 15, 12, 15,
      pas: 1.25),
  _DemoEx('curl-barre', 'Curl barre', ['Curl biceps barre', 'Barbell curl'], [Muscle.biceps], [Muscle.avantBras], 'barre', 25, 8, 12),
  _DemoEx('curl-marteau', 'Curl marteau', ['Hammer curl', 'Curl marteau haltères'], [Muscle.biceps, Muscle.avantBras], [], 'halteres', 12, 10, 12,
      pas: 1),
];

const _legs = [
  _DemoEx('squat', 'Squat', ['Squat barre', 'Back squat', 'Barbell squat'], [Muscle.quadriceps, Muscle.fessiers],
      [Muscle.ischios, Muscle.lombaires, Muscle.adducteurs], 'barre', 80, 5, 8),
  _DemoEx('souleve-de-terre-roumain', 'Soulevé de terre roumain', ['Romanian deadlift', 'RDL', 'Soulevé de terre jambes tendues'],
      [Muscle.ischios, Muscle.fessiers], [Muscle.lombaires], 'barre', 70, 8, 10),
  _DemoEx('presse-a-cuisses', 'Presse à cuisses', ['Presse inclinée', 'Leg press'], [Muscle.quadriceps], [Muscle.fessiers, Muscle.adducteurs], 'machine',
      140, 10, 12, pas: 5),
  _DemoEx('leg-curl', 'Leg curl allongé', ['Leg curl', 'Lying leg curl'], [Muscle.ischios], [Muscle.mollets], 'machine', 35, 10, 12),
  _DemoEx('leg-extension', 'Leg extension', ['Extension des jambes'], [Muscle.quadriceps], [], 'machine', 45, 12, 15),
  _DemoEx('mollets-debout', 'Mollets debout', ['Extension mollets debout', 'Standing calf raise'], [Muscle.mollets], [], 'machine', 60, 12, 15, pas: 5),
];

/// Données inventées réalistes pour la variante démo (--dart-define=DEMO=true).
abstract final class DemoData {
  static Future<void> seed(AppData data, {DateTime? now}) async {
    final rnd = math.Random(42);
    final today = now ?? DateTime.now();
    final debut = DateTime(today.year, today.month - 6, today.day);

    // Profil
    final profil = UserProfile(
      id: 'moi',
      prenom: 'Tristan',
      sexe: Sexe.homme,
      naissance: DateTime(2003, 5, 14),
      tailleCm: 181,
      poidsKg: 77.2,
      poidsCibleKg: 80,
      objectif: Objectif.prendreDuMuscle,
      niveau: Niveau.intermediaire,
      activite: NiveauActivite.modere,
      joursParSemaine: 4,
      dureeSeanceMin: 75,
      materiel: const {Materiel.salleComplete},
      creeLe: debut,
    );
    await data.profile.save(profil.copyWith(objectifsNutrition: NutritionCalc.objectifs(profil)));

    // Exercices : ceux du catalogue quand ils existent, sinon créés en perso.
    final ids = <String, String>{};
    final manquants = <Exercise>[];
    for (final d in [..._push, ..._pull, ..._legs]) {
      final found = [d.nom, ...d.alias].map(data.exercises.findByName).whereType<Exercise>().firstOrNull;
      if (found != null) {
        ids[d.slug] = found.id;
      } else {
        final id = 'demo-${d.slug}';
        ids[d.slug] = id;
        manquants.add(Exercise(
          id: id,
          nom: d.nom,
          alias: d.alias,
          musclesPrincipaux: d.principaux,
          musclesSecondaires: d.secondaires,
          equipement: d.equipement,
          perso: true,
          suiviExplicite: d.pdc ? ExerciseTracking.poidsDuCorpsLeste : null,
          source: 'demo',
          creeLe: debut,
        ));
      }
    }
    if (manquants.isNotEmpty) await data.exercises.addCustomAll(manquants);

    // Routines, dossier et programme
    final dossier = await data.routines.addFolder('Push Pull Legs');
    Routine routine(String nom, List<_DemoEx> list, int ordre) => Routine(
          id: 'demo-routine-${nom.toLowerCase()}',
          nom: nom,
          folderId: dossier.id,
          ordre: ordre,
          creeLe: debut,
          notes: 'Monter la charge dès que le haut de la fourchette passe sur toutes les séries.',
          exercices: [
            for (final (i, d) in list.indexed)
              RoutineExercise(
                id: newId(),
                exerciseId: ids[d.slug]!,
                reposSec: i < 2 ? 150 : 90,
                series: [
                  if (i == 0) const PlannedSet(type: SetType.echauffement, reps: 10),
                  for (var s = 0; s < (i < 2 ? 4 : 3); s++) PlannedSet(reps: d.repsMin, repsMax: d.repsMax),
                ],
              ),
          ],
        );
    final routines = [routine('Push', _push, 0), routine('Pull', _pull, 1), routine('Legs', _legs, 2)];
    await data.routines.saveAll(routines);

    // Séances : quatre jours par semaine, chaque routine à jour fixe (Push,
    // Pull, Legs, puis Push). Si aujourd'hui n'est pas un de ces jours, il
    // prend la place du jour d'avant : la routine du jour a ainsi été faite ce
    // jour-là chaque semaine, et l'onglet Routines la propose.
    final jours = [DateTime.monday, DateTime.tuesday, DateTime.thursday, DateTime.saturday];
    if (!jours.contains(today.weekday)) {
      final avant = jours.lastWhere((j) => j < today.weekday, orElse: () => jours.last);
      jours[jours.indexOf(avant)] = today.weekday;
      jours.sort();
    }
    const tour = [0, 1, 2, 0];
    final sessions = <WorkoutSession>[];
    var cycle = 0;
    final totalJours = today.difference(debut).inDays;
    for (var j = 0; j <= totalJours; j++) {
      final day = DateTime(debut.year, debut.month, debut.day + j);
      if (!jours.contains(day.weekday)) continue;
      if (j == totalJours) break; // pas de séance aujourd'hui : elle reste à faire
      // Séance manquée de temps en temps, sauf le jour de la semaine où l'on
      // est, sur les neuf dernières semaines (la suggestion en dépend).
      final tenue = day.weekday == today.weekday && totalJours - j <= 63;
      if (rnd.nextDouble() < 0.08 && !tenue) continue;
      final semaine = j ~/ 7;
      final deload = semaine > 0 && semaine % 7 == 6;
      final progres = j / totalJours;
      final idx = tour[jours.indexOf(day.weekday)];
      cycle++;
      final list = [_push, _pull, _legs][idx];
      final weekend = day.weekday >= DateTime.saturday;
      var t = DateTime(day.year, day.month, day.day, weekend ? 10 : 18, weekend ? 30 : 5 + rnd.nextInt(40));
      final start = t;
      final exercices = <SessionExercise>[];
      for (final (i, d) in list.indexed) {
        // Progression d'environ 12 à 20 % en six mois, avec du bruit.
        final gain = d.pdc ? 12.5 * progres : d.debut * (0.12 + 0.08 * (i % 2)) * progres;
        var charge = d.debut + gain + (rnd.nextDouble() - 0.5) * d.pas;
        if (deload) charge *= 0.85;
        charge = math.max(0, (charge / d.pas).round() * d.pas);
        final sets = <WorkoutSet>[];
        if (i == 0 && !d.pdc) {
          t = t.add(const Duration(minutes: 3));
          sets.add(WorkoutSet(id: newId(), type: SetType.echauffement, poids: (charge * 0.5 / d.pas).round() * d.pas, reps: 10, fait: true, faitLe: t, tempsReposSec: 90));
        }
        final n = i < 2 ? 4 : 3;
        for (var s = 0; s < n; s++) {
          final reps = math.max(d.repsMin - 1, d.repsMax - s - rnd.nextInt(2) - (deload ? 0 : (progres * 2).floor() % 2));
          final repos = i < 2 ? 150 + rnd.nextInt(40) : 80 + rnd.nextInt(30);
          t = t.add(Duration(seconds: 45 + repos));
          sets.add(WorkoutSet(
            id: newId(),
            type: s == n - 1 && i >= 3 && rnd.nextDouble() < 0.3 ? SetType.echec : SetType.normale,
            poids: charge,
            reps: reps,
            rpe: s == n - 1 ? 8 + rnd.nextInt(3) * 0.5 : null,
            fait: true,
            faitLe: t,
            tempsReposSec: repos,
          ));
        }
        exercices.add(SessionExercise(id: newId(), exerciseId: ids[d.slug]!, series: sets, reposSec: i < 2 ? 150 : 90));
        t = t.add(Duration(minutes: 1 + rnd.nextInt(3)));
      }
      sessions.add(WorkoutSession(
        id: newId(),
        nom: routines[idx].nom,
        routineId: routines[idx].id,
        debut: start,
        fin: t,
        exercices: exercices,
        ressenti: 3 + rnd.nextInt(3),
        source: 'demo',
        notes: rnd.nextDouble() < 0.15 ? 'Bonne énergie, charges solides.' : null,
      ));
    }
    // Deux photos et une vidéo sur les dernières séances (images de
    // remplacement dessinées par l'appli ; la vidéo n'a pas de fichier, sa
    // tuile ne montre que sa durée).
    final medias = Directory('${data.store.dir.path}${Platform.pathSeparator}medias');
    String? image(String Function() dessiner) {
      try {
        return dessiner();
      } on FileSystemException {
        return null;
      }
    }

    for (var k = 0; k < 3 && k < sessions.length; k++) {
      final i = sessions.length - 1 - k;
      final photos = [
        for (var n = 0; n < (k == 1 ? 1 : 2); n++) image(() => DemoImages.haltere(medias, 'demo_seance_${k}_$n', variante: (k + n) % 3)),
      ].whereType<String>();
      if (photos.isEmpty) continue;
      sessions[i] = sessions[i].copyWith(medias: [
        for (final chemin in photos) SessionMedia(chemin: chemin),
        if (k == 0) SessionMedia(chemin: '${medias.path}${Platform.pathSeparator}demo_seance_video.mp4', video: true, dureeSec: 24),
      ]);
    }

    // Images d'un ancien dessin restées sur le disque : redessinées une fois.
    DemoImages.rafraichir(medias);

    // Cardio : une sortie par semaine sur les trois derniers mois, un jour
    // sans musculation (cœur dans la semaine et le calendrier).
    final rndCardio = math.Random(7);
    final jourCardio = [DateTime.wednesday, DateTime.friday, DateTime.sunday].firstWhere((j) => !jours.contains(j));
    const sorties = [('Course à pied', TypeSeance.cardio), ('Vélo', TypeSeance.cardio), ('Rameur', TypeSeance.aviron), ('Fractionné', TypeSeance.hiit)];
    for (var j = math.max(0, totalJours - 13 * 7); j < totalJours; j++) {
      final day = DateTime(debut.year, debut.month, debut.day + j);
      if (day.weekday != jourCardio) continue;
      final recente = totalJours - j <= 14;
      final manquee = rndCardio.nextDouble() < 0.25;
      final minutes = 28 + rndCardio.nextInt(25);
      final tirage = sorties[rndCardio.nextInt(10) < 6 ? 0 : 1 + rndCardio.nextInt(3)];
      // Les deux dernières sont des courses : le cœur se voit dans la semaine.
      final (nom, type) = recente ? sorties.first : tirage;
      if (manquee && !recente) continue;
      final depart = DateTime(day.year, day.month, day.day, 7, 10 + rndCardio.nextInt(30));
      sessions.add(WorkoutSession(
        id: newId(),
        nom: nom,
        debut: depart,
        fin: depart.add(Duration(minutes: type == TypeSeance.hiit ? 22 : minutes)),
        type: type,
        source: 'demo',
      ));
    }
    await data.sessions.addAll(sessions);

    final prog = await data.programs.save(Program(
      id: 'demo-programme-ppl',
      nom: 'Push Pull Legs, 12 semaines',
      description: 'Trois routines en cycle, quatre séances par semaine, progression sur la fourchette de répétitions.',
      dureeSemaines: 12,
      joursParSemaine: 4,
      routineIds: routines.map((r) => r.id).toList(),
      creeLe: debut,
      objectif: Objectif.prendreDuMuscle.label,
      niveau: Niveau.intermediaire.label,
    ));
    final recentes = sessions.where((s) => today.difference(s.debut).inDays < 7 * 7).length;
    await data.programs.save(prog.copyWith(
      actif: true,
      debuteLe: DateTime(today.year, today.month, today.day - 7 * 7),
      seancesFaites: recentes,
      prochainIndex: jours.contains(today.weekday) ? tour[jours.indexOf(today.weekday)] : cycle % 3,
      semaineCourante: (recentes ~/ 4).clamp(0, 11),
    ));

    // Poids et mesures : de 72,5 à 77 kg environ.
    // Les huit tours sont repris toutes les deux semaines, au demi-centimètre.
    double demi(double cm) => (cm * 2).round() / 2;
    var prochainsTours = 0;
    final mesures = <BodyMeasurement>[];
    for (var j = 0; j <= totalJours; j += 2 + rnd.nextInt(2)) {
      final day = DateTime(debut.year, debut.month, debut.day + j, 7, 30);
      final p = j / totalJours;
      final mensuel = j >= prochainsTours;
      if (mensuel) prochainsTours += 14;
      mesures.add(BodyMeasurement(
        id: newId(),
        date: day,
        poidsKg: double.parse((72.5 + 4.6 * p + (rnd.nextDouble() - 0.5) * 0.9).toStringAsFixed(1)),
        masseGrassePct: double.parse((15.2 - 1.3 * p + (rnd.nextDouble() - 0.5) * 0.6).toStringAsFixed(1)),
        tours: mensuel
            ? {
                TourCorps.cou: demi(37.5 + 1.0 * p),
                TourCorps.epaules: demi(116.0 + 4.5 * p),
                TourCorps.poitrine: demi(98.0 + 4.0 * p),
                TourCorps.taille: demi(80.0 - 1.0 * p),
                TourCorps.brasGauche: demi(35.0 + 2.2 * p),
                TourCorps.brasDroit: demi(35.0 + 2.2 * p),
                TourCorps.avantBrasGauche: demi(29.0 + 1.0 * p),
                TourCorps.avantBrasDroit: demi(29.0 + 1.0 * p),
                TourCorps.cuisseGauche: demi(56.0 + 2.5 * p),
                TourCorps.cuisseDroite: demi(56.0 + 2.5 * p),
                TourCorps.molletGauche: demi(36.5 + 1.0 * p),
                TourCorps.molletDroit: demi(36.5 + 1.0 * p),
              }
            : const {},
        source: 'demo',
      ));
    }
    await data.health.addMeasurementsAll(mesures);

    // Photos de progression : une de face toutes les six semaines environ,
    // profil et dos au début et à la fin. Silhouettes de remplacement.
    const vues = [(0.0, 0), (0.0, 1), (0.0, 2), (0.25, 0), (0.5, 0), (0.75, 0), (1.0, 0), (1.0, 1), (1.0, 2)];
    for (final (n, (p, vue)) in vues.indexed) {
      final chemin = image(() => DemoImages.silhouette(medias, 'demo_photo_$n', vue: vue, carrure: 1 + 0.07 * p));
      if (chemin == null) break;
      final jour = (p * (totalJours - 1)).round();
      await data.health.savePhoto(ProgressPhoto(
        id: 'demo-photo-$n',
        date: DateTime(debut.year, debut.month, debut.day + jour, 8),
        chemin: chemin,
        vue: PhotoVue.values[vue],
        poidsKg: double.parse((72.5 + 4.6 * p).toStringAsFixed(1)),
      ));
    }

    // Sommeil : six mois de nuits.
    final nuits = <SleepEntry>[];
    for (var j = 1; j <= totalJours; j++) {
      final reveil = DateTime(debut.year, debut.month, debut.day + j);
      final weekend = reveil.weekday >= DateTime.saturday;
      final coucher = reveil.subtract(Duration(minutes: (weekend ? 60 : 120) + rnd.nextInt(70)));
      final lever = DateTime(reveil.year, reveil.month, reveil.day, weekend ? 8 : 7, rnd.nextInt(45));
      final duree = lever.difference(coucher).inMinutes;
      nuits.add(SleepEntry(
        id: newId(),
        coucher: coucher,
        lever: lever,
        qualite: (duree > 460 ? 4 : 3) + (rnd.nextDouble() < 0.3 ? 1 : 0) - (rnd.nextDouble() < 0.15 ? 1 : 0),
        profondMin: (duree * (0.16 + rnd.nextDouble() * 0.06)).round(),
        paradoxalMin: (duree * (0.2 + rnd.nextDouble() * 0.05)).round(),
        eveilMin: 5 + rnd.nextInt(20),
        legerMin: (duree * 0.52).round(),
        source: 'demo',
      ));
    }
    await data.health.addSleepAll(nuits);

    // Compléments
    final creatine = await data.health.saveSupplement(const Supplement(id: '', nom: 'Créatine', dose: 5, unite: 'g', heures: ['08:00']));
    final whey = await data.health.saveSupplement(const Supplement(id: '', nom: 'Whey', dose: 30, unite: 'g', heures: ['19:30']));
    final vitD = await data.health.saveSupplement(const Supplement(id: '', nom: 'Vitamine D', dose: 1, unite: 'gélule', heures: ['08:00']));
    final prises = <SupplementIntake>[];
    for (var j = 0; j < 60; j++) {
      final day = DateTime(today.year, today.month, today.day - 60 + j);
      for (final s in [creatine, whey, vitD]) {
        if (rnd.nextDouble() < 0.85) {
          prises.add(SupplementIntake(id: newId(), supplementId: s.id, date: DateTime(day.year, day.month, day.day, 8 + rnd.nextInt(12))));
        }
      }
    }
    await data.health.addIntakesAll(prises);

    // Nutrition : deux mois de journal.
    await _nutrition(data, rnd, today);

    // Une conversation avec le coach.
    final conv = await data.coach.create(titre: 'Progresser au développé couché');
    await data.coach.addMessage(conv.id, CoachRole.utilisateur, 'Je stagne un peu au développé couché, tu me conseilles quoi ?');
    await data.coach.addMessage(
      conv.id,
      CoachRole.coach,
      'Tes charges montent bien depuis six mois, le palier actuel est normal. '
      'Garde tes quatre séries, mais vise 8 répétitions à la même charge avant d\'ajouter 2,5 kg. '
      'Ajoute aussi une série de pompes lestées en fin de séance push, et surveille ton sommeil : '
      'tes nuits sous 7 h coïncident avec tes séances les moins bonnes.',
    );
  }

  static Future<void> _nutrition(AppData data, math.Random rnd, DateTime today) async {
    Food f(String id, String nom, double kcal, double p, double g, double l, {double fibres = 0, List<Portion> portions = const []}) => Food(
          id: 'demo-aliment-$id',
          nom: nom,
          pour100g: Macros(kcal: kcal, proteines: p, glucides: g, lipides: l, fibres: fibres),
          portions: portions,
          source: 'perso',
        );
    final avoine = f('avoine', 'Flocons d\'avoine', 372, 13.5, 58.7, 7, fibres: 10);
    final lait = f('lait', 'Lait demi-écrémé', 46, 3.3, 4.8, 1.6);
    final banane = f('banane', 'Banane', 90, 1.1, 20.5, 0.3, fibres: 2.6, portions: const [Portion(label: '1 banane', grammes: 120)]);
    final poulet = f('poulet', 'Blanc de poulet cuit', 150, 31, 0, 2.5);
    final riz = f('riz', 'Riz basmati cuit', 140, 3, 31, 0.4);
    final brocoli = f('brocoli', 'Brocoli vapeur', 34, 2.8, 4, 0.4, fibres: 2.6);
    final oeufs = f('oeufs', 'Œufs', 145, 12.5, 0.7, 10, portions: const [Portion(label: '1 œuf', grammes: 55)]);
    final fromageBlanc = f('fromage-blanc', 'Fromage blanc 3 %', 83, 7.4, 4, 3.2);
    final whey = f('whey', 'Whey protéine', 380, 78, 7, 6, portions: const [Portion(label: '1 dose', grammes: 30)]);
    final amandes = f('amandes', 'Amandes', 610, 21, 7, 52, fibres: 12);
    final saumon = f('saumon', 'Pavé de saumon', 208, 20, 0, 13.5);
    final pates = f('pates', 'Pâtes complètes cuites', 150, 5.5, 29, 1.1, fibres: 4);
    final pain = f('pain', 'Pain complet', 245, 9, 42, 3.5, fibres: 7, portions: const [Portion(label: '1 tranche', grammes: 40)]);
    final avocat = f('avocat', 'Avocat', 160, 2, 1.8, 15, fibres: 6.7);
    final pomme = f('pomme', 'Pomme', 54, 0.3, 11.6, 0.2, fibres: 2.4, portions: const [Portion(label: '1 pomme', grammes: 150)]);
    final skyr = f('skyr', 'Skyr nature', 63, 11, 4, 0.2);
    for (final food in [avoine, lait, banane, poulet, riz, brocoli, oeufs, fromageBlanc, whey, amandes, saumon, pates, pain, avocat, pomme, skyr]) {
      await data.nutrition.saveFood(food.copyWith(favori: food == poulet || food == avoine));
    }

    final entries = <FoodEntry>[];
    final eau = <WaterLog>[];
    FoodEntry e(Food food, double g, DateTime d, MealType m) =>
        FoodEntry(id: newId(), date: d, repas: m, nom: food.nom, quantiteG: g, macros: food.pour(g), foodId: food.id);
    double v(double g) => (g * (0.85 + rnd.nextDouble() * 0.3)).roundToDouble();

    for (var j = 60; j >= 0; j--) {
      final d = DateTime(today.year, today.month, today.day - j);
      final isToday = j == 0;
      final pd = DateTime(d.year, d.month, d.day, 7, 40);
      entries.addAll([e(avoine, v(80), pd, MealType.petitDejeuner), e(lait, v(250), pd, MealType.petitDejeuner), e(banane, 120, pd, MealType.petitDejeuner)]);
      if (rnd.nextBool()) entries.add(e(whey, 30, pd, MealType.petitDejeuner));
      if (!isToday || today.hour >= 13) {
        final dej = DateTime(d.year, d.month, d.day, 12, 30);
        entries.addAll(rnd.nextBool()
            ? [e(poulet, v(180), dej, MealType.dejeuner), e(riz, v(250), dej, MealType.dejeuner), e(brocoli, v(150), dej, MealType.dejeuner)]
            : [e(saumon, v(150), dej, MealType.dejeuner), e(pates, v(250), dej, MealType.dejeuner), e(avocat, v(70), dej, MealType.dejeuner)]);
      }
      if (!isToday || today.hour >= 17) {
        final col = DateTime(d.year, d.month, d.day, 16, 30);
        entries.addAll([e(skyr, v(150), col, MealType.collation), e(amandes, v(25), col, MealType.collation), e(pomme, 150, col, MealType.collation)]);
      }
      if (!isToday || today.hour >= 21) {
        final din = DateTime(d.year, d.month, d.day, 20, 15);
        entries.addAll([
          e(oeufs, 165, din, MealType.diner),
          e(pain, v(80), din, MealType.diner),
          e(fromageBlanc, v(200), din, MealType.diner),
          if (rnd.nextBool()) e(poulet, v(120), din, MealType.diner),
        ]);
      }
      final verres = isToday ? (today.hour ~/ 3).clamp(0, 8) : 7 + rnd.nextInt(5);
      for (var k = 0; k < verres; k++) {
        eau.add(WaterLog(id: newId(), date: DateTime(d.year, d.month, d.day, 8 + k * 1 + rnd.nextInt(2)), ml: 250));
      }
    }
    await data.nutrition.addEntries(entries);
    await data.nutrition.addWaterLogs(eau);

    await data.nutrition.saveMeal(Meal(
      id: '',
      nom: 'Petit-déjeuner du sportif',
      repas: MealType.petitDejeuner,
      favori: true,
      items: [
        MealItem(foodId: avoine.id, nom: avoine.nom, grammes: 80, macros: avoine.pour(80)),
        MealItem(foodId: lait.id, nom: lait.nom, grammes: 250, macros: lait.pour(250)),
        MealItem(foodId: banane.id, nom: banane.nom, grammes: 120, macros: banane.pour(120)),
        MealItem(foodId: whey.id, nom: whey.nom, grammes: 30, macros: whey.pour(30)),
      ],
    ));
  }
}
