import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

enum OngletExercices { aConfirmer, reconnus, nouveaux }

String lienChoisir(String nom) => '/import/exercices/choisir?nom=${Uri.encodeQueryComponent(nom)}';
String lienNouveau(String nom) => '/import/exercices/nouveau?nom=${Uri.encodeQueryComponent(nom)}';

/// `/import/exercices` : rapprochement des noms du fichier avec le catalogue.
class ExercicesPage extends StatefulWidget {
  const ExercicesPage({super.key});

  @override
  State<ExercicesPage> createState() => _ExercicesPageState();
}

class _ExercicesPageState extends State<ExercicesPage> {
  final flow = ImportFlow.instance;
  OngletExercices? _onglet;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final p = flow.preview;
        if (p == null) return const SansFichier(titre: 'Exercices');
        final r = p.rapport;
        final c = context.colors;
        final onglet = _onglet ?? (r.aConfirmer.isNotEmpty ? OngletExercices.aConfirmer : OngletExercices.reconnus);
        final liste = switch (onglet) {
          OngletExercices.aConfirmer => r.aConfirmer,
          OngletExercices.reconnus => r.reconnus,
          OngletExercices.nouveaux => r.nouveaux,
        };
        final ambigus = r.aConfirmer.where((x) => x.statut == StatutRapprochement.ambigu).length;
        final inconnus = r.aConfirmer.length - ambigus;
        // Seules les suggestions sûres s'acceptent en lot ; les autres se
        // confirment une par une.
        final sures = r.aConfirmer.where((x) => x.suggestionSure).length;
        final aVerifier = ambigus - sures;

        return PageImport(
          title: 'Exercices',
          subtitle: r.aConfirmer.isEmpty ? 'Tout est associé' : '${Fmt.pluriel(r.aConfirmer.length, 'nom')} à confirmer',
          bottomBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.aConfirmer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      if (sures > 0)
                        Expanded(
                          child: PillButton.secondary(
                            label: 'Tout accepter ($sures)',
                            size: PillSize.small,
                            onPressed: () {
                              final n = flow.accepterSuggestions();
                              Toasts.success(
                                context,
                                '${Fmt.pluriel(n, 'suggestion sûre acceptée', 'suggestions sûres acceptées')}'
                                '${aVerifier > 0 ? ', $aVerifier à confirmer une par une' : ''}',
                              );
                            },
                          ),
                        ),
                      if (sures > 0 && inconnus > 0) const SizedBox(width: 8),
                      if (inconnus > 0)
                        Expanded(
                          child: PillButton.secondary(
                            label: 'Créer les inconnus',
                            size: PillSize.small,
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Créer ${Fmt.pluriel(inconnus, 'exercice perso', 'exercices perso')} ?',
                                message: 'Les noms sans correspondance deviendront des exercices personnels, que tu pourras compléter ensuite.',
                                confirmLabel: 'Créer',
                                icon: Icons.add_circle_outline_rounded,
                              );
                              if (ok) flow.creerTousLesInconnus();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              PillButton(
                label: r.aConfirmer.isEmpty ? 'Continuer' : 'Encore ${r.aConfirmer.length} à confirmer',
                trailingIcon: Icons.arrow_forward_rounded,
                expand: true,
                size: PillSize.large,
                onPressed: r.aConfirmer.isEmpty ? () => context.push('/import/options') : null,
              ),
            ],
          ),
          body: Column(
            children: [
              const EtapesImport(courante: 2),
              padded(SegmentedChips<OngletExercices>(
                segments: [
                  (OngletExercices.aConfirmer, 'À confirmer ${r.aConfirmer.length}'),
                  (OngletExercices.reconnus, 'Reconnus ${r.reconnus.length}'),
                  (OngletExercices.nouveaux, 'Perso ${r.nouveaux.length}'),
                ],
                value: onglet,
                onChanged: (o) => setState(() => _onglet = o),
              )),
              const SizedBox(height: 8),
              Expanded(
                child: liste.isEmpty
                    ? _vide(onglet)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 6, AppTokens.gutter, 24),
                        itemCount: liste.length + (onglet == OngletExercices.aConfirmer ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (onglet == OngletExercices.aConfirmer && i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${_bilan(sures, aVerifier, inconnus)}'
                                'Touche une suggestion pour l\'accepter, ou le nom pour chercher dans le catalogue. Tes choix sont retenus pour les prochains imports.',
                                style: AppType.rowSubtitle(color: c.text2),
                              ),
                            );
                          }
                          final x = liste[onglet == OngletExercices.aConfirmer ? i - 1 : i];
                          return switch (onglet) {
                            OngletExercices.aConfirmer => _AConfirmer(r: x),
                            OngletExercices.reconnus => _Reconnu(r: x),
                            OngletExercices.nouveaux => _Nouveau(r: x),
                          };
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vide(OngletExercices o) => switch (o) {
        OngletExercices.aConfirmer => const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Tout est associé',
            message: 'Chaque nom du fichier correspond à un exercice. Tu peux continuer.',
            compact: true,
          ),
        OngletExercices.reconnus => const EmptyState(
            icon: Icons.manage_search_rounded,
            title: 'Aucun exercice reconnu',
            message: 'Associe les noms à confirmer à des exercices du catalogue.',
            compact: true,
          ),
        OngletExercices.nouveaux => const EmptyState(
            icon: Icons.add_circle_outline_rounded,
            title: 'Aucun exercice perso',
            message: 'Un nom sans équivalent dans le catalogue peut devenir un exercice personnel.',
            compact: true,
          ),
      };
}

/// Ce qui reste à faire, en une phrase (vide s'il ne reste rien).
String _bilan(int sures, int aVerifier, int inconnus) {
  final morceaux = [
    if (sures > 0) Fmt.pluriel(sures, 'suggestion sûre', 'suggestions sûres'),
    if (aVerifier > 0) '$aVerifier à confirmer une par une',
    if (inconnus > 0) '$inconnus à choisir',
  ];
  return morceaux.isEmpty ? '' : '${morceaux.join(', ')}. ';
}

String _compte(Rapprochement r) =>
    '${Fmt.pluriel(r.series, 'série')} · ${Fmt.pluriel(r.seances, 'séance')}';

class _AConfirmer extends StatelessWidget {
  const _AConfirmer({required this.r});
  final Rapprochement r;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flow = ImportFlow.instance;
    final ambigu = r.statut == StatutRapprochement.ambigu;
    final modele = r.modele;
    final etat = !ambigu
        ? 'À choisir'
        : r.suggestionSure
            ? 'Suggestion sûre'
            : 'À confirmer';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: AppTokens.radius12,
              onTap: () => context.push(lienChoisir(r.nomSource)),
              child: Row(
                children: [
                  IconHalo(icon: ambigu ? Icons.help_outline_rounded : Icons.question_mark_rounded, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.nomSource, style: AppType.rowTitle()),
                        Text('$etat · ${_compte(r)}', style: AppType.rowSubtitle()),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.text3),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cand in r.candidats.take(3))
                  ChipFilter(
                    label: cand.deTable ? cand.entree.nom : '${cand.entree.nom} · ${(cand.score * 100).round()} %',
                    selected: false,
                    icon: Icons.check_rounded,
                    onTap: () => flow.confirmer(r.nomSource, cand.entree.id),
                  ),
                ChipFilter(
                  label: modele == null ? 'Exercice perso' : 'Créer « ${modele.nom} »',
                  selected: false,
                  icon: Icons.add_rounded,
                  onTap: () => context.push(lienNouveau(r.nomSource)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Reconnu extends StatelessWidget {
  const _Reconnu({required this.r});
  final Rapprochement r;

  @override
  Widget build(BuildContext context) {
    final statut = switch (r.statut) {
      StatutRapprochement.exact => 'Nom identique',
      StatutRapprochement.automatique => 'Reconnu automatiquement',
      _ => 'Choisi par toi',
    };
    return ListTileX(
      leading: IconHalo(icon: Icons.check_rounded, size: 36),
      title: r.nomSource,
      subtitle: '→ ${r.choisi?.nom ?? '?'} · $statut · ${Fmt.pluriel(r.series, 'série')}',
      subtitleMaxLines: 2,
      showChevron: true,
      onTap: () => context.push(lienChoisir(r.nomSource)),
    );
  }
}

class _Nouveau extends StatelessWidget {
  const _Nouveau({required this.r});
  final Rapprochement r;

  @override
  Widget build(BuildContext context) {
    final d = ImportFlow.instance.brouillon(r.nomSource);
    final muscles = d.muscles.isEmpty ? 'muscles à préciser' : d.muscles.map((m) => m.label).join(', ');
    return ListTileX(
      leading: IconHalo(icon: Icons.add_rounded, size: 36),
      title: d.nom,
      subtitle: '${r.nomSource == d.nom ? '' : 'Depuis « ${r.nomSource} » · '}${Equipements.label(d.equipement)} · $muscles',
      subtitleMaxLines: 2,
      value: '${r.series}',
      showChevron: true,
      onTap: () => context.push(lienNouveau(r.nomSource)),
    );
  }
}

