import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/format.dart';
import '../../../core/logic/text_search.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

enum _Filtre { toutes, nouvelles, doublons }

/// `/import/apercu/seances` : toutes les séances lues dans le fichier.
class SeancesLuesPage extends StatefulWidget {
  const SeancesLuesPage({super.key});

  @override
  State<SeancesLuesPage> createState() => _SeancesLuesPageState();
}

class _SeancesLuesPageState extends State<SeancesLuesPage> {
  final _ctrl = TextEditingController();
  String _q = '';
  _Filtre _filtre = _Filtre.toutes;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ImportFlow.instance.preview;
    if (p == null) return const SansFichier(titre: 'Séances du fichier');
    final toutes = p.seances;
    final doublons = toutes.where((s) => s.doublon).length;
    final indexes = <int>[
      for (var i = toutes.length - 1; i >= 0; i--)
        if ((_filtre == _Filtre.toutes ||
                (_filtre == _Filtre.doublons) == toutes[i].doublon) &&
            (_q.isEmpty ||
                TextSearch.score(_q, toutes[i].titre, [for (final e in toutes[i].exercices) e.nomSource]) > 0))
          i,
    ];
    return SubPageScaffold(
      title: 'Séances du fichier',
      subtitle: Fmt.pluriel(toutes.length, 'séance'),
      body: Column(
        children: [
          padded(SearchField(
            controller: _ctrl,
            hint: 'Séance ou exercice',
            onChanged: (v) => setState(() => _q = v.trim()),
          )),
          const SizedBox(height: 10),
          ChipFilterBar<_Filtre>(
            options: [
              (_Filtre.toutes, 'Toutes (${toutes.length})'),
              (_Filtre.nouvelles, 'À importer (${toutes.length - doublons})'),
              if (doublons > 0) (_Filtre.doublons, 'Déjà présentes ($doublons)'),
            ],
            selected: {_filtre},
            onChanged: (s) => setState(() => _filtre = s.isEmpty ? _Filtre.toutes : s.first),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: indexes.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucune séance',
                    message: _q.isEmpty ? 'Rien dans ce filtre.' : 'Aucune séance ne correspond à « $_q ».',
                    compact: true,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 32),
                    itemCount: indexes.length,
                    itemBuilder: (context, k) {
                      final i = indexes[k];
                      final s = toutes[i];
                      return ListTileX(
                        leading: IconHalo(
                          icon: s.doublon ? Icons.content_copy_rounded : Icons.fitness_center_rounded,
                          off: s.doublon,
                        ),
                        title: s.titre,
                        subtitle: '${Fmt.jourCap(s.debut)} ${Fmt.heure(s.debut)}'
                            '${s.doublon ? ' · déjà présente' : ''}',
                        value: Fmt.pluriel(s.nombreSeries, 'série'),
                        showChevron: true,
                        onTap: () => context.push('/import/apercu/seances/$i'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// `/import/apercu/seances/:index` : détail d'une séance lue.
class SeanceLuePage extends StatelessWidget {
  const SeanceLuePage({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final flow = ImportFlow.instance;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final p = flow.preview;
        if (p == null) return const SansFichier(titre: 'Séance');
        if (index < 0 || index >= p.seances.length) {
          return SubPageScaffold(
            title: 'Séance',
            body: EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Séance introuvable',
              message: 'Le fichier a changé depuis.',
              actionLabel: 'Voir toutes les séances',
              onAction: () => context.pushReplacement('/import/apercu/seances'),
            ),
          );
        }
        final s = p.seances[index];
        final c = context.colors;
        final unite = flow.unite == UniteCharge.lb ? 'lb' : 'kg';
        double aff(double kg) => flow.unite == UniteCharge.lb ? kg / livreEnKg : kg;
        return SubPageScaffold(
          title: s.titre,
          subtitle: '${Fmt.jourCap(s.debut)} à ${Fmt.heure(s.debut)}',
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (s.doublon)
                padded(const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Encart(
                    texte: 'Une séance commence déjà à cette minute dans ton historique : celle-ci ne sera pas importée.',
                    titre: 'Déjà présente',
                  ),
                )),
              padded(GrilleStats(items: [
                (label: 'Durée', valeur: s.duree == null ? '-' : Fmt.duree(s.duree!), unite: null, icon: Icons.timer_outlined),
                (label: 'Exercices', valeur: '${s.exercices.length}', unite: null, icon: Icons.fitness_center_rounded),
                (label: 'Séries', valeur: '${s.nombreSeries}', unite: null, icon: Icons.format_list_numbered_rounded),
              ])),
              if (s.notes != null && s.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                padded(AppCard(label: 'Notes', child: Text(s.notes!, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 14)))),
              ],
              for (final e in s.exercices) ...[
                const SizedBox(height: 12),
                padded(_CarteExercice(exo: e, rapprochement: p.rapprochements[cleNom(e.nomSource)], unite: unite, aff: aff)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CarteExercice extends StatelessWidget {
  const _CarteExercice({required this.exo, required this.rapprochement, required this.unite, required this.aff});
  final ImportedExercise exo;
  final Rapprochement? rapprochement;
  final String unite;
  final double Function(double) aff;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = rapprochement;
    final flow = ImportFlow.instance;
    final (texte, couleur) = switch (r?.statut) {
      StatutRapprochement.exact || StatutRapprochement.automatique || StatutRapprochement.manuel =>
        ('→ ${r!.choisi?.nom ?? exo.nomSource}', c.success),
      StatutRapprochement.nouveau => ('Exercice perso : ${flow.brouillon(exo.nomSource).nom}', c.text2),
      _ => ('À confirmer', c.warning),
    };
    return AppCard(
      onTap: () => context.push(
        r?.statut == StatutRapprochement.nouveau
            ? '/import/exercices/nouveau?nom=${Uri.encodeQueryComponent(exo.nomSource)}'
            : '/import/exercices/choisir?nom=${Uri.encodeQueryComponent(exo.nomSource)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exo.nomSource, style: AppType.rowTitle()),
          const SizedBox(height: 2),
          Text(texte, style: AppType.rowSubtitle(color: couleur)),
          if (exo.supersetGroupe != null) ...[
            const SizedBox(height: 6),
            TagPill('Superset ${exo.supersetGroupe}', icon: Icons.link_rounded, color: c.text2),
          ],
          const SizedBox(height: 10),
          for (final set in exo.series)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      set.type == SetKind.echauffement ? 'É' : '${set.index}',
                      style: AppType.rowValue(color: set.type == SetKind.echauffement ? c.warning : c.text3).copyWith(fontSize: 13),
                    ),
                  ),
                  Expanded(child: Text(_detail(set), style: AppType.rowValue().copyWith(fontSize: 14))),
                  if (set.type != SetKind.normale)
                    Text(set.type.libelle, style: AppType.rowSubtitle()),
                ],
              ),
            ),
          if (exo.notes != null && exo.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(exo.notes!, style: AppType.rowSubtitle()),
          ],
        ],
      ),
    );
  }

  String _detail(ImportedSet s) {
    final parts = <String>[];
    if ((s.poidsKg ?? 0) > 0) parts.add('${Fmt.n(aff(s.poidsKg!))} $unite');
    if ((s.reps ?? 0) > 0) parts.add('${s.reps} reps');
    if ((s.dureeSec ?? 0) > 0) parts.add(Fmt.duree(Duration(seconds: s.dureeSec!)));
    if ((s.distanceM ?? 0) > 0) parts.add(s.distanceM! >= 1000 ? '${Fmt.n(s.distanceM! / 1000, decimals: 2)} km' : '${Fmt.n(s.distanceM!, decimals: 0)} m');
    if (s.rpe != null) parts.add('RPE ${Fmt.n(s.rpe!)}');
    return parts.isEmpty ? 'Poids du corps' : parts.join(' × ');
  }
}

/// `/import/apercu/messages` : remarques et erreurs de lecture.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ImportFlow.instance.preview;
    if (p == null) return const SansFichier(titre: 'Remarques');
    final msgs = [...p.rapport.messages]..sort((a, b) => b.gravite.index.compareTo(a.gravite.index));
    return SubPageScaffold(
      title: 'Remarques de lecture',
      subtitle: Fmt.pluriel(msgs.length, 'remarque'),
      body: msgs.isEmpty
          ? const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Aucune remarque', message: 'Le fichier a été lu sans souci.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 32),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final m = msgs[i];
                final (icon, libelle) = switch (m.gravite) {
                  Gravite.erreur => (Icons.error_outline_rounded, 'Erreur'),
                  Gravite.avertissement => (Icons.warning_amber_rounded, 'Ligne ignorée ou corrigée'),
                  Gravite.info => (Icons.info_outline_rounded, 'Information'),
                };
                return ListTileX(
                  leading: IconHalo(icon: icon, size: 36),
                  title: m.ligne == null ? libelle : 'Ligne ${m.ligne}',
                  subtitle: m.texte,
                  subtitleMaxLines: 4,
                );
              },
            ),
    );
  }
}
