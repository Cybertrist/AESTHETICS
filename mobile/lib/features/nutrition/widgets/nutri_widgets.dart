import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/recipe.dart';

/// Couleurs des valeurs nutritionnelles, prises dans les couleurs de domaine.
extension NutriColors on AppColors {
  Color get kcal => accent;
  Color get proteines => training;
  Color get glucides => weight;
  Color get lipides => sleep;
  Color get eau => coach;
}

IconData mealIcon(MealType t) => switch (t) {
      MealType.petitDejeuner => Icons.free_breakfast_rounded,
      MealType.dejeuner => Icons.lunch_dining_rounded,
      MealType.collation => Icons.cookie_rounded,
      MealType.diner => Icons.dinner_dining_rounded,
    };

/// Icône d'un aliment selon son origine.
IconData foodIcon(Food f) {
  if (f.source == 'recette') return Icons.menu_book_rounded;
  if (f.codeBarres != null) return Icons.qr_code_rounded;
  if (f.liquide) return Icons.local_drink_rounded;
  return Icons.restaurant_rounded;
}

/// « 150 g », « 2 × œuf (120 g) », « 330 ml ».
String quantiteLabel(FoodEntry e, {bool liquide = false}) {
  if (e.quantiteG <= 0) return 'Ajout rapide';
  final u = liquide ? 'ml' : 'g';
  if (e.portionLabel != null && e.portionLabel!.isNotEmpty) return '${e.portionLabel} · ${Fmt.n(e.quantiteG, decimals: 0)} $u';
  return '${Fmt.n(e.quantiteG, decimals: 0)} $u';
}

String macrosLine(Macros m) => 'P ${Fmt.n(m.proteines, decimals: 0)} · G ${Fmt.n(m.glucides, decimals: 0)} · L ${Fmt.n(m.lipides, decimals: 0)}';

/// Vignette d'un aliment : photo du produit si elle existe, sinon icône à halo.
class FoodThumb extends StatelessWidget {
  const FoodThumb({super.key, required this.food, this.size = 42});
  final Food food;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = IconHalo(icon: foodIcon(food), color: food.source == 'recette' ? c.weight : c.nutrition, size: size, glow: size > 40);
    final url = food.image;
    if (url == null || !url.startsWith('http')) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.34),
      child: Container(
        width: size,
        height: size,
        color: c.surface3,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Icon(foodIcon(food), size: size * 0.5, color: c.nutrition),
          placeholder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Pastille Nutri-Score (A à E), aux couleurs officielles du logo.
class NutriScoreBadge extends StatelessWidget {
  const NutriScoreBadge({super.key, required this.grade, this.large = false});
  final String grade;
  final bool large;

  // Couleurs du logo Nutri-Score, fixées par son règlement d'usage.
  static const _couleurs = {
    'a': Color(0xFF038141),
    'b': Color(0xFF85BB2F),
    'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100),
    'e': Color(0xFFE63E11),
  };

  @override
  Widget build(BuildContext context) {
    final g = grade.toLowerCase();
    final c = context.colors;
    if (!large) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: _couleurs[g] ?? c.surface3, borderRadius: AppTokens.radius8),
        child: Text(g.toUpperCase(), style: AppType.number(11.5, color: g == 'c' ? Colors.black : Colors.white)),
      );
    }
    return Semantics(
      label: 'Nutri-Score ${g.toUpperCase()}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppTokens.veil, borderRadius: AppTokens.radius12, border: Border.all(color: AppTokens.veilBorder)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in _couleurs.keys)
              AnimatedContainer(
                duration: AppTokens.fast,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: l == g ? 34 : 24,
                height: l == g ? 34 : 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: l == g ? _couleurs[l] : _couleurs[l]!.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(l == g ? 10 : 7),
                ),
                child: Text(
                  l.toUpperCase(),
                  style: AppType.number(l == g ? 17 : 12, color: l == g ? (l == 'c' ? Colors.black : Colors.white) : c.text2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une barre de macro : libellé, « 120 / 160 g », jauge colorée.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, required this.goal, required this.color, this.unit = 'g', this.compact = false});
  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = goal <= 0 ? 0.0 : value / goal;
    final reste = goal - value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: compact ? 13 : 14))),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: Fmt.n(value, decimals: 0), style: AppType.rowValue().copyWith(fontSize: compact ? 13 : 14)),
                TextSpan(text: ' / ${Fmt.n(goal, decimals: 0)} $unit', style: AppType.rowSubtitle()),
              ]),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        _Bar(ratio: ratio, color: color, height: compact ? 6 : 8),
        if (!compact) ...[
          const SizedBox(height: 5),
          Text(
            reste >= 0 ? 'Encore ${Fmt.n(reste, decimals: 0)} $unit' : '${Fmt.n(-reste, decimals: 0)} $unit de plus que prévu',
            style: AppType.rowSubtitle(color: reste >= 0 ? c.text3 : c.warning).copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.color, required this.height});
  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = ratio > 1;
    return LayoutBuilder(
      builder: (context, box) => Container(
        height: height,
        width: box.maxWidth,
        decoration: BoxDecoration(color: AppTokens.veil2, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: AppTokens.normal,
          curve: Curves.easeOutCubic,
          width: box.maxWidth * ratio.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
            border: over ? Border.all(color: c.warning, width: 1.5) : null,
          ),
        ),
      ),
    );
  }
}

/// Trois petites colonnes P / G / L pour une fiche ou une ligne.
class MacroTriplet extends StatelessWidget {
  const MacroTriplet({super.key, required this.macros, this.size = 18});
  final Macros macros;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget col(String l, double v, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle())),
              ]),
              const SizedBox(height: 4),
              Text('${Fmt.n(v, decimals: v < 10 ? 1 : 0)} g', style: AppType.number(size)),
            ],
          ),
        );
    return Row(children: [
      col('Protéines', macros.proteines, c.proteines),
      col('Glucides', macros.glucides, c.glucides),
      col('Lipides', macros.lipides, c.lipides),
    ]);
  }
}

/// Anneau de répartition des calories entre les trois macros.
class MacroSplitRing extends StatelessWidget {
  const MacroSplitRing({super.key, required this.macros, this.size = 120, this.center});
  final Macros macros;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = macros.proteines * 4, g = macros.glucides * 4, l = macros.lipides * 9;
    final total = p + g + l;
    if (total <= 0) {
      return ProgressRing(value: 0, size: size, stroke: size * 0.09, center: center);
    }
    return SegmentRing(
      size: size,
      stroke: size * 0.09,
      parts: [RingPart(p, c.proteines), RingPart(g, c.glucides), RingPart(l, c.lipides)],
      center: center,
    );
  }
}

/// Parts des calories venant des protéines, glucides, lipides (en %).
(int, int, int) macroPercents(Macros m) {
  final p = m.proteines * 4, g = m.glucides * 4, l = m.lipides * 9;
  final t = p + g + l;
  if (t <= 0) return (0, 0, 0);
  final pp = (p / t * 100).round(), gp = (g / t * 100).round();
  return (pp, gp, 100 - pp - gp);
}

/// Ligne d'aliment dans une liste de recherche.
class FoodRow extends StatelessWidget {
  const FoodRow({super.key, required this.food, required this.onTap, this.onAdd, this.nutriscore, this.trailingInfo, this.onLongPress});
  final Food food;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onLongPress;
  final String? nutriscore;
  final String? trailingInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final portion = food.portions.isNotEmpty ? food.portions.first : null;
    final base = portion;
    final kcal = base != null ? food.pour(base.grammes).kcal : food.pour100g.kcal;
    final unite = food.liquide ? 'ml' : 'g';
    final sub = [
      if (food.marque != null) food.marque!,
      base != null ? '${base.label} (${Fmt.n(base.grammes, decimals: 0)} $unite)' : '100 $unite',
      ?trailingInfo,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 2, vertical: 10),
        child: Row(
          children: [
            FoodThumb(food: food),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(food.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle())),
                    if (food.favori) ...[const SizedBox(width: 6), Icon(Icons.star_rounded, size: 15, color: c.accent)],
                  ]),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.n(kcal, decimals: 0), style: AppType.rowValue()),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (nutriscore != null) ...[NutriScoreBadge(grade: nutriscore!), const SizedBox(width: 6)],
                  Text('kcal', style: AppType.rowSubtitle()),
                ]),
              ],
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              RoundIconButton(icon: Icons.add_rounded, onPressed: onAdd, size: 36, filled: false, iconColor: c.accent, tooltip: 'Ajouter'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne d'une recette dans une liste.
class RecipeRow extends StatelessWidget {
  const RecipeRow({super.key, required this.recipe, required this.onTap, this.onAdd});
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTileX(
      leading: IconHalo(icon: Icons.menu_book_rounded, color: c.weight),
      title: recipe.nom,
      subtitle: '${Fmt.pluriel(recipe.items.length, 'ingrédient')} · ${Fmt.pluriel(recipe.portions, 'portion')}',
      value: Fmt.kcal(recipe.parPortion.kcal),
      onTap: onTap,
      trailing: onAdd == null
          ? null
          : RoundIconButton(icon: Icons.add_rounded, onPressed: onAdd, size: 36, filled: false, iconColor: c.accent, tooltip: 'Ajouter'),
    );
  }
}

/// Deux volets côte à côte sur le Fold ouvert, empilés sinon.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.left, required this.right, this.breakpoint = 720, this.leftFlex = 5, this.rightFlex = 6});
  final Widget left;
  final Widget right;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < breakpoint) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          Expanded(flex: rightFlex, child: right),
        ],
      );
    });
  }
}

/// Champ numérique compact (valeurs nutritionnelles).
class NumberField extends StatelessWidget {
  const NumberField({super.key, required this.controller, required this.label, this.suffix, this.onChanged, this.decimal = true, this.autofocus = false, this.hint});
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool decimal;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: onChanged,
      style: AppType.rowValue(),
      decoration: InputDecoration(labelText: label, suffixText: suffix, hintText: hint),
    );
  }
}

/// Lit un nombre saisi à la française (virgule acceptée).
double? parseNumber(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Écrit un nombre pour un champ : « 12,5 », « 80 ».
String numberText(double? v, {int decimals = 1}) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(decimals).replaceAll('.', ',').replaceAll(RegExp(r',?0+$'), '');
}
