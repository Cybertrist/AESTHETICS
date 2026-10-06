import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Un onglet de [IconTabBar].
class IconTab<T> {
  const IconTab(this.value, this.label, this.icon);
  final T value;
  final String label;
  final IconData icon;
}

/// Onglets du haut : icône au-dessus du libellé, l'actif en blanc souligné
/// d'un trait blanc, les autres en gris, un filet sous la rangée. Se pose
/// aussi dans `AppScaffold(bottom: ...)`.
class IconTabBar<T> extends StatelessWidget implements PreferredSizeWidget {
  const IconTabBar({super.key, required this.tabs, required this.value, required this.onChanged});

  final List<IconTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.surface))),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab.value == value,
                child: InkWell(
                  onTap: () => onChanged(tab.value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(tab.icon, size: 26, color: tab.value == value ? c.text : c.text2),
                      const SizedBox(height: 4),
                      IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tab.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTokens.fontUi,
                                fontSize: 15,
                                fontWeight: tab.value == value ? FontWeight.w500 : FontWeight.w400,
                                color: tab.value == value ? c.text : c.text2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            AnimatedContainer(
                              duration: AppTokens.fast,
                              height: 3,
                              decoration: BoxDecoration(
                                color: tab.value == value ? c.text : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vignette d'exercice en tête de ligne : carte grise arrondie portrait
/// (les images ont un fond transparent), l'image contenue sans déformation,
/// un petit « ? » gris dans le coin.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, this.image, this.width = 48, this.height = 72, this.help = true});

  /// Image de l'exercice (réseau, fichier ou asset) ; sans image, une icône.
  final ImageProvider? image;
  final double width;
  final double height;

  /// Petit « ? » en bas à droite.
  final bool help;

  @override
  Widget build(BuildContext context) {
    final gris = context.colors.text2;
    // Décodée à la taille affichée : les poses font 720 px de côté, soit 2 Mo
    // en mémoire chacune pour une vignette de 48 points.
    final largeur = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: context.colors.surface2, borderRadius: BorderRadius.circular(5)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: image == null
                ? Icon(Icons.fitness_center_rounded, color: gris, size: 22)
                : Image(image: ResizeImage.resizeIfNeeded(largeur, null, image!), fit: BoxFit.contain, filterQuality: FilterQuality.medium),
          ),
          if (help)
            Positioned(
              right: 3,
              bottom: 1,
              child: Text('?', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 10, color: gris)),
            ),
        ],
      ),
    );
  }
}

/// Carte d'exercice pour la grille à deux colonnes : grande image sur fond
/// gris #2C2C2E, signet en haut à gauche, « ? » en haut à droite, nom et
/// muscle dessous. Dans une grille : `gridDelegate: ExerciseCard.gridDelegate`.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.bookmarked = false,
    this.onBookmark,
    this.onHelp,
    this.onTap,
    this.selected = false,
  });

  final String title;

  /// Muscle principal (« Pectoraux »).
  final String? subtitle;

  /// Visuel de l'exercice (en général un `Image` en `BoxFit.contain`).
  final Widget? image;
  final bool bookmarked;
  final VoidCallback? onBookmark;
  final VoidCallback? onHelp;
  final VoidCallback? onTap;

  /// Choisi (ajout de plusieurs exercices) : cadre blanc et coche.
  final bool selected;

  /// Deux colonnes, cartes un peu plus hautes que larges.
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.74,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: selected ? BorderSide(color: c.text, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
                      child: image ?? Icon(Icons.fitness_center_rounded, size: 48, color: c.text3),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 2,
                    child: IconButton(
                      tooltip: bookmarked ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      onPressed: onBookmark,
                      icon: Icon(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: bookmarked ? c.text : c.text2, size: 24),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: selected
                        ? const Padding(padding: EdgeInsets.all(10), child: CheckBadge(size: 26))
                        : IconButton(
                            tooltip: 'Aide',
                            onPressed: onHelp,
                            icon: Text('?', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 20, color: c.text2)),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coche noire dans une pastille blanche (sélection).
class CheckBadge extends StatelessWidget {
  const CheckBadge({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: size * 0.66, color: Colors.black),
      );
}

/// Choix par cercle (« Focus Area », matériel) : image ronde, cercle blanc
/// et coche dans une pastille blanche quand c'est choisi, libellé dessous.
class SelectCircle extends StatelessWidget {
  const SelectCircle({super.key, required this.child, required this.selected, required this.onTap, this.label, this.size = 104});

  /// Image anatomique ou de matériel (contenue).
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: AppTokens.fast,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? c.text : Colors.transparent, width: 2),
                      ),
                      child: ClipOval(child: Padding(padding: EdgeInsets.all(size * 0.06), child: child)),
                    ),
                  ),
                  if (selected)
                    Positioned(right: size * 0.02, top: size * 0.02, child: CheckBadge(size: size * 0.24)),
                ],
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 17, fontWeight: FontWeight.w500, color: c.text)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Case choisie par un cadre blanc arrondi (filtre par muscle en silhouette,
/// en tête de la liste d'exercices).
class SelectSquare extends StatelessWidget {
  const SelectSquare({super.key, required this.child, required this.selected, required this.onTap, this.size = 64, this.tooltip});

  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final box = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: AppTokens.radius8,
          border: Border.all(color: selected ? context.colors.text : Colors.transparent, width: 1.5),
        ),
        child: child,
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip!, child: box);
  }
}

/// Encadré de résumé aux bords fins (Durée / Volume / Séries) : libellés
/// gris centrés, valeurs blanches dessous (une valeur peut être à l'accent,
/// comme le chrono).
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.items, this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 8)});

  /// Libellé, valeur, couleur de la valeur (blanc par défaut).
  final List<(String, String, Color?)> items;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(borderRadius: AppTokens.radius12, border: Border.all(color: c.frame)),
      child: Row(
        children: [
          for (final (label, value, color) in items)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, maxLines: 1, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(value, maxLines: 1, style: AppType.number(16, weight: FontWeight.w500, color: color ?? c.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Largeurs relatives des colonnes du tableau des séries.
const _setFlex = [10, 24, 16, 16, 10];

/// En-tête du tableau des séries : SET / PREVIOUS / KG / REPS en petites
/// capitales grises.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({
    super.key,
    this.labels = const ['SÉRIE', 'PRÉCÉDENT', 'KG', 'REPS'],
    this.padding = const EdgeInsets.symmetric(horizontal: AppTokens.gutter, vertical: 8),
  });

  final List<String> labels;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final st = AppType.overline(color: context.colors.text2).copyWith(fontSize: 11);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < 4 && i < labels.length; i++)
            Expanded(
              flex: _setFlex[i],
              child: Text(labels[i], textAlign: i < 2 ? TextAlign.left : TextAlign.center, style: st),
            ),
          Expanded(flex: _setFlex[4], child: const SizedBox()),
        ],
      ),
    );
  }
}

/// Ligne d'une série : numéro à l'accent, précédent en gris, charge et
/// répétitions, coche ronde à droite. Validée : fond vert très sombre et
/// coche verte pleine. Les valeurs peuvent être des champs ([weightField],
/// [repsField]) à la place du texte.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.label,
    this.previous = '',
    this.weight = '',
    this.reps = '',
    this.done = false,
    this.onToggle,
    this.weightField,
    this.repsField,
    this.labelColor,
    this.hint = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
    this.height = 52,
  });

  /// Numéro de la série (« 1 ») ou lettre (« É » pour échauffement).
  final String label;
  final String previous;
  final String weight;
  final String reps;
  final bool done;
  final VoidCallback? onToggle;
  final Widget? weightField;
  final Widget? repsField;

  /// Couleur du numéro ; accent par défaut.
  final Color? labelColor;

  /// Valeurs grisées (reprises de la dernière fois, pas encore saisies).
  final bool hint;
  final EdgeInsetsGeometry padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final valueStyle = AppType.number(17, weight: FontWeight.w500, color: hint && !done ? c.text3 : c.text);
    return AnimatedContainer(
      duration: AppTokens.fast,
      height: height,
      color: done ? c.setDone : Colors.transparent,
      padding: padding,
      child: Row(
        children: [
          Expanded(
            flex: _setFlex[0],
            child: Text(label, style: AppType.number(17, weight: FontWeight.w500, color: labelColor ?? c.accent)),
          ),
          Expanded(
            flex: _setFlex[1],
            child: Text(previous, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13.5)),
          ),
          Expanded(flex: _setFlex[2], child: Center(child: weightField ?? Text(weight, style: valueStyle))),
          Expanded(flex: _setFlex[3], child: Center(child: repsField ?? Text(reps, style: valueStyle))),
          Expanded(
            flex: _setFlex[4],
            child: Align(
              alignment: Alignment.centerRight,
              child: SetCheck(done: done, onTap: onToggle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coche ronde d'une série : verte pleine quand elle est faite, grise sinon.
class SetCheck extends StatelessWidget {
  const SetCheck({super.key, required this.done, this.onTap, this.size = 34});

  final bool done;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Série faite' : 'Valider la série',
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.8,
        child: AnimatedContainer(
          duration: AppTokens.fast,
          width: size,
          height: size * 0.82,
          decoration: BoxDecoration(color: done ? c.check : c.surface2, borderRadius: BorderRadius.circular(size)),
          child: Icon(Icons.check_rounded, size: size * 0.6, color: done ? Colors.white : c.text3),
        ),
      ),
    );
  }
}

/// Barre de volume d'un muscle : vignette à gauche, nom, barre rouge rosée
/// avec sa valeur (« 4 080kg »), puis une barre grise avec le nombre de
/// séries.
class MuscleBar extends StatelessWidget {
  const MuscleBar({
    super.key,
    required this.name,
    required this.value,
    required this.valueLabel,
    this.secondary,
    this.secondaryLabel,
    this.leading,
    this.color,
    this.large = false,
    this.onTap,
  });

  final String name;

  /// Part de la barre rouge, 0..1.
  final double value;
  final String valueLabel;

  /// Part de la barre grise (séries), 0..1 ; masquée si nulle.
  final double? secondary;
  final String? secondaryLabel;

  /// Vignette anatomique (`BodyMap` réduit, image).
  final Widget? leading;
  final Color? color;

  /// Version mise en avant (barres plus épaisses, texte plus grand).
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = large ? 16.0 : 12.0;
    final fs = large ? 17.0 : 14.5;
    final labelW = large ? 90.0 : 74.0;
    // La valeur suit le bout de la barre, comme sur la référence.
    Widget bar(double v, Color col, String text, Color textColor) => LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              Container(
                width: math.max(h, (box.maxWidth - labelW - 8) * v.clamp(0.0, 1.0)),
                height: h,
                decoration: BoxDecoration(color: col, borderRadius: AppTokens.radiusPill),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: AppType.number(fs - 1, weight: FontWeight.w400, color: textColor))),
            ],
          ),
        );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[SizedBox(width: large ? 72 : 60, height: large ? 72 : 60, child: leading), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: fs + 1)),
                  const SizedBox(height: 6),
                  bar(value, color ?? c.muscleBar, valueLabel, c.text2),
                  if (secondary != null) ...[
                    const SizedBox(height: 6),
                    bar(secondary!, c.surface3, secondaryLabel ?? '', c.text2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La semaine en pastilles : un rond d'accent avec un haltère les jours
/// d'entraînement, un point gris les autres, le jour dessous.
class WeekDots extends StatelessWidget {
  const WeekDots({super.key, required this.days, this.size = 38, this.icon = Icons.fitness_center_rounded});

  /// Libellé court (« Lun ») et jour d'entraînement ou non.
  final List<(String, bool)> days;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final (label, on) in days)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: on
                    ? Container(
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                        child: Icon(icon, size: size * 0.55, color: c.onAccent),
                      )
                    : Center(
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle)),
                      ),
              ),
              const SizedBox(height: 6),
              Text(label, style: AppType.rowSubtitle(color: c.text2)),
            ],
          ),
      ],
    );
  }
}

/// Graphique en barres plates de l'accent, avec lignes de repère fines et
/// graduations à gauche (0, 20k, 40k).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    this.height = 220,
    this.color,
    this.gridLines = 2,
    this.formatAxis,
    this.labels,
  });

  final List<double> values;
  final double height;
  final Color? color;

  /// Nombre de lignes de repère au-dessus de zéro.
  final int gridLines;

  /// Texte d'une graduation (par défaut 20k, 40k...).
  final String Function(double)? formatAxis;

  /// Libellés sous les barres (facultatifs).
  final List<String>? labels;

  static String _k(double v) => v >= 1000 ? '${(v / 1000).round()}k' : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chart = SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarsPainter(
          values: values,
          color: color ?? c.accent,
          grid: c.surface3,
          axis: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 12),
          lines: gridLines,
          format: formatAxis ?? _k,
        ),
      ),
    );
    if (labels == null) return chart;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        chart,
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Row(
            children: [
              for (final l in labels!)
                Expanded(child: Text(l, textAlign: TextAlign.center, maxLines: 1, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.values, required this.color, required this.grid, required this.axis, required this.lines, required this.format});

  final List<double> values;
  final Color color;
  final Color grid;
  final TextStyle axis;
  final int lines;
  final String Function(double) format;

  double _nice(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (m * p >= v) return m * p;
    }
    return 10 * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    final step = _nice(maxV / (lines + 0.3));
    final top = step * (lines + 0.3);
    final h = size.height;
    final linePaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= lines; i++) {
      final v = step * i;
      final y = h - v / top * h;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), linePaint);
      final tp = TextPainter(text: TextSpan(text: format(v), style: axis), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    if (values.isEmpty) return;
    final w = (size.width - left) / values.length;
    final gap = w * 0.12;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final bh = (values[i] / top * h).clamp(0.0, h);
      final r = Rect.fromLTWH(left + i * w + gap / 2, h - bh, w - gap, bh);
      canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.values != values || o.color != color;
}
