import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Titre de section (« Popular Programs », « Équipement ») : blanc, 18,
/// medium, en casse normale, avec à droite une action texte d'accent
/// (« Tout voir ») ou un élément libre. Avec [large], 22.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel = 'Tout voir',
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppTokens.gutter, AppTokens.s24, AppTokens.s8, AppTokens.s12),
    this.large = false,
    this.actionIcon,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;

  /// Sans callback, pas d'action affichée.
  final VoidCallback? onAction;

  /// Remplace l'action texte (icône, menu, compte discret...).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Titre plus grand (22).
  final bool large;

  /// Icône devant l'action (Icons.add_rounded pour « + Ajouter »).
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: (large ? t.headlineSmall : t.titleLarge)?.copyWith(fontSize: large ? 22 : 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: t.bodySmall?.copyWith(color: c.text2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onAction != null)
            AccentLink(label: actionLabel, icon: actionIcon, onTap: onAction!),
        ],
      ),
    );
  }
}

/// Étiquette grise en tête de carte (« Volume », « All Exercises »), avec un
/// élément à droite (compte discret, lien d'accent, icône).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, fontWeight: FontWeight.w400, color: color ?? context.colors.text2),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Petit texte discret à droite d'une étiquette (« 3 séances »).
class LabelCount extends StatelessWidget {
  const LabelCount(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.rowSubtitle(color: context.colors.text3).copyWith(fontSize: 13));
}

/// Lien texte (« Tout voir », « + Ajouter »), sans fond : blanc, comme les
/// liens de la maquette (« Voir plus », « Historique »).
class AccentLink extends StatelessWidget {
  const AccentLink({super.key, required this.label, required this.onTap, this.icon, this.color});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.radiusPill,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: col), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, fontWeight: FontWeight.w600, color: col)),
          ],
        ),
      ),
    );
  }
}
