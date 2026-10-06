import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'halo.dart';

/// Icône de début de ligne. Rendu `IconHalo` (rond gris plat)
/// sauf avec [background] ou [circle] : pastille de la couleur donnée.
/// Pour du code neuf, préférer `IconHalo` directement.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color, this.background, this.size = 42, this.circle = false});

  final IconData icon;

  /// Couleur de l'icône ; par défaut l'accent.
  final Color? color;
  final Color? background;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (background == null && !circle) return IconHalo(icon: icon, color: color, size: size);
    final c = context.colors;
    final fg = color ?? c.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.14),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// Ligne de liste : vignette ou icône, titre blanc, sous-titre gris
/// (« 0/3 Done »), valeur à droite en chiffres tabulaires, chevron discret.
class ListTileX extends StatelessWidget {
  const ListTileX({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = false,
    this.dense = false,
    this.selected = false,
    this.enabled = true,
    this.padding,
    this.titleStyle,
    this.subtitleMaxLines = 2,
    this.value,
    this.valueColor,
    this.subtitleColor,
  });

  /// Marges à passer dans une `AppCard` (qui a déjà les siennes).
  static const cardPadding = EdgeInsets.symmetric(vertical: 10);

  final String title;
  final String? subtitle;

  /// Vignette d'exercice (`ExerciseThumbnail`) ou `IconHalo`.
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Chevron à droite, pour une ligne qui ouvre une page.
  final bool showChevron;
  final bool dense;

  /// Surlignée (détail ouvert dans le volet voisin sur le Fold).
  final bool selected;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final int subtitleMaxLines;

  /// Valeur à droite (« 1 284 kg », « 7 h 32 »), gras et tabulaire.
  final String? value;
  final Color? valueColor;

  /// Couleur du sous-titre (accent pour « 14 sept. · record »).
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vpad = dense ? 8.0 : 11.0;
    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle ?? AppType.rowTitle().copyWith(fontSize: dense ? 15 : 16),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowSubtitle(color: subtitleColor),
                ),
              ],
            ],
          ),
        ),
        if (value != null) ...[const SizedBox(width: 12), Text(value!, style: AppType.rowValue(color: valueColor))],
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (showChevron) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: c.text3, size: 20),
        ],
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: AnimatedContainer(
          duration: AppTokens.normal,
          decoration: BoxDecoration(
            color: selected ? c.surface2 : Colors.transparent,
            border: null,
            borderRadius: AppTokens.radius14,
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: padding ?? EdgeInsets.symmetric(horizontal: AppTokens.gutter, vertical: vpad),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

/// Étiquette pilule teintée plate (« Record », « 6 séries à faire › »).
/// Avec [onTap], elle devient un lien avec chevron.
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key, this.color, this.icon, this.solid = false, this.onTap, this.large = false});

  final String label;
  final Color? color;
  final IconData? icon;

  /// Fond plein plutôt que teinté.
  final bool solid;

  /// Rend l'étiquette touchable, avec un chevron.
  final VoidCallback? onTap;

  /// Plus grande (13).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.accent;
    final fg = solid ? c.onAccent : col;
    final fs = large ? 13.0 : 11.0;
    final pill = Container(
      padding: large ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7) : const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? col : col.withValues(alpha: 0.16),
        borderRadius: AppTokens.radiusPill,
        border: null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: fs + 3, color: fg), SizedBox(width: large ? 7 : 4)],
          Text(
            label,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: fs, fontWeight: FontWeight.w500, color: fg, height: 1.2),
          ),
          if (onTap != null) ...[const SizedBox(width: 2), Icon(Icons.chevron_right_rounded, size: fs + 3, color: fg)],
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(onTap: onTap, borderRadius: AppTokens.radiusPill, child: pill);
  }
}

/// Groupe de lignes dans une carte #1C1C1E aux coins 12, séparées par un
/// filet #2C2C2E (style réglages). [label] ajoute une étiquette grise en tête.
class TileGroup extends StatelessWidget {
  const TileGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
    this.label,
    this.labelTrailing,
    this.dividers = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  /// Étiquette grise en tête de carte.
  final String? label;
  final Widget? labelTrailing;

  /// Filets entre les lignes.
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = <Widget>[];
    if (label != null) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 14, AppTokens.gutter, 4),
        child: Row(
          children: [
            Expanded(child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 15))),
            ?labelTrailing,
          ],
        ),
      ));
    }
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && dividers) items.add(Divider(height: 1, indent: AppTokens.gutter, endIndent: AppTokens.gutter, color: c.line));
      items.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: Material(
        color: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
        ),
      ),
    );
  }
}
