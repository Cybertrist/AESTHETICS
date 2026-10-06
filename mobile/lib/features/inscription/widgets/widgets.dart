import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Titre d'une étape : grande question et petite phrase d'aide.
class StepTitle extends StatelessWidget {
  const StepTitle({super.key, required this.title, this.subtitle, this.eyebrow});

  final String title;
  final String? subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 8, AppTokens.gutter + 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(), style: AppType.overline(color: context.colors.text2)),
            const SizedBox(height: 8),
          ],
          Text(title, style: AppType.screenTitle().copyWith(fontSize: 28, height: 1.15)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppType.rowSubtitle().copyWith(fontSize: 14.5, height: 1.4, color: AppTokens.text2)),
          ],
        ],
      ),
    );
  }
}

/// Carte de choix : icône à halo, titre, description, pastille cochée.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multi = false,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// Case carrée (choix multiple) plutôt que rond.
  final bool multi;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppTokens.radius16,
          border: Border.all(color: selected ? c.text : Colors.transparent, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppTokens.radius16,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    IconHalo(icon: icon!, size: 42),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppType.rowTitle()),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: AppType.rowSubtitle()),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                  const SizedBox(width: 10),
                  _Coche(selected: selected, multi: multi),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Coche extends StatelessWidget {
  const _Coche({required this.selected, required this.multi});
  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppTokens.fast,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? c.text : Colors.transparent,
        shape: multi ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multi ? BorderRadius.circular(7) : null,
        border: Border.all(color: selected ? c.text : c.text3.withValues(alpha: 0.6), width: 1.6),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 16, color: c.bg) : null,
    );
  }
}

/// Grille de cartes de choix : une colonne sur le Fold fermé, deux s'il y a la place.
class OptionGrid extends StatelessWidget {
  const OptionGrid({super.key, required this.children, this.minWidth = 300});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / minWidth).floor().clamp(1, 2);
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Règle horizontale graduée qui défile sous un repère fixe.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.majorEvery = 10,
    this.labelOf,
    this.spacing = 11,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  /// Une grande graduation (avec son chiffre) toutes les [majorEvery] petites.
  final int majorEvery;
  final String Function(double v)? labelOf;
  final double spacing;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late ScrollController _ctrl;
  double? _dernier;

  int get _count => ((widget.max - widget.min) / widget.step).round() + 1;
  double _offsetDe(double v) => ((v.clamp(widget.min, widget.max) - widget.min) / widget.step).round() * widget.spacing;
  double _valeurDe(double off) {
    final i = (off / widget.spacing).round().clamp(0, _count - 1);
    return double.parse((widget.min + i * widget.step).toStringAsFixed(3));
  }

  @override
  void initState() {
    super.initState();
    _dernier = widget.value;
    _ctrl = ScrollController(initialScrollOffset: _offsetDe(widget.value));
    _ctrl.addListener(_surDefilement);
  }

  @override
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    final change = old.min != widget.min || old.step != widget.step || old.max != widget.max;
    if ((change || (widget.value - (_dernier ?? widget.value)).abs() > widget.step / 2) && _ctrl.hasClients) {
      _dernier = widget.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) _ctrl.jumpTo(_offsetDe(widget.value));
      });
    }
  }

  void _surDefilement() {
    final v = _valeurDe(_ctrl.offset);
    if (v != _dernier) {
      _dernier = v;
      HapticFeedback.selectionClick();
      widget.onChanged(v);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 92,
      child: LayoutBuilder(builder: (context, box) {
        final demi = box.maxWidth / 2;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.18, 0.82, 1],
              ).createShader(r),
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  final cible = _offsetDe(_valeurDe(_ctrl.offset));
                  if ((cible - _ctrl.offset).abs() > 0.5) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_ctrl.hasClients) _ctrl.animateTo(cible, duration: AppTokens.fast, curve: Curves.easeOut);
                    });
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: demi),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size((_count - 1) * widget.spacing, 92),
                      painter: _RulerPainter(
                        count: _count,
                        spacing: widget.spacing,
                        majorEvery: widget.majorEvery,
                        labelOf: (i) => widget.labelOf?.call(widget.min + i * widget.step) ?? _fmt(widget.min + i * widget.step),
                        tick: c.text3,
                        major: c.text2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: 3,
                height: 54,
                decoration: BoxDecoration(color: c.text, borderRadius: AppTokens.radiusPill),
              ),
            ),
          ],
        );
      }),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.count,
    required this.spacing,
    required this.majorEvery,
    required this.labelOf,
    required this.tick,
    required this.major,
  });

  final int count;
  final double spacing;
  final int majorEvery;
  final String Function(int i) labelOf;
  final Color tick;
  final Color major;

  @override
  void paint(Canvas canvas, Size size) {
    final pMinor = Paint()
      ..color = tick.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final pMid = Paint()
      ..color = tick
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final pMajor = Paint()
      ..color = major
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = i * spacing;
      final isMajor = i % majorEvery == 0;
      final isMid = !isMajor && majorEvery % 2 == 0 && i % (majorEvery ~/ 2) == 0;
      final h = isMajor ? 40.0 : (isMid ? 28.0 : 18.0);
      canvas.drawLine(Offset(x, 6), Offset(x, 6 + h), isMajor ? pMajor : (isMid ? pMid : pMinor));
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: labelOf(i),
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, fontWeight: FontWeight.w700, color: major, fontFeatures: AppTokens.tabular),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 56));
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.count != count || old.spacing != spacing || old.majorEvery != majorEvery || old.tick != tick || old.major != major;
}

/// Roue verticale façon sélecteur de date, aux couleurs de l'appli.
class WheelColumn extends StatelessWidget {
  const WheelColumn({
    super.key,
    required this.controller,
    required this.items,
    required this.onChanged,
    this.width,
  });

  final FixedExtentScrollController controller;
  final List<String> items;
  final ValueChanged<int> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: width,
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 44,
        diameterRatio: 1.4,
        squeeze: 1.05,
        useMagnifier: true,
        magnification: 1.12,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onChanged(i);
        },
        childCount: items.length,
        itemBuilder: (context, i) => Center(
          child: Text(
            items[i],
            style: TextStyle(
              fontFamily: AppTokens.fontUi,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: c.text,
              fontFeatures: AppTokens.tabular,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grand chiffre centré avec son unité, touchable pour une saisie au clavier.
class HeroValue extends StatelessWidget {
  const HeroValue({super.key, required this.value, this.unit, this.caption, this.onTap});

  final String value;
  final String? unit;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: '$value ${unit ?? ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: AppType.number(56)),
                  if (unit != null) ...[
                    const SizedBox(width: 6),
                    Text(unit!, style: AppType.rowTitle(color: c.text2).copyWith(fontSize: 20)),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.edit_rounded, size: 16, color: c.text3),
                  ],
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!, textAlign: TextAlign.center, style: AppType.rowSubtitle()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit encart d'information gris, icône à halo.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface2, borderRadius: AppTokens.radius14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHalo(icon: icon, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13, height: 1.45))),
        ],
      ),
    );
  }
}

/// Choix rond façon « zone ciblée » : image dans un cercle, anneau blanc
/// et pastille cochée quand il est choisi.
class RoundChoice extends StatelessWidget {
  const RoundChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.size = 96,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
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
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(child: child),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: size * 0.02,
                      top: size * 0.02,
                      child: Container(
                        width: size * 0.26,
                        height: size * 0.26,
                        decoration: BoxDecoration(color: c.text, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)),
                        child: Icon(Icons.check_rounded, size: size * 0.17, color: c.bg),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle()),
          ],
        ),
      ),
    );
  }
}

/// Grille de choix ronds : 3 colonnes sur le Fold fermé, plus s'il y a la place.
class RoundChoiceGrid extends StatelessWidget {
  const RoundChoiceGrid({super.key, required this.itemCount, required this.itemBuilder, this.maxSize = 112});

  final int itemCount;
  final Widget Function(BuildContext context, int i, double size) itemBuilder;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / 150).floor().clamp(4, 8);
      final w = box.maxWidth / cols;
      final size = (w - 16).clamp(64.0, maxSize);
      return Wrap(
        runSpacing: 18,
        children: [
          for (var i = 0; i < itemCount; i++) SizedBox(width: w, child: Center(child: itemBuilder(context, i, size))),
        ],
      );
    });
  }
}

/// Barre d'actions fixée en bas de page, posée dans le corps de la page.
/// (Le `bottomBar` de `SubPageScaffold` prend toute la hauteur tant que
/// `ContentWidth` y centre sans `heightFactor` : demande faite au socle.)
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.body, required this.bar});

  final Widget body;
  final Widget? bar;

  @override
  Widget build(BuildContext context) {
    final b = bar;
    if (b == null) return body;
    final c = context.colors;
    return Column(
      children: [
        Expanded(child: body),
        DecoratedBox(
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          child: SafeArea(
            top: false,
            child: Padding(padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10), child: b),
          ),
        ),
      ],
    );
  }
}
