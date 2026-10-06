import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'section_header.dart';

/// Carte plate : fond #1C1C1E sur le noir, coins de 12, ni ombre ni
/// bordure. Plus claire : `color: c.surface2` (#2C2C2E).
/// Avec [label], la carte commence par une étiquette en petites capitales
/// grise et [labelTrailing] à droite.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.color,
    this.border = false,
    this.borderColor,
    this.radius = AppTokens.r12,
    this.gradient,
    this.width,
    this.height,
    this.label,
    this.labelTrailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Fond ; par défaut surface (#1C1C1E).
  final Color? color;

  /// Filet autour de la carte.
  final bool border;
  final Color? borderColor;
  final double radius;
  final Gradient? gradient;
  final double? width;
  final double? height;

  /// Étiquette grise en tête de carte (« Volume »).
  final String? label;

  /// À droite de l'étiquette (compte discret, lien d'accent).
  final Widget? labelTrailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border || borderColor != null ? BorderSide(color: borderColor ?? c.line) : BorderSide.none,
    );
    final content = label == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionLabel(label!, trailing: labelTrailing),
              const SizedBox(height: 12),
              child,
            ],
          );
    Widget inner = Padding(padding: padding, child: content);
    if (onTap != null || onLongPress != null) {
      inner = InkWell(onTap: onTap, onLongPress: onLongPress, child: inner);
    }
    final card = Material(
      color: gradient == null ? (color ?? c.surface) : Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: gradient == null
          ? inner
          : Ink(decoration: ShapeDecoration(shape: shape, gradient: gradient), child: inner),
    );
    return Container(margin: margin, width: width, height: height, child: card);
  }
}
