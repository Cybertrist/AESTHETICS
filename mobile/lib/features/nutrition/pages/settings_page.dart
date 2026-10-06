import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/off_client.dart';
import '../nav.dart';
import '../widgets/nutri_widgets.dart';

/// Réglages de la nutrition : noms des repas, eau, recherche en ligne.
class NutritionSettingsPage extends StatefulWidget {
  const NutritionSettingsPage({super.key});

  @override
  State<NutritionSettingsPage> createState() => _NutritionSettingsPageState();
}

class _NutritionSettingsPageState extends State<NutritionSettingsPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late final OpenFoodFactsClient off = OpenFoodFactsClient.forStore(context.read<Store>());
  int? _cache;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final n = await off.cacheSize();
    if (mounted) setState(() => _cache = n);
  }

  Future<void> _rename(MealType t) async {
    final nom = await showTextInputDialog(context, title: 'Nom du repas', initial: x.nomRepas(t), hint: t.label, maxLength: 30);
    if (nom != null) await x.renommerRepas(t, nom);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: x,
      builder: (context, _) => SubPageScaffold(
        title: 'Réglages',
        subtitle: 'Nutrition',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            TileGroup(
              label: 'NOMS DES REPAS',
              labelTrailing: MealType.values.any(x.estRenomme)
                  ? AccentLink(
                      label: 'Rétablir',
                      onTap: () async {
                        for (final t in MealType.values) {
                          await x.renommerRepas(t, null);
                        }
                      },
                    )
                  : null,
              children: [
                for (final t in MealType.values)
                  ListTileX(
                    leading: IconHalo(icon: mealIcon(t), color: c.nutrition),
                    title: x.nomRepas(t),
                    subtitle: x.estRenomme(t) ? 'À la place de « ${t.label} »' : 'Toucher pour renommer',
                    showChevron: true,
                    onTap: () => _rename(t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TileGroup(label: 'OBJECTIFS ET EAU', children: [
              ListTileX(
                leading: IconHalo(icon: Icons.flag_rounded, color: c.accent),
                title: 'Objectifs',
                subtitle: 'Calories, macros, cyclage',
                showChevron: true,
                onTap: () => NutritionNav.goals(context),
              ),
              ListTileX(
                leading: IconHalo(icon: Icons.local_drink_rounded, color: c.eau),
                title: 'Taille du verre',
                value: '${x.verreMl} ml',
                showChevron: true,
                onTap: () async {
                  final v = await showChoiceDialog<int>(
                    context,
                    title: 'Taille du verre',
                    selected: x.verreMl,
                    options: const [(150, '150 ml'), (200, '200 ml'), (250, '250 ml'), (330, '330 ml (canette)'), (500, '500 ml (bouteille)'), (750, '750 ml (gourde)')],
                  );
                  if (v != null) await x.setVerreMl(v);
                },
              ),
            ]),
            const SizedBox(height: 16),
            TileGroup(label: 'BASE ALIMENTAIRE EN LIGNE', children: [
              ListTileX(
                leading: IconHalo(icon: Icons.travel_explore_rounded, color: c.nutrition),
                title: 'Recherche en ligne',
                subtitle: 'Base ouverte Open Food Facts, en français',
                trailing: Switch(value: x.rechercheEnLigne, onChanged: x.setRechercheEnLigne),
                onTap: () => x.setRechercheEnLigne(!x.rechercheEnLigne),
              ),
              ListTileX(
                leading: IconHalo(icon: Icons.offline_pin_rounded, color: c.nutrition),
                title: 'Produits gardés hors ligne',
                subtitle: 'Relus sans réseau, mis à jour après deux semaines',
                value: _cache == null ? '…' : '$_cache',
                trailing: TextButton(
                  onPressed: (_cache ?? 0) == 0
                      ? null
                      : () async {
                          final ok = await showConfirmDialog(context, title: 'Vider le cache ?', message: 'Les aliments déjà ajoutés au journal restent.', confirmLabel: 'Vider', destructive: true);
                          if (!ok) return;
                          await off.clearCache();
                          await _loadCache();
                          if (context.mounted) Toasts.show(context, 'Cache vidé');
                        },
                  child: const Text('Vider'),
                ),
              ),
              ListTileX(
                leading: IconHalo(icon: Icons.history_rounded, color: c.text3),
                title: 'Recherches récentes',
                value: '${x.recherchesRecentes.length}',
                trailing: TextButton(onPressed: x.recherchesRecentes.isEmpty ? null : x.effacerRecherches, child: const Text('Effacer')),
              ),
            ]),
            const SizedBox(height: 16),
            TileGroup(label: 'MES LISTES', children: [
              ListTileX(leading: IconHalo(icon: Icons.inventory_2_rounded, color: c.nutrition), title: 'Mes aliments', showChevron: true, onTap: () => NutritionNav.myFoods(context)),
              ListTileX(leading: IconHalo(icon: Icons.bookmarks_rounded, color: c.sleep), title: 'Repas enregistrés', showChevron: true, onTap: () => NutritionNav.meals(context)),
              ListTileX(leading: IconHalo(icon: Icons.menu_book_rounded, color: c.weight), title: 'Recettes', showChevron: true, onTap: () => NutritionNav.recipes(context)),
            ]),
            const SizedBox(height: 16),
            TileGroup(children: [
              ListTileX(
                leading: IconHalo(icon: Icons.restart_alt_rounded, color: c.error),
                title: 'Rétablir les réglages',
                subtitle: 'Noms des repas, verre, cyclage, recherche en ligne',
                onTap: () async {
                  final ok = await showConfirmDialog(context, title: 'Rétablir les réglages ?', message: 'Ton journal, tes aliments et tes recettes ne changent pas.', confirmLabel: 'Rétablir', destructive: true);
                  if (!ok) return;
                  await x.reinitialiserReglages();
                  if (context.mounted) Toasts.show(context, 'Réglages rétablis');
                },
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 16, AppTokens.gutter + 4, 0),
              child: Text(
                'Les données des produits viennent d\'Open Food Facts, base collaborative sous licence ODbL. Vérifie l\'étiquette en cas de doute.',
                style: AppType.rowSubtitle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
