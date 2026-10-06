import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';
import 'corps_page.dart';

enum _Action { modifier, supprimer }

/// Toutes les mesures, la plus récente d'abord.
class MesuresPage extends StatefulWidget {
  const MesuresPage({super.key});

  @override
  State<MesuresPage> createState() => _MesuresPageState();
}

class _MesuresPageState extends State<MesuresPage> {
  String _filtre = 'tout';

  Future<void> _menu(BuildContext context, BodyMeasurement m) async {
    final a = await showActionMenu<_Action>(
      context,
      title: Fmt.jourCap(m.date),
      items: const [
        ActionMenuItem(value: _Action.modifier, label: 'Modifier', icon: Icons.edit_rounded),
        ActionMenuItem(value: _Action.supprimer, label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!context.mounted || a == null) return;
    if (a == _Action.modifier) {
      context.push('/sante/corps/mesure?id=${m.id}');
      return;
    }
    final ok = await showConfirmDialog(context, title: 'Supprimer cette mesure ?', confirmLabel: 'Supprimer', destructive: true, icon: Icons.delete_outline_rounded);
    if (!ok || !context.mounted) return;
    final repo = context.read<HealthRepo>();
    await repo.deleteMeasurement(m.id);
    if (context.mounted) Toasts.show(context, 'Mesure supprimée', actionLabel: 'Annuler', onAction: () => repo.saveMeasurement(m));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unite = context.watch<ProfileRepo>().unite;
    final toutes = context.watch<HealthRepo>().measurements;
    final liste = switch (_filtre) {
      'poids' => toutes.where((m) => m.poidsKg != null).toList(),
      'tours' => toutes.where((m) => m.tours.isNotEmpty).toList(),
      _ => toutes,
    };
    return SubPageScaffold(
      title: 'Historique des mesures',
      subtitle: Fmt.pluriel(toutes.length, 'mesure'),
      haloColor: c.weight,
      actions: [RoundIconButton(icon: Icons.add_rounded, tooltip: 'Nouvelle mesure', onPressed: () => context.push('/sante/corps/mesure'))],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 8),
            child: SegmentedChips<String>(
              segments: const [('tout', 'Tout'), ('poids', 'Pesées'), ('tours', 'Mensurations')],
              value: _filtre,
              onChanged: (v) => setState(() => _filtre = v),
            ),
          ),
          Expanded(
            child: liste.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.monitor_weight_rounded,
                      iconColor: c.weight,
                      title: 'Aucune mesure',
                      message: 'Vos pesées et vos tours s\'afficheront ici.',
                      actionLabel: 'Nouvelle mesure',
                      onAction: () => context.push('/sante/corps/mesure'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: liste.length,
                    itemBuilder: (context, i) {
                      final m = liste[i];
                      final prec = liste.skip(i + 1).where((x) => x.poidsKg != null).firstOrNull;
                      final delta = m.poidsKg != null && prec?.poidsKg != null ? m.poidsKg! - prec!.poidsKg! : null;
                      final details = [
                        if (m.masseGrassePct != null) '${Fmt.n(m.masseGrassePct)} % MG',
                        if (m.tours.isNotEmpty) Fmt.pluriel(m.tours.length, 'tour'),
                        if (m.source == 'health connect') 'Health Connect',
                      ];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 6),
                        child: Material(
                          color: c.surface,
                          borderRadius: AppTokens.radius14,
                          clipBehavior: Clip.antiAlias,
                          child: ListTileX(
                            leading: IconHalo(
                              icon: m.poidsKg != null ? Icons.monitor_weight_rounded : Icons.straighten_rounded,
                              color: c.weight,
                              size: 38,
                              glow: false,
                            ),
                            title: '${Fmt.jourCap(m.date)} · ${Fmt.heure(m.date)}',
                            subtitle: [
                              if (delta != null) '${signe(Fmt.poidsAffiche(delta, unite))} ${unite.label}',
                              ...details,
                            ].join(' · '),
                            value: m.poidsKg == null ? null : Fmt.poids(m.poidsKg, unite),
                            showChevron: true,
                            onTap: () => context.push('/sante/corps/mesure?id=${m.id}'),
                            onLongPress: () => _menu(context, m),
                            trailing: IconButton(
                              tooltip: 'Actions',
                              icon: Icon(Icons.more_vert_rounded, color: c.text3, size: 20),
                              onPressed: () => _menu(context, m),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Toutes les mensurations, avec leur évolution.
class MensurationsPage extends StatelessWidget {
  const MensurationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mesures = context.watch<HealthRepo>().measurements;
    final avec = [for (final g in GroupeTour.values) if (g.serie(mesures).isNotEmpty) g];
    final sans = [for (final g in GroupeTour.values) if (g.serie(mesures).isEmpty) g];
    final derniere = mesures.where((m) => m.tours.isNotEmpty).firstOrNull;
    return SubPageScaffold(
      title: 'Mensurations',
      subtitle: derniere == null ? null : 'Dernier relevé ${Fmt.relatif(derniere.date).toLowerCase()}',
      haloColor: c.weight,
      actions: [RoundIconButton(icon: Icons.add_rounded, tooltip: 'Mesurer', onPressed: () => context.push('/sante/corps/mesure?tours=1'))],
      body: avec.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.straighten_rounded,
                iconColor: c.weight,
                title: 'Aucun tour mesuré',
                message: 'Un mètre ruban de couturière suffit. Mesurez toujours au même endroit, le matin.',
                actionLabel: 'Mesurer maintenant',
                onAction: () => context.push('/sante/corps/mesure?tours=1'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                TileGroup(
                  label: 'Suivies',
                  children: [for (final g in avec) LigneTour(groupe: g, serie: g.serie(mesures), color: c.weight)],
                ),
                if (sans.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TileGroup(
                    label: 'Pas encore mesurées',
                    children: [
                      for (final g in sans)
                        ListTileX(
                          leading: IconHalo(icon: Icons.straighten_rounded, color: c.weight, size: 38, off: true),
                          title: g.label,
                          subtitle: g.conseil,
                          showChevron: true,
                          onTap: () => context.push('/sante/corps/mesure?tours=1'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Détail d'une mensuration : courbe et relevés.
class TourPage extends StatefulWidget {
  const TourPage({super.key, required this.groupe});
  final GroupeTour groupe;

  @override
  State<TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<TourPage> {
  Periode _periode = Periode.annee;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = widget.groupe;
    final mesures = context.watch<HealthRepo>().measurements;
    final tous = g.serie(mesures);
    final pts = g.serie(mesures, depuis: _periode.debut());
    final releves = mesures.where((m) => g.valeur(m) != null).toList();
    final delta = SanteCalc.variation(tous);
    final bien = delta == null || delta == 0 ? null : (g.baisserEstBien ? delta < 0 : delta > 0);
    return SubPageScaffold(
      title: g.label,
      haloColor: c.weight,
      actions: [RoundIconButton(icon: Icons.add_rounded, tooltip: 'Nouveau relevé', onPressed: () => context.push('/sante/corps/mesure?tours=1'))],
      body: tous.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.straighten_rounded,
                iconColor: c.weight,
                title: 'Pas encore de relevé',
                message: g.conseil,
                actionLabel: 'Mesurer',
                onAction: () => context.push('/sante/corps/mesure?tours=1'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                AppCard(
                  margin: santePad,
                  child: BigNumber(
                    value: Fmt.n(tous.last.v),
                    unit: 'cm',
                    label: g.deuxCotes ? 'Moyenne gauche et droite' : 'Dernier relevé',
                    caption: delta == null ? Fmt.date(tous.last.date) : '${signe(delta)} cm depuis le ${Fmt.date(tous.first.date)}',
                    captionColor: bien == true ? c.accent : null,
                    footer: Text(g.conseil, style: AppType.rowSubtitle()),
                  ),
                ),
                const SizedBox(height: 12),
                CarteCourbe(
                  label: 'Évolution',
                  periode: _periode,
                  periodes: const [Periode.mois, Periode.trimestre, Periode.annee],
                  onPeriode: (p) => setState(() => _periode = p),
                  child: SanteCourbe(points: pts, debut: _periode.debut(), fin: DateTime.now(), color: c.weight, format: (v) => Fmt.n(v)),
                ),
                const SizedBox(height: 12),
                TileGroup(
                  label: 'Relevés',
                  labelTrailing: LabelCount(Fmt.pluriel(releves.length, 'relevé')),
                  children: [
                    for (final m in releves)
                      ListTileX(
                        title: Fmt.jourCap(m.date),
                        subtitle: g.deuxCotes
                            ? 'Gauche ${m.tours[g.tours[0]] == null ? '-' : Fmt.n(m.tours[g.tours[0]])} · Droite ${m.tours[g.tours[1]] == null ? '-' : Fmt.n(m.tours[g.tours[1]])}'
                            : null,
                        value: '${Fmt.n(g.valeur(m))} cm',
                        showChevron: true,
                        onTap: () => context.push('/sante/corps/mesure?id=${m.id}'),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
