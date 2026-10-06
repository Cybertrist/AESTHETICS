import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

enum _OrdreDates { auto, jourDabord, moisDabord }

/// `/import/colonnes` : associer chaque colonne d'un tableau quelconque.
class ColonnesPage extends StatefulWidget {
  const ColonnesPage({super.key, this.depuisApercu = false});

  /// Ouvert depuis l'aperçu : on y revient au lieu d'en empiler un autre.
  final bool depuisApercu;

  @override
  State<ColonnesPage> createState() => _ColonnesPageState();
}

class _ColonnesPageState extends State<ColonnesPage> {
  final flow = ImportFlow.instance;
  late ColumnMapping _m;
  UniteCharge? _unite;
  _OrdreDates _dates = _OrdreDates.auto;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final p = flow.preview;
    final base = flow.colonnes ?? p?.detection.colonnes ?? (p == null ? null : ColumnMapping.deviner(p.table.enTetes));
    _m = ColumnMapping(Map.of(base?.colonnes ?? const {}));
    _unite = base?.uniteCharge;
    _dates = switch (base?.moisDabord) {
      null => _OrdreDates.auto,
      true => _OrdreDates.moisDabord,
      false => _OrdreDates.jourDabord,
    };
  }

  /// Premières valeurs non vides d'une colonne.
  List<String> _exemples(CsvTable t, int col, {int n = 3}) {
    final out = <String>[];
    for (final r in t.lignes) {
      final v = r.at(col);
      if (v != null && v.trim().isNotEmpty && !out.contains(v)) out.add(v.trim());
      if (out.length >= n) break;
    }
    return out;
  }

  Future<void> _choisir(ChampImport champ, CsvTable t) async {
    final prises = {for (final e in _m.colonnes.entries) if (e.key != champ) e.value: e.key};
    final choix = await showChoiceDialog<int>(
      context,
      title: champ.libelle,
      message: champ.obligatoire ? 'Ce champ est obligatoire.' : 'Facultatif : laisse vide si le fichier ne le contient pas.',
      selected: _m.colonnes[champ] ?? -1,
      options: [
        if (!champ.obligatoire || _m.colonnes[champ] != null) (-1, 'Aucune colonne'),
        for (var i = 0; i < t.enTetes.length; i++)
          (
            i,
            '${t.enTetes[i].isEmpty ? 'Colonne ${i + 1}' : t.enTetes[i]}'
                '${prises[i] != null ? ' (déjà : ${prises[i]!.libelle})' : ''}'
                '${_exemples(t, i, n: 1).isEmpty ? '' : '  ·  ${_exemples(t, i, n: 1).first}'}',
          ),
      ],
    );
    if (choix == null) return;
    setState(() {
      if (choix < 0) {
        _m.colonnes.remove(champ);
      } else {
        // Une colonne ne sert qu'à un champ : on la retire de l'autre.
        _m.colonnes.removeWhere((k, v) => v == choix && k != champ);
        _m.colonnes[champ] = choix;
      }
    });
  }

  Future<void> _valider() async {
    _m
      ..uniteCharge = _unite
      ..moisDabord = switch (_dates) {
        _OrdreDates.auto => null,
        _OrdreDates.moisDabord => true,
        _OrdreDates.jourDabord => false,
      };
    setState(() => _enCours = true);
    await flow.appliquerColonnes(_m, context.read<AppData>());
    if (!mounted) return;
    setState(() => _enCours = false);
    if (flow.etat != EtatAnalyse.pret) {
      Toasts.error(context, flow.erreur ?? 'Analyse impossible.');
      return;
    }
    if (flow.rapport?.seances == 0 && (flow.rapport?.seancesDoublons ?? 0) == 0) {
      Toasts.error(context, 'Aucune séance lue avec ces colonnes. Vérifie la date et l\'exercice.');
      return;
    }
    if (widget.depuisApercu && context.canPop()) {
      context.pop();
    } else {
      context.pushReplacement('/import/apercu');
    }
  }

  Future<void> _reinitialiser(CsvTable t) async {
    setState(() {
      _m = ColumnMapping(Map.of(ColumnMapping.deviner(t.enTetes).colonnes));
      _unite = null;
      _dates = _OrdreDates.auto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = flow.preview;
    if (p == null) return const SansFichier(titre: 'Associer les colonnes');
    final t = p.table;
    final c = context.colors;
    final manquants = _m.manquants;
    final pret = _m.estUtilisable;

    return PageImport(
      title: 'Associer les colonnes',
      subtitle: '${t.enTetes.length} colonnes · ${t.lignes.length} lignes',
      actions: [
        IconButton(
          tooltip: 'Deviner à nouveau',
          icon: const Icon(Icons.auto_fix_high_rounded),
          onPressed: () => _reinitialiser(t),
        ),
      ],
      bottomBar: PillButton(
        label: 'Analyser avec ces colonnes',
        icon: Icons.check_rounded,
        expand: true,
        size: PillSize.large,
        loading: _enCours,
        onPressed: pret && !_enCours ? _valider : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const EtapesImport(courante: 0),
          padded(Text(
            'Indique ce que contient chaque colonne. Une ligne du fichier doit correspondre à une série.',
            style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 14),
          )),
          const SizedBox(height: 14),
          padded(_Extrait(table: t, mapping: _m)),
          const SizedBox(height: 14),
          if (!pret)
            padded(Encart(
              ton: TonEncart.attention,
              titre: 'Il manque des colonnes',
              texte: manquants.isNotEmpty
                  ? 'À associer : ${manquants.map((m) => m.libelle).join(', ')}, puis une charge, des répétitions, une durée ou une distance.'
                  : 'Associe au moins une charge, des répétitions, une durée ou une distance.',
            )),
          TileGroup(
            margin: const EdgeInsets.fromLTRB(AppTokens.gutter, 16, AppTokens.gutter, 0),
            label: 'Champs',
            children: [
              for (final champ in ChampImport.values)
                ListTileX(
                  leading: IconHalo(
                    icon: _icone(champ),
                    off: _m.colonnes[champ] == null,
                    size: 36,
                  ),
                  title: champ.obligatoire ? '${champ.libelle} *' : champ.libelle,
                  subtitle: _m.colonnes[champ] == null
                      ? (champ.obligatoire ? 'Obligatoire' : 'Non utilisé')
                      : 'ex. ${_exemples(t, _m.colonnes[champ]!).join(' · ')}',
                  subtitleColor: _m.colonnes[champ] == null && champ.obligatoire ? c.warning : null,
                  value: _m.colonnes[champ] == null ? null : _nomColonne(t, _m.colonnes[champ]!),
                  valueColor: c.text,
                  showChevron: true,
                  onTap: () => _choisir(champ, t),
                ),
            ],
          ),
          const SectionHeader(title: 'Unité des charges'),
          padded(SegmentedChips<UniteCharge?>(
            segments: const [(null, 'D\'après l\'en-tête'), (UniteCharge.kg, 'Kilos'), (UniteCharge.lb, 'Livres')],
            value: _unite,
            onChanged: (v) => setState(() => _unite = v),
          )),
          const SectionHeader(title: 'Format des dates'),
          padded(SegmentedChips<_OrdreDates>(
            segments: const [
              (_OrdreDates.auto, 'Automatique'),
              (_OrdreDates.jourDabord, '31/12/2026'),
              (_OrdreDates.moisDabord, '12/31/2026'),
            ],
            value: _dates,
            onChanged: (v) => setState(() => _dates = v),
          )),
          const SizedBox(height: 8),
          padded(Text(
            'Automatique : si un jour dépasse 12, l\'ordre est déduit tout seul.',
            style: AppType.rowSubtitle(),
          )),
        ],
      ),
    );
  }

  String _nomColonne(CsvTable t, int i) => t.enTetes[i].isEmpty ? 'Colonne ${i + 1}' : t.enTetes[i];

  IconData _icone(ChampImport c) => switch (c) {
        ChampImport.date => Icons.event_rounded,
        ChampImport.seance => Icons.label_outline_rounded,
        ChampImport.exercice => Icons.fitness_center_rounded,
        ChampImport.poids => Icons.scale_rounded,
        ChampImport.unite => Icons.straighten_rounded,
        ChampImport.reps => Icons.repeat_rounded,
        ChampImport.typeSerie => Icons.category_outlined,
        ChampImport.dureeSeance => Icons.timer_outlined,
        ChampImport.dureeSerie => Icons.av_timer_rounded,
        ChampImport.distance => Icons.route_rounded,
        ChampImport.rpe => Icons.speed_rounded,
        ChampImport.rir => Icons.battery_5_bar_rounded,
        ChampImport.notes => Icons.notes_rounded,
        ChampImport.notesSeance => Icons.sticky_note_2_outlined,
      };
}

/// Extrait du fichier : les premières lignes, en-têtes colorés selon l'association.
class _Extrait extends StatelessWidget {
  const _Extrait({required this.table, required this.mapping});
  final CsvTable table;
  final ColumnMapping mapping;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final champParCol = {for (final e in mapping.colonnes.entries) e.value: e.key};
    final lignes = table.lignes.take(4).toList();
    return AppCard(
      label: 'Extrait du fichier',
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < table.enTetes.length; i++)
              Container(
                width: 130,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: champParCol[i] != null ? c.surface2 : c.veil,
                  borderRadius: AppTokens.radius12,
                  border: Border.all(color: champParCol[i] != null ? c.text2 : c.veilBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (champParCol[i]?.libelle ?? 'Ignorée').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.overline(color: champParCol[i] != null ? c.text : c.text3).copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      table.enTetes[i].isEmpty ? 'Colonne ${i + 1}' : table.enTetes[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.rowTitle().copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    for (final l in lignes)
                      Text(
                        l.at(i) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.rowSubtitle(),
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
