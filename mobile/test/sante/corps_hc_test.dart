import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/sante/services/corps_hc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pesées de Health Connect rangées dans les saisies, sans écran.
void main() {
  ReleveHc poids(DateTime d, double kg) => (date: d, poidsKg: kg, grasPct: null);
  ReleveHc gras(DateTime d, double pct) => (date: d, poidsKg: null, grasPct: pct);

  test('une saisie par jour : dernière pesée et dernier taux de gras', () {
    final f = CorpsHc.fusionner(const [], [
      poids(DateTime(2026, 10, 10, 7), 76.4),
      poids(DateTime(2026, 10, 10, 21), 77.1),
      gras(DateTime(2026, 10, 10, 7), 0.152),
      poids(DateTime(2026, 10, 11, 7, 30), 76.24999),
    ]);
    expect(f.aRetirer, isEmpty);
    expect(f.aEcrire, hasLength(2));
    final hier = f.aEcrire.firstWhere((m) => m.id == 'hc-2026-10-10');
    expect(hier.poidsKg, 77.1);
    // Une fraction devient un pourcentage.
    expect(hier.masseGrassePct, 15.2);
    expect(hier.source, CorpsHc.source);
    final jour = f.aEcrire.firstWhere((m) => m.id == 'hc-2026-10-11');
    expect(jour.poidsKg, 76.25);
    expect(jour.masseGrassePct, isNull);
    expect(jour.date, DateTime(2026, 10, 11, 7, 30));
  });

  test('une valeur saisie à la main est gardée, le reste est complété', () {
    final manuelle = BodyMeasurement(id: 'a', date: DateTime(2026, 10, 11, 12), poidsKg: 75, tours: const {TourCorps.cou: 38}, source: 'manuel');
    final f = CorpsHc.fusionner([manuelle], [poids(DateTime(2026, 10, 11, 7), 76.2), gras(DateTime(2026, 10, 11, 7), 14.8)]);
    final m = f.aEcrire.single;
    expect(m.id, 'a');
    expect(m.poidsKg, 75);
    expect(m.masseGrassePct, 14.8);
    expect(m.tours, {TourCorps.cou: 38});
    expect(m.source, 'manuel');
  });

  test('une saisie de la balance suit la balance, et rien ne s\'écrit sans changement', () {
    final lus = [poids(DateTime(2026, 10, 11, 7), 76.2), gras(DateTime(2026, 10, 11, 7), 14.8)];
    final premiere = CorpsHc.fusionner(const [], lus).aEcrire;
    expect(CorpsHc.fusionner(premiere, lus).aEcrire, isEmpty);
    final apres = CorpsHc.fusionner(premiere, [...lus, poids(DateTime(2026, 10, 11, 20), 76.9)]).aEcrire.single;
    expect(apres.id, 'hc-2026-10-11');
    expect(apres.poidsKg, 76.9);
    expect(apres.masseGrassePct, 14.8);
  });

  test('les anciennes pesées importées une par une sont remplacées', () {
    final anciennes = [
      BodyMeasurement(id: 'hc-p-x', date: DateTime(2026, 10, 11, 7), poidsKg: 76.2, source: CorpsHc.source),
      BodyMeasurement(id: 'hc-mg-y', date: DateTime(2026, 10, 11, 7), masseGrassePct: 14.8, source: CorpsHc.source),
    ];
    final f = CorpsHc.fusionner(anciennes, [poids(DateTime(2026, 10, 11, 7), 76.2), gras(DateTime(2026, 10, 11, 7), 14.8)]);
    expect(f.aRetirer, ['hc-p-x', 'hc-mg-y']);
    expect(f.aEcrire.single.id, 'hc-2026-10-11');
  });

  test('valeurs nulles ou négatives ignorées', () {
    expect(CorpsHc.fusionner(const [], [poids(DateTime(2026, 10, 11), 0), gras(DateTime(2026, 10, 11), -1)]).aEcrire, isEmpty);
  });
}
