import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/resume_jour.dart';
import '../routes.dart';
import '../widgets/cartes.dart';
import '../widgets/commun.dart';

enum _Periode { mois, trimestre, an, tout }

/// Records battus, séance par séance.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  _Periode _periode = _Periode.trimestre;
  bool _tous = false;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final now = DateTime.now();
    final depuis = switch (_periode) {
      _Periode.mois => now.subtract(const Duration(days: 30)),
      _Periode.trimestre => now.subtract(const Duration(days: 91)),
      _Periode.an => now.subtract(const Duration(days: 365)),
      _Periode.tout => DateTime(1970),
    };
    final base = historiqueRecords(sessions.sessions);
    final filtres = (_tous ? base : recordsPrincipaux(base)).where((r) => !r.session.debut.isBefore(depuis)).toList();
    final exercices = filtres.map((r) => r.record.exerciseId).toSet().length;

    final groupes = <String, List<RecordBattu>>{};
    for (final r in filtres) {
      groupes.putIfAbsent(r.session.id, () => []).add(r);
    }

    return SubPageScaffold(
      title: 'Records',
      haloColor: c.weight,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedChips<_Periode>(
            segments: const [
              (_Periode.mois, '30 jours'),
              (_Periode.trimestre, '3 mois'),
              (_Periode.an, '1 an'),
              (_Periode.tout, 'Tout'),
            ],
            value: _periode,
            onChanged: (p) => setState(() => _periode = p),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: BigNumber(
                    value: '${filtres.length}',
                    label: filtres.length > 1 ? 'Records sur la période' : 'Record sur la période',
                    caption: filtres.isEmpty ? null : 'sur ${Fmt.pluriel(exercices, 'exercice')}',
                  ),
                ),
                IconHalo(icon: Icons.emoji_events_rounded, color: c.weight, size: 56),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedControl<bool>(
            segments: const [(false, 'Principaux'), (true, 'Tous les types')],
            value: _tous,
            onChanged: (v) => setState(() => _tous = v),
            accentThumb: false,
          ),
          const SizedBox(height: 12),
          if (filtres.isEmpty)
            EmptyState(
              icon: Icons.emoji_events_rounded,
              iconColor: c.weight,
              title: base.isEmpty ? 'Pas encore de record' : 'Aucun record sur cette période',
              message: base.isEmpty
                  ? 'Dès que tu dépasses une charge, un nombre de répétitions ou un volume déjà fait sur un exercice, il apparaît ici.'
                  : 'Élargis la période pour retrouver tes records plus anciens.',
              actionLabel: base.isEmpty ? 'Voir la séance du jour' : 'Tout afficher',
              onAction: base.isEmpty
                  ? () => context.push(AujourdhuiPaths.seanceDuJour)
                  : () => setState(() => _periode = _Periode.tout),
            )
          else
            for (final g in groupes.values) ...[
              TileGroup(
                margin: EdgeInsets.zero,
                label: '${Fmt.relatif(g.first.session.debut)} · ${g.first.session.nom}',
                labelTrailing: AccentLink(
                  label: 'Séance',
                  onTap: () => context.push(AujourdhuiPaths.seanceDetail(g.first.session.id)),
                ),
                children: [
                  for (final r in g)
                    ListTileX(
                      leading: MiniatureExercice(exercise: ex.byId(r.record.exerciseId), size: 42),
                      title: ex.nameOf(r.record.exerciseId),
                      subtitle: r.record.type.label,
                      value: valeurRecord(r.record, u),
                      valueColor: c.accent,
                      onTap: () => context.push(AujourdhuiPaths.seanceDetail(r.session.id)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          if (filtres.isNotEmpty)
            Center(child: PillButton.link(label: 'Courbes par exercice', onPressed: () => context.go(Paths.progres))),
        ],
      ),
    );
  }
}
