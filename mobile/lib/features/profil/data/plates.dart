import 'prefs.dart';

/// Résultat du calculateur : les disques d'un côté de la barre.
class ChargementBarre {
  const ChargementBarre({required this.barreKg, required this.parCote, required this.cibleKg});

  final double barreKg;

  /// Disques d'un côté, du plus lourd au plus léger.
  final List<double> parCote;
  final double cibleKg;

  double get totalKg => barreKg + 2 * parCote.fold(0.0, (a, d) => a + d);

  /// Écart avec la cible (positif : il manque du poids).
  double get ecartKg => cibleKg - totalKg;
  bool get exact => ecartKg.abs() < 0.001;
}

/// Calculateur de disques, à partir des barres et disques des réglages.
abstract final class Plates {
  /// Charge la barre au plus près de [cibleKg] sans la dépasser, en
  /// respectant le nombre de paires de chaque disque.
  static ChargementBarre charger(double cibleKg, double barreKg, List<Disque> disques) {
    final tries = [...disques]..sort((a, b) => b.poidsKg.compareTo(a.poidsKg));
    var reste = (cibleKg - barreKg) / 2;
    final cote = <double>[];
    for (final d in tries) {
      var n = d.paires;
      while (n > 0 && reste + 1e-9 >= d.poidsKg) {
        cote.add(d.poidsKg);
        reste -= d.poidsKg;
        n--;
      }
    }
    return ChargementBarre(barreKg: barreKg, parCote: cote, cibleKg: cibleKg);
  }

  /// Poids le plus lourd possible avec ce matériel.
  static double maximum(double barreKg, List<Disque> disques) =>
      barreKg + 2 * disques.fold(0.0, (a, d) => a + d.poidsKg * d.paires);
}
