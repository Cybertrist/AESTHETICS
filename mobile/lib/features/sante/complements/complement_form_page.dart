import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';
import '../sommeil/nuit_form_page.dart';
import '../services/rappels_complements.dart';
import 'complements_page.dart';

const _unites = ['g', 'mg', 'µg', 'ml', 'gélule', 'gélules', 'comprimé', 'comprimés', 'dose', 'doses', 'UI'];

/// Ajout ou modification d'un complément.
class ComplementFormPage extends StatefulWidget {
  const ComplementFormPage({super.key, this.id, this.modele});
  final String? id;
  final String? modele;

  @override
  State<ComplementFormPage> createState() => _ComplementFormPageState();
}

class _ComplementFormPageState extends State<ComplementFormPage> {
  Supplement? _origine;
  final _nom = TextEditingController();
  final _dose = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String _unite = 'g';
  List<String> _heures = [];
  bool _actif = true;
  bool _modifie = false;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    final s = widget.id == null ? null : context.read<HealthRepo>().supplements.where((x) => x.id == widget.id).firstOrNull;
    _origine = s;
    if (s != null) {
      _nom.text = s.nom;
      _dose.text = ChampNombre.ecrire(s.dose, decimals: 2);
      _unite = s.unite;
      _heures = [...s.heures];
      _actif = s.actif;
      _notes.text = s.notes ?? '';
    } else if (modelesComplements[widget.modele] case final m?) {
      _nom.text = m.$1;
      _dose.text = ChampNombre.ecrire(m.$2);
      _unite = m.$3;
      _notes.text = m.$4;
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? get _erreur {
    if (_nom.text.trim().isEmpty) return 'Donnez un nom';
    final d = ChampNombre.lire(_dose);
    if (d == null || d <= 0) return 'Dose à vérifier';
    return null;
  }

  Future<void> _ajouterHeure() async {
    final t = await choisirHeure(context, const TimeOfDay(hour: 8, minute: 0), titre: 'Heure du rappel');
    if (t == null) return;
    final h = SanteHeure.texte(t);
    if (_heures.contains(h)) return;
    setState(() {
      _heures = [..._heures, h]..sort();
      _modifie = true;
    });
  }

  Future<void> _modifierHeure(String ancienne) async {
    final hm = SanteCalc.parseHeure(ancienne) ?? (8, 0);
    final t = await choisirHeure(context, TimeOfDay(hour: hm.$1, minute: hm.$2), titre: 'Heure du rappel');
    if (t == null) return;
    final h = SanteHeure.texte(t);
    setState(() {
      _heures = {..._heures.where((x) => x != ancienne), h}.toList()..sort();
      _modifie = true;
    });
  }

  Future<void> _enregistrer() async {
    if (_erreur != null) return;
    setState(() => _enregistrement = true);
    final repo = context.read<HealthRepo>();
    final settings = context.read<SettingsRepo>();
    final store = context.read<Store>();
    final s = Supplement(
      id: _origine?.id ?? '',
      nom: _nom.text.trim(),
      dose: ChampNombre.lire(_dose)!,
      unite: _unite,
      heures: _heures,
      actif: _actif,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await repo.saveSupplement(s);
    // Une heure choisie sans rappels actifs : on propose de les activer.
    var rappelsOk = true;
    if (_heures.isNotEmpty && !settings.settings.rappelsComplements && mounted) {
      final oui = await showConfirmDialog(
        context,
        title: 'Activer les rappels ?',
        message: 'Vous recevrez une notification à ${_heures.join(', ')}.',
        confirmLabel: 'Activer',
        cancelLabel: 'Plus tard',
        icon: Icons.notifications_rounded,
      );
      if (oui) rappelsOk = await RappelsComplements.activer(store: store, settings: settings, sante: repo);
    } else {
      await RappelsComplements.replanifier(store: store, settings: settings, sante: repo);
    }
    if (!mounted) return;
    context.pop();
    if (!rappelsOk) {
      Toasts.show(context, 'Complément enregistré, mais les notifications sont bloquées.', kind: ToastKind.error, actionLabel: 'Autoriser', onAction: RappelsComplements.ouvrirReglagesSysteme);
    } else {
      Toasts.success(context, _origine == null ? '${s.nom} ajouté' : '${s.nom} modifié');
    }
  }

  Future<void> _supprimer() async {
    final s = _origine!;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ${s.nom} ?',
      message: 'Son historique de prises sera effacé aussi. Pour arrêter sans perdre l\'historique, mettez-le en pause.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    final repo = context.read<HealthRepo>();
    final settings = context.read<SettingsRepo>();
    final store = context.read<Store>();
    await repo.deleteSupplement(s.id);
    await RappelsComplements.replanifier(store: store, settings: settings, sante: repo);
    if (!mounted) return;
    context.go('/sante/complements');
    Toasts.show(context, '${s.nom} supprimé');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final err = _erreur;
    final rappels = context.watch<SettingsRepo>().settings.rappelsComplements;
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        final ok = await showConfirmDialog(context, title: 'Abandonner la saisie ?', confirmLabel: 'Abandonner', destructive: true);
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: SubPageScaffold(
        title: _origine == null ? 'Nouveau complément' : 'Modifier',
        haloColor: c.nutrition,
        closeIcon: true,
        actions: [
          if (_origine != null) RoundIconButton(icon: Icons.delete_outline_rounded, filled: false, tooltip: 'Supprimer', onPressed: _supprimer),
        ],
        body: AvecBarre(
          barre: PillButton(label: 'Enregistrer', expand: true, size: PillSize.large, loading: _enregistrement, onPressed: err == null ? _enregistrer : null),
          child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            AppCard(
              margin: santePad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nom,
                    autofocus: _origine == null && widget.modele == null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() => _modifie = true),
                    decoration: const InputDecoration(labelText: 'Nom', hintText: 'Créatine, vitamine D...'),
                  ),
                  if (_origine == null && widget.modele == null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in modelesComplements.entries)
                          ChipFilter(
                            label: e.value.$1,
                            color: c.nutrition,
                            selected: _nom.text == e.value.$1,
                            onTap: () => setState(() {
                              _nom.text = e.value.$1;
                              _dose.text = ChampNombre.ecrire(e.value.$2);
                              _unite = e.value.$3;
                              if (_notes.text.isEmpty) _notes.text = e.value.$4;
                              _modifie = true;
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ChampNombre(controller: _dose, label: 'Dose', onChanged: (_) => setState(() => _modifie = true))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unites.contains(_unite) ? _unite : null,
                          decoration: const InputDecoration(labelText: 'Unité'),
                          dropdownColor: c.surface3,
                          items: [for (final u in _unites) DropdownMenuItem(value: u, child: Text(u))],
                          onChanged: (v) => setState(() {
                            _unite = v ?? _unite;
                            _modifie = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              label: 'Heures de prise',
              labelTrailing: AccentLink(label: 'Ajouter', icon: Icons.add_rounded, onTap: _ajouterHeure),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_heures.isEmpty)
                    Text('Aucune heure : le rappel général s\'applique si les rappels sont actifs.', style: AppType.rowSubtitle())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in _heures)
                          ChipFilter(
                            label: h,
                            icon: Icons.alarm_rounded,
                            color: c.nutrition,
                            selected: true,
                            onTap: () => _modifierHeure(h),
                            onRemove: () => setState(() {
                              _heures = [..._heures]..remove(h);
                              _modifie = true;
                            }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    rappels ? 'Les rappels sont actifs.' : 'Les rappels sont désactivés : ils vous seront proposés à l\'enregistrement.',
                    style: AppType.rowSubtitle(color: rappels ? c.nutrition : null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TileGroup(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 2, vertical: 4),
                  title: Text('Actif', style: AppType.rowTitle()),
                  subtitle: Text(_actif ? 'Affiché chaque jour à cocher' : 'En pause, l\'historique est gardé', style: AppType.rowSubtitle()),
                  value: _actif,
                  onChanged: (v) => setState(() {
                    _actif = v;
                    _modifie = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: santePad,
              child: TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _modifie = true,
                decoration: const InputDecoration(labelText: 'Note', hintText: 'Avec un repas, avant la séance...'),
              ),
            ),
            if (_origine == null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 4),
                child: Text(
                  'Ces informations servent à votre suivi personnel et ne remplacent pas l\'avis d\'un professionnel de santé.',
                  style: AppType.rowSubtitle(),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

