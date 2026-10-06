import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';

/// Saisie d'une mesure : poids, masse grasse, tours au mètre ruban.
class MesureFormPage extends StatefulWidget {
  const MesureFormPage({super.key, this.id, this.focusTours = false});
  final String? id;

  /// Ouvre directement sur les tours (depuis les mensurations).
  final bool focusTours;

  @override
  State<MesureFormPage> createState() => _MesureFormPageState();
}

class _MesureFormPageState extends State<MesureFormPage> {
  BodyMeasurement? _origine;
  DateTime _date = DateTime.now();
  final _poids = TextEditingController();
  final _mg = TextEditingController();
  final _mm = TextEditingController();
  final Map<TourCorps, TextEditingController> _tours = {for (final t in TourCorps.values) t: TextEditingController()};
  late bool _toursOuverts = widget.focusTours;
  bool _modifie = false;
  bool _enregistrement = false;
  late UnitePoids _unite;

  @override
  void initState() {
    super.initState();
    final repo = context.read<HealthRepo>();
    _unite = context.read<ProfileRepo>().unite;
    final m = widget.id == null ? null : repo.measurements.firstWhereOrNull((x) => x.id == widget.id);
    _origine = m;
    if (m != null) {
      _date = m.date;
      _poids.text = m.poidsKg == null ? '' : ChampNombre.ecrire(Fmt.poidsAffiche(m.poidsKg!, _unite));
      _mg.text = ChampNombre.ecrire(m.masseGrassePct);
      _mm.text = m.masseMusculaireKg == null ? '' : ChampNombre.ecrire(Fmt.poidsAffiche(m.masseMusculaireKg!, _unite));
      for (final e in m.tours.entries) {
        _tours[e.key]!.text = ChampNombre.ecrire(e.value);
      }
      if (m.tours.isNotEmpty) _toursOuverts = true;
    }
  }

  @override
  void dispose() {
    for (final c in [_poids, _mg, _mm, ..._tours.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _erreur {
    final p = ChampNombre.lire(_poids);
    final mg = ChampNombre.lire(_mg);
    if (_poids.text.isNotEmpty && (p == null || p < 20 || p > 400)) return 'Poids à vérifier';
    if (_mg.text.isNotEmpty && (mg == null || mg < 2 || mg > 70)) return 'Masse grasse entre 2 et 70 %';
    for (final e in _tours.entries) {
      final v = ChampNombre.lire(e.value);
      if (e.value.text.isNotEmpty && (v == null || v < 10 || v > 250)) return '${e.key.label} : valeur à vérifier';
    }
    final vide = _poids.text.isEmpty && _mg.text.isEmpty && _mm.text.isEmpty && _tours.values.every((c) => c.text.isEmpty);
    if (vide) return 'Renseignez au moins une valeur';
    return null;
  }

  Future<void> _enregistrer() async {
    if (_erreur != null) return;
    setState(() => _enregistrement = true);
    final p = ChampNombre.lire(_poids);
    final mm = ChampNombre.lire(_mm);
    final m = BodyMeasurement(
      id: _origine?.id ?? '',
      date: _date,
      poidsKg: p == null ? null : Fmt.poidsStocke(p, _unite),
      masseGrassePct: ChampNombre.lire(_mg),
      masseMusculaireKg: mm == null ? null : Fmt.poidsStocke(mm, _unite),
      tours: {
        for (final e in _tours.entries)
          if (ChampNombre.lire(e.value) != null) e.key: ChampNombre.lire(e.value)!,
      },
      source: _origine?.source ?? 'manuel',
    );
    await context.read<HealthRepo>().saveMeasurement(m);
    if (!mounted) return;
    context.pop();
    Toasts.success(context, _origine == null ? 'Mesure enregistrée' : 'Mesure modifiée');
  }

  void _change() => setState(() => _modifie = true);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final err = _erreur;
    final dernier = repo.latestWeightEntry;
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        final ok = await showConfirmDialog(context, title: 'Abandonner la saisie ?', message: 'Les valeurs saisies seront perdues.', confirmLabel: 'Abandonner', destructive: true);
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: SubPageScaffold(
        title: _origine == null ? 'Nouvelle mesure' : 'Modifier la mesure',
        haloColor: c.weight,
        closeIcon: true,
        body: AvecBarre(
          barre: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (err != null && _modifie)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(err, textAlign: TextAlign.center, style: AppType.rowSubtitle(color: c.error)),
              ),
            PillButton(label: 'Enregistrer', expand: true, size: PillSize.large, loading: _enregistrement, onPressed: err == null ? _enregistrer : null),
          ],
        ),
          child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            TileGroup(
              children: [
                LigneChoix(
                  icon: Icons.event_rounded,
                  color: c.weight,
                  label: 'Date',
                  value: '${Fmt.relatif(_date)} à ${Fmt.heure(_date)}',
                  onTap: () async {
                    final d = await choisirDate(context, _date);
                    if (d == null || !context.mounted) return;
                    final h = await choisirHeure(context, TimeOfDay.fromDateTime(_date));
                    setState(() {
                      _date = DateTime(d.year, d.month, d.day, h?.hour ?? _date.hour, h?.minute ?? _date.minute);
                      _modifie = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              label: 'Balance',
              labelTrailing: dernier?.poidsKg == null ? null : Text('Dernière : ${Fmt.poids(dernier!.poidsKg, _unite)}', style: AppType.rowSubtitle()),
              child: Column(
                children: [
                  ChampNombre(controller: _poids, label: 'Poids', unite: _unite.label, hint: dernier?.poidsKg == null ? '75,0' : ChampNombre.ecrire(Fmt.poidsAffiche(dernier!.poidsKg!, _unite)), onChanged: (_) => _change()),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ChampNombre(controller: _mg, label: 'Masse grasse', unite: '%', hint: repo.latestBodyFat == null ? '15' : ChampNombre.ecrire(repo.latestBodyFat), onChanged: (_) => _change())),
                      const SizedBox(width: 10),
                      Expanded(child: ChampNombre(controller: _mm, label: 'Masse musculaire', unite: _unite.label, onChanged: (_) => _change())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Pesez-vous le matin, après être passé aux toilettes et avant de manger, pour comparer ce qui est comparable.', style: AppType.rowSubtitle()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTileX(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    leading: IconHalo(icon: Icons.straighten_rounded, color: c.weight, size: 38),
                    title: 'Mensurations',
                    subtitle: _toursOuverts ? 'En centimètres, au mètre ruban' : 'Bras, poitrine, taille, hanches, cuisses, mollets, cou',
                    trailing: Icon(_toursOuverts ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.text3),
                    onTap: () => setState(() => _toursOuverts = !_toursOuverts),
                  ),
                  if (_toursOuverts)
                    for (final g in GroupeTour.values) ...[
                      const SizedBox(height: 12),
                      Text(g.label.toUpperCase(), style: AppType.overline(color: c.text3)),
                      const SizedBox(height: 2),
                      Text(g.conseil, style: AppType.rowSubtitle()),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < g.tours.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: ChampNombre(
                                controller: _tours[g.tours[i]]!,
                                label: g.deuxCotes ? (i == 0 ? 'Gauche' : 'Droite') : g.label,
                                unite: 'cm',
                                hint: repo.latestTour(g.tours[i]) == null ? null : ChampNombre.ecrire(repo.latestTour(g.tours[i])),
                                onChanged: (_) => _change(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
