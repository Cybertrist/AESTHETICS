import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/exporters.dart';
import '../data/fichiers.dart';
import '../data/import_flow.dart';
import '../widgets/import_widgets.dart';

enum _Format { csv, json }

enum _Periode { tout, troisMois, unAn, perso }

/// Fichier prêt à partager ou enregistrer.
typedef _Sortie = ({String nom, List<int> octets, String mime});

/// `/import/export` : exporter ses données en CSV ou JSON.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final Set<JeuExport> _jeux = {JeuExport.seances};
  _Format _format = _Format.csv;
  _Periode _periode = _Periode.tout;
  DateTimeRange? _plage;
  SeparateurCsv _sep = SeparateurCsv.virgule;
  late UnitePoids _unite = context.read<ProfileRepo>().unite;
  List<WaterLog> _eau = const [];
  String? _action;

  @override
  void initState() {
    super.initState();
    _chargerEau();
  }

  /// L'eau n'a pas d'accès global dans NutritionRepo : lecture directe de sa collection.
  Future<void> _chargerEau() async {
    final raw = await context.read<Store>().readList('eau');
    final out = <WaterLog>[];
    for (final j in raw) {
      try {
        out.add(WaterLog.fromJson(j));
      } catch (_) {}
    }
    if (mounted) setState(() => _eau = out);
  }

  (DateTime, DateTime)? get _bornes {
    final now = DateTime.now();
    final fin = DateTime(now.year, now.month, now.day + 1);
    return switch (_periode) {
      _Periode.tout => null,
      _Periode.troisMois => (DateTime(now.year, now.month - 3, now.day), fin),
      _Periode.unAn => (DateTime(now.year - 1, now.month, now.day), fin),
      _Periode.perso => _plage == null
          ? null
          : (_plage!.start, DateTime(_plage!.end.year, _plage!.end.month, _plage!.end.day + 1)),
    };
  }

  bool _dans(DateTime d) {
    final b = _bornes;
    return b == null || (!d.isBefore(b.$1) && d.isBefore(b.$2));
  }

  Future<void> _choisirPlage() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _plage ?? DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now),
      helpText: 'Période à exporter',
      saveText: 'Valider',
    );
    if (r != null) {
      setState(() {
        _plage = r;
        _periode = _Periode.perso;
      });
    }
  }

  Map<JeuExport, int> _comptes(BuildContext context) {
    final ex = context.watch<ExerciseRepo>();
    final ss = context.watch<SessionRepo>();
    final h = context.watch<HealthRepo>();
    final n = context.watch<NutritionRepo>();
    return {
      JeuExport.seances: ss.sessions.where((s) => _dans(s.debut)).length,
      JeuExport.exercicesPerso: ex.perso.length,
      JeuExport.mesures: h.measurements.where((m) => _dans(m.date)).length,
      JeuExport.sommeil: h.sleep.where((s) => _dans(s.coucher)).length,
      JeuExport.nutrition: n.entries.where((e) => _dans(e.date)).length,
      JeuExport.eau: _eau.where((e) => _dans(e.date)).length,
    };
  }

  List<_Sortie> _fichiers() {
    final ex = context.read<ExerciseRepo>();
    final seances = context.read<SessionRepo>().sessions.where((s) => _dans(s.debut)).toList();
    final h = context.read<HealthRepo>();
    final n = context.read<NutritionRepo>();
    final jeux = JeuExport.values.where(_jeux.contains).toList();
    if (_format == _Format.json) {
      final data = <String, Object?>{
        'application': 'aesthetic',
        'type': 'export',
        'version': 1,
        'date': DateTime.now().toIso8601String(),
        'unitePoids': 'kg',
      };
      for (final j in jeux) {
        data[j.name] = switch (j) {
          JeuExport.seances => jsonDecode(utf8.decode(Exporteurs.seancesJson(seances, ex.nameOf)))['seances'],
          JeuExport.exercicesPerso => [for (final e in ex.perso) e.toJson()],
          JeuExport.mesures => [for (final m in h.measurements.where((m) => _dans(m.date))) m.toJson()],
          JeuExport.sommeil => [for (final s in h.sleep.where((s) => _dans(s.coucher))) s.toJson()],
          JeuExport.nutrition => [for (final e in n.entries.where((e) => _dans(e.date))) e.toJson()],
          JeuExport.eau => [for (final e in _eau.where((e) => _dans(e.date))) e.toJson()],
        };
      }
      final base = jeux.length == 1 ? _base(jeux.first) : 'donnees';
      return [
        (
          nom: Exporteurs.nomFichier(base, 'json'),
          octets: utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
          mime: Mime.json,
        ),
      ];
    }
    return [
      for (final j in jeux)
        (
          nom: Exporteurs.nomFichier(_base(j), 'csv'),
          octets: switch (j) {
            JeuExport.seances => Exporteurs.seancesCsv(seances, ex.nameOf, _sep, unite: _unite),
            JeuExport.exercicesPerso => Exporteurs.exercicesPersoCsv(ex.perso, _sep),
            JeuExport.mesures => Exporteurs.mesuresCsv(h.measurements.where((m) => _dans(m.date)).toList(), _sep),
            JeuExport.sommeil => Exporteurs.sommeilCsv(h.sleep.where((s) => _dans(s.coucher)).toList(), _sep),
            JeuExport.nutrition => Exporteurs.nutritionCsv(n.entries.where((e) => _dans(e.date)).toList(), _sep),
            JeuExport.eau => Exporteurs.eauCsv(_eau.where((e) => _dans(e.date)).toList(), _sep),
          },
          mime: Mime.csv,
        ),
    ];
  }

  String _base(JeuExport j) => switch (j) {
        JeuExport.seances => 'seances',
        JeuExport.exercicesPerso => 'exercices-perso',
        JeuExport.mesures => 'mesures',
        JeuExport.sommeil => 'sommeil',
        JeuExport.nutrition => 'nutrition',
        JeuExport.eau => 'eau',
      };

  /// Plusieurs CSV : réunis dans une archive pour l'enregistrement.
  _Sortie _unique(List<_Sortie> f) {
    if (f.length == 1) return f.first;
    final a = Archive();
    for (final x in f) {
      a.addFile(ArchiveFile.bytes(x.nom, x.octets));
    }
    return (nom: Exporteurs.nomFichier('export', 'zip'), octets: ZipEncoder().encodeBytes(a), mime: Mime.zip);
  }

  Future<void> _executer(String action) async {
    setState(() => _action = action);
    try {
      final f = _fichiers();
      const sujet = 'Mes données Aesthetics';
      if (action == 'partager' && f.length > 1) {
        final ok = await Fichiers.courant.partagerPlusieurs(f, sujet: sujet);
        if (mounted && ok) Toasts.success(context, '${f.length} fichiers partagés');
        return;
      }
      final u = _unique(f);
      final ok = action == 'partager'
          ? await Fichiers.courant.partager(u.nom, u.octets, u.mime, sujet: sujet)
          : await Fichiers.courant.enregistrer(u.nom, u.octets, u.mime);
      if (!mounted) return;
      if (ok) {
        Toasts.success(context, action == 'partager' ? 'Export prêt : ${u.nom}' : 'Enregistré : ${u.nom}');
      }
    } catch (e) {
      if (mounted) Toasts.error(context, 'Export impossible : $e');
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final comptes = _comptes(context);
    final totalDonnees = comptes.values.fold(0, (a, b) => a + b);
    final choisis = _jeux.where((j) => (comptes[j] ?? 0) > 0).toList();
    final vide = totalDonnees == 0 && _periode == _Periode.tout;
    final busy = _action != null;

    if (vide) {
      return PageImport(
        title: 'Exporter',
        body: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Rien à exporter pour l\'instant',
          message: 'Enregistre des séances, des mesures ou des repas, ou importe ton historique.',
          actionLabel: 'Importer un historique',
          onAction: () {
            ImportFlow.instance.demarrer(ImportSource.application);
            context.push('/import/fichier');
          },
        ),
      );
    }

    return PageImport(
      title: 'Exporter',
      subtitle: 'CSV ou JSON, à garder ou à partager',
      bottomBar: Row(
        children: [
          Expanded(
            child: PillButton.secondary(
              label: 'Enregistrer',
              icon: Icons.save_alt_rounded,
              loading: _action == 'enregistrer',
              onPressed: choisis.isEmpty || busy ? null : () => _executer('enregistrer'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: 'Partager',
              icon: Icons.ios_share_rounded,
              loading: _action == 'partager',
              onPressed: choisis.isEmpty || busy ? null : () => _executer('partager'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          DeuxVolets(
            gauche: [
              TileGroup(
                label: 'Contenu',
                labelTrailing: LabelCount(Fmt.pluriel(choisis.length, 'jeu', 'jeux')),
                children: [
                  for (final j in JeuExport.values)
                    ListTileX(
                      leading: IconHalo(icon: _icone(j), size: 38),
                      title: j.label,
                      subtitle: '${Fmt.n(comptes[j] ?? 0, decimals: 0)} · ${j.description}',
                      enabled: (comptes[j] ?? 0) > 0,
                      trailing: Checkbox(
                        value: _jeux.contains(j),
                        onChanged: (comptes[j] ?? 0) == 0
                            ? null
                            : (v) => setState(() => v == true ? _jeux.add(j) : _jeux.remove(j)),
                      ),
                      onTap: (comptes[j] ?? 0) == 0
                          ? null
                          : () => setState(() => _jeux.contains(j) ? _jeux.remove(j) : _jeux.add(j)),
                    ),
                ],
              ),
            ],
            droite: [
              const SectionHeader(title: 'Format'),
              padded(SegmentedControl<_Format>(
                segments: const [(_Format.csv, 'CSV'), (_Format.json, 'JSON')],
                value: _format,
                onChanged: (f) => setState(() => _format = f),
              )),
              const SizedBox(height: 8),
              padded(Text(
                _format == _Format.csv
                    ? 'Un fichier par jeu de données, lisible dans un tableur. Le CSV des séances se réimporte tel quel.'
                    : 'Un seul fichier structuré, pratique pour un script ou une autre appli. Pour tout sauvegarder, utilise plutôt la sauvegarde.',
                style: AppType.rowSubtitle(),
              )),
              const SectionHeader(title: 'Période'),
              padded(SegmentedChips<_Periode>(
                segments: const [
                  (_Periode.tout, 'Tout'),
                  (_Periode.troisMois, '3 mois'),
                  (_Periode.unAn, '1 an'),
                  (_Periode.perso, 'Dates'),
                ],
                value: _periode,
                onChanged: (p) => p == _Periode.perso ? _choisirPlage() : setState(() => _periode = p),
              )),
              if (_periode == _Periode.perso && _plage != null) ...[
                const SizedBox(height: 8),
                padded(Align(
                  alignment: Alignment.centerLeft,
                  child: TagPill(
                    'Du ${Fmt.date(_plage!.start)} au ${Fmt.date(_plage!.end)}',
                    icon: Icons.date_range_rounded,
                    color: c.text,
                    onTap: _choisirPlage,
                  ),
                )),
              ],
              if (_format == _Format.csv) ...[
                const SectionHeader(title: 'Séparateur'),
                padded(Column(
                  children: [
                    for (final s in SeparateurCsv.values)
                      CarteChoix(
                        titre: s.label,
                        description: s.description,
                        selectionne: _sep == s,
                        onTap: () => setState(() => _sep = s),
                      ),
                  ],
                )),
                if (_jeux.contains(JeuExport.seances)) ...[
                  const SectionHeader(title: 'Charges des séances'),
                  padded(SegmentedControl<UnitePoids>(
                    segments: const [(UnitePoids.kg, 'Kilos'), (UnitePoids.lb, 'Livres')],
                    value: _unite,
                    onChanged: (u) => setState(() => _unite = u),
                  )),
                ],
              ],
              if (choisis.length > 1) ...[
                const SizedBox(height: 14),
                padded(Encart(
                  texte: _format == _Format.csv
                      ? 'Partager envoie ${choisis.length} fichiers CSV ; Enregistrer les réunit dans une archive ZIP.'
                      : 'Les ${choisis.length} jeux sont réunis dans un seul fichier JSON.',
                )),
              ],
              if (_jeux.isNotEmpty && choisis.isEmpty) ...[
                const SizedBox(height: 14),
                padded(const Encart(ton: TonEncart.attention, texte: 'Aucune donnée sur cette période pour les jeux choisis.')),
              ],
            ],
          ),
          const SizedBox(height: 8),
          padded(Text('Les photos ne sont pas exportées ici : elles vont dans la sauvegarde complète.', style: AppType.rowSubtitle(color: c.text3))),
        ],
      ),
    );
  }

  IconData _icone(JeuExport j) => switch (j) {
        JeuExport.seances => Icons.fitness_center_rounded,
        JeuExport.exercicesPerso => Icons.add_circle_outline_rounded,
        JeuExport.mesures => Icons.monitor_weight_outlined,
        JeuExport.sommeil => Icons.bedtime_rounded,
        JeuExport.nutrition => Icons.restaurant_rounded,
        JeuExport.eau => Icons.water_drop_rounded,
      };
}
