import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

enum PillVariant {
  /// Pilule pleine d'accent (« Terminer ») : l'action principale.
  primary,

  /// Pilule gris plein #2C2C2E, texte blanc (« + Ajouter une série »).
  secondary,

  /// Pilule bordée d'un cadre fin gris, texte blanc.
  outline,

  /// Texte d'accent seul.
  ghost,

  /// Suppression, abandon : texte rouge sur gris.
  danger,
}

enum PillSize { small, medium, large }

/// Bouton pilule plat. [chevron] ajoute « › » pour un bouton qui ouvre une
/// page.
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PillVariant.primary,
    this.size = PillSize.medium,
    this.expand = false,
    this.loading = false,
    this.tooltip,
    this.chevron = false,
    this.color,
  });

  /// Pilule grise pleine, texte blanc.
  const PillButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = PillSize.medium,
    this.expand = false,
    this.loading = false,
    this.tooltip,
    this.chevron = false,
    this.color,
  }) : variant = PillVariant.secondary;

  const PillButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = PillSize.medium,
    this.expand = false,
    this.loading = false,
    this.tooltip,
    this.chevron = false,
    this.color,
  }) : variant = PillVariant.ghost;

  /// Pilule grise avec chevron (ouvre une page).
  const PillButton.link({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = PillSize.medium,
    this.expand = false,
    this.tooltip,
    this.color,
  })  : variant = PillVariant.secondary,
        trailingIcon = null,
        loading = false,
        chevron = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PillVariant variant;
  final PillSize size;

  /// Prend toute la largeur disponible.
  final bool expand;
  final bool loading;
  final String? tooltip;

  /// Chevron « › » après le libellé.
  final bool chevron;

  /// Couleur à la place de l'accent (primary et ghost) ou du texte (secondary).
  final Color? color;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null && !widget.loading;
    // Bouton sans fond : texte blanc (plus d'accent sur une commande).
    final accent = widget.color ?? c.text;
    // Le bouton principal est blanc, sauf couleur imposée.
    final plein = widget.color ?? c.bouton;
    final onPlein = widget.color == null ? c.onBouton : AccentChoice.onColorFor(plein);

    final (Color bg, Color fg, BorderSide? side) = switch (widget.variant) {
      PillVariant.primary => (plein, onPlein, null),
      PillVariant.secondary => (c.surface2, widget.color ?? c.text, null),
      PillVariant.outline => (Colors.transparent, c.text, BorderSide(color: c.frame)),
      PillVariant.ghost => (Colors.transparent, accent, null),
      PillVariant.danger => (c.surface2, c.error, null),
    };
    // Désactivé : l'accent éteint (le « Finish » bleu sombre), sinon gris.
    final disabledBg = switch (widget.variant) {
      PillVariant.primary => plein.withValues(alpha: 0.25),
      PillVariant.secondary || PillVariant.danger => c.surface,
      _ => Colors.transparent,
    };
    final disabledFg = widget.variant == PillVariant.primary ? plein.withValues(alpha: 0.55) : c.text3;

    final (double height, double padH, double font, double iconSize) = switch (widget.size) {
      PillSize.small => (34.0, 14.0, 13.5, 16.0),
      PillSize.medium => (44.0, 20.0, 15.0, 19.0),
      PillSize.large => (52.0, 26.0, 16.0, 22.0),
    };

    final color = enabled ? fg : disabledFg;
    final trailing = widget.trailingIcon ?? (widget.chevron ? Icons.chevron_right_rounded : null);
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: iconSize - 2,
            height: iconSize - 2,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: iconSize, color: color),
        if ((widget.loading || widget.icon != null) && widget.label.isNotEmpty) SizedBox(width: widget.size == PillSize.small ? 5 : 7),
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTokens.fontUi,
                fontSize: font,
                // Le bouton principal (blanc) porte un libellé en gras.
                fontWeight: widget.variant == PillVariant.primary ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          Icon(trailing, size: iconSize, color: color),
        ],
      ],
    );

    Widget button = AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: AppTokens.fast,
      curve: Curves.easeOut,
      child: Material(
        color: enabled ? bg : disabledBg,
        shape: StadiumBorder(side: side ?? BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: height),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.label.isEmpty ? 0 : padH),
              child: content,
            ),
          ),
        ),
      ),
    );

    if (widget.expand) button = SizedBox(width: double.infinity, child: button);
    if (widget.tooltip != null) button = Tooltip(message: widget.tooltip!, child: button);
    return Semantics(button: true, enabled: enabled, label: widget.label, child: button);
  }
}

/// Bouton rond à icône : plein d'accent, ou gris #2C2C2E.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.filled = true,
    this.color,
    this.iconColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  /// Plein (accent par défaut) ou gris.
  final bool filled;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = color ?? (filled ? c.bouton : c.surface2);
    final fg = iconColor ?? (filled && color == null ? c.onBouton : c.text);
    final btn = Material(
      color: onPressed == null ? c.surface : bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: onPressed == null ? c.text3 : fg),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
