import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_widgets.dart';

/// Saisie ou modification d'une nuit.
class NuitFormPage extends StatefulWidget {
  const NuitFormPage({super.key, this.id});
  final String? id;

  @override
  State<NuitFormPage> createState() => _NuitFormPageState();
}

class _NuitFormPageState extends State<NuitFormPage> {
  SleepEntry? _origine;
  late DateTime _jour;
  TimeOfDay _coucher = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _lever = const TimeOfDay(hour: 7, minute: 15);
  int? _qualite;
  bool _phases = false;
  final _profond = TextEditingController();
  final _leger = TextEditingController();
  final _paradoxal = TextEditingController();
  final _eveil = TextEditingController();
  final _notes = TextEditingController();
  bool _modifie = false;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<HealthRepo>();
    final n = widget.id == null ? null : repo.sleep.firstWhereOrNull((s) => s.id == widget.id);
    _origine = n;
    _jour = Dates.jour(DateTime.now());
    if (n != null) {
      _jour = n.jour;
      _coucher = TimeOfDay.fromDateTime(n.coucher);
      _lever = TimeOfDay.fromDateTime(n.lever);
      _qualite = n.qualite;
      _phases = n.aDesPhases;
      _profond.text = n.profondMin?.toString() ?? '';
      _leger.text = n.legerMin?.toString() ?? '';
      _paradoxal.text = n.paradoxalMin?.toString() ?? '';
      _eveil.text = n.eveilMin?.toString() ?? '';
      _notes.text = n.notes ?? '';
    } else if (repo.lastSleep != null) {
      // Reprend les heures de la dernière nuit : c'est souvent les mêmes.
      _coucher = TimeOfDay.fromDateTime(repo.lastSleep!.coucher);
      _lever = TimeOfDay.fromDateTime(repo.lastSleep!.lever);
    }
  }

  @override
  void dispose() {
    for (final c in [_profond, _leger, _paradoxal, _eveil, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Le coucher tombe la veille du réveil s'il est après midi.
  DateTime get _dateCoucher {
    final veille = _coucher.hour >= 12;
    final base = veille ? _jour.subtract(const Duration(days: 1)) : _jour;
    return DateTime(base.year, base.month, base.day, _coucher.hour, _coucher.minute);
  }

  DateTime get _dateLever => DateTime(_jour.year, _jour.month, _jour.day, _lever.hour, _lever.minute);

  Duration get _duree => _dateLever.difference(_dateCoucher);

  String? get _erreur {
    final d = _duree;
    if (d.inMinutes <= 0) return 'Le lever doit suivre le coucher.';
    if (d.inHours >= 16) return 'Une nuit de plus de 16 heures ? Vérifiez les heures.';
    if (_phases) {
      final somme = [_profond, _leger, _paradoxal, _eveil].map((c) => int.tryParse(c.text) ?? 0).fold(0, (a, b) => a + b);
      if (somme > d.inMinutes + 5) return 'Les phases dépassent la durée de la nuit (${Fmt.duree(d)}).';
    }
    return null;
  }

  void _touche(VoidCallback f) => setState(() {
        f();
        _modifie = true;
      });

  Future<void> _enregistrer() async {
    if (_erreur != null) return;
    final repo = context.read<HealthRepo>();
    // Une seule nuit par jour de réveil.
    final doublon = repo.sleep.firstWhereOrNull((s) => s.jour == _jour && s.id != _origine?.id);
    if (doublon != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Une nuit existe déjà ce jour-là',
        message: 'Remplacer la nuit du ${Fmt.jour(_jour)} (${Fmt.sommeil(doublon.duree)}) par celle-ci ?',
        confirmLabel: 'Remplacer',
      );
      if (!ok) return;
      await repo.deleteSleep(doublon.id);
    }
    setState(() => _enregistrement = true);
    int? lire(TextEditingController c) => _phases ? int.tryParse(c.text) : null;
    final n = SleepEntry(
      id: _origine?.id ?? '',
      coucher: _dateCoucher,
      lever: _dateLever,
      qualite: _qualite,
      profondMin: lire(_profond),
      legerMin: lire(_leger),
      paradoxalMin: lire(_paradoxal),
      eveilMin: lire(_eveil),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      source: _origine?.source ?? 'manuel',
    );
    await repo.saveSleep(n);
    if (!mounted) return;
    context.pop();
    Toasts.success(context, _origine == null ? 'Nuit enregistrée' : 'Nuit modifiée');
  }

  Future<bool> _quitter() async {
    if (!_modifie) return true;
    return showConfirmDialog(context, title: 'Abandonner la saisie ?', message: 'Les changements seront perdus.', confirmLabel: 'Abandonner', destructive: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final err = _erreur;
    final d = _duree;
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (await _quitter() && context.mounted) Navigator.of(context).pop();
      },
      child: SubPageScaffold(
        title: _origine == null ? 'Noter une nuit' : 'Modifier la nuit',
        haloColor: c.sleep,
        closeIcon: true,
        body: AvecBarre(
          barre: PillButton(
          label: 'Enregistrer',
          expand: true,
          size: PillSize.large,
          loading: _enregistrement,
          onPressed: err == null ? _enregistrer : null,
        ),
          child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            AppCard(
              margin: santePad,
              child: Center(
                child: BigNumber(
                  value: d.inMinutes > 0 ? Fmt.sommeil(d) : '-',
                  label: 'Durée de la nuit',
                  size: 42,
                  color: err == null ? null : c.error,
                  caption: err ?? '${Fmt.jourCap(_dateCoucher)} › ${Fmt.jour(_dateLever)}',
                  captionColor: err == null ? null : c.error,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TileGroup(
              label: 'Heures',
              children: [
                LigneChoix(
                  icon: Icons.wb_sunny_rounded,
                  color: c.weight,
                  label: 'Réveil le',
                  value: Fmt.relatif(_jour),
                  onTap: () async {
                    final v = await choisirDate(context, _jour);
                    if (v != null) _touche(() => _jour = Dates.jour(v));
                  },
                ),
                LigneChoix(
                  icon: Icons.bedtime_rounded,
                  color: c.sleep,
                  label: 'Coucher',
                  value: SanteHeure.texte(_coucher),
                  onTap: () async {
                    final v = await choisirHeure(context, _coucher, titre: 'Heure du coucher');
                    if (v != null) _touche(() => _coucher = v);
                  },
                ),
                LigneChoix(
                  icon: Icons.alarm_rounded,
                  color: c.coach,
                  label: 'Lever',
                  value: SanteHeure.texte(_lever),
                  onTap: () async {
                    final v = await choisirHeure(context, _lever, titre: 'Heure du lever');
                    if (v != null) _touche(() => _lever = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              label: 'Qualité ressentie',
              child: QualitePicker(value: _qualite, onChanged: (q) => _touche(() => _qualite = q)),
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _phases,
                    onChanged: (v) => _touche(() => _phases = v),
                    title: Text('Détail des phases', style: AppType.rowTitle()),
                    subtitle: Text('En minutes, depuis votre montre ou votre appli de réveil', style: AppType.rowSubtitle()),
                  ),
                  if (_phases) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: ChampNombre(controller: _profond, label: 'Profond', unite: 'min', decimal: false, onChanged: (_) => _touche(() {}))),
                        const SizedBox(width: 10),
                        Expanded(child: ChampNombre(controller: _leger, label: 'Léger', unite: 'min', decimal: false, onChanged: (_) => _touche(() {}))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: ChampNombre(controller: _paradoxal, label: 'Paradoxal', unite: 'min', decimal: false, onChanged: (_) => _touche(() {}))),
                        const SizedBox(width: 10),
                        Expanded(child: ChampNombre(controller: _eveil, label: 'Éveil', unite: 'min', decimal: false, onChanged: (_) => _touche(() {}))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: santePad,
              child: TextField(
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _modifie = true,
                decoration: const InputDecoration(labelText: 'Note', hintText: 'Café tard, réveil à 3 h, bruit...'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

abstract final class SanteHeure {
  static String texte(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
