import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Icône de début de ligne : l'icône dans un rond gris plat (#2C2C2E), sans
/// lueur ni dégradé. Le nom est gardé pour les écrans qui s'en servent.
class IconHalo extends StatelessWidget {
  const IconHalo({
    super.key,
    required this.icon,
    this.color,
    this.size = 42,
    this.off = false,
    this.glow = true,
  });

  /// Icône d'un domaine (entraînement, nutrition, sommeil...), teintée de
  /// sa couleur.
  IconHalo.domain(
    AppDomain domain, {
    super.key,
    IconData? icon,
    this.size = 42,
    this.off = false,
    this.glow = true,
  })  : icon = icon ?? domain.icon,
        color = domain.color;

  final IconData icon;

  /// Couleur de l'icône ; blanc par défaut.
  final Color? color;

  /// Diamètre du rond (42 dans une liste, 36 en compact, 56 à 64 en tête).
  final double size;

  /// Éteinte : icône grise (élément vide ou désactivé).
  final bool off;

  /// Sans effet : il n'y a plus de lueur. Gardé pour compatibilité.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: off ? c.surface : c.surface2, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: off ? c.text3 : (color ?? c.text)),
    );
  }
}

/// Ancien halo de haut d'écran : désormais rien (la DA est plate). Gardé
/// pour que les écrans qui le posent compilent toujours.
class ScreenHalo extends StatelessWidget {
  const ScreenHalo({super.key, this.color, this.height = AppTokens.haloHeight, this.strength = 1});

  final Color? color;
  final double height;
  final double strength;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
