import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/erreurs_frequentes.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_index.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/formats.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/records.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart' show sousTitreExercice;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Zone Exercices : recherche sur le vrai catalogue, fichiers d'images,
/// records et formats sur des cas limites.
List<Exercise> _catalogue() => (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List)
    .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();

WorkoutSet _s(String id, double? kg, int? reps, {SetType type = SetType.normale, int? duree, bool fait = true}) =>
    WorkoutSet(id: id, type: type, poids: kg, reps: reps, dureeSec: duree, fait: fait);

WorkoutSession _seance(String id, DateTime d, List<WorkoutSet> series, {String exercice = 'x'}) => WorkoutSession(
      id: id,
      nom: 'Séance',
      debut: d,
      fin: d.add(const Duration(hours: 1)),
      exercices: [SessionExercise(id: 'e$id', exerciseId: exercice, series: series)],
    );

ExerciseStats _stats(List<WorkoutSession> l) => ExerciseStats([for (final s in l) (session: s, exercise: s.exercices.first)]);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  final catalogue = _catalogue();
  final index = ExerciseIndex();
  List<Exercise> chercher(String q, {Map<String, int> freq = const {}}) => index.filtrer(
        catalogue: catalogue,
        perso: const [],
        filtres: LibraryFilters(query: q),
        favoris: const {},
        recents: const [],
        frequences: freq,
      );
  Exercise ex(String id) => catalogue.firstWhere((e) => e.id == id);

  group('catalogue sur le disque', () {
    test('608 exercices, identifiants uniques, muscles et libellés connus', () {
      expect(catalogue, hasLength(608));
      expect(catalogue.map((e) => e.id).toSet(), hasLength(608));
      for (final e in catalogue) {
        expect(e.musclesPrincipaux, isNotEmpty, reason: e.id);
        expect(e.musclesPrincipaux.toSet().intersection(e.musclesSecondaires.toSet()), isEmpty, reason: e.id);
        expect(Categories.labels.containsKey(e.categorie), isTrue, reason: '${e.id} : ${e.categorie}');
        expect(Equipements.labels.containsKey(e.equipement), isTrue, reason: '${e.id} : ${e.equipement}');
        expect(e.instructions, isNotEmpty, reason: e.id);
      }
    });

    test('chaque exercice a ses poses et son animation sur le disque', () {
      final manquants = <String>[];
      var sansAnimation = 0;
      for (final e in catalogue) {
        if (e.media.imagesLocales.isEmpty) manquants.add('${e.id} : aucune pose');
        for (final p in [?e.media.gif, ...e.media.imagesLocales]) {
          if (!File(p).existsSync()) manquants.add('${e.id} : $p');
        }
        if (e.media.gif == null) sansAnimation++;
      }
      expect(manquants, isEmpty);
      // Les maintiens et les étirements n'ont qu'une pose fixe.
      expect(sansAnimation, 112);
    });
  });

  group('recherche sur le vrai catalogue', () {
    test('accents, majuscules, espaces et ponctuation ne comptent pas', () {
      for (final q in ['DEVELOPPE COUCHE', 'développé couché', '  Développé   couché ', 'developpe-couche !']) {
        expect(chercher(q).first.id, 'developpe-couche', reason: q);
      }
    });

    test('mots dans le désordre', () {
      expect(chercher('couché développé').first.id, 'developpe-couche');
      expect(chercher('haltere curl').first.nom, 'Curl haltères');
      expect(chercher('elastique squat').map((e) => e.nom), contains('Squat à l\'élastique'));
    });

    test('un alias exact passe devant les simples mentions', () {
      expect(chercher('bench').first.id, 'developpe-couche');
      expect(chercher('dc').first.id, 'developpe-couche');
      expect(chercher('ohp').first.id, 'developpe-militaire');
      expect(chercher('rdl').first.id, 'souleve-de-terre-roumain');
    });

    test('« dos » ne ramène pas les abdos', () {
      final r = chercher('dos');
      expect(r, isNotEmpty);
      const dos = {Muscle.grandDorsal, Muscle.trapezes, Muscle.rhomboides, Muscle.lombaires};
      expect(r.where((e) => !e.musclesPrincipaux.any(dos.contains) && e.categorie != 'dos' && !e.nom.toLowerCase().contains('dos')), isEmpty);
      expect(r.any((e) => e.id == 'crunch'), isFalse);
      expect(r.any((e) => e.id == 'tractions'), isTrue);
    });

    test('les mots des raccourcis donnent des résultats', () {
      for (final q in ['pecs', 'abdos', 'epaules', 'ischios', 'mollets', 'fessiers', 'biceps', 'triceps', 'avant-bras', 'cuisses', 'dos']) {
        expect(chercher(q), isNotEmpty, reason: q);
      }
      expect(chercher('pecs').every((e) => e.musclesPrincipaux.contains(Muscle.pectoraux) || e.nom.toLowerCase().contains('pec')), isTrue);
    });

    test('aucune réponse', () {
      expect(chercher('zzz'), isEmpty);
      expect(chercher('squat zzz'), isEmpty);
    });

    test('à score égal, le plus fait d\'abord', () {
      expect(chercher('squat', freq: {'squat-goblet': 9}).take(2).map((e) => e.id), ['squat', 'squat-goblet']);
    });

    test('tri « les plus faits » : à égalité, l\'ordre alphabétique ignore les accents', () {
      final r = index.filtrer(
        catalogue: catalogue,
        perso: const [],
        filtres: const LibraryFilters(sort: LibrarySort.frequence, muscles: {Muscle.pectoraux}, principauxSeulement: true),
        favoris: const {},
        recents: const [],
        frequences: const {'pec-deck': 3},
      );
      expect(r.first.id, 'pec-deck');
      final noms = r.skip(1).map((e) => e.nom).toList();
      expect(noms.indexWhere((n) => n.startsWith('Écarté')), lessThan(noms.indexWhere((n) => n.startsWith('Pompes'))));
    });
  });

  test('sous-titre de la grille : le muscle affiché suit la catégorie', () {
    expect(sousTitreExercice(ex('squat')), 'Quadriceps');
    expect(sousTitreExercice(ex('squat-avant')), 'Quadriceps');
    expect(sousTitreExercice(ex('presse-a-cuisses')), 'Quadriceps');
    expect(sousTitreExercice(ex('developpe-couche')), 'Pectoraux');
    expect(sousTitreExercice(ex('tractions')), 'Grand dorsal');
    expect(sousTitreExercice(ex('tractions-supination')), 'Grand dorsal');
    expect(sousTitreExercice(ex('souleve-de-terre-roumain')), 'Ischio-jambiers');
    expect(sousTitreExercice(ex('pompes-diamant')), 'Triceps');
    expect(sousTitreExercice(ex('elevations-laterales')), 'Deltoïdes latéraux');
  });

  group('erreurs fréquentes', () {
    test('un leg curl ne reçoit pas les erreurs du curl biceps', () {
      for (final id in ['leg-curl-assis', 'leg-curl-allonge', 'nordic-curl', 'curl-poignets']) {
        expect(ErreursFrequentes.pour(ex(id)).join(' '), isNot(contains('Coudes qui avancent')), reason: id);
      }
      expect(ErreursFrequentes.pour(ex('curl-barre')).join(' '), contains('Coudes qui avancent'));
    });
    test('« rétraction » n\'est pas une traction', () {
      final e = catalogue.firstWhere((e) => e.nom == 'Rétraction du menton maintenue');
      expect(ErreursFrequentes.pour(e).join(' '), isNot(contains('Élan des jambes')));
      expect(ErreursFrequentes.pour(ex('tractions')).join(' '), contains('Élan des jambes'));
    });
    test('jamais vide', () {
      for (final e in catalogue) {
        expect(ErreursFrequentes.pour(e), isNotEmpty, reason: e.id);
      }
    });
  });

  test('1RM estimé : une répétition, échauffement, série non faite, sans charge', () {
    expect(Strength.setOneRm(_s('a', 100, 1)), 100);
    expect(Strength.setOneRm(_s('a', 100, 5, type: SetType.echauffement)), 0);
    expect(Strength.setOneRm(_s('a', 100, 5, fait: false)), 0);
    expect(Strength.setOneRm(_s('a', 0, 12)), 0);
    expect(Strength.setOneRm(_s('a', null, null)), 0);
    expect(Strength.setOneRm(_s('a', 100, 5)), closeTo(114.6, 0.1));
    // Pas de saut entre 10 et 11 répétitions.
    expect(Strength.setOneRm(_s('a', 100, 11)), greaterThan(Strength.setOneRm(_s('a', 100, 10))));
  });

  group('records, cas limites', () {
    final j1 = DateTime(2026, 9, 1, 18), j2 = DateTime(2026, 9, 8, 18), j3 = DateTime(2026, 9, 15, 18);

    test('une seule séance : tous les records, tous à sa date', () {
      final st = _stats([_seance('a', j1, [_s('a1', 60, 5)])]);
      final r = recordsDe(st, ExerciseTracking.poidsReps);
      expect(r.map((x) => x.type), [TypeRecord.unRm, TypeRecord.poidsMax, TypeRecord.repsMax, TypeRecord.volumeSeance, TypeRecord.volumeSerie]);
      expect(r.every((x) => x.date == j1 && x.sessionId == 'a'), isTrue);
      expect(r[3].valeur, 300);
      expect(r[3].nbSeries, 1);
      expect(progressionRecord(st, TypeRecord.poidsMax), hasLength(1));
    });

    test('les échauffements ne comptent nulle part', () {
      final st = _stats([
        _seance('a', j1, [_s('w', 200, 30, type: SetType.echauffement), _s('a1', 60, 5), _s('a2', 50, 8)]),
      ]);
      final r = {for (final x in recordsDe(st, ExerciseTracking.poidsReps)) x.type: x};
      expect(r[TypeRecord.poidsMax]!.valeur, 60);
      expect(r[TypeRecord.repsMax]!.valeur, 8);
      expect(r[TypeRecord.volumeSeance]!.valeur, 700);
      expect(r[TypeRecord.volumeSeance]!.nbSeries, 2);
      expect(r[TypeRecord.volumeSerie]!.valeur, 400);
      expect(st.nbSeries, 2);
      expect(st.points.single.volume, 700);
    });

    test('une séance faite seulement d\'échauffements ne crée aucun record', () {
      final st = _stats([_seance('a', j1, [_s('w', 40, 10, type: SetType.echauffement)])]);
      expect(recordsDe(st, ExerciseTracking.poidsReps), isEmpty);
      expect(meilleureDeSeance(st.points.single, ExerciseTracking.poidsReps), isNull);
    });

    test('record égalé : la première fois garde le record', () {
      final st = _stats([
        _seance('a', j1, [_s('a1', 80, 5)]),
        _seance('b', j2, [_s('b1', 80, 5)]),
      ]);
      expect(progressionRecord(st, TypeRecord.poidsMax).single.sessionId, 'a');
    });

    test('poids du corps sans lest : seules les répétitions donnent un record', () {
      final st = _stats([_seance('a', j1, [_s('a1', null, 12), _s('a2', 0, 9)])]);
      final r = recordsDe(st, ExerciseTracking.poidsDuCorpsLeste);
      expect(r.map((x) => x.type), [TypeRecord.repsMax]);
      expect(r.single.valeur, 12);
      expect(r.single.detail(ExerciseTracking.poidsDuCorpsLeste, UnitePoids.kg), '12 réps');
    });

    test('poids du corps : la séance qui tient le record de répétitions a la médaille dorée', () {
      final st = _stats([
        _seance('leste', j1, [_s('a1', 10, 5), _s('a2', null, 8)]),
        _seance('sans', j2, [_s('b1', null, 12), _s('b2', 0, 9)]),
        _seance('moins', j3, [_s('c1', null, 10)]),
      ]);
      const t = ExerciseTracking.poidsDuCorpsLeste;
      final parId = {for (final p in st.points) p.session.id: p};
      expect(meilleureDeSeance(parId['sans']!, t)!.label, 'Réps');
      expect(tientLeRecord(st, parId['sans']!, t), isTrue, reason: '12 répétitions : record en cours');
      expect(tientLeRecord(st, parId['leste']!, t), isTrue, reason: '+10 kg : record de charge');
      expect(tientLeRecord(st, parId['moins']!, t), isFalse);
    });

    test('durée : record à la seconde près', () {
      final st = _stats([_seance('a', j1, [_s('a1', null, null, duree: 95), _s('a2', null, null, duree: 60)])]);
      final r = recordsDe(st, ExerciseTracking.duree).single;
      expect(r.valeur, 95);
      expect(r.valeurTexte(UnitePoids.kg), '1 min 35 s');
      expect(ExFmt.serieFiche(_s('x', null, null, duree: 60), ExerciseTracking.duree, UnitePoids.kg), '1 min');
      expect(ExFmt.serieFiche(_s('x', null, null, duree: 45), ExerciseTracking.duree, UnitePoids.kg), '45 s');
      expect(ExFmt.secondes(3725), '1 h 02');
    });

    test('1RM en livres : arrondi après la conversion', () {
      final st = _stats([_seance('a', j1, [_s('a1', 100, 5)])]);
      final r = recordsDe(st, ExerciseTracking.poidsReps).first;
      expect(r.type, TypeRecord.unRm);
      expect(r.valeurTexte(UnitePoids.kg), '115 kg');
      expect(r.valeurTexte(UnitePoids.lb), '253 lb');
    });

    test('historique : du plus ancien au plus récent quel que soit l\'ordre reçu', () {
      final st = _stats([_seance('c', j3, [_s('c', 1, 1)]), _seance('a', j1, [_s('a', 1, 1)]), _seance('b', j2, [_s('b', 1, 1)])]);
      expect(st.points.map((p) => p.session.id), ['a', 'b', 'c']);
      expect(st.premiere, j1);
      expect(st.derniere, j3);
    });

    test('exercice jamais fait', () {
      final st = ExerciseStats(const []);
      expect(st.vide, isTrue);
      expect(recordsDe(st, ExerciseTracking.poidsReps), isEmpty);
      expect(st.derniere, isNull);
      expect(st.dans(StatPeriod.mois3), isEmpty);
    });

    test('périodes : la borne est comprise', () {
      final now = DateTime(2026, 10, 2, 12);
      final st = _stats([
        _seance('a', now.subtract(const Duration(days: 31)), [_s('a', 1, 1)]),
        _seance('b', now.subtract(const Duration(days: 32)), [_s('b', 1, 1)]),
      ]);
      expect(st.dans(StatPeriod.mois1, now: now).map((p) => p.session.id), ['a']);
      expect(st.dans(StatPeriod.tout, now: now), hasLength(2));
    });
  });

  test('explorateur : la semaine commence lundi à minuit, échauffements exclus, secondaire à moitié', () {
    final lundi = DateTime(2026, 10, 5, 8);
    Exercise? lookup(String id) => catalogue.where((e) => e.id == id).firstOrNull;
    final seances = [
      _seance('dimanche', DateTime(2026, 10, 4, 23, 30), [_s('a', 60, 8), _s('b', 60, 8)], exercice: 'curl-barre'),
      _seance('lundi', DateTime(2026, 10, 5, 0, 0), [_s('c', 60, 8), _s('w', 20, 15, type: SetType.echauffement)], exercice: 'curl-barre'),
      // Tractions en supination : biceps en principal ; tirage vertical : biceps en secondaire.
      _seance('tirage', DateTime(2026, 10, 5, 7), [_s('d', 50, 10), _s('e', 50, 10)], exercice: 'tirage-vertical'),
      _seance('demain', DateTime(2026, 10, 6, 7), [_s('f', 60, 8)], exercice: 'curl-barre'),
    ];
    final c = chiffresDuMuscle(Muscle.biceps, seances: seances, lookup: lookup, maintenant: lundi);
    expect(c.seriesSemaine, 3, reason: '1 série lundi, 2 demi-séries du tirage, 1 série prévue demain dans la même semaine');
    expect(c.dernier, DateTime(2026, 10, 5, 0, 0), reason: 'ni le tirage (secondaire) ni la séance à venir');
    final vide = chiffresDuMuscle(Muscle.cou, seances: seances, lookup: lookup, maintenant: lundi);
    expect(vide.seriesSemaine, 0);
    expect(vide.dernier, isNull);
    expect(vide.recuperation, 100);
  });

  group('formats des courbes', () {
    test('1RM sans décimale, répétitions en français, durée à la seconde', () {
      expect(ExFmt.metric(StatMetric.unRm, 11.46, UnitePoids.kg), '11 kg');
      expect(ExFmt.metric(StatMetric.repsMax, 12, UnitePoids.kg), '12 réps');
      expect(ExFmt.metric(StatMetric.repsMax, 1, UnitePoids.kg), '1 rép');
      expect(ExFmt.metric(StatMetric.dureeMax, 95, UnitePoids.kg), '1 min 35 s');
    });
    test('axe : une décimale quand l\'écart est petit', () {
      expect(ExFmt.axe(StatMetric.unRm, 11.25, UnitePoids.kg, fin: true), '11,3');
      expect(ExFmt.axe(StatMetric.unRm, 11.25, UnitePoids.kg), '11');
    });
  });
}
