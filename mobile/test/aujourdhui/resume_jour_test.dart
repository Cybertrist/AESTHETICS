import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/aujourdhui/logic/resume_jour.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records : pas de record sans historique, puis record battu', () {
    WorkoutSession s(String id, int jour, double poids) => WorkoutSession(
          id: id,
          nom: 'Push',
          debut: DateTime(2026, 9, jour, 18),
          fin: DateTime(2026, 9, jour, 19),
          exercices: [
            SessionExercise(id: 'e$id', exerciseId: 'developpe-couche', series: [
              WorkoutSet(id: 's$id', poids: poids, reps: 8, fait: true),
            ]),
          ],
        );
    final r = historiqueRecords([s('c', 10, 90), s('b', 5, 80), s('a', 1, 80)]);
    expect(r.every((x) => x.session.id == 'c'), isTrue);
    expect(r.any((x) => x.record.type == RecordType.poidsMax && x.record.valeur == 90), isTrue);
  });

  test('salutation selon l\'heure', () {
    expect(salutation(DateTime(2026, 9, 30, 8)), 'Bonjour');
    expect(salutation(DateTime(2026, 9, 30, 14)), 'Bon après-midi');
    expect(salutation(DateTime(2026, 9, 30, 21)), 'Bonsoir');
    expect(salutation(DateTime(2026, 9, 30, 2)), 'Bonsoir');
  });
}
