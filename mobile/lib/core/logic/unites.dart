import 'format.dart';

/// Unités d'affichage des longueurs (tours du corps) et des distances.
/// Tout reste enregistré en centimètres et en mètres : seul l'affichage et
/// la saisie suivent le choix fait dans Réglages > Unités (gardé dans le
/// profil, que `ProfileRepo` recopie ici).
abstract final class Affichage {
  /// Tours du corps en pouces plutôt qu'en centimètres.
  static bool pouces = false;

  /// Distances en miles plutôt qu'en kilomètres.
  static bool miles = false;

  static const cmParPouce = 2.54;
  static const mParMile = 1609.344;

  static String get longueur => pouces ? 'po' : 'cm';
  static String get longueurNom => pouces ? 'pouces' : 'centimètres';
  static String get distanceLabel => miles ? 'mi' : 'km';

  static double _net(double v, int decimales) {
    final f = decimales == 1 ? 10 : 100;
    return (v * f).round() / f;
  }

  /// Centimètres vers l'unité affichée (au dixième en pouces).
  static double longueurAffichee(double cm) => pouces ? _net(cm / cmParPouce, 1) : cm;
  static double longueurStockee(double v) => pouces ? v * cmParPouce : v;

  /// Écart de longueur, null conservé.
  static double? ecartLongueur(double? cm) => cm == null ? null : longueurAffichee(cm);

  /// « 39 » ou « 15,4 » : le nombre seul.
  static String lg(double cm) => Fmt.n(longueurAffichee(cm));

  /// « 39 cm » ou « 15,4 po ».
  static String longueurTexte(double cm) => '${lg(cm)} $longueur';

  /// Mètres vers kilomètres ou miles (au centième en miles).
  static double distanceAffichee(double m) => miles ? _net(m / mParMile, 2) : m / 1000;
  static double distanceStockee(double v) => v * (miles ? mParMile : 1000);

  /// « 5,2 km », « 800 m » ou « 3,23 mi ».
  static String distance(double m, {int decimals = 2}) {
    if (miles) return '${Fmt.n(distanceAffichee(m), decimals: 2)} mi';
    return m >= 1000 ? '${Fmt.n(m / 1000, decimals: decimals)} km' : '${Fmt.n(m, decimals: 0)} m';
  }
}
