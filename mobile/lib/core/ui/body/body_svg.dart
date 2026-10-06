// Compatibilité : le personnage n'est plus en SVG (voir body_images.dart et tools/corps3d/).
// Ce fichier garde l'ancien point d'entrée utilisé au démarrage.
import 'body_images.dart';

export 'body_images.dart' show BodyView;

abstract final class BodySvgRepository {
  /// Précharge les images du personnage.
  static Future<void> precache() => BodyImageRepository.precache();
}
