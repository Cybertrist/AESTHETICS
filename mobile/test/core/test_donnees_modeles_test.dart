import 'dart:convert';

import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aller-retour exact : ce qui est écrit puis relu se réécrit à l'identique.
void _allerRetour<T>(T objet, Map<String, dynamic> Function(T) versJson, T Function(Map<String, dynamic>) depuisJson) {
  final a = jsonEncode(versJson(objet));
  final relu = depuisJson(Map<String, dynamic>.from(jsonDecode(a) as Map));
  expect(jsonEncode(versJson(relu)), a);
}

WorkoutSession _seanceComplete() => WorkoutSession(
      id: 's1',
      nom: 'DOS / BICEPS',
      debut: DateTime(2026, 9, 30, 18, 5, 11, 123),
      fin: DateTime(2026, 9, 30, 19, 50),
      routineId: 'r1',
      programId: 'p1',
      notes: 'Bonne séance',
      ressenti: 4,
      photo: 'medias/a.jpg',
      source: 'import',
      type: TypeSeance.crossTraining,
      medias: const [
        SessionMedia(chemin: 'medias/1.jpg'),
        SessionMedia(chemin: 'medias/2.mp4', video: true, dureeSec: 24),
      ],
      exercices: [
        SessionExercise(
          id: 'e1',
          exerciseId: 'tirage-vertical',
          reposSec: 120,
          supersetId: 'ss',
          notes: 'Coudes bas',
          series: [
            for (final (i, t) in SetType.values.indexed)
              WorkoutSet(
                id: 'set$i',
                type: t,
                poids: 42.5 + i,
                reps: 8 + i,
                rpe: 8.5,
                fait: i.isEven,
                tempsReposSec: 95,
                dureeSec: 30,
                distanceM: 12.5,
                faitLe: DateTime(2026, 9, 30, 18, 10 + i),
              ),
          ],
        ),
      ],
    );

void main() {
  group('types de série', () {
    test('douze types, les quatre premiers gardent leur nom de fichier', () {
      expect(SetType.values, hasLength(12));
      expect(SetType.values.take(4).map((t) => t.name), ['echauffement', 'normale', 'degressive', 'echec']);
      expect(SetType.ordrePanneau.toSet(), SetType.values.toSet());
      expect(SetType.values.map((t) => t.name).toSet(), hasLength(12));
      // Lettres toutes différentes : deux types ne se confondent pas dans le tableau.
      expect(SetType.values.map((t) => t.lettre).toSet(), hasLength(12));
    });

    test('chaque type se relit depuis son nom', () {
      for (final t in SetType.values) {
        final s = WorkoutSet.fromJson(WorkoutSet(id: 'x', type: t).toJson());
        expect(s.type, t);
        expect(PlannedSet.fromJson(PlannedSet(type: t).toJson()).type, t);
      }
    });

    test('type inconnu ou mal typé : série normale, sans erreur', () {
      for (final v in ['superset', '', 'ECHEC', 12, true, null, <String>[]]) {
        expect(WorkoutSet.fromJson({'id': 'x', 'type': v}).type, SetType.normale, reason: '$v');
      }
    });

    test('seul l\'échauffement est hors volume', () {
      for (final t in SetType.values) {
        final s = WorkoutSet(id: 'x', type: t, poids: 10, reps: 10, fait: true);
        expect(s.volume, t == SetType.echauffement ? 0 : 100, reason: t.name);
      }
    });
  });

  group('aller-retour toJson / fromJson', () {
    test('séance complète (médias, type, douze types de série)', () {
      final s = _seanceComplete();
      _allerRetour(s, (x) => x.toJson(), WorkoutSession.fromJson);
      final relu = WorkoutSession.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(s.toJson())) as Map));
      expect(relu.type, TypeSeance.crossTraining);
      expect(relu.medias, s.medias);
      expect(relu.debut, s.debut);
      expect(relu.fin, s.fin);
      expect(relu.exercices.single.series.map((x) => x.type), SetType.values);
      expect(relu.exercices.single.series.map((x) => x.fait), s.exercices.single.series.map((x) => x.fait));
      expect(relu.volume, s.volume);
    });

    test('chaque type de séance', () {
      for (final t in TypeSeance.values) {
        final s = WorkoutSession(id: 'a', nom: 'n', debut: DateTime(2026), type: t);
        expect(WorkoutSession.fromJson(s.toJson()).type, t);
      }
    });

    test('séance minimale', () {
      _allerRetour(WorkoutSession(id: 'a', nom: 'n', debut: DateTime(2026, 1, 1)), (x) => x.toJson(), WorkoutSession.fromJson);
    });

    test('média', () {
      for (final m in const [
        SessionMedia(chemin: 'a.jpg'),
        SessionMedia(chemin: 'b.mp4', video: true),
        SessionMedia(chemin: 'c.mp4', video: true, dureeSec: 0),
      ]) {
        expect(SessionMedia.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(m.toJson())) as Map)), m);
      }
    });

    test('routine, dossier, programme, record', () {
      _allerRetour(
        Routine(
          id: 'r',
          nom: 'Push',
          folderId: 'f',
          notes: 'n',
          ordre: 3,
          creeLe: DateTime(2026, 1, 2, 3, 4, 5),
          modifieLe: DateTime(2026, 2, 2),
          exercices: [
            RoutineExercise(id: 'a', exerciseId: 'x', reposSec: 75, supersetId: 's', notes: 'n', series: [
              for (final t in SetType.values)
                PlannedSet(type: t, poids: 50, reps: 8, repsMax: 12, dureeSec: 30, distanceM: 100, rpe: 9),
            ]),
          ],
        ),
        (x) => x.toJson(),
        Routine.fromJson,
      );
      _allerRetour(const Folder(id: 'f', nom: 'Dossier', ordre: 2, replie: true), (x) => x.toJson(), Folder.fromJson);
      _allerRetour(
        Program(
          id: 'p',
          nom: 'PPL',
          description: 'd',
          dureeSemaines: 12,
          joursParSemaine: 6,
          routineIds: const ['a', 'b'],
          actif: true,
          debuteLe: DateTime(2026, 3, 1),
          semaineCourante: 2,
          prochainIndex: 1,
          seancesFaites: 13,
          niveau: 'avance',
          objectif: 'force',
          creeLe: DateTime(2026, 2, 1),
        ),
        (x) => x.toJson(),
        Program.fromJson,
      );
      for (final t in RecordType.values) {
        _allerRetour(
          PersonalRecord(exerciseId: 'x', type: t, valeur: 102.5, date: DateTime(2026, 5, 5), sessionId: 's', poids: 100, reps: 3),
          (x) => x.toJson(),
          PersonalRecord.fromJson,
        );
      }
    });

    test('profil, réglages, exercice, mesure, photo', () {
      _allerRetour(
        UserProfile(
          id: 'moi',
          prenom: 'Tristan',
          sexe: Sexe.autre,
          naissance: DateTime(1999, 5, 12),
          tailleCm: 181.5,
          poidsKg: 77.2,
          poidsCibleKg: 82,
          objectif: Objectif.force,
          niveau: Niveau.avance,
          activite: NiveauActivite.tresActif,
          joursParSemaine: 5,
          dureeSeanceMin: 75,
          materiel: const {Materiel.barre, Materiel.banc},
          unitePoids: UnitePoids.lb,
          objectifsNutrition: const NutritionGoals(kcal: 3000),
          photo: 'p.jpg',
          creeLe: DateTime(2026, 1, 1, 8),
        ),
        (x) => x.toJson(),
        UserProfile.fromJson,
      );
      _allerRetour(
        const AppSettings(reposParDefautSec: 120, incrementPoidsKg: 1.25, joursRappel: [2, 4], premierJourSemaine: 7, coachApiKey: 'k'),
        (x) => x.toJson(),
        AppSettings.fromJson,
      );
      _allerRetour(
        Exercise(
          id: 'perso-1',
          nom: 'Mon exo',
          nomEn: 'My lift',
          alias: const ['a'],
          musclesPrincipaux: const [Muscle.pectoraux],
          musclesSecondaires: const [Muscle.triceps],
          equipement: 'barre',
          categorie: 'pectoraux',
          mecanique: 'polyarticulaire',
          niveau: 'debutant',
          instructions: const ['i'],
          conseils: const ['c'],
          media: const ExerciseMedia(gif: 'g', imagesLocales: ['l']),
          source: 'import',
          perso: true,
          suiviExplicite: ExerciseTracking.poidsDuree,
          notes: 'n',
          creeLe: DateTime(2026, 4, 4),
        ),
        (x) => x.toJson(),
        Exercise.fromJson,
      );
      _allerRetour(
        BodyMeasurement(id: 'm', date: DateTime(2026, 6, 6), poidsKg: 77, masseGrassePct: 14.5, masseMusculaireKg: 36, tours: {for (final t in TourCorps.values) t: 30.5}, source: 'profil'),
        (x) => x.toJson(),
        BodyMeasurement.fromJson,
      );
      _allerRetour(
        ProgressPhoto(id: 'p', date: DateTime(2026, 6, 6), chemin: 'c.jpg', vue: PhotoVue.dos, poidsKg: 77, note: 'n'),
        (x) => x.toJson(),
        ProgressPhoto.fromJson,
      );
    });
  });

  group('anciens fichiers', () {
    // Séance telle qu'elle était écrite avant l'ajout de type, medias et des huit nouveaux types de série.
    const ancienne = '{"id":"s","nom":"Push","debut":"2026-03-18T18:05:11.000","fin":"2026-03-18T19:12:33.000",'
        '"exercices":[{"id":"e","exerciseId":"developpe-couche-barre","series":['
        '{"id":"a","type":"echauffement","poids":40.0,"reps":10,"fait":true},'
        '{"id":"b","type":"normale","poids":80.0,"reps":6,"fait":true},'
        '{"id":"c","type":"degressive","poids":60.0,"reps":8,"fait":true},'
        '{"id":"d","type":"echec","poids":82.5,"reps":4,"fait":true}],"reposSec":90}],"photo":"x.jpg"}';

    test('séance sans type ni médias', () {
      final s = WorkoutSession.fromJson(Map<String, dynamic>.from(jsonDecode(ancienne) as Map));
      expect(s.type, TypeSeance.musculation);
      expect(s.medias, isEmpty);
      expect(s.photo, 'x.jpg');
      expect(s.exercices.single.series.map((x) => x.type),
          [SetType.echauffement, SetType.normale, SetType.degressive, SetType.echec]);
      expect(s.volume, 80 * 6 + 60 * 8 + 82.5 * 4);
      // Réécrite, elle ne gagne aucune clé : un ancien fichier reste un ancien fichier.
      expect(jsonDecode(jsonEncode(s.toJson())), jsonDecode(ancienne));
    });

    test('type de séance inconnu : musculation', () {
      for (final v in ['yoga', '', 3, null, <String, dynamic>{}]) {
        expect(WorkoutSession.fromJson({'id': 's', 'nom': 'n', 'debut': '2026-01-01T10:00:00.000', 'type': v}).type, TypeSeance.musculation);
      }
    });

    test('champs mal typés : lecture sans erreur', () {
      final s = WorkoutSession.fromJson({
        'id': 12,
        'nom': null,
        'debut': '2026-01-01T10:00:00.000',
        'fin': 'pas une date',
        'exercices': {'a': 1},
        'medias': 'photo.jpg',
        'ressenti': 'beaucoup',
        'type': ['cardio'],
      });
      expect(s.id, '12');
      expect(s.fin, isNull);
      expect(s.exercices, isEmpty);
      expect(s.medias, isEmpty);
      expect(s.ressenti, isNull);
      final s2 = WorkoutSession.fromJson({
        'id': 's',
        'debut': '2026-01-01T10:00:00.000',
        'medias': [1, 'a', null, {'chemin': 'ok.jpg', 'video': 'true', 'dureeSec': '12'}, {'video': true}],
        'exercices': [
          3,
          {'id': 'e', 'exerciseId': 'x', 'series': [null, {'id': 'a', 'poids': '82,5', 'reps': '6.0', 'fait': 1}]},
        ],
      });
      expect(s2.medias.first, const SessionMedia(chemin: 'ok.jpg', video: true, dureeSec: 12));
      expect(s2.exercices.single.series.single.poids, 82.5);
      expect(s2.exercices.single.series.single.reps, 6);
      expect(s2.exercices.single.series.single.fait, isTrue);
    });

    test('nombres non finis écrits en texte : valeur absente, pas d\'erreur', () {
      final s = WorkoutSet.fromJson({'id': 'a', 'poids': 'NaN', 'reps': 'Infinity', 'rpe': '-Infinity', 'dureeSec': 'NaN'});
      expect(s.poids, isNull);
      expect(s.reps, isNull);
      expect(s.rpe, isNull);
      expect(s.dureeSec, isNull);
    });

    test('profil dont les objectifs nutritionnels sont illisibles : le profil reste lisible', () {
      final p = UserProfile.fromJson({'id': 'moi', 'prenom': 'Tristan', 'creeLe': '2026-01-01T00:00:00.000', 'objectifsNutrition': 'auto'});
      expect(p.prenom, 'Tristan');
      expect(p.objectifsNutrition, isNull);
    });

    test('profil et réglages d\'une valeur d\'enum inconnue', () {
      final p = UserProfile.fromJson({'prenom': 'T', 'sexe': 'x', 'objectif': 'x', 'niveau': 'x', 'activite': 'x', 'unitePoids': 'stone', 'materiel': ['x', 'banc']});
      expect(p.sexe, Sexe.homme);
      expect(p.unitePoids, UnitePoids.kg);
      expect(p.materiel, contains(Materiel.banc));
    });
  });
}
