import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_card.dart';

/// Tuile de statistique : étiquette grise, grand chiffre Roboto gras,
/// unité, variation.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.delta,
    this.deltaPositive,
    this.caption,
    this.onTap,
    this.compact = false,
    this.color,
    this.footer,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;

  /// Variation affichée sous le chiffre (« +2,5 kg »).
  final String? delta;

  /// Sens de la variation : vrai = bon signe (accent), faux = discret, null = neutre.
  final bool? deltaPositive;
  final String? caption;
  final VoidCallback? onTap;
  final bool compact;

  /// Couleur de l'icône ; accent par défaut.
  final Color? color;

  /// Élément sous le chiffre (sparkline, barre).
  final Widget? footer;

  /// Couleur du chiffre (accent pour un reste, domaine...) ; blanc par défaut.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    final accent = color ?? c.accent;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: c.text2)),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppType.number(compact ? 24 : 30, color: valueColor)),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: t.bodyMedium?.copyWith(color: c.text2, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deltaPositive != null)
                  Icon(
                    deltaPositive! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: deltaPositive! ? accent : c.text3,
                  ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    delta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelMedium?.copyWith(color: deltaPositive == true ? accent : c.text3),
                  ),
                ),
              ],
            ),
          ],
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.text3)),
          ],
          if (footer != null) ...[const SizedBox(height: AppTokens.s12), footer!],
        ],
      ),
    );
  }
}
