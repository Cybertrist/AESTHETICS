import 'package:aesthetic/features/seance/widgets/serie_ligne.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un nombre seul compte en secondes, ou en minutes pour le cardio', () {
    expect(lireDuree('45'), 45);
    expect(lireDuree('35', minutes: true), 35 * 60);
    expect(lireDuree('1:30'), 90);
    expect(lireDuree('1:30', minutes: true), 90);
    expect(lireDuree('1:05:00', minutes: true), 3900);
    expect(lireDuree(ecrireDuree(3900), minutes: true), 3900);
    expect(lireDuree(''), isNull);
  });
}
