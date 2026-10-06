import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_actions.dart';
import 'coach_scope.dart';

CoachActionRunner coachRunner(BuildContext context) => CoachActionRunner(
      exercises: context.read<ExerciseRepo>(),
      routines: context.read<RoutineRepo>(),
      nutrition: context.read<NutritionRepo>(),
      unite: context.read<ProfileRepo>().unite,
    );

/// Action proposée par le coach, validable d'un geste.
class ActionCard extends StatefulWidget {
  const ActionCard({super.key, required this.action, required this.actionKey});

  final CoachAction action;

  /// Identifiant stable (idMessage#rang) pour se souvenir qu'elle est appliquée.
  final String actionKey;

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _busy = false;

  Future<void> _apply() async {
    final runner = coachRunner(context);
    final prefs = context.coachPrefs;
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final res = await runner.apply(widget.action);
      await prefs.markApplied(widget.actionKey);
      if (!mounted) return;
      Toasts.success(
        context,
        res.message,
        actionLabel: res.route == null ? null : 'Voir',
        onAction: res.route == null ? null : () => router.go(res.route!),
      );
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d\'appliquer cette action.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details() async {
    final a = widget.action;
    if (a is! RoutineAction) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => RoutinePreviewDialog(action: a));
    if (ok == true && mounted) await _apply();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = widget.action;
    context.watch<RoutineRepo>();
    context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final runner = coachRunner(context);
    final applied = context.coachPrefs.prefs.actionsAppliquees.contains(widget.actionKey);
    final blocage = applied ? null : runner.blocage(a);

    final subtitle = switch (a) {
      ChargeAction() => [
          if (a.poids != null) Fmt.poids(Fmt.poidsStocke(a.poids!, unite), unite),
          if (a.reps != null) Fmt.pluriel(a.reps!, 'répétition'),
          if (blocage == null && !applied) () {
            final r = runner.routinesPour(a);
            return r.length == 1 ? 'dans « ${r.first.nom} »' : 'dans ${r.length} routines';
          }(),
        ].join(', '),
      _ => a.sousTitre,
    };

    return AppCard(
      color: c.surface2,
      border: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconHalo.domain(a.domain, icon: a.icon, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (a) {
                        RoutineAction() => 'NOUVELLE ROUTINE',
                        ChargeAction() => 'MODIFIER UNE CHARGE',
                        RepasAction() => 'AJOUTER UN REPAS',
                      },
                      style: AppType.overline(color: c.text3),
                    ),
                    const SizedBox(height: 2),
                    Text(a.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
                  ],
                ),
              ),
            ],
          ),
          if (a is RoutineAction && a.exercices.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final e in a.exercices.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 5, color: c.text3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle(color: c.text)),
                    ),
                    const SizedBox(width: 8),
                    Text(e.resume(unite), style: AppType.rowSubtitle().copyWith(fontSize: 13)),
                  ],
                ),
              ),
            if (a.exercices.length > 4)
              Text('et ${Fmt.pluriel(a.exercices.length - 4, 'autre exercice', 'autres exercices')}', style: AppType.rowSubtitle().copyWith(fontSize: 13)),
          ],
          if (a is RepasAction) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TagPill('P ${Fmt.n(a.macros.proteines, decimals: 0)} g', color: AppTokens.domainNutrition),
                TagPill('G ${Fmt.n(a.macros.glucides, decimals: 0)} g', color: AppTokens.domainWeight),
                TagPill('L ${Fmt.n(a.macros.lipides, decimals: 0)} g', color: AppTokens.domainHeart),
                if (a.quantite != null) TagPill('${Fmt.n(a.quantite, decimals: 0)} g'),
              ],
            ),
          ],
          if (blocage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(blocage, style: AppType.rowSubtitle(color: c.warning).copyWith(fontSize: 13))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (applied)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      Flexible(child: Text(a.libelleApplique, style: AppType.rowSubtitle(color: c.accent).copyWith(fontWeight: FontWeight.w700))),
                    ],
                  ),
                )
              else
                Flexible(
                  child: PillButton(
                    label: a.boutonAppliquer,
                    icon: Icons.check_rounded,
                    size: PillSize.small,
                    loading: _busy,
                    onPressed: blocage == null ? _apply : null,
                  ),
                ),
              if (a is RoutineAction && !applied) ...[
                const SizedBox(width: 8),
                PillButton.ghost(label: 'Détails', size: PillSize.small, onPressed: _details),
              ],
              if (applied) ...[
                PillButton.link(
                  label: 'Voir',
                  size: PillSize.small,
                  onPressed: () => context.go(a is RepasAction ? '/nutrition' : '/entrainer/routines'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Aperçu complet d'une routine proposée, avec la correspondance des exercices.
class RoutinePreviewDialog extends StatelessWidget {
  const RoutinePreviewDialog({super.key, required this.action});

  final RoutineAction action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final runner = coachRunner(context);
    final unite = context.read<ProfileRepo>().unite;
    final matches = runner.matches(action);
    final nouveaux = matches.where((m) => m.exercise == null).length;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
              child: Row(
                children: [
                  IconHalo.domain(AppDomain.entrainement, icon: Icons.playlist_add_rounded, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.nom, style: context.textStyles.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(action.sousTitre, style: AppType.rowSubtitle()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (action.notes != null && action.notes!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Text(action.notes!, style: AppType.rowSubtitle()),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: action.exercices.length,
                itemBuilder: (context, i) {
                  final p = action.exercices[i];
                  final m = matches[i].exercise;
                  return ListTileX(
                    dense: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: SizedBox(
                      width: 26,
                      child: Text('${i + 1}', textAlign: TextAlign.center, style: AppType.number(15, color: c.text3)),
                    ),
                    title: m?.nom ?? p.nom,
                    subtitle: [
                      p.resume(unite),
                      if (p.repos != null) 'repos ${Fmt.repos(p.repos!)}',
                      if (m == null) 'sera créé comme exercice personnel',
                    ].join(', '),
                    subtitleColor: m == null ? c.warning : null,
                  );
                },
              ),
            ),
            if (nouveaux > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Text(
                  '${Fmt.pluriel(nouveaux, 'exercice')} introuvable${nouveaux > 1 ? 's' : ''} dans la bibliothèque : '
                  '${nouveaux > 1 ? 'ils seront créés' : 'il sera créé'} dans tes exercices personnels.',
                  style: AppType.rowSubtitle().copyWith(fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PillButton.ghost(label: 'Fermer', onPressed: () => Navigator.of(context).pop(false)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: PillButton(
                      label: 'Ajouter la routine',
                      icon: Icons.check_rounded,
                      onPressed: action.exercices.isEmpty ? null : () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
