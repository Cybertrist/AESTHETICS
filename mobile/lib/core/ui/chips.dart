import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Puce de filtre : gris foncé plein au repos, texte gris ; choisie, cadre
/// blanc et texte blanc (comme la silhouette choisie dans les filtres par
/// muscle).
class ChipFilter extends StatelessWidget {
  const ChipFilter({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.onRemove,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Nombre affiché après le libellé.
  final int? count;

  /// Petite croix pour retirer le filtre.
  final VoidCallback? onRemove;

  /// Couleur du cadre et du texte quand la puce est choisie (blanc par défaut).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.text;
    final fg = selected ? col : c.text2;
    return AnimatedContainer(
      duration: AppTokens.fast,
      decoration: BoxDecoration(
        color: selected ? c.surface2 : c.surface,
        borderRadius: AppTokens.radiusPill,
        border: Border.all(color: selected ? col : Colors.transparent, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppTokens.radiusPill,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(icon == null ? 14 : 11, 6.5, onRemove == null ? 14 : 6, 6.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                // Un libellé plus large que l'écran se coupe au lieu de déborder.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, fontWeight: FontWeight.w500, color: fg, height: 1.25),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12.5, fontWeight: FontWeight.w500, color: c.text3, fontFeatures: AppTokens.tabular),
                  ),
                ],
                if (onRemove != null) ...[
                  const SizedBox(width: 2),
                  Semantics(
                    button: true,
                    label: 'Retirer $label',
                    child: InkResponse(onTap: onRemove, radius: 14, child: Icon(Icons.close_rounded, size: 16, color: fg)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rangée de puces défilante. Choix unique, ou multiple avec [multi].
class ChipFilterBar<T> extends StatelessWidget {
  const ChipFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = false,
    this.allLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
  });

  /// Valeur et libellé de chaque filtre.
  final List<(T, String)> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multi;

  /// Puce « Tout » en tête qui vide la sélection.
  final String? allLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          if (allLabel != null) ...[
            ChipFilter(label: allLabel!, selected: selected.isEmpty, onTap: () => onChanged({})),
            const SizedBox(width: 8),
          ],
          for (final (value, label) in options) ...[
            ChipFilter(
              label: label,
              selected: selected.contains(value),
              onTap: () {
                final next = Set<T>.of(selected);
                if (next.contains(value)) {
                  next.remove(value);
                } else {
                  if (!multi) next.clear();
                  next.add(value);
                }
                onChanged(next);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Sélecteur à segments : bac gris foncé en pilule, le segment choisi en
/// gris clair (par défaut) ; [accentThumb] le remplit d'accent, hors du design
/// du 2 octobre (jamais d'accent plein sur une commande).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 40,
    this.accentThumb = false,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  /// Curseur plein d'accent plutôt que gris clair.
  final bool accentThumb;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = segments.indexWhere((s) => s.$1 == value).clamp(0, segments.length - 1);
    final n = segments.length;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface, borderRadius: AppTokens.radiusPill),
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth / n;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: AppTokens.normal,
              curve: Curves.easeOutCubic,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accentThumb ? c.accent : c.surface3,
                  borderRadius: AppTokens.radiusPill,
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(segments[i].$1),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppTokens.fast,
                            style: TextStyle(
                              fontFamily: AppTokens.fontUi,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: i == index ? (accentThumb ? c.onAccent : c.text) : c.text2,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(segments[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Cases de période (1 mois / 3 mois / 1 an) : cases grises séparées, la
/// choisie en cadre blanc.
class SegmentedChips<T> extends StatelessWidget {
  const SegmentedChips({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 36,
    this.gap = 8,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Builder(builder: (context) {
              final on = segments[i].$1 == value;
              return Material(
                color: on ? c.surface2 : c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTokens.radius8,
                  side: BorderSide(color: on ? c.text : Colors.transparent, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: AppTokens.radius8,
                  onTap: () => onChanged(segments[i].$1),
                  child: SizedBox(
                    height: height,
                    child: Center(
                      child: Text(
                        segments[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.5, fontWeight: FontWeight.w500, color: on ? c.text : c.text2),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Sélecteur à flèches « ‹ Libellé › » : mois, semaine, jour. Une flèche à
/// null est grisée.
class StepSelector extends StatelessWidget {
  const StepSelector({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
    this.onTapLabel,
    this.previousTooltip = 'Précédent',
    this.nextTooltip = 'Suivant',
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Toucher le libellé (revenir à aujourd'hui, ouvrir un calendrier).
  final VoidCallback? onTapLabel;
  final String previousTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget arrow(IconData icon, VoidCallback? onTap, String tip) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: onTap == null ? c.text3.withValues(alpha: 0.5) : c.text),
        );
    return Container(
      height: 48,
      decoration: BoxDecoration(color: c.surface, borderRadius: AppTokens.radius12),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, onPrevious, previousTooltip),
          Expanded(
            child: InkWell(
              onTap: onTapLabel,
              borderRadius: AppTokens.radius8,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, fontWeight: FontWeight.w500, color: c.text),
                ),
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, onNext, nextTooltip),
        ],
      ),
    );
  }
}

/// Sélecteur de mois « ‹ Septembre 2026 › ». [month] est ramené au 1er du
/// mois ; au-delà de [last] (par défaut le mois courant), la flèche suivante
/// est grisée.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.month, required this.onChanged, this.first, this.last});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final DateTime? first;
  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final m = DateTime(month.year, month.month);
    final now = DateTime.now();
    final max = last == null ? DateTime(now.year, now.month) : DateTime(last!.year, last!.month);
    final min = first == null ? null : DateTime(first!.year, first!.month);
    final prev = DateTime(m.year, m.month - 1);
    final next = DateTime(m.year, m.month + 1);
    return StepSelector(
      label: Fmt.mois(m),
      previousTooltip: 'Mois précédent',
      nextTooltip: 'Mois suivant',
      onPrevious: min != null && prev.isBefore(min) ? null : () => onChanged(prev),
      onNext: next.isAfter(max) ? null : () => onChanged(next),
    );
  }
}
