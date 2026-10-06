import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';
import 'exercices_page.dart';

/// `/import/exercices/choisir?nom=` : associer un nom du fichier à un exercice.
class ChoisirExercicePage extends StatefulWidget {
  const ChoisirExercicePage({super.key, required this.nomSource});
  final String nomSource;

  @override
  State<ChoisirExercicePage> createState() => _ChoisirExercicePageState();
}

class _ChoisirExercicePageState extends State<ChoisirExercicePage> {
  final flow = ImportFlow.instance;
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _choisir(String id) {
    flow.confirmer(widget.nomSource, id);
    Toasts.success(context, '« ${widget.nomSource} » associé');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = flow.preview;
    if (p == null) return const SansFichier(titre: 'Associer un exercice');
    final r = p.rapprochements[cleNom(widget.nomSource)];
    if (r == null) {
      return SubPageScaffold(
        title: 'Associer un exercice',
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nom introuvable',
          message: '« ${widget.nomSource} » n\'est plus dans le fichier analysé.',
          actionLabel: 'Retour aux exercices',
          onAction: () => context.pop(),
        ),
      );
    }
    final repo = context.watch<ExerciseRepo>();
    final resultats = _q.isEmpty ? const <Exercise>[] : repo.search(query: _q).take(60).toList();
    final series = flow.seriesDe(widget.nomSource).toList();
    final chargeMax = series.fold<double>(0, (a, s) => (s.poidsKg ?? 0) > a ? s.poidsKg! : a);
    final actuel = r.choisi;

    final entete = <Widget>[
      padded(AppCard(
        child: Row(
          children: [
            IconHalo(icon: Icons.description_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DANS LE FICHIER', style: AppType.overline()),
                  const SizedBox(height: 2),
                  Text(widget.nomSource, style: AppType.rowTitle().copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.pluriel(r.series, 'série')} · ${Fmt.pluriel(r.seances, 'séance')}'
                    '${chargeMax > 0 ? ' · jusqu\'à ${Fmt.n(chargeMax)} kg' : ''}',
                    style: AppType.rowSubtitle(),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
      if (actuel != null) ...[
        const SizedBox(height: 10),
        padded(Encart(
          ton: TonEncart.succes,
          titre: 'Associé à ${actuel.nom}',
          texte: r.statut == StatutRapprochement.manuel ? 'Choisi par toi.' : 'Trouvé automatiquement.',
          action: r.statut == StatutRapprochement.manuel
              ? PillButton.link(label: 'Annuler ce choix', onPressed: () => flow.annulerChoix(widget.nomSource))
              : null,
        )),
      ],
      const SizedBox(height: 12),
      padded(SearchField(
        controller: _ctrl,
        hint: 'Chercher dans le catalogue',
        onChanged: (v) => setState(() => _q = v.trim()),
      )),
    ];

    return SubPageScaffold(
      title: 'Associer un exercice',
      subtitle: widget.nomSource,
      body: CustomScrollView(
        slivers: [
          SliverList(delegate: SliverChildListDelegate(entete)),
          if (_q.isEmpty) ...[
            if (r.candidats.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Suggestions')),
              SliverList.builder(
                itemCount: r.candidats.length,
                itemBuilder: (context, i) {
                  final cand = r.candidats[i];
                  final ex = repo.byId(cand.entree.id);
                  return _Ligne(
                    ex: ex,
                    nom: cand.entree.nom,
                    detail: 'Proche de « ${cand.nomCompare} »',
                    score: cand.score,
                    selectionne: actuel?.id == cand.entree.id,
                    onTap: () => _choisir(cand.entree.id),
                  );
                },
              ),
            ] else
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: EmptyState(
                    icon: Icons.manage_search_rounded,
                    title: 'Aucune suggestion',
                    message: 'Cherche l\'exercice dans le catalogue ou crée un exercice perso.',
                    compact: true,
                  ),
                ),
              ),
          ] else if (resultats.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun résultat',
                message: 'Rien pour « $_q ». Essaie un autre mot, ou crée un exercice perso.',
                compact: true,
              ),
            )
          else ...[
            SliverToBoxAdapter(child: SectionHeader(title: 'Résultats', trailing: LabelCount(Fmt.pluriel(resultats.length, 'exercice')))),
            SliverList.builder(
              itemCount: resultats.length,
              itemBuilder: (context, i) {
                final ex = resultats[i];
                return _Ligne(
                  ex: ex,
                  nom: ex.nom,
                  detail: [ex.equipementLabel, if (ex.musclesPrincipaux.isNotEmpty) ex.musclesPrincipaux.first.label, if (ex.perso) 'perso'].join(' · '),
                  selectionne: actuel?.id == ex.id,
                  onTap: () => _choisir(ex.id),
                );
              },
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 16, AppTokens.gutter, 40),
              child: AppCard(
                onTap: () => context.pushReplacement(lienNouveau(widget.nomSource)),
                padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
                child: ListTileX(
                  padding: ListTileX.cardPadding,
                  leading: IconHalo(icon: Icons.add_rounded),
                  title: 'Créer un exercice personnel',
                  subtitle: 'Garder « ${widget.nomSource} » comme un exercice à part',
                  showChevron: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ex, required this.nom, required this.detail, required this.selectionne, required this.onTap, this.score});
  final Exercise? ex;
  final String nom;
  final String detail;
  final double? score;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vignette = ex?.media.thumbnail;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
      child: ListTileX(
        selected: selectionne,
        leading: vignette != null && vignette.startsWith('assets/')
            ? ClipRRect(
                borderRadius: AppTokens.radius12,
                child: Container(
                  width: 42,
                  height: 42,
                  color: c.surface2,
                  child: Image.asset(vignette, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
                ),
              )
            : IconHalo(icon: Icons.fitness_center_rounded, size: 42),
        title: nom,
        subtitle: detail,
        value: score == null ? null : '${(score! * 100).round()} %',
        valueColor: score == null ? null : (score! >= 0.8 ? c.success : c.text2),
        onTap: onTap,
      ),
    );
  }
}
