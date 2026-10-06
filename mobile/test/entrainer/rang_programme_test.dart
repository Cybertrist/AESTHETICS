import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/accueil/volet_routines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Program prog(String id, List<String> routines, {bool actif = false}) =>
      Program(id: id, nom: id, routineIds: routines, actif: actif, creeLe: DateTime(2026, 10, 1));

  test('la carte de jour d\'une routine suit sa place dans son programme', () {
    final rangs = rangDansProgramme([
      prog('a', ['pecs', 'dos', 'jambes']),
    ]);
    expect(rangs, {'pecs': 0, 'dos': 1, 'jambes': 2});
  });

  test('une routine dans deux programmes garde la place du programme actif', () {
    final rangs = rangDansProgramme([
      prog('ancien', ['dos', 'pecs']),
      prog('actif', ['pecs', 'jambes', 'dos'], actif: true),
    ]);
    expect(rangs['pecs'], 0);
    expect(rangs['dos'], 2);
  });

  test('une routine hors programme n\'a pas de place', () {
    expect(rangDansProgramme([prog('a', ['pecs'])])['libre'], isNull);
  });
}
