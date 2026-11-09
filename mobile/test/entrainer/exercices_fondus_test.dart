import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("l'écarté à la machine, fondu dans le pec deck, est relu comme pec deck", () {
    final s = WorkoutSession.fromJson({
      'id': 'a',
      'debut': '2026-11-01T18:00:00',
      'exercices': [
        {'id': 'x', 'exerciseId': 'machine-chest-fly'},
        {'id': 'y', 'exerciseId': 'developpe-couche'},
      ],
    });
    expect(s.exercices.map((e) => e.exerciseId), ['pec-deck', 'developpe-couche']);
    final r = RoutineExercise.fromJson({'id': 'r', 'exerciseId': 'machine-chest-fly'});
    expect(r.exerciseId, 'pec-deck');
  });
}
