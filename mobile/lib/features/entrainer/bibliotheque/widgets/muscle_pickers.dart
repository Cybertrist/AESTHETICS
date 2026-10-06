import 'package:flutter/material.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_map.dart';
import '../../../../core/ui/ui.dart';
import '../../routines/widgets/sous_page.dart';

/// Les deux vues du personnage, à la plus grande taille qui tient dans la
/// largeur disponible (sans dépasser [maxHeight]).
class FittedBodyDual extends StatelessWidget {
  const FittedBodyDual({
    super.key,
    this.intensities = const {},
    this.selected = const {},
    this.onTap,
    this.maxHeight = 420,
    this.labels = true,
  });

  final Map<Muscle, double> intensities;
  final Set<Muscle> selected;
  final ValueChanged<Muscle>? onTap;
  final double maxHeight;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const spacing = 12.0;
      final byWidth = (box.maxWidth - spacing) / 2 / BodyMap.aspectRatio;
      final h = byWidth < maxHeight ? byWidth : maxHeight;
      return Center(
        child: BodyMapDual(
          intensities: intensities,
          selected: selected,
          onTap: onTap,
          height: h,
          spacing: spacing,
          labels: labels,
        ),
      );
    });
  }
}

/// Puces des muscles regroupées par zone.
class MuscleChips extends StatelessWidget {
  const MuscleChips({super.key, required this.isSelected, required this.onTap, this.colorOf, this.labelOf});

  final bool Function(Muscle) isSelected;
  final ValueChanged<Muscle> onTap;

  /// Couleur de la puce choisie (accent par défaut).
  final Color? Function(Muscle)? colorOf;
  final String Function(Muscle)? labelOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in MuscleRegion.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(r.label, style: AppType.rowSubtitle()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in r.muscles)
                ChipFilter(
                  label: labelOf?.call(m) ?? m.label,
                  selected: isSelected(m),
                  color: colorOf?.call(m),
                  onTap: () => onTap(m),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Résultat de la page de filtre par muscle.
typedef MuscleFilterResult = ({Set<Muscle> muscles, bool principauxSeulement});

/// Page plein écran : toucher les muscles sur le personnage (ou dans les
/// puces) pour filtrer les exercices.
class MuscleFilterPage extends StatefulWidget {
  const MuscleFilterPage({super.key, this.initial = const {}, this.principauxSeulement = false});

  final Set<Muscle> initial;
  final bool principauxSeulement;

  static Future<MuscleFilterResult?> open(BuildContext context, {Set<Muscle> initial = const {}, bool principauxSeulement = false}) =>
      Navigator.of(context, rootNavigator: true).push<MuscleFilterResult>(MaterialPageRoute(
        builder: (_) => MuscleFilterPage(initial: initial, principauxSeulement: principauxSeulement),
      ));

  @override
  State<MuscleFilterPage> createState() => _MuscleFilterPageState();
}

class _MuscleFilterPageState extends State<MuscleFilterPage> {
  late final Set<Muscle> _sel = {...widget.initial};
  late bool _principaux = widget.principauxSeulement;

  void _toggle(Muscle m) => setState(() => _sel.contains(m) ? _sel.remove(m) : _sel.add(m));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    final body = FittedBodyDual(selected: _sel, onTap: _toggle, maxHeight: wide ? 520 : 400);
    final options = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _principaux,
            onChanged: (v) => setState(() => _principaux = v),
            title: Text('Muscle principal seulement', style: AppType.rowTitle()),
            subtitle: Text(
              _principaux ? 'Seuls les exercices qui ciblent d\'abord ces muscles' : 'Inclut les exercices où ils travaillent en second',
              style: AppType.rowSubtitle(),
            ),
          ),
        ),
        MuscleChips(isSelected: _sel.contains, onTap: _toggle),
      ],
    );
    return SousPage(
      title: 'Filtrer par muscle',
      subtitle: _sel.isEmpty ? 'Touche un muscle sur le personnage' : Fmt.pluriel(_sel.length, 'muscle choisi', 'muscles choisis'),
      closeIcon: true,
      actions: [
        if (_sel.isNotEmpty) TextButton(onPressed: () => setState(_sel.clear), child: const Text('Effacer')),
      ],
      bottomBar: BoutonPrincipal(
        label: _sel.isEmpty ? 'Tous les muscles' : 'Appliquer',
        onPressed: () => Navigator.pop<MuscleFilterResult>(context, (muscles: _sel, principauxSeulement: _principaux)),
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(AppTokens.gutter), child: body)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(0, AppTokens.gutter, AppTokens.gutter, 24), children: [options]),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
              children: [
                body,
                const SizedBox(height: 8),
                Text('Touche un muscle pour le choisir, touche-le encore pour le retirer.',
                    textAlign: TextAlign.center, style: AppType.rowSubtitle(color: c.text3)),
                const SizedBox(height: 16),
                options,
              ],
            ),
    );
  }
}

/// Rôle d'un muscle dans un exercice perso.
enum MuscleRole { principal, secondaire }

/// Saisie des muscles d'un exercice perso : on choisit le rôle, puis on
/// touche le personnage. Principaux en rouge plein, secondaires en rouge léger.
class MuscleRolePicker extends StatefulWidget {
  const MuscleRolePicker({super.key, required this.principaux, required this.secondaires, required this.onChanged});

  final List<Muscle> principaux;
  final List<Muscle> secondaires;
  final void Function(List<Muscle> principaux, List<Muscle> secondaires) onChanged;

  @override
  State<MuscleRolePicker> createState() => _MuscleRolePickerState();
}

class _MuscleRolePickerState extends State<MuscleRolePicker> {
  MuscleRole _role = MuscleRole.principal;

  void _tap(Muscle m) {
    final p = [...widget.principaux];
    final s = [...widget.secondaires];
    final target = _role == MuscleRole.principal ? p : s;
    final other = _role == MuscleRole.principal ? s : p;
    if (target.contains(m)) {
      target.remove(m);
    } else {
      other.remove(m);
      target.add(m);
    }
    widget.onChanged(p, s);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final intens = {for (final m in widget.secondaires) m: 0.4, for (final m in widget.principaux) m: 1.0};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelecteurSegmente<MuscleRole>(
          segments: [
            (MuscleRole.principal, 'Principaux (${widget.principaux.length})'),
            (MuscleRole.secondaire, 'Secondaires (${widget.secondaires.length})'),
          ],
          value: _role,
          onChanged: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: 14),
        FittedBodyDual(intensities: intens, onTap: _tap, maxHeight: 340),
        const SizedBox(height: 10),
        const MuscleLegend(),
        MuscleChips(
          isSelected: (m) => widget.principaux.contains(m) || widget.secondaires.contains(m),
          colorOf: (m) => widget.principaux.contains(m) ? c.muscle : c.muscle.withValues(alpha: 0.7),
          labelOf: (m) => widget.secondaires.contains(m) ? '${m.label} (2nd)' : m.label,
          onTap: _tap,
        ),
      ],
    );
  }
}

/// Légende rouge plein / rouge léger.
class MuscleLegend extends StatelessWidget {
  const MuscleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget dot(Color col, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: AppType.rowSubtitle()),
        ]);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children: [
        dot(c.muscle, 'Principaux'),
        dot(Color.lerp(c.muscleIdle, c.muscle, 0.45)!, 'Secondaires'),
      ],
    );
  }
}
