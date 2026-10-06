import 'package:aesthetic/core/models/models.dart';

import 'test_bilan_banc.dart';

/// Jeux de séances des tests du bilan. Le bilan testé est toujours celui de
/// septembre 2026, vu le vendredi 2 octobre 2026.
final moisBilan = DateTime(2026, 9);
final maintenantBilan = DateTime(2026, 10, 2, 12);

const _noms = ['Dos / Biceps', 'Pecs / Épaules', 'Pecs / Triceps', 'Jambes', 'Bras'];
const _exos = ['tirage', 'dc', 'long', 'squat', 'curl', 'lat', 'crunch', 'tractions'];

/// Un an d'historique : 14 séances en septembre, 28 en août, des records.
List<WorkoutSession> jeuNormal() => [
      for (var j = 0; j < 14; j++)
        seance(
          DateTime(2026, 9, 1 + j * 2, 18),
          _exos[j % _exos.length],
          [for (var k = 0; k < 3 + j % 3; k++) (40.0 + j * 2.5, 10)],
          nom: _noms[j % _noms.length],
          minutes: 49 + j * 7,
        ),
      for (var j = 0; j < 28; j++)
        seance(
          DateTime(2026, 8, 1 + j, 18),
          _exos[j % _exos.length],
          [for (var k = 0; k < 5; k++) (40.0 + j, 10)],
          nom: _noms[j % _noms.length],
          minutes: 80,
        ),
      for (var m = 1; m <= 11; m++)
        for (var j = 0; j < (m * 5) % 13 + 1; j++)
          seance(
            DateTime(2025, 8 + m, 1 + j * 2, 18),
            _exos[j % _exos.length],
            [for (var k = 0; k < 4; k++) (20.0 + m, 10)],
            nom: _noms[j % _noms.length],
          ),
    ];

/// Une seule séance, jamais rien avant.
List<WorkoutSession> jeuUneSeance() => [
      seance(DateTime(2026, 9, 14, 18), 'dc', [(60, 10), (60, 8)], nom: 'Pecs / Triceps', minutes: 49),
    ];

/// Quarante séances dans le mois, aux noms très longs, et un historique.
List<WorkoutSession> jeuQuarante() => [
      for (var j = 0; j < 40; j++)
        seance(
          DateTime(2026, 9, 1 + j % 30, 7 + (j ~/ 30) * 12),
          _exos[j % _exos.length],
          [for (var k = 0; k < 4; k++) (60.0 + j, 10)],
          nom: j.isEven ? 'Haut du corps, poussée lourde puis tirage léger en superset' : 'Jambes',
          minutes: 95 + j,
        ),
      for (var j = 0; j < 4; j++) seance(DateTime(2026, 8, 3 + j * 7, 18), _exos[j], [(50, 10)]),
    ];

/// Volume énorme, vingt records, noms très longs partout.
List<WorkoutSession> jeuExtreme() => [
      // Le mois d'avant : chaque exercice une fois, léger.
      for (final (i, e) in _exos.indexed) seance(DateTime(2026, 8, 3 + i, 18), e, [(20, 10)], nom: 'Séance'),
      for (var i = 0; i < 20; i++) seance(DateTime(2026, 8, 2 + i, 7), 'perso$i', [(20, 10)]),
      // Le mois : des charges absurdes, 31 séances de six heures.
      for (var j = 0; j < 30; j++)
        seance(
          DateTime(2026, 9, 1 + j, 6),
          _exos[j % _exos.length],
          [for (var k = 0; k < 12; k++) (999.5, 999)],
          nom: 'Séance interminable du matin avec tout le monde à la salle',
          minutes: 400,
        ),
      for (var i = 0; i < 20; i++) seance(DateTime(2026, 9, 2 + i, 20), 'perso$i', [(1234.5, 100)]),
    ];

/// Exercices perso du jeu extrême, aux noms très longs.
List<Exercise> exercicesExtremes() => [
      for (var i = 0; i < 20; i++)
        Exercise(
          id: 'perso$i',
          nom: 'Développé incliné aux haltères prise neutre numéro ${i + 1} sur banc à 30 degrés',
          musclesPrincipaux: const [Muscle.pectoraux],
        ),
    ];

/// Rien en septembre, mais un historique avant.
List<WorkoutSession> jeuMoisVide() => [
      for (var j = 0; j < 10; j++) seance(DateTime(2026, 8, 1 + j * 3, 18), _exos[j % _exos.length], [(50, 10), (50, 10)]),
      for (var j = 0; j < 6; j++) seance(DateTime(2026, 6, 1 + j * 3, 18), _exos[j % _exos.length], [(50, 10)]),
    ];

/// Que du poids du corps : des séances, aucun volume.
List<WorkoutSession> jeuSansCharge() => [
      for (var j = 0; j < 8; j++) seance(DateTime(2026, 9, 1 + j * 3, 18), j.isEven ? 'tractions' : 'crunch', [(0, 8 + j), (0, 8)], nom: 'Poids du corps', minutes: 20),
      for (var j = 0; j < 4; j++) seance(DateTime(2026, 8, 3 + j * 7, 18), 'tractions', [(0, 6)], nom: 'Poids du corps'),
    ];
