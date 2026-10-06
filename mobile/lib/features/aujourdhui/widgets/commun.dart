import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/ui/body/body_map.dart';

/// Couleurs des macros, reprises partout dans le module.
abstract final class CouleursMacros {
  static Color proteines(BuildContext c) => c.colors.heart;
  static Color glucides(BuildContext c) => c.colors.weight;
  static Color lipides(BuildContext c) => c.colors.sleep;
  static Color eau(BuildContext c) => c.colors.coach;
}

/// Chevron discret à droite d'une étiquette de carte qui ouvre une page.
class ChevronCarte extends StatelessWidget {
  const ChevronCarte({super.key, this.texte});
  final String? texte;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (texte != null)
          Text(texte!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12, fontWeight: FontWeight.w600, color: c.text3)),
        Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
      ],
    );
  }
}

/// Vignette d'un exercice sur fond gris arrondi (les images ont un fond
/// transparent), jamais étirée.
class MiniatureExercice extends StatelessWidget {
  const MiniatureExercice({super.key, required this.exercise, this.size = 44});

  final Exercise? exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final src = exercise?.media.thumbnail;
    final fallback = Icon(Icons.fitness_center_rounded, size: size * 0.45, color: const Color(0xFF8A8A8A));
    Widget img;
    if (src == null) {
      img = fallback;
    } else if (src.startsWith('http')) {
      img = CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => fallback,
        placeholder: (_, _) => const SizedBox.shrink(),
      );
    } else {
      img = Image.asset(src, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback);
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(color: context.colors.surface2, borderRadius: BorderRadius.circular(size * 0.26)),
      clipBehavior: Clip.antiAlias,
      child: Center(child: img),
    );
  }
}

/// Barres verticales simples sur quelques jours (sommeil, pas, volume).
/// La barre [surlignee] prend la couleur pleine, les autres un voile.
class BarresJours extends StatelessWidget {
  const BarresJours({
    super.key,
    required this.valeurs,
    required this.libelles,
    this.couleur,
    this.hauteur = 120,
    this.surlignee,
    this.objectif,
    this.etiquettes,
  });

  final List<double?> valeurs;
  final List<String> libelles;
  final Color? couleur;
  final double hauteur;
  final int? surlignee;

  /// Trait horizontal pointillé à cette valeur.
  final double? objectif;

  /// Petit texte au-dessus de chaque barre.
  final List<String>? etiquettes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = couleur ?? c.accent;
    final max = [...valeurs.whereType<double>(), objectif ?? 0, 1.0].reduce((a, b) => a > b ? a : b) * 1.1;
    final lblStyle = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11, fontWeight: FontWeight.w700, color: c.text3);
    return SizedBox(
      height: hauteur + 38,
      child: Stack(
        children: [
          if (objectif != null && objectif! > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 16 + hauteur * (1 - objectif! / max),
              child: CustomPaint(size: const Size(double.infinity, 1), painter: _Pointilles(c.text3.withValues(alpha: 0.6))),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < valeurs.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (etiquettes != null)
                        Text(etiquettes![i], maxLines: 1, style: lblStyle.copyWith(fontSize: 10, color: i == surlignee ? c.text : c.text3)),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (valeurs[i] ?? 0) / max),
                        duration: AppTokens.slow,
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Container(
                          width: 18,
                          height: valeurs[i] == null ? 4 : (hauteur * v).clamp(4.0, hauteur),
                          decoration: BoxDecoration(
                            color: valeurs[i] == null
                                ? AppTokens.veil2
                                : (surlignee == null || i == surlignee ? col : col.withValues(alpha: 0.45)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(libelles[i], style: lblStyle.copyWith(color: i == surlignee ? c.text : c.text3)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pointilles extends CustomPainter {
  _Pointilles(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Pointilles old) => old.color != color;
}

/// « Lundi 29 sept. » court pour les listes.
String jourCourt(DateTime d) => Fmt.relatif(d);

/// Personnage face et dos à [height] au plus, réduit si la largeur manque
/// (jamais déformé, toujours touchable).
class CorpsDouble extends StatelessWidget {
  const CorpsDouble({super.key, this.intensities = const {}, required this.height, this.onTap, this.labels = false, this.spacing = 8});

  final Map<Muscle, double> intensities;
  final double height;
  final ValueChanged<Muscle>? onTap;
  final bool labels;
  final double spacing;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: BodyMapDual(intensities: intensities, height: height, onTap: onTap, labels: labels, spacing: spacing),
      );
}

/// `SubPageScaffold` dont la barre d'action est posée sous le contenu :
/// contourne le bogue connu de `SubPageScaffold(bottomBar:)` (voir
/// COORDINATION). Une fois le noyau corrigé, revenir à `SubPageScaffold`.
class SousPage extends StatelessWidget {
  const SousPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.haloColor,
    this.actions = const [],
    this.maxContentWidth = 760,
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final Color? haloColor;
  final List<Widget> actions;
  final double maxContentWidth;
  final Widget? bottomBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SubPageScaffold(
      title: title,
      subtitle: subtitle,
      haloColor: haloColor,
      actions: actions,
      maxContentWidth: maxContentWidth,
      body: bottomBar == null
          ? body
          : Column(
              children: [
                Expanded(child: body),
                DecoratedBox(
                  decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: bottomBar,
                  ),
                ),
              ],
            ),
    );
  }
}
