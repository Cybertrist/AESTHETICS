import 'dart:async';

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
import '../data/off_client.dart';
import '../data/recipe.dart';
import '../nav.dart';
import '../widgets/nutri_page.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

enum _Onglet { recents, favoris, perso, repas, recettes }

/// Ajouter un aliment : recherche (locale et en ligne), scan, récents,
/// favoris, aliments perso, repas enregistrés, recettes.
/// En mode [choisir], rend un `MealItem` au lieu d'écrire dans le journal.
class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key, this.jour, this.repas, this.choisir = false, this.scanAuDemarrage = false});

  final DateTime? jour;
  final MealType? repas;
  final bool choisir;
  final bool scanAuDemarrage;

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late final OpenFoodFactsClient off = OpenFoodFactsClient.forStore(context.read<Store>());
  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  late DateTime _jour = widget.jour ?? x.jour.value;
  late MealType _repas = widget.repas ?? NutritionLogic.repasParDefaut(_jour);
  _Onglet _onglet = _Onglet.recents;

  // Recherche en ligne
  bool _loading = false;
  String? _error;
  List<OnlineFood> _online = [];
  String _onlineFor = '';
  int _requete = 0;

  int _ajouts = 0;

  @override
  void initState() {
    super.initState();
    if (widget.scanAuDemarrage) WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim();

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    if (_q.length < 2) {
      setState(() {
        _online = [];
        _error = null;
        _loading = false;
        _onlineFor = '';
      });
      return;
    }
    if (!x.rechercheEnLigne) return;
    _debounce = Timer(const Duration(milliseconds: 450), _searchOnline);
  }

  Future<void> _searchOnline() async {
    final q = _q;
    if (q.length < 2 || !x.rechercheEnLigne) return;
    final id = ++_requete;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await off.search(q);
      if (!mounted || id != _requete) return;
      setState(() {
        _online = r;
        _onlineFor = q;
        _loading = false;
      });
      unawaited(x.noterRecherche(q));
    } on OnlineFoodError catch (e) {
      if (!mounted || id != _requete) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _online = [];
      });
    }
  }

  // Ajouts

  Future<void> _open(Food food, {String? nutriscore}) async {
    final r = await NutritionNav.food(
      context,
      FoodPageArgs(
        food: food,
        mode: widget.choisir ? FoodPageMode.choisir : FoodPageMode.ajouter,
        jour: _jour,
        repas: _repas,
        nutriscore: nutriscore ?? x.nutriscoreOf(food.id),
      ),
    );
    if (!mounted) return;
    if (widget.choisir && r is MealItem) {
      Navigator.of(context).pop(r);
    } else if (r == true) {
      setState(() => _ajouts++);
    }
  }

  /// Ajout direct avec la portion par défaut.
  Future<void> _quick(Food food, {String? nutriscore}) async {
    final portion = food.portions.isNotEmpty ? food.portions.first : null;
    final g = portion?.grammes ?? 100;
    if (widget.choisir) {
      if (food.source == 'openfoodfacts') await context.read<NutritionRepo>().saveFood(food);
      if (nutriscore != null) await x.setNutriscore(food.id, nutriscore);
      if (mounted) Navigator.of(context).pop(MealItem(foodId: food.id, nom: food.nom, grammes: g, macros: food.pour(g)));
      return;
    }
    final repo = context.read<NutritionRepo>();
    if (nutriscore != null) await x.setNutriscore(food.id, nutriscore);
    final e = await repo.addFood(food, g, date: NutritionLogic.heurePour(_jour, _repas), repas: _repas, portionLabel: portion == null ? null : '1 ${portion.label}');
    if (!mounted) return;
    setState(() => _ajouts++);
    Toasts.success(context, '${food.nom} ajouté à ${x.nomRepas(_repas).toLowerCase()}', actionLabel: 'Annuler', onAction: () {
      repo.deleteEntry(e.id);
      if (mounted) setState(() => _ajouts--);
    });
  }

  Future<void> _addMeal(Meal m) async {
    final repo = context.read<NutritionRepo>();
    await repo.addMealToDay(m, date: NutritionLogic.heurePour(_jour, _repas), repas: _repas);
    if (!mounted) return;
    setState(() => _ajouts += m.items.length);
    Toasts.success(context, '${m.nom} ajouté à ${x.nomRepas(_repas).toLowerCase()}');
  }

  Future<void> _showMeal(Meal m) async {
    final c = context.colors;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(m.nom, style: ctx.textStyles.titleLarge),
                const SizedBox(height: 4),
                Text('${Fmt.kcal(m.macros.kcal)} · ${macrosLine(m.macros)}', style: AppType.rowSubtitle()),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final i in m.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(child: Text(i.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14))),
                            Text('${Fmt.n(i.grammes, decimals: 0)} g', style: AppType.rowSubtitle()),
                            const SizedBox(width: 12),
                            Text(Fmt.n(i.macros.kcal, decimals: 0), style: AppType.rowValue().copyWith(fontSize: 14, color: c.text2)),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                  PillButton.ghost(label: 'Modifier', onPressed: () => Navigator.of(ctx).pop('modifier')),
                  PillButton(label: 'Ajouter', icon: Icons.add_rounded, onPressed: () => Navigator.of(ctx).pop('ajouter')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (r == 'ajouter') {
      await _addMeal(m);
    } else if (r == 'modifier') {
      await NutritionNav.editMeal(context, meal: m);
    }
  }

  Future<void> _addRecipe(Recipe r) async {
    final repo = context.read<NutritionRepo>();
    final food = repo.foodById(Recipe.foodIdFor(r.id)) ?? await repo.saveFood(r.toFood());
    await _quick(food);
  }

  // Scan

  Future<void> _scan() async {
    final code = await NutritionNav.scan(context);
    if (code == null || !mounted) return;
    await lookupBarcode(code);
  }

  Future<void> lookupBarcode(String code) async {
    final repo = context.read<NutritionRepo>();
    final local = repo.foodByBarcode(code);
    if (local != null) {
      await _open(local);
      return;
    }
    OnlineFood? found;
    String? error;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _LoadingDialog(message: 'Recherche du produit…'),
    );
    try {
      found = await off.product(code);
    } on OnlineFoodError catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (found != null) {
      await _open(found.food, nutriscore: found.nutriscore);
      return;
    }
    final choix = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: error == null ? Icons.search_off_rounded : Icons.wifi_off_rounded,
        title: error == null ? 'Produit introuvable' : 'Recherche impossible',
        message: error ?? 'Le code $code n\'est pas dans la base. Tu peux créer l\'aliment à partir de l\'étiquette, il sera reconnu au prochain scan.',
        confirmLabel: error == null ? 'Créer l\'aliment' : 'Réessayer',
      ),
    ).then((ok) => ok == true ? (error == null ? 'creer' : 'reessayer') : null);
    if (!mounted) return;
    if (choix == 'reessayer') {
      await lookupBarcode(code);
    } else if (choix == 'creer') {
      final f = await NutritionNav.editFood(context, codeBarres: code);
      if (f != null && mounted) await _open(f);
    }
  }

  Future<void> _createFood() async {
    final f = await NutritionNav.editFood(context, nom: _q.isEmpty ? null : _q);
    if (f != null && mounted) await _open(f);
  }

  Future<void> _changeMeal() async {
    final m = await pickMeal(context, selected: _repas, title: 'Ajouter à');
    if (m != null) setState(() => _repas = m);
  }

  Future<void> _changeDay() async {
    final d = await pickDay(context, initial: _jour);
    if (d != null) setState(() => _jour = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: x,
      builder: (context, _) => NutriSubPage(
        title: widget.choisir ? 'Choisir un aliment' : 'Ajouter',
        closeIcon: true,
        subtitle: widget.choisir ? 'Pour un repas ou une recette' : null,
        actions: [
          if (!widget.choisir)
            IconButton(tooltip: 'Ajout rapide de calories', onPressed: () => NutritionNav.quickAdd(context, jour: _jour, repas: _repas), icon: const Icon(Icons.bolt_rounded)),
        ],
        bottomBar: widget.choisir || _ajouts == 0
            ? null
            : Row(children: [
                Expanded(
                  child: Text(
                    '${Fmt.pluriel(_ajouts, 'aliment ajouté', 'aliments ajoutés')} à ${x.nomRepas(_repas).toLowerCase()}',
                    style: AppType.rowSubtitle(color: c.text2),
                  ),
                ),
                PillButton(label: 'Terminer', icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop()),
              ]),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.choisir)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 10),
                child: Row(children: [
                  Expanded(
                    child: _TargetChip(icon: mealIcon(_repas), label: x.nomRepas(_repas), onTap: _changeMeal),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetChip(
                      icon: Icons.event_rounded,
                      label: Dates.memeJour(_jour, DateTime.now()) ? 'Aujourd\'hui' : Fmt.relatif(_jour),
                      onTap: _changeDay,
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 10),
              child: SearchField(
                controller: _query,
                focusNode: _focus,
                hint: 'Chercher un aliment, une marque…',
                onChanged: _onChanged,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  _searchOnline();
                },
                trailing: IconButton(
                  tooltip: 'Scanner un code-barres',
                  onPressed: _scan,
                  icon: Icon(Icons.qr_code_scanner_rounded, color: c.accent),
                ),
              ),
            ),
            Expanded(child: _q.isEmpty ? _browse() : _results()),
          ],
        ),
      ),
    );
  }

  // Sans recherche : onglets

  Widget _browse() {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final onglets = [
      (_Onglet.recents, 'Récents'),
      (_Onglet.favoris, 'Favoris'),
      (_Onglet.perso, 'Mes aliments'),
      if (!widget.choisir) (_Onglet.repas, 'Repas'),
      if (!widget.choisir) (_Onglet.recettes, 'Recettes'),
    ];
    Widget list;
    switch (_onglet) {
      case _Onglet.recents:
        final foods = repo.recentFoods(limit: 40);
        list = foods.isEmpty
            ? const EmptyState(icon: Icons.history_rounded, title: 'Aucun aliment récent', message: 'Cherche un aliment ou scanne un code-barres : il apparaîtra ici la prochaine fois.')
            : _foodList(foods);
      case _Onglet.favoris:
        final foods = repo.favoriteFoods;
        list = foods.isEmpty
            ? const EmptyState(icon: Icons.star_outline_rounded, title: 'Pas encore de favori', message: 'Touche l\'étoile sur la fiche d\'un aliment pour le retrouver ici.')
            : _foodList(foods);
      case _Onglet.perso:
        final foods = repo.foodsPerso.where((f) => f.source == 'perso').toList()..sort((a, b) => a.nom.compareTo(b.nom));
        list = foods.isEmpty
            ? EmptyState(
                icon: Icons.edit_note_rounded,
                title: 'Aucun aliment perso',
                message: 'Crée tes propres aliments à partir d\'une étiquette ou d\'une recette de famille.',
                actionLabel: 'Créer un aliment',
                onAction: _createFood,
              )
            : _foodList(foods, footer: _createButton());
      case _Onglet.repas:
        final meals = repo.meals;
        list = meals.isEmpty
            ? EmptyState(
                icon: Icons.bookmarks_outlined,
                title: 'Aucun repas enregistré',
                message: 'Enregistre un repas que tu manges souvent pour l\'ajouter en un geste.',
                actionLabel: 'Créer un repas',
                onAction: () => NutritionNav.editMeal(context),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final m in meals)
                    ListTileX(
                      leading: IconHalo(icon: Icons.bookmark_rounded, color: c.sleep),
                      title: m.nom,
                      subtitle: '${Fmt.pluriel(m.items.length, 'aliment')} · ${macrosLine(m.macros)}',
                      value: Fmt.n(m.macros.kcal, decimals: 0),
                      onTap: () => _showMeal(m),
                      trailing: RoundIconButton(icon: Icons.add_rounded, onPressed: () => _addMeal(m), size: 36, filled: false, iconColor: c.accent, tooltip: 'Ajouter'),
                    ),
                ],
              );
      case _Onglet.recettes:
        final recettes = x.recettes;
        list = recettes.isEmpty
            ? EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Aucune recette',
                message: 'Assemble plusieurs aliments, indique le nombre de portions, et ajoute une part en un geste.',
                actionLabel: 'Créer une recette',
                onAction: () => NutritionNav.editRecipe(context),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final r in recettes)
                    RecipeRow(
                      recipe: r,
                      onTap: () => NutritionNav.recipe(context, r.id, jour: _jour, repas: _repas),
                      onAdd: () => _addRecipe(r),
                    ),
                ],
              );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
            children: [
              for (final (o, l) in onglets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipFilter(label: l, selected: _onglet == o, onTap: () => setState(() => _onglet = o)),
                ),
            ],
          ),
        ),
        if (x.recherchesRecentes.isNotEmpty && _onglet == _Onglet.recents)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 6, AppTokens.gutter, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in x.recherchesRecentes.take(6))
                ActionChip(
                  avatar: Icon(Icons.search_rounded, size: 16, color: c.text3),
                  label: Text(s),
                  onPressed: () {
                    _query.text = s;
                    _onChanged(s);
                  },
                ),
            ]),
          ),
        const SizedBox(height: 6),
        Expanded(child: list),
      ],
    );
  }

  Widget _createButton() => Padding(
        padding: const EdgeInsets.all(AppTokens.gutter),
        child: Center(child: PillButton.link(label: 'Créer un aliment', icon: Icons.add_rounded, onPressed: _createFood)),
      );

  Widget _foodList(List<Food> foods, {Widget? footer}) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: foods.length + (footer == null ? 0 : 1),
        itemBuilder: (context, i) {
          if (i == foods.length) return footer!;
          final f = foods[i];
          return FoodRow(food: f, nutriscore: x.nutriscoreOf(f.id), onTap: () => _open(f), onAdd: () => _quick(f));
        },
      );

  // Avec recherche : locale puis en ligne

  Widget _results() {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final local = repo.searchFoods(_q, limit: 25);
    final localIds = local.map((f) => f.codeBarres).whereType<String>().toSet();
    final online = _online.where((o) => !localIds.contains(o.food.codeBarres)).toList();
    final children = <Widget>[
      if (local.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 8, AppTokens.gutter, 4),
          child: SectionLabel('DANS TES ALIMENTS', trailing: LabelCount('${local.length}')),
        ),
        for (final f in local) FoodRow(food: f, nutriscore: x.nutriscoreOf(f.id), onTap: () => _open(f), onAdd: () => _quick(f)),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 16, AppTokens.gutter, 4),
        child: SectionLabel('BASE EN LIGNE', trailing: _loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)) : null),
      ),
      if (!x.rechercheEnLigne)
        Padding(
          padding: const EdgeInsets.all(AppTokens.gutter),
          child: EmptyState(
            compact: true,
            icon: Icons.cloud_off_rounded,
            title: 'Recherche en ligne coupée',
            message: 'Active-la dans les réglages de la nutrition pour chercher parmi des millions de produits.',
            actionLabel: 'Activer',
            onAction: () async {
              await x.setRechercheEnLigne(true);
              _searchOnline();
            },
          ),
        )
      else if (_loading && online.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(horizontal: AppTokens.gutter), child: SkeletonList(count: 5))
      else if (_error != null)
        Padding(
          padding: const EdgeInsets.all(AppTokens.gutter),
          child: EmptyState(compact: true, icon: Icons.wifi_off_rounded, title: 'Recherche en ligne impossible', message: _error, actionLabel: 'Réessayer', onAction: _searchOnline),
        )
      else if (_q.length < 2)
        Padding(
          padding: const EdgeInsets.all(AppTokens.gutter),
          child: Text('Tape au moins deux lettres.', style: AppType.rowSubtitle()),
        )
      else if (online.isEmpty && _onlineFor == _q)
        Padding(
          padding: const EdgeInsets.all(AppTokens.gutter),
          child: EmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: 'Rien trouvé en ligne',
            message: 'Essaie un autre mot, scanne le code-barres, ou crée l\'aliment toi-même.',
            actionLabel: 'Scanner',
            onAction: _scan,
          ),
        )
      else
        for (final o in online)
          FoodRow(
            food: o.food,
            nutriscore: o.nutriscore,
            trailingInfo: o.quantite,
            onTap: () => _open(o.food, nutriscore: o.nutriscore),
            onAdd: () => _quick(o.food, nutriscore: o.nutriscore),
          ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
        child: AppCard(
          color: c.surface2,
          child: Row(children: [
            IconHalo(icon: Icons.edit_note_rounded, color: c.nutrition, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text('Tu ne le trouves pas ? Crée « $_q » avec les valeurs de l\'étiquette.', style: AppType.rowSubtitle(color: c.text2))),
            const SizedBox(width: 8),
            PillButton.secondary(label: 'Créer', size: PillSize.small, onPressed: _createFood),
          ]),
        ),
      ),
      const SizedBox(height: 32),
    ];
    return ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: children);
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: AppTokens.veil,
      shape: RoundedRectangleBorder(borderRadius: AppTokens.radiusPill, side: const BorderSide(color: AppTokens.veilBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 18, color: c.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14))),
            Icon(Icons.expand_more_rounded, size: 18, color: c.text3),
          ]),
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent)),
          const SizedBox(width: 18),
          Flexible(child: Text(message, style: AppType.rowTitle())),
        ]),
      ),
    );
  }
}
