import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../data/import_journal.dart';
import '../widgets/import_widgets.dart';
import 'resume_page.dart' show cheminHistorique;

String _libelleMode(String m) => switch (m) {
      'remplacerImportees' => 'Remplace les imports précédents',
      'remplacerTout' => 'Remplace tout l\'historique',
      _ => 'Ajouté à l\'historique',
    };

/// `/import/journal` : imports précédents.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late Future<List<ImportJournalEntry>> _f = ImportJournal.lire(context.read<Store>());

  void _recharger() => setState(() => _f = ImportJournal.lire(context.read<Store>()));

  Future<void> _menu() async {
    final store = context.read<Store>();
    final choix = await showActionMenu<String>(
      context,
      title: 'Journal des imports',
      items: const [
        ActionMenuItem(value: 'correspondances', label: 'Oublier les correspondances de noms', icon: Icons.link_off_rounded),
        ActionMenuItem(value: 'vider', label: 'Vider le journal', icon: Icons.delete_sweep_rounded, destructive: true),
      ],
    );
    if (!mounted || choix == null) return;
    if (choix == 'correspondances') {
      final ok = await showConfirmDialog(
        context,
        title: 'Oublier les correspondances ?',
        message: 'Les noms que tu as associés à des exercices ne seront plus reconnus d\'office au prochain import. Tes séances ne changent pas.',
        confirmLabel: 'Oublier',
        destructive: true,
      );
      if (!ok) return;
      await ImportJournal.oublierCorrespondances(store);
      if (mounted) Toasts.success(context, 'Correspondances oubliées');
    } else {
      final ok = await showConfirmDialog(
        context,
        title: 'Vider le journal ?',
        message: 'Les séances importées restent dans ton historique, mais ces imports ne pourront plus être annulés d\'un coup.',
        confirmLabel: 'Vider',
        destructive: true,
      );
      if (!ok) return;
      await ImportJournal.vider(store);
      if (mounted) {
        Toasts.success(context, 'Journal vidé');
        _recharger();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageImport(
      title: 'Imports précédents',
      actions: [IconButton(tooltip: 'Plus d\'options', icon: const Icon(Icons.more_vert_rounded), onPressed: _menu)],
      body: FutureBuilder<List<ImportJournalEntry>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 5));
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Journal illisible',
              message: 'Le fichier du journal n\'a pas pu être lu.',
              actionLabel: 'Réessayer',
              onAction: _recharger,
            );
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.history_rounded,
              title: 'Aucun import',
              message: 'Quand tu importes un historique, il apparaît ici et peut être annulé.',
              actionLabel: 'Importer un historique',
              onAction: () {
                ImportFlow.instance.demarrer(ImportSource.application);
                context.push('/import/fichier');
              },
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 32),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTileX(
                leading: IconHalo(icon: Icons.history_rounded),
                title: e.fichier,
                subtitle: '${Fmt.jourCap(e.date)} · ${Fmt.pluriel(e.seanceIds.length, 'séance')}',
                showChevron: true,
                onTap: () async {
                  await context.push('/import/journal/${e.id}');
                  if (mounted) _recharger();
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// `/import/journal/:id` : détail d'un import, avec annulation.
class JournalDetailPage extends StatefulWidget {
  const JournalDetailPage({super.key, required this.id});
  final String id;

  @override
  State<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends State<JournalDetailPage> {
  late final Future<List<ImportJournalEntry>> _f = ImportJournal.lire(context.read<Store>());
  bool _enCours = false;

  Future<void> _annuler(ImportJournalEntry e, int presentes) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Annuler cet import ?',
      message: '${Fmt.pluriel(presentes, 'séance sera supprimée', 'séances seront supprimées')} de ton historique'
          '${e.exercicesCrees.isEmpty ? '' : ', et les exercices perso créés pour elles s\'ils ne servent plus'}.',
      confirmLabel: 'Annuler l\'import',
      cancelLabel: 'Garder',
      destructive: true,
      icon: Icons.undo_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _enCours = true);
    final r = await ImportFlow.annulerImport(context.read<AppData>(), e);
    if (!mounted) return;
    Toasts.success(context, '${Fmt.pluriel(r.seances, 'séance supprimée', 'séances supprimées')}'
        '${r.exercices > 0 ? ', ${Fmt.pluriel(r.exercices, 'exercice perso retiré', 'exercices perso retirés')}' : ''}');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    return FutureBuilder<List<ImportJournalEntry>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const PageImport(title: 'Import', body: Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 4)));
        }
        final e = (snap.data ?? const <ImportJournalEntry>[]).where((x) => x.id == widget.id).firstOrNull;
        if (e == null) {
          return PageImport(
            title: 'Import',
            body: EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Import introuvable',
              message: 'Il a peut-être été annulé ou le journal a été vidé.',
              actionLabel: 'Voir les imports',
              onAction: () => context.pushReplacement('/import/journal'),
            ),
          );
        }
        final ids = e.seanceIds.toSet();
        final presentes = sessions.sessions.where((s) => ids.contains(s.id)).toList();
        return PageImport(
          title: e.fichier,
          subtitle: 'Importé le ${Fmt.date(e.date)} à ${Fmt.heure(e.date)}',
          bottomBar: PillButton(
            label: 'Annuler cet import',
            icon: Icons.undo_rounded,
            variant: PillVariant.danger,
            expand: true,
            loading: _enCours,
            onPressed: _enCours ? null : () => _annuler(e, presentes.length),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              padded(GrilleStats(items: [
                (label: 'Séances importées', valeur: '${e.seanceIds.length}', unite: null, icon: Icons.fitness_center_rounded),
                (label: 'Encore présentes', valeur: '${presentes.length}', unite: null, icon: Icons.inventory_2_outlined),
                (label: 'Séries', valeur: Fmt.n(e.series, decimals: 0), unite: null, icon: Icons.format_list_numbered_rounded),
                (label: 'Perso créés', valeur: '${e.exercicesCrees.length}', unite: null, icon: Icons.add_circle_outline_rounded),
              ])),
              const SizedBox(height: 12),
              padded(AppCard(
                label: 'Détails',
                child: Column(
                  children: [
                    _ligne('Format', e.format),
                    _ligne('Mode', _libelleMode(e.mode)),
                    _ligne('Période', periode(e.debut, e.fin)),
                    if (e.doublons > 0) _ligne('Doublons ignorés', '${e.doublons}'),
                    if (e.remplacees > 0) _ligne('Séances remplacées', '${e.remplacees}'),
                  ],
                ),
              )),
              if (presentes.isNotEmpty) ...[
                SectionHeader(
                  title: 'Séances',
                  trailing: LabelCount(Fmt.pluriel(presentes.length, 'séance')),
                ),
                TileGroup(
                  children: [
                    for (final s in presentes.take(8))
                      ListTileX(
                        leading: IconHalo(icon: Icons.fitness_center_rounded, size: 36),
                        title: s.nom,
                        subtitle: Fmt.jourCap(s.debut),
                        value: Fmt.pluriel(s.nbSeriesFaites, 'série'),
                        showChevron: true,
                        onTap: () => context.push('$cheminHistorique/${s.id}'),
                      ),
                  ],
                ),
                if (presentes.length > 8)
                  padded(Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AccentLink(label: 'Tout l\'historique', onTap: () => context.push(cheminHistorique)),
                  )),
              ] else
                padded(const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Encart(texte: 'Toutes les séances de cet import ont déjà été supprimées de ton historique.'),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: AppType.rowSubtitle().copyWith(fontSize: 14))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: Text(valeur, textAlign: TextAlign.right, style: AppType.rowValue().copyWith(fontSize: 14))),
          ],
        ),
      );
}
