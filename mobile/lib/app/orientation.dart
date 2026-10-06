import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Orientation de l'écran : verrouillée en portrait sur un téléphone (ou un
/// pliant fermé), libre dès que le plus petit côté atteint [seuil] (pliant
/// ouvert, tablette). Fait ici plutôt que dans le manifeste, qui figerait
/// aussi le pliant ouvert.
abstract final class OrientationEcran {
  /// Plus petit côté, en points, à partir duquel l'écran tourne librement.
  static const seuil = 600.0;

  static bool? _portrait;

  /// Vrai quand un écran de ce plus petit côté doit rester en portrait.
  static bool verrouille(double plusPetitCote) => plusPetitCote > 0 && plusPetitCote < seuil;

  /// Applique le verrou pour un écran de ce plus petit côté. Ne parle au
  /// système que si l'état change (ouverture ou fermeture du pliant).
  static void appliquer(double plusPetitCote) {
    if (plusPetitCote <= 0) return;
    final portrait = verrouille(plusPetitCote);
    if (portrait == _portrait) return;
    _portrait = portrait;
    SystemChrome.setPreferredOrientations(
      portrait ? const [DeviceOrientation.portraitUp] : const <DeviceOrientation>[],
    );
  }

  /// Oublie l'état appliqué (tests).
  @visibleForTesting
  static void reinitialiser() => _portrait = null;
}

/// Suit la taille de l'écran et tient le verrou à jour.
class VerrouOrientation extends StatelessWidget {
  const VerrouOrientation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    OrientationEcran.appliquer(MediaQuery.sizeOf(context).shortestSide);
    return child;
  }
}
