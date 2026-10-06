import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/text_search.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../nav.dart';
import '../widgets/nutri_widgets.dart';

enum _Filtre { perso, favoris, enregistres }

/// Mes aliments : créés à la main, favoris, et ceux venus de la base en ligne.
class MyFoodsPage extends StatefulWidget {
  const MyFoodsPage({super.key});

  @override
  State<MyFoodsPage> createState() => _MyFoodsPageState();
}

class _MyFoodsPageState extends State<MyFoodsPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  _Filtre _filtre = _Filtre.perso;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final f = await NutritionNav.editFood(context);
    if (f != null && mounted) setState(() => _filtre = _Filtre.perso);
  }

  Future<void> _open(Food f) async {
    if (f.source == 'perso') {
      await NutritionNav.editFood(context, food: f);
    } else {
      await NutritionNav.food(context, FoodPageArgs(food: f, jour: x.jour.value, nutriscore: x.nutriscoreOf(f.id)));
    }
  }

  Future<void> _menu(Food f) async {
    final repo = context.read<NutritionRepo>();
    final a = await showActionMenu<String>(context, title: f.nom, items: [
      const ActionMenuItem(value: 'ajouter', label: 'Ajouter au journal', icon: Icons.add_rounded),
      if (f.source == 'perso') const ActionMenuItem(value: 'modifier', label: 'Modifier', icon: Icons.edit_rounded),
      ActionMenuItem(value: 'favori', label: f.favori ? 'Retirer des favoris' : 'Ajouter aux favoris', icon: f.favori ? Icons.star_outline_rounded : Icons.star_rounded),
      if (f.source != 'recette') const ActionMenuItem(value: 'supprimer', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
    ]);
    if (a == null || !mounted) return;
    switch (a) {
      case 'ajouter':
        await NutritionNav.food(context, FoodPageArgs(food: f, jour: x.jour.value, nutriscore: x.nutriscoreOf(f.id)));
      case 'modifier':
        await NutritionNav.editFood(context, food: f);
      case 'favori':
        await repo.toggleFavoriteFood(f.id);
      case 'supprimer':
        final ok = await showConfirmDialog(context, title: 'Supprimer « ${f.nom} » ?', message: 'Les repas déjà notés gardent leurs valeurs.', confirmLabel: 'Supprimer', destructive: true);
        if (!ok) return;
        await repo.deleteFood(f.id);
        if (mounted) Toasts.show(context, 'Aliment supprimé', actionLabel: 'Annuler', onAction: () => repo.saveFood(f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    var foods = switch (_filtre) {
      _Filtre.perso => repo.foodsPerso.where((f) => f.source == 'perso').toList(),
      _Filtre.favoris => repo.favoriteFoods,
      _Filtre.enregistres => repo.foodsPerso.where((f) => f.source != 'perso' && f.source != 'recette').toList(),
    };
    final q = _q.text.trim();
    if (q.isNotEmpty) foods = foods.where((f) => TextSearch.score(q, f.nom, [f.marque]) > 0).toList();
    foods.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    final vide = switch (_filtre) {
      _Filtre.perso => EmptyState(
          icon: Icons.edit_note_rounded,
          iconColor: c.nutrition,
          title: q.isEmpty ? 'Aucun aliment perso' : 'Aucun résultat',
          message: q.isEmpty ? 'Crée un aliment avec les valeurs de son étiquette : il sera proposé dans la recherche.' : 'Aucun aliment perso ne correspond.',
          actionLabel: 'Créer un aliment',
          onAction: _create,
        ),
      _Filtre.favoris => EmptyState(
          icon: Icons.star_outline_rounded,
          iconColor: c.accent,
          title: 'Aucun favori',
          message: 'Touche l\'étoile sur la fiche d\'un aliment pour l\'ajouter ici.',
        ),
      _Filtre.enregistres => EmptyState(
          icon: Icons.cloud_download_rounded,
          iconColor: c.nutrition,
          title: 'Rien pour l\'instant',
          message: 'Les produits trouvés en ligne ou scannés sont gardés ici dès que tu les ajoutes.',
        ),
    };

    return SubPageScaffold(
      title: 'Mes aliments',
      haloColor: c.nutrition,
      actions: [IconButton(tooltip: 'Créer un aliment', onPressed: _create, icon: const Icon(Icons.add_rounded))],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 10),
          child: SearchField(controller: _q, hint: 'Filtrer mes aliments', onChanged: (_) => setState(() {})),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: SegmentedChips<_Filtre>(
            segments: const [(_Filtre.perso, 'Créés'), (_Filtre.favoris, 'Favoris'), (_Filtre.enregistres, 'Enregistrés')],
            value: _filtre,
            onChanged: (v) => setState(() => _filtre = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: foods.isEmpty
              ? Center(child: SingleChildScrollView(padding: const EdgeInsets.all(AppTokens.gutter), child: vide))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: foods.length,
                  itemBuilder: (context, i) => FoodRow(
                    food: foods[i],
                    nutriscore: x.nutriscoreOf(foods[i].id),
                    onTap: () => _open(foods[i]),
                    onLongPress: () => _menu(foods[i]),
                    onAdd: () => NutritionNav.food(context, FoodPageArgs(food: foods[i], jour: x.jour.value, nutriscore: x.nutriscoreOf(foods[i].id))),
                  ),
                ),
        ),
      ]),
    );
  }
}
