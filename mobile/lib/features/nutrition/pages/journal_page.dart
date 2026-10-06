import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../nav.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Onglet Nutrition : le journal d'un jour.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key, this.initialDay});

  /// Jour demandé par un lien (`/nutrition?jour=2026-09-30`).
  final DateTime? initialDay;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late final NutritionExtras x = NutritionExtras.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => x.jour.value = widget.initialDay!);
    }
  }

  @override
  void didUpdateWidget(JournalPage old) {
    super.didUpdateWidget(old);
    if (widget.initialDay != null && widget.initialDay != old.initialDay) x.jour.value = widget.initialDay!;
  }

  void _setDay(DateTime d) => x.jour.value = Dates.jour(d);

  Future<void> _menu(DateTime jour) async {
    final a = await showActionMenu<String>(
      context,
      items: const [
        ActionMenuItem(value: 'objectifs', label: 'Objectifs', icon: Icons.flag_rounded),
        ActionMenuItem(value: 'aliments', label: 'Mes aliments', icon: Icons.inventory_2_rounded),
        ActionMenuItem(value: 'repas', label: 'Repas enregistrés', icon: Icons.bookmarks_rounded),
        ActionMenuItem(value: 'recettes', label: 'Recettes', icon: Icons.menu_book_rounded),
        ActionMenuItem(value: 'copier', label: 'Copier un jour entier ici', icon: Icons.content_copy_rounded),
        ActionMenuItem(value: 'reglages', label: 'Réglages de la nutrition', icon: Icons.tune_rounded),
      ],
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'objectifs':
        await NutritionNav.goals(context);
      case 'aliments':
        await NutritionNav.myFoods(context);
      case 'repas':
        await NutritionNav.meals(context);
      case 'recettes':
        await NutritionNav.recipes(context);
      case 'copier':
        await _copyWholeDay(jour);
      case 'reglages':
        await NutritionNav.settings(context);
    }
  }

  Future<void> _copyWholeDay(DateTime jour) async {
    final repo = context.read<NutritionRepo>();
    final d = await pickDay(context, initial: jour.subtract(const Duration(days: 1)), help: 'Copier quel jour ?');
    if (d == null || !mounted) return;
    final n = repo.entriesFor(d).length;
    if (n == 0) {
      Toasts.show(context, 'Rien n\'était noté ce jour-là.');
      return;
    }
    if (Dates.memeJour(d, jour)) return;
    await repo.copyDay(d, jour);
    if (mounted) Toasts.success(context, '${Fmt.pluriel(n, 'aliment copié', 'aliments copiés')} depuis ${Fmt.relatif(d).toLowerCase()}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([x, x.jour]),
      builder: (context, _) {
        final jour = x.jour.value;
        final today = Dates.memeJour(jour, DateTime.now());
        return AppScaffold(
          title: 'Nutrition',
          eyebrow: today ? Fmt.jour(jour) : Fmt.relatif(jour),
          haloColor: context.colors.accent,
          actions: [
            RoundIconButton(icon: Icons.calendar_month_rounded, onPressed: () => NutritionNav.calendar(context), filled: false, size: 40, tooltip: 'Calendrier'),
            const SizedBox(width: 6),
            RoundIconButton(icon: Icons.insights_rounded, onPressed: () => NutritionNav.stats(context), filled: false, size: 40, tooltip: 'Statistiques'),
            const SizedBox(width: 6),
            RoundIconButton(icon: Icons.more_horiz_rounded, onPressed: () => _menu(jour), filled: false, size: 40, tooltip: 'Plus'),
          ],
          maxContentWidth: 1100,
          slivers: [
            SliverToBoxAdapter(child: _DayBar(jour: jour, onChanged: _setDay)),
            SliverToBoxAdapter(
              child: !x.loaded
                  ? const Padding(padding: EdgeInsets.all(AppTokens.gutter), child: SkeletonList(count: 5))
                  : _JournalBody(jour: jour),
            ),
          ],
        );
      },
    );
  }
}

/// ‹ Aujourd'hui › et la bande des sept jours.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.jour, required this.onChanged});
  final DateTime jour;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final now = Dates.jour(DateTime.now());
    final semaine = Dates.joursSemaine(jour);
    final label = Dates.memeJour(jour, now) ? 'Aujourd\'hui' : Fmt.jourCap(jour);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 8),
      child: Column(
        children: [
          StepSelector(
            label: label,
            previousTooltip: 'Jour précédent',
            nextTooltip: 'Jour suivant',
            onPrevious: () => onChanged(jour.subtract(const Duration(days: 1))),
            onNext: () => onChanged(DateTime(jour.year, jour.month, jour.day + 1)),
            onTapLabel: () => Dates.memeJour(jour, now) ? NutritionNav.calendar(context) : onChanged(now),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in semaine)
                Expanded(
                  child: _DayChip(
                    day: d,
                    selected: Dates.memeJour(d, jour),
                    today: Dates.memeJour(d, now),
                    ratio: () {
                      final g = goalsOf(context, d).goals.kcal;
                      final k = repo.totalsFor(d).kcal;
                      return g <= 0 ? 0.0 : k / g;
                    }(),
                    onTap: () => onChanged(d),
                  ),
                ),
            ],
          ),
          if (!Dates.memeJour(jour, now) && jour.isAfter(now))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Jour à venir : tu peux préparer tes repas à l\'avance.', style: AppType.rowSubtitle(color: c.text2)),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.today, required this.ratio, required this.onTap});
  final DateTime day;
  final bool selected;
  final bool today;
  final double ratio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: Fmt.jourCap(day),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius14,
        child: AnimatedContainer(
          duration: AppTokens.fast,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : Colors.transparent,
            borderRadius: AppTokens.radius14,
            border: Border.all(color: selected ? c.accentBorder : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(Dates.initiale(day), style: AppType.overline(color: selected ? c.accent : c.text3).copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 6),
              ProgressRing(
                value: ratio,
                size: 32,
                stroke: 3,
                color: c.kcal,
                center: Text(
                  '${day.day}',
                  style: AppType.number(12.5, color: today || selected ? c.text : c.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalBody extends StatelessWidget {
  const _JournalBody({required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<NutritionRepo>();
    final dg = goalsOf(context, jour);
    final totals = repo.totalsFor(jour);
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CaloriesCard(jour: jour, totals: totals, dg: dg),
        const SizedBox(height: 12),
        _QuickActions(jour: jour),
        const SizedBox(height: 12),
        _WaterCard(jour: jour, goalMl: dg.goals.eauMl),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in MealType.values) ...[
          _MealCard(jour: jour, repas: t),
          const SizedBox(height: 12),
        ],
        const _ToolsGroup(),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 720) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 18), SectionLabel('REPAS'), const SizedBox(height: 10), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: right),
          ],
        );
      }),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.jour, required this.totals, required this.dg});
  final DateTime jour;
  final Macros totals;
  final DayGoals dg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = dg.goals;
    final reste = g.kcal - totals.kcal;
    final ratio = g.kcal <= 0 ? 0.0 : totals.kcal / g.kcal;
    return AppCard(
      label: 'CALORIES',
      labelTrailing: dg.libelle == null
          ? AccentLink(label: 'Objectifs', onTap: () => NutritionNav.goals(context))
          : TagPill(dg.libelle!, icon: dg.entrainement! ? Icons.fitness_center_rounded : Icons.self_improvement_rounded, color: dg.entrainement! ? c.training : c.sleep, onTap: () => NutritionNav.goals(context)),
      onTap: () => NutritionNav.mealDetail(context, null, jour),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: BigNumber(
                  label: reste >= 0 ? 'Restantes' : 'Au-delà de l\'objectif',
                  value: Fmt.n(reste.abs(), decimals: 0),
                  unit: 'kcal',
                  size: 42,
                  color: reste >= 0 ? c.text : c.warning,
                  caption: '${Fmt.n(totals.kcal, decimals: 0)} mangées sur ${Fmt.n(g.kcal, decimals: 0)}',
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: ratio,
                size: 92,
                stroke: 9,
                color: c.kcal,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(ratio * 100).round()} %', style: AppType.number(17)),
                    Text('atteint', style: AppType.rowSubtitle().copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MacroBar(label: 'Protéines', value: totals.proteines, goal: g.proteinesG, color: c.proteines),
          const SizedBox(height: 14),
          MacroBar(label: 'Glucides', value: totals.glucides, goal: g.glucidesG, color: c.glucides),
          const SizedBox(height: 14),
          MacroBar(label: 'Lipides', value: totals.lipides, goal: g.lipidesG, color: c.lipides),
          if (g.fibresG > 0) ...[
            const SizedBox(height: 14),
            MacroBar(label: 'Fibres', value: totals.fibres, goal: g.fibresG, color: c.nutrition, compact: true),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) {
    final repas = NutritionLogic.repasParDefaut(jour);
    return Row(
      children: [
        Expanded(
          child: PillButton(
            label: 'Ajouter',
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () => NutritionNav.addFood(context, jour: jour, repas: repas),
          ),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.qr_code_scanner_rounded,
          tooltip: 'Scanner un code-barres',
          filled: false,
          onPressed: () => NutritionNav.addFood(context, jour: jour, repas: repas, scan: true),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.bolt_rounded,
          tooltip: 'Ajout rapide de calories',
          filled: false,
          onPressed: () => NutritionNav.quickAdd(context, jour: jour, repas: repas),
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.jour, required this.goalMl});
  final DateTime jour;
  final int goalMl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final x = NutritionExtras.of(context);
    final ml = repo.waterFor(jour);
    final verre = x.verreMl;
    final nbVerres = (goalMl / verre).ceil().clamp(1, 16);
    final pleins = (ml / verre).floor();
    Future<void> add(int v) async {
      final now = DateTime.now();
      await repo.addWater(v, date: Dates.memeJour(jour, now) ? now : DateTime(jour.year, jour.month, jour.day, 12));
    }

    return AppCard(
      onTap: () => NutritionNav.water(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconHalo(icon: Icons.water_drop_rounded, color: c.eau, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eau', style: AppType.rowTitle()),
                    Text(
                      ml >= goalMl ? 'Objectif atteint, bravo' : 'Encore ${Fmt.n((goalMl - ml) / 1000, decimals: 2)} L',
                      style: AppType.rowSubtitle(color: ml >= goalMl ? c.eau : null),
                    ),
                  ],
                ),
              ),
              Text.rich(TextSpan(children: [
                TextSpan(text: Fmt.n(ml / 1000, decimals: 2), style: AppType.number(22)),
                TextSpan(text: ' / ${Fmt.n(goalMl / 1000, decimals: 1)} L', style: AppType.rowSubtitle()),
              ])),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < nbVerres; i++)
                Semantics(
                  button: true,
                  label: i < pleins ? 'Verre bu' : 'Ajouter un verre',
                  child: InkWell(
                    borderRadius: AppTokens.radius8,
                    onTap: () => i < pleins ? repo.undoWater(jour) : add(verre),
                    child: AnimatedContainer(
                      duration: AppTokens.fast,
                      width: 26,
                      height: 32,
                      decoration: BoxDecoration(
                        color: i < pleins ? c.eau.withValues(alpha: 0.85) : AppTokens.veil2,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(9)),
                        border: Border.all(color: i < pleins ? c.eau : AppTokens.veilBorder),
                      ),
                      child: i == pleins ? Icon(Icons.add_rounded, size: 16, color: c.eau) : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PillButton.secondary(
                  label: '+${Fmt.n(verre, decimals: 0)} ml',
                  icon: Icons.water_drop_outlined,
                  expand: true,
                  size: PillSize.small,
                  color: c.eau,
                  onPressed: () => add(verre),
                ),
              ),
              const SizedBox(width: 8),
              PillButton(
                label: 'Autre',
                variant: PillVariant.outline,
                size: PillSize.small,
                onPressed: () async {
                  final v = await showNumberInputDialog(context, title: 'Quantité d\'eau', unit: 'ml', decimal: false, confirmLabel: 'Ajouter');
                  if (v != null && v > 0) await add(v.round());
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Retirer le dernier verre',
                onPressed: ml == 0 ? null : () => repo.undoWater(jour),
                icon: const Icon(Icons.undo_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.jour, required this.repas});
  final DateTime jour;
  final MealType repas;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final x = NutritionExtras.of(context);
    final entries = repo.entriesFor(jour, repas);
    final total = entries.fold(Macros.zero, (a, e) => a + e.macros);
    final hier = jour.subtract(const Duration(days: 1));
    final nbHier = entries.isEmpty ? repo.entriesFor(hier, repas).length : 0;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r16)),
            onTap: entries.isEmpty ? () => NutritionNav.addFood(context, jour: jour, repas: repas) : () => NutritionNav.mealDetail(context, repas, jour),
            onLongPress: () => showMealMenu(context, repas, jour),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
              child: Row(
                children: [
                  IconHalo(icon: mealIcon(repas), color: c.nutrition, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.nomRepas(repas), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          entries.isEmpty ? 'Rien pour l\'instant' : macrosLine(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.rowSubtitle(),
                        ),
                      ],
                    ),
                  ),
                  if (entries.isNotEmpty) Text(Fmt.n(total.kcal, decimals: 0), style: AppType.rowValue()),
                  if (entries.isNotEmpty) Text(' kcal', style: AppType.rowSubtitle()),
                  IconButton(
                    tooltip: 'Ajouter à ${x.nomRepas(repas).toLowerCase()}',
                    onPressed: () => NutritionNav.addFood(context, jour: jour, repas: repas),
                    icon: Icon(Icons.add_circle_rounded, color: c.accent, size: 28),
                  ),
                  IconButton(
                    tooltip: 'Options du repas',
                    onPressed: () => showMealMenu(context, repas, jour),
                    icon: Icon(Icons.more_vert_rounded, color: c.text3),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isNotEmpty) Divider(height: 1, color: c.line, indent: 16, endIndent: 16),
          for (final e in entries) EntryTile(entry: e),
          if (entries.isEmpty && nbHier > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PillButton.link(
                  label: 'Copier celui de la veille',
                  icon: Icons.history_rounded,
                  size: PillSize.small,
                  onPressed: () async {
                    final n = await repo.copyMeal(hier, repas, jour, repas);
                    if (context.mounted) Toasts.success(context, '${Fmt.pluriel(n, 'aliment copié', 'aliments copiés')} depuis la veille');
                  },
                ),
              ),
            ),
          if (entries.isNotEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Une entrée du journal : glisser pour supprimer, toucher pour modifier,
/// appui long pour le menu.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.showTime = false});
  final FoodEntry entry;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<NutritionRepo>();
    final food = entry.foodId == null ? null : repo.foodById(entry.foodId!);
    final sub = [quantiteLabel(entry, liquide: food?.liquide ?? false), if (showTime) Fmt.heure(entry.date)].join(' · ');
    return Dismissible(
      key: ValueKey('entree-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: c.error.withValues(alpha: 0.14),
        child: Icon(Icons.delete_outline_rounded, color: c.error),
      ),
      onDismissed: (_) => deleteEntryWithUndo(context, entry),
      child: InkWell(
        onTap: () => openEntry(context, entry),
        onLongPress: () => showEntryMenu(context, entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(Fmt.n(entry.macros.kcal, decimals: 0), style: AppType.rowValue().copyWith(fontSize: 14, color: c.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolsGroup extends StatelessWidget {
  const _ToolsGroup();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final x = NutritionExtras.of(context);
    final streak = NutritionLogic.streak(repo);
    return TileGroup(
      margin: EdgeInsets.zero,
      label: 'OUTILS',
      labelTrailing: streak > 1 ? LabelCount('$streak jours notés d\'affilée') : null,
      children: [
        ListTileX(
          leading: IconHalo(icon: Icons.flag_rounded, color: c.accent),
          title: 'Objectifs',
          subtitle: x.cyclage.actif ? 'Calories, macros, cyclage actif' : 'Calories, macros, eau',
          showChevron: true,
          onTap: () => NutritionNav.goals(context),
        ),
        ListTileX(
          leading: IconHalo(icon: Icons.insights_rounded, color: c.training),
          title: 'Statistiques',
          subtitle: 'Moyennes, courbes, respect des macros',
          showChevron: true,
          onTap: () => NutritionNav.stats(context),
        ),
        ListTileX(
          leading: IconHalo(icon: Icons.inventory_2_rounded, color: c.nutrition),
          title: 'Mes aliments',
          subtitle: Fmt.pluriel(repo.foodsPerso.where((f) => f.source == 'perso').length, 'aliment perso', 'aliments perso'),
          showChevron: true,
          onTap: () => NutritionNav.myFoods(context),
        ),
        ListTileX(
          leading: IconHalo(icon: Icons.bookmarks_rounded, color: c.sleep),
          title: 'Repas enregistrés',
          subtitle: Fmt.pluriel(repo.meals.length, 'repas', 'repas'),
          showChevron: true,
          onTap: () => NutritionNav.meals(context),
        ),
        ListTileX(
          leading: IconHalo(icon: Icons.menu_book_rounded, color: c.weight),
          title: 'Recettes',
          subtitle: Fmt.pluriel(x.recettes.length, 'recette'),
          showChevron: true,
          onTap: () => NutritionNav.recipes(context),
        ),
      ],
    );
  }
}
