import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';
import '../services/rappels_complements.dart';

/// Modèles proposés quand la liste est vide.
const modelesComplements = <String, (String, double, String, String)>{
  'creatine': ('Créatine', 5, 'g', 'Tous les jours, même au repos'),
  'whey': ('Whey', 30, 'g', 'Après la séance ou en collation'),
  'vitamine-d': ('Vitamine D', 1, 'gélule', 'Avec un repas gras'),
  'omega-3': ('Oméga 3', 2, 'gélules', 'Pendant un repas'),
  'magnesium': ('Magnésium', 300, 'mg', 'Le soir'),
  'cafeine': ('Caféine', 200, 'mg', 'Avant la séance, pas après 16 h'),
};

/// Case à cocher d'une prise (accent nutrition, pas le vert des séries).
class CasePrise extends StatelessWidget {
  const CasePrise({super.key, required this.pris, this.size = 26});
  final bool pris;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppTokens.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pris ? c.nutrition : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: pris ? c.nutrition : c.text3, width: 1.8),
      ),
      child: pris ? Icon(Icons.check_rounded, size: size * 0.72, color: Colors.black) : null,
    );
  }
}

String doseTexte(Supplement s) => '${Fmt.n(s.dose, decimals: 2)} ${s.unite}';

/// Compléments : la liste du jour à cocher, les rappels, l'historique.
class ComplementsPage extends StatefulWidget {
  const ComplementsPage({super.key});

  @override
  State<ComplementsPage> createState() => _ComplementsPageState();
}

class _ComplementsPageState extends State<ComplementsPage> {
  DateTime _jour = Dates.jour(DateTime.now());
  String _heureGenerale = '08:00';
  bool _bascule = false;

  @override
  void initState() {
    super.initState();
    RappelsComplements.heureGenerale(context.read<Store>()).then((h) {
      if (mounted) setState(() => _heureGenerale = h);
    });
  }

  Future<void> _rappels(bool v) async {
    setState(() => _bascule = true);
    final store = context.read<Store>();
    final settings = context.read<SettingsRepo>();
    final sante = context.read<HealthRepo>();
    if (v) {
      final ok = await RappelsComplements.activer(store: store, settings: settings, sante: sante);
      if (!ok && mounted) {
        Toasts.show(
          context,
          'Les notifications sont bloquées pour l\'appli.',
          kind: ToastKind.error,
          actionLabel: 'Autoriser',
          onAction: RappelsComplements.ouvrirReglagesSysteme,
        );
      }
    } else {
      await RappelsComplements.desactiver(store: store, settings: settings, sante: sante);
    }
    if (mounted) setState(() => _bascule = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final actifs = repo.activeSupplements;
    final pause = repo.supplements.where((s) => !s.actif).toList();
    final today = Dates.jour(DateTime.now());
    final pris = actifs.where((s) => repo.takenOn(s.id, _jour)).length;

    return SubPageScaffold(
      title: 'Compléments',
      haloColor: c.nutrition,
      actions: [RoundIconButton(icon: Icons.add_rounded, tooltip: 'Ajouter', onPressed: () => context.push('/sante/complements/ajouter'))],
      body: repo.supplements.isEmpty
          ? ListView(
              padding: const EdgeInsets.only(top: 24, bottom: 32),
              children: [
                EmptyState(
                  icon: Icons.medication_rounded,
                  iconColor: c.nutrition,
                  title: 'Aucun complément suivi',
                  message: 'Ajoutez ce que vous prenez, cochez chaque jour, recevez un rappel à l\'heure choisie.',
                  actionLabel: 'Ajouter un complément',
                  onAction: () => context.push('/sante/complements/ajouter'),
                ),
                const SizedBox(height: 8),
                TileGroup(
                  label: 'Les plus courants',
                  children: [
                    for (final e in modelesComplements.entries)
                      ListTileX(
                        leading: IconHalo(icon: Icons.add_rounded, color: c.nutrition, size: 38, glow: false),
                        title: e.value.$1,
                        subtitle: e.value.$4,
                        value: '${Fmt.n(e.value.$2)} ${e.value.$3}',
                        showChevron: true,
                        onTap: () => context.push('/sante/complements/ajouter?modele=${e.key}'),
                      ),
                  ],
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                Padding(
                  padding: santePad,
                  child: StepSelector(
                    label: Fmt.relatif(_jour) == 'Aujourd\'hui' ? 'Aujourd\'hui' : Fmt.jourCap(_jour),
                    onPrevious: () => setState(() => _jour = _jour.subtract(const Duration(days: 1))),
                    onNext: _jour.isBefore(today) ? () => setState(() => _jour = DateTime(_jour.year, _jour.month, _jour.day + 1)) : null,
                    onTapLabel: () async {
                      final d = await choisirDate(context, _jour, last: today);
                      if (d != null) setState(() => _jour = Dates.jour(d));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  margin: santePad,
                  label: 'Prises du jour',
                  labelTrailing: LabelCount('$pris / ${actifs.length}'),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProgressBar(value: actifs.isEmpty ? 0 : pris / actifs.length, color: c.nutrition),
                      const SizedBox(height: 6),
                      if (actifs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Tous vos compléments sont en pause.', style: AppType.rowSubtitle()),
                        ),
                      for (final s in actifs)
                        ListTileX(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          leading: CasePrise(pris: repo.takenOn(s.id, _jour)),
                          title: s.nom,
                          subtitle: [doseTexte(s), if (s.heures.isNotEmpty) s.heures.join(', ')].join(' · '),
                          trailing: IconButton(
                            tooltip: 'Détail',
                            icon: Icon(Icons.chevron_right_rounded, color: c.text3),
                            onPressed: () => context.push('/sante/complements/${s.id}'),
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            repo.toggleIntake(s.id, _jour);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  margin: santePad,
                  label: '30 derniers jours',
                  child: _Calendrier(jours: 30, supplements: actifs),
                ),
                const SizedBox(height: 12),
                TileGroup(
                  label: 'Rappels',
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 2, vertical: 4),
                      secondary: IconHalo(icon: Icons.notifications_rounded, color: c.nutrition, size: 38),
                      title: Text('Me le rappeler', style: AppType.rowTitle()),
                      subtitle: Text(
                        settings.rappelsComplements
                            ? 'Une notification à chaque heure choisie, $_heureGenerale pour les compléments sans heure'
                            : 'Désactivés',
                        style: AppType.rowSubtitle(),
                      ),
                      value: settings.rappelsComplements,
                      onChanged: _bascule ? null : _rappels,
                    ),
                    ListTileX(
                      leading: IconHalo(icon: Icons.tune_rounded, color: c.text2, size: 38),
                      title: 'Heure générale et autres rappels',
                      subtitle: 'Réglages des notifications',
                      showChevron: true,
                      onTap: () => context.push('/reglages/notifications'),
                    ),
                  ],
                ),
                if (pause.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TileGroup(
                    label: 'En pause',
                    children: [
                      for (final s in pause)
                        ListTileX(
                          leading: IconHalo(icon: Icons.pause_rounded, color: c.nutrition, size: 38, off: true),
                          title: s.nom,
                          subtitle: doseTexte(s),
                          showChevron: true,
                          onTap: () => context.push('/sante/complements/${s.id}'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Grille des derniers jours : plus la case est pleine, plus il y a eu de prises.
class _Calendrier extends StatelessWidget {
  const _Calendrier({required this.jours, required this.supplements});
  final int jours;
  final List<Supplement> supplements;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final today = Dates.jour(DateTime.now());
    final liste = [for (var i = jours - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    if (supplements.isEmpty) return Text('Rien à suivre pour l\'instant.', style: AppType.rowSubtitle());
    final complets = liste.where((d) => supplements.every((s) => repo.takenOn(s.id, d))).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, box) {
          const gap = 5.0;
          final parLigne = box.maxWidth < 360 ? 10 : 15;
          final taille = (box.maxWidth - gap * (parLigne - 1)) / parLigne;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final d in liste)
                Tooltip(
                  message: '${Fmt.jourMois(d)} : ${supplements.where((s) => repo.takenOn(s.id, d)).length} / ${supplements.length}',
                  child: Container(
                    width: taille,
                    height: taille,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(taille * 0.3),
                      color: Color.lerp(c.veil2, c.nutrition, supplements.where((s) => repo.takenOn(s.id, d)).length / supplements.length),
                      border: d == today ? Border.all(color: c.text2, width: 1.4) : null,
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 12),
        Text('$complets ${complets > 1 ? 'jours complets' : 'jour complet'} sur $jours', style: AppType.rowSubtitle()),
      ],
    );
  }
}

/// Détail d'un complément : série, régularité, historique.
class ComplementPage extends StatelessWidget {
  const ComplementPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final s = repo.supplements.where((x) => x.id == id).firstOrNull;
    if (s == null) {
      return SubPageScaffold(
        title: 'Complément',
        haloColor: c.nutrition,
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            iconColor: c.nutrition,
            title: 'Complément introuvable',
            message: 'Il a peut-être été supprimé.',
            actionLabel: 'Mes compléments',
            onAction: () => context.go('/sante/complements'),
          ),
        ),
      );
    }
    final today = Dates.jour(DateTime.now());
    final serie = SanteCalc.serie((d) => repo.takenOn(s.id, d));
    final sur30 = [for (var i = 0; i < 30; i++) today.subtract(Duration(days: i))].where((d) => repo.takenOn(s.id, d)).length;
    final semaines = [for (var i = 55; i >= 0; i--) today.subtract(Duration(days: i))];
    final historique = [
      for (var i = 0; i < 60; i++)
        for (final p in repo.intakesFor(today.subtract(Duration(days: i))).where((p) => p.supplementId == s.id)) p,
    ];

    return SubPageScaffold(
      title: s.nom,
      subtitle: '${doseTexte(s)}${s.actif ? '' : ' · en pause'}',
      haloColor: c.nutrition,
      actions: [
        RoundIconButton(icon: Icons.edit_rounded, filled: false, tooltip: 'Modifier', onPressed: () => context.push('/sante/complements/${s.id}/modifier')),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          AppCard(
            margin: santePad,
            onTap: s.actif ? () => repo.toggleIntake(s.id, today) : null,
            child: Row(
              children: [
                CasePrise(pris: repo.takenOn(s.id, today), size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(repo.takenOn(s.id, today) ? 'Pris aujourd\'hui' : 'Pas encore pris aujourd\'hui', style: AppType.rowTitle()),
                      Text(s.actif ? 'Touchez pour cocher ou décocher' : 'En pause : reprenez-le pour le cocher', style: AppType.rowSubtitle()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            margin: santePad,
            child: Row(
              children: [
                Expanded(child: MiniChiffre(label: 'Série', value: '$serie', unit: serie > 1 ? 'jours' : 'jour', color: c.nutrition)),
                Expanded(child: MiniChiffre(label: 'Sur 30 jours', value: '${(sur30 / 30 * 100).round()}', unit: '%', caption: '$sur30 prises')),
                Expanded(child: MiniChiffre(label: 'Rappel', value: s.heures.isEmpty ? '-' : s.heures.first, caption: s.heures.length > 1 ? '+ ${s.heures.length - 1}' : null)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            margin: santePad,
            label: '8 dernières semaines',
            child: Column(
              children: [
                Row(
                  children: [
                    for (final l in Dates.initiales)
                      Expanded(child: Text(l, textAlign: TextAlign.center, style: AppType.rowSubtitle().copyWith(fontSize: 10.5))),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  children: [
                    for (var i = 0; i < semaines.first.weekday - 1; i++) const SizedBox(),
                    for (final d in semaines)
                      GestureDetector(
                        onTap: d.isAfter(today) ? null : () => repo.toggleIntake(s.id, d),
                        child: Container(
                          decoration: BoxDecoration(
                            color: repo.takenOn(s.id, d) ? c.nutrition : c.veil2,
                            borderRadius: BorderRadius.circular(6),
                            border: d == today ? Border.all(color: c.text2, width: 1.4) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text('${d.day}', style: AppType.rowSubtitle(color: repo.takenOn(s.id, d) ? Colors.black : c.text3).copyWith(fontSize: 10)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Touchez un jour pour corriger un oubli.', style: AppType.rowSubtitle()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.notes != null && s.notes!.isNotEmpty) ...[
            AppCard(margin: santePad, label: 'Note', child: Text(s.notes!, style: AppType.rowSubtitle().copyWith(fontSize: 14))),
            const SizedBox(height: 12),
          ],
          TileGroup(
            label: 'Historique',
            labelTrailing: LabelCount(Fmt.pluriel(historique.length, 'prise')),
            children: historique.isEmpty
                ? [const ListTileX(title: 'Aucune prise sur 60 jours')]
                : [
                    for (final p in historique.take(20))
                      ListTileX(
                        dense: true,
                        title: Fmt.jourCap(p.date),
                        value: Fmt.heure(p.date),
                        trailing: IconButton(
                          tooltip: 'Retirer',
                          icon: Icon(Icons.close_rounded, color: c.text3, size: 18),
                          onPressed: () => repo.toggleIntake(s.id, p.date),
                        ),
                      ),
                  ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: santePad,
            child: PillButton.secondary(
              label: s.actif ? 'Mettre en pause' : 'Reprendre',
              icon: s.actif ? Icons.pause_rounded : Icons.play_arrow_rounded,
              expand: true,
              onPressed: () async {
                await repo.saveSupplement(s.copyWith(actif: !s.actif));
                if (!context.mounted) return;
                await RappelsComplements.replanifier(store: context.read<Store>(), settings: context.read<SettingsRepo>(), sante: repo);
              },
            ),
          ),
        ],
      ),
    );
  }
}
