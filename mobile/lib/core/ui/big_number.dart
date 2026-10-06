import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Le grand chiffre d'un écran (« 197 248kg ») : une
/// ligne grise au-dessus (« Volume »), le chiffre en Roboto gras, l'unité
/// collée, une ligne grise dessous (période, variation).
class BigNumber extends StatelessWidget {
  const BigNumber({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.caption,
    this.size = 36,
    this.color,
    this.captionColor,
    this.footer,
  });

  final String value;
  final String? unit;

  /// Ligne grise au-dessus du chiffre.
  final String? label;

  /// Ligne sous le chiffre (« +2,5 kg ce mois-ci »).
  final String? caption;

  /// 32 à 40 en tête d'écran.
  final double size;
  final Color? color;

  /// Accent pour une bonne nouvelle, gris par défaut.
  final Color? captionColor;

  /// Sous la légende (une étiquette pilule, une jauge).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 17, fontWeight: FontWeight.w400, color: c.text2)),
          const SizedBox(height: 8),
        ],
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.number(size, color: color)),
              if (unit != null) ...[
                const SizedBox(width: 1),
                Text(unit!, style: AppType.number(size, color: color ?? c.text)),
              ],
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, fontWeight: FontWeight.w400, color: captionColor ?? c.text2),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: 10), footer!],
      ],
    );
  }
}

/// Titre d'un volet sur le Fold déplié :
/// petites capitales discrètes toujours présentes (pour que les titres des
/// volets voisins tombent à la même hauteur), puis le titre en 26 très gras,
/// et un montant éventuel à droite.
class PaneTitle extends StatelessWidget {
  const PaneTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(24, 10, 24, 12),
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (eyebrow ?? '').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.overline(color: context.colors.text3),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.screenTitle())),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ],
        ),
      );
}
