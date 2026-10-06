import 'package:flutter/material.dart';

/// Largeurs de référence : écran externe du Fold (étroit), écran interne (large).
abstract final class Breakpoints {
  static const compact = 600.0;
  static const expanded = 840.0;

  /// Largeur maximale du contenu d'une page sur grand écran.
  static const content = 760.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < Breakpoints.compact;
  bool get isWide => screenWidth >= Breakpoints.compact;
  bool get isExpanded => screenWidth >= Breakpoints.expanded;

  /// Nombre de colonnes conseillé pour une grille de cartes.
  int gridColumns({double minTileWidth = 160}) =>
      (screenWidth / minTileWidth).floor().clamp(2, 6);
}

/// Centre le contenu et limite sa largeur sur grand écran.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Breakpoints.content});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Version sliver de [ContentWidth].
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({super.key, required this.sliver, this.maxWidth = Breakpoints.content});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final extra = (constraints.crossAxisExtent - maxWidth).clamp(0.0, double.infinity) / 2;
      return SliverPadding(padding: EdgeInsets.symmetric(horizontal: extra), sliver: sliver);
    });
  }
}
