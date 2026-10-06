import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_actions.dart';
import '../widgets/coach_scope.dart';
import 'chat_page.dart';

/// Toutes les conversations, groupées par date, avec recherche.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _query = '';

  Future<void> _options(Conversation c) async {
    final repo = context.read<CoachRepo>();
    final choix = await showActionMenu<String>(
      context,
      title: c.titre,
      items: [
        const ActionMenuItem(value: 'ouvrir', label: 'Ouvrir', icon: Icons.chat_bubble_outline_rounded),
        const ActionMenuItem(value: 'renommer', label: 'Renommer', icon: Icons.edit_rounded),
        ActionMenuItem(
          value: 'epingler',
          label: c.epinglee ? 'Désépingler' : 'Épingler en haut',
          icon: c.epinglee ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        ),
        const ActionMenuItem(value: 'supprimer', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted || choix == null) return;
    switch (choix) {
      case 'ouvrir':
        openCoachChat(context, id: c.id);
      case 'renommer':
        final t = await showTextInputDialog(context, title: 'Renommer la conversation', initial: c.titre, maxLength: 60);
        if (t != null && t.trim().isNotEmpty) await repo.rename(c.id, t.trim());
      case 'epingler':
        await repo.togglePin(c.id);
      case 'supprimer':
        final ok = await showConfirmDialog(
          context,
          title: 'Supprimer « ${c.titre} » ?',
          message: 'Les messages seront effacés du téléphone.',
          confirmLabel: 'Supprimer',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !mounted) return;
        context.coachEngine.stop(c.id);
        await repo.delete(c.id);
        if (mounted) Toasts.show(context, 'Conversation supprimée.');
    }
  }

  Future<void> _toutEffacer() async {
    final repo = context.read<CoachRepo>();
    final ok = await showConfirmDialog(
      context,
      title: 'Effacer tout l\'historique ?',
      message: 'Toutes les conversations avec le coach seront supprimées du téléphone. Cette action est définitive.',
      confirmLabel: 'Tout effacer',
      destructive: true,
      icon: Icons.delete_sweep_rounded,
    );
    if (!ok || !mounted) return;
    for (final c in repo.conversations) {
      context.coachEngine.stop(c.id);
    }
    await repo.clear();
    if (mounted) Toasts.show(context, 'Historique effacé.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = context.watch<CoachRepo>().conversations;
    final q = _query.trim();
    final list = q.isEmpty
        ? all
        : all.where((x) => TextSearch.matches(q, [x.titre, ...x.messages.map((m) => m.texte)])).toList();

    final now = DateTime.now();
    final groupes = <String, List<Conversation>>{};
    for (final x in list) {
      final d = Dates.jour(x.derniereActivite);
      final ecart = Dates.jour(now).difference(d).inDays;
      final g = x.epinglee
          ? 'Épinglées'
          : ecart == 0
              ? 'Aujourd\'hui'
              : ecart == 1
                  ? 'Hier'
                  : ecart < 7
                      ? 'Cette semaine'
                      : ecart < 31
                          ? 'Ce mois-ci'
                          : Fmt.mois(d);
      (groupes[g] ??= []).add(x);
    }

    Widget body;
    if (all.isEmpty) {
      body = EmptyState(
        icon: Icons.forum_outlined,
        iconColor: AppTokens.domainCoach,
        title: 'Aucune conversation',
        message: 'Pose ta première question au coach : tes échanges seront gardés ici, sur ton téléphone.',
        actionLabel: 'Nouvelle conversation',
        onAction: () => openCoachChat(context),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 4),
            child: SearchField(hint: 'Rechercher dans les conversations', onChanged: (v) => setState(() => _query = v)),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun résultat',
                message: 'Aucune conversation ne contient « $q ».',
                compact: true,
              ),
            ),
          for (final g in groupes.entries) ...[
            const SizedBox(height: 14),
            TileGroup(
              label: g.key,
              labelTrailing: LabelCount(Fmt.pluriel(g.value.length, 'conversation')),
              children: [
                for (final x in g.value)
                  ListTileX(
                    leading: IconHalo(
                      icon: x.epinglee ? Icons.push_pin_rounded : Icons.chat_bubble_rounded,
                      color: AppTokens.domainCoach,
                      size: 40,
                    ),
                    title: x.titre,
                    subtitle: _apercu(x),
                    value: Dates.jour(now).difference(Dates.jour(x.derniereActivite)).inDays <= 1
                        ? Fmt.heure(x.derniereActivite)
                        : Fmt.jourMois(x.derniereActivite),
                    valueColor: c.text3,
                    onTap: () => openCoachChat(context, id: x.id),
                    onLongPress: () => _options(x),
                    trailing: IconButton(
                      tooltip: 'Options',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _options(x),
                      icon: Icon(Icons.more_horiz_rounded, color: c.text3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return SubPageScaffold(
      title: 'Historique',
      subtitle: all.isEmpty ? null : Fmt.pluriel(all.length, 'conversation'),
      actions: [
        if (all.isNotEmpty)
          IconButton(
            tooltip: 'Tout effacer',
            onPressed: _toutEffacer,
            icon: Icon(Icons.delete_sweep_outlined, color: c.text),
          ),
        IconButton(
          tooltip: 'Nouvelle conversation',
          onPressed: () => openCoachChat(context),
          icon: Icon(Icons.add_comment_rounded, color: c.text),
        ),
      ],
      body: body,
    );
  }

  String _apercu(Conversation x) {
    final m = x.messages.lastWhere((m) => m.texte.trim().isNotEmpty, orElse: () => CoachMessage(id: '', role: CoachRole.coach, texte: '', date: x.creeLe));
    if (m.texte.isEmpty) return 'Conversation vide';
    final t = CoachAction.parse(m.texte).texte.replaceAll(RegExp(r'[*_#>`]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return '${m.role == CoachRole.utilisateur ? 'Toi : ' : ''}$t';
  }
}
