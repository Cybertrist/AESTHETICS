import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Écriture commune (CHASSE.md, point 18c) : charge × répétitions, repos en
/// minutes:secondes, décimale à virgule, et `Fmt.relatif` au changement d'heure.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('charge et répétitions : espace avant kg, signe ×', () {
    expect(Fmt.charge(70, 6), '70 kg × 6');
    expect(Fmt.charge(72.5, 8), '72,5 kg × 8');
    expect(Fmt.charge(null, 12), '× 12');
    expect(Fmt.charge(0, 12), '× 12');
    expect(Fmt.charge(85, null), '85 kg');
    expect(Fmt.charge(null, null), '-');
    expect(Fmt.charge(100, 5, UnitePoids.lb), '220,5 lb × 5');
    expect(Fmt.charge(70, 6).contains('x'), isFalse);
    expect(Fmt.fois, '×');
  });

  test('volume : « 1 690 kg »', () {
    expect(Fmt.volume(1690), '1 690 kg');
    expect(Fmt.poids(70), '70 kg');
  });

  test('repos en minutes:secondes', () {
    expect(Fmt.minSec(150), '2:30');
    expect(Fmt.minSec(45), '0:45');
    expect(Fmt.minSec(60), '1:00');
    expect(Fmt.minSec(0), '0:00');
    expect(Fmt.minSec(-5), '0:00');
    expect(Fmt.minSec(605), '10:05');
    // L'ancienne fonction ne change pas (ses appelants comptent dessus).
    expect(Fmt.repos(90), '1:30');
    expect(Fmt.repos(45), '45 s');
    expect(Fmt.repos(120), '2 min');
  });

  test('décimale à virgule pour un champ de saisie, et relecture', () {
    expect(Fmt.decimal(72.5), '72,5');
    expect(Fmt.decimal(100), '100');
    expect(Fmt.decimal(100.0), '100');
    expect(Fmt.decimal(1250), '1250');
    expect(Fmt.decimal(2.25), '2,25');
    expect(Fmt.decimal(77.26, decimals: 1), '77,3');
    expect(Fmt.decimal(-0.001), '0');
    expect(Fmt.decimal(null), '');
    expect(Fmt.decimal(72.5).contains('.'), isFalse);

    expect(Fmt.lireDecimal('72,5'), 72.5);
    expect(Fmt.lireDecimal('72.5'), 72.5);
    expect(Fmt.lireDecimal(' 1 250 '), 1250);
    expect(Fmt.lireDecimal(''), isNull);
    expect(Fmt.lireDecimal(null), isNull);
    expect(Fmt.lireDecimal('abc'), isNull);
    expect(Fmt.lireDecimal('1,2,3'), isNull);
    for (final v in [0.0, 2.5, 72.5, 100.0, 142.25]) {
      expect(Fmt.lireDecimal(Fmt.decimal(v)), v);
    }
  });

  test('joursEntre compte des jours de calendrier', () {
    expect(Fmt.joursEntre(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
    expect(Fmt.joursEntre(DateTime(2026, 3, 28, 23, 59), DateTime(2026, 3, 30, 0, 1)), 2);
    expect(Fmt.joursEntre(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 1);
    expect(Fmt.joursEntre(DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1, 1)), 1);
    expect(Fmt.joursEntre(DateTime(2026, 10, 2), DateTime(2026, 10, 1)), -1);
    expect(Fmt.joursEntre(DateTime(2026, 10, 2, 1), DateTime(2026, 10, 2, 23)), 0);
  });

  test('relatif autour du passage à l\'heure d\'été (journée de 23 heures)', () {
    // Dimanche 29 mars 2026 : en France la journée ne dure que 23 heures.
    final lundi = DateTime(2026, 3, 30, 9);
    expect(Fmt.relatif(DateTime(2026, 3, 30, 0, 5), now: lundi), 'Aujourd\'hui');
    expect(Fmt.relatif(DateTime(2026, 3, 29, 18), now: lundi), 'Hier');
    expect(Fmt.relatif(DateTime(2026, 3, 28, 18), now: lundi), 'Samedi');
    expect(Fmt.relatif(DateTime(2026, 3, 31, 7), now: lundi), 'Demain');
    // Vu du dimanche lui-même.
    final dimanche = DateTime(2026, 3, 29, 23, 30);
    expect(Fmt.relatif(DateTime(2026, 3, 28, 23, 50), now: dimanche), 'Hier');
    expect(Fmt.relatif(DateTime(2026, 3, 30, 0, 10), now: dimanche), 'Demain');
  });

  test('relatif autour du retour à l\'heure d\'hiver (journée de 25 heures)', () {
    final lundi = DateTime(2026, 10, 26, 0, 30);
    expect(Fmt.relatif(DateTime(2026, 10, 25, 0, 10), now: lundi), 'Hier');
    expect(Fmt.relatif(DateTime(2026, 10, 24, 23, 50), now: lundi), 'Samedi');
    expect(Fmt.relatif(DateTime(2026, 10, 19, 12), now: lundi), '19 oct.');
    expect(Fmt.relatif(DateTime(2026, 10, 20, 12), now: lundi), 'Mardi');
  });
}
