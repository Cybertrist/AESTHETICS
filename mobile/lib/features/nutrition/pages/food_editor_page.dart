import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/logic/nutrition_calc.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../nav.dart';
import '../widgets/nutri_page.dart';
import '../widgets/nutri_widgets.dart';

/// Créer ou modifier un aliment perso (valeurs de l'étiquette).
class FoodEditorPage extends StatefulWidget {
  const FoodEditorPage({super.key, this.food, this.codeBarres, this.nom});
  final Food? food;
  final String? codeBarres;
  final String? nom;

  @override
  State<FoodEditorPage> createState() => _FoodEditorPageState();
}

class _FoodEditorPageState extends State<FoodEditorPage> {
  late final Food? f = widget.food;
  late final _nom = TextEditingController(text: f?.nom ?? widget.nom ?? '');
  late final _marque = TextEditingController(text: f?.marque ?? '');
  late final _code = TextEditingController(text: f?.codeBarres ?? widget.codeBarres ?? '');
  late final _base = TextEditingController(text: '100');
  late final Map<String, TextEditingController> _v = {
    'kcal': TextEditingController(text: numberText(f?.pour100g.kcal)),
    'proteines': TextEditingController(text: numberText(f?.pour100g.proteines)),
    'glucides': TextEditingController(text: numberText(f?.pour100g.glucides)),
    'sucres': TextEditingController(text: numberText(f?.pour100g.sucres)),
    'lipides': TextEditingController(text: numberText(f?.pour100g.lipides)),
    'fibres': TextEditingController(text: numberText(f?.pour100g.fibres)),
    'sel': TextEditingController(text: numberText(f?.pour100g.sel, decimals: 2)),
  };
  late bool _liquide = f?.liquide ?? false;
  late List<Portion> _portions = [...?f?.portions];
  bool _dirty = false;
  bool _saving = false;

  bool get _editing => f != null && f!.id.isNotEmpty;

  @override
  void dispose() {
    for (final c in [_nom, _marque, _code, _base, ..._v.values]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(String k) => parseNumber(_v[k]!.text) ?? 0;

  Macros get _pour100 {
    final base = parseNumber(_base.text) ?? 100;
    final f = base <= 0 ? 1.0 : 100 / base;
    return Macros(
      kcal: _num('kcal') * f,
      proteines: _num('proteines') * f,
      glucides: _num('glucides') * f,
      sucres: _num('sucres') * f,
      lipides: _num('lipides') * f,
      fibres: _num('fibres') * f,
      sel: _num('sel') * f,
    );
  }

  double get _kcalMacros => NutritionCalc.kcalDesMacros(proteines: _num('proteines'), glucides: _num('glucides'), lipides: _num('lipides'));

  void _changed() => setState(() => _dirty = true);

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return showConfirmDialog(context, title: 'Abandonner les modifications ?', confirmLabel: 'Abandonner', destructive: true);
  }

  Future<void> _addPortion([int? index]) async {
    final p = index == null ? null : _portions[index];
    final r = await showDialog<Portion>(context: context, builder: (_) => _PortionDialog(portion: p, unite: _liquide ? 'ml' : 'g'));
    if (r == null) return;
    setState(() {
      if (index == null) {
        _portions = [..._portions, r];
      } else {
        _portions = [..._portions]..[index] = r;
      }
      _dirty = true;
    });
  }

  Future<void> _scan() async {
    final code = await NutritionNav.scan(context);
    if (code != null) {
      _code.text = code;
      _changed();
    }
  }

  Future<void> _save() async {
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      Toasts.error(context, 'Donne un nom à l\'aliment.');
      return;
    }
    if (_v['kcal']!.text.trim().isEmpty && _kcalMacros <= 0) {
      Toasts.error(context, 'Indique au moins les calories.');
      return;
    }
    final repo = context.read<NutritionRepo>();
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    if (code.isNotEmpty) {
      final other = repo.foodByBarcode(code);
      if (other != null && other.id != f?.id) {
        final ok = await showConfirmDialog(context, title: 'Code déjà utilisé', message: '« ${other.nom} » a déjà ce code-barres. Garder quand même ?', confirmLabel: 'Garder');
        if (!ok) return;
      }
    }
    setState(() => _saving = true);
    var m = _pour100;
    if (m.kcal <= 0) m = Macros(kcal: _kcalMacros * (100 / (parseNumber(_base.text) ?? 100)), proteines: m.proteines, glucides: m.glucides, lipides: m.lipides, fibres: m.fibres, sucres: m.sucres, sel: m.sel);
    final food = Food(
      id: _editing ? f!.id : '',
      nom: nom,
      marque: _marque.text.trim().isEmpty ? null : _marque.text.trim(),
      codeBarres: code.isEmpty ? null : code,
      pour100g: m,
      portions: _portions,
      source: 'perso',
      favori: f?.favori ?? false,
      liquide: _liquide,
    );
    final saved = await repo.saveFood(food);
    if (!mounted) return;
    Toasts.success(context, _editing ? 'Aliment mis à jour' : 'Aliment créé');
    Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer « ${f!.nom} » ?',
      message: 'Les repas déjà notés gardent leurs valeurs.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<NutritionRepo>().deleteFood(f!.id);
    if (!mounted) return;
    Toasts.show(context, 'Aliment supprimé');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = _liquide ? 'ml' : 'g';
    final kcalSaisies = _num('kcal');
    final ecart = kcalSaisies > 0 && _kcalMacros > 0 ? (kcalSaisies - _kcalMacros).abs() / kcalSaisies : 0.0;

    final ident = AppCard(
      label: 'L\'ALIMENT',
      child: Column(children: [
        TextField(controller: _nom, textCapitalization: TextCapitalization.sentences, onChanged: (_) => _changed(), decoration: const InputDecoration(labelText: 'Nom')),
        const SizedBox(height: 12),
        TextField(controller: _marque, textCapitalization: TextCapitalization.words, onChanged: (_) => _changed(), decoration: const InputDecoration(labelText: 'Marque (facultatif)')),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          onChanged: (_) => _changed(),
          decoration: InputDecoration(
            labelText: 'Code-barres (facultatif)',
            suffixIcon: IconButton(tooltip: 'Scanner', onPressed: _scan, icon: Icon(Icons.qr_code_scanner_rounded, color: c.accent)),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _liquide,
          onChanged: (v) => setState(() {
            _liquide = v;
            _dirty = true;
          }),
          title: Text('C\'est une boisson', style: AppType.rowTitle()),
          subtitle: Text('Quantités en millilitres', style: AppType.rowSubtitle()),
        ),
      ]),
    );

    final values = AppCard(
      label: 'VALEURS NUTRITIONNELLES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Pour', style: AppType.rowTitle()),
            const SizedBox(width: 10),
            SizedBox(width: 90, child: NumberField(controller: _base, label: '', suffix: u, decimal: false, onChanged: (_) => _changed())),
            const SizedBox(width: 10),
            Expanded(child: Text('comme sur l\'étiquette', style: AppType.rowSubtitle())),
          ]),
          const SizedBox(height: 14),
          NumberField(controller: _v['kcal']!, label: 'Énergie', suffix: 'kcal', onChanged: (_) => _changed()),
          if (ecart > 0.15)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                const SizedBox(width: 6),
                Expanded(child: Text('Les macros donnent ${Fmt.n(_kcalMacros, decimals: 0)} kcal. Vérifie l\'étiquette.', style: AppType.rowSubtitle(color: c.warning))),
              ]),
            ),
          if (_kcalMacros > 0 && kcalSaisies <= 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  _v['kcal']!.text = numberText(_kcalMacros.roundToDouble());
                  _changed();
                },
                icon: const Icon(Icons.calculate_rounded, size: 18),
                label: Text('Calculer depuis les macros (${Fmt.n(_kcalMacros, decimals: 0)} kcal)'),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: NumberField(controller: _v['proteines']!, label: 'Protéines', suffix: 'g', onChanged: (_) => _changed())),
            const SizedBox(width: 10),
            Expanded(child: NumberField(controller: _v['lipides']!, label: 'Lipides', suffix: 'g', onChanged: (_) => _changed())),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: NumberField(controller: _v['glucides']!, label: 'Glucides', suffix: 'g', onChanged: (_) => _changed())),
            const SizedBox(width: 10),
            Expanded(child: NumberField(controller: _v['sucres']!, label: 'dont sucres', suffix: 'g', onChanged: (_) => _changed())),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: NumberField(controller: _v['fibres']!, label: 'Fibres', suffix: 'g', onChanged: (_) => _changed())),
            const SizedBox(width: 10),
            Expanded(child: NumberField(controller: _v['sel']!, label: 'Sel', suffix: 'g', onChanged: (_) => _changed())),
          ]),
        ],
      ),
    );

    final portions = AppCard(
      label: 'PORTIONS',
      labelTrailing: AccentLink(label: 'Ajouter', icon: Icons.add_rounded, onTap: () => _addPortion()),
      child: _portions.isEmpty
          ? Text('Ajoute des portions (« 1 tranche », « 1 pot ») pour saisir plus vite qu\'en grammes.', style: AppType.rowSubtitle())
          : Column(children: [
              for (var i = 0; i < _portions.length; i++)
                ListTileX(
                  dense: true,
                  padding: EdgeInsets.zero,
                  title: _portions[i].label,
                  value: '${Fmt.n(_portions[i].grammes, decimals: 0)} $u',
                  onTap: () => _addPortion(i),
                  trailing: IconButton(
                    tooltip: 'Retirer la portion',
                    onPressed: () => setState(() {
                      _portions = [..._portions]..removeAt(i);
                      _dirty = true;
                    }),
                    icon: Icon(Icons.close_rounded, color: c.text3, size: 20),
                  ),
                ),
            ]),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: NutriSubPage(
        title: _editing ? 'Modifier l\'aliment' : 'Nouvel aliment',
        closeIcon: true,
        haloColor: c.nutrition,
        actions: [if (_editing) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: c.error))],
        bottomBar: PillButton(label: 'Enregistrer', icon: Icons.check_rounded, expand: true, size: PillSize.large, loading: _saving, onPressed: _save),
        maxContentWidth: 1000,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TwoPane(
              breakpoint: 680,
              left: Padding(
                padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ident, const SizedBox(height: 12), portions]),
              ),
              right: Padding(
                padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
                child: values,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortionDialog extends StatefulWidget {
  const _PortionDialog({this.portion, required this.unite});
  final Portion? portion;
  final String unite;

  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  late final _label = TextEditingController(text: widget.portion?.label ?? '');
  late final _g = TextEditingController(text: numberText(widget.portion?.grammes));

  @override
  void dispose() {
    _label.dispose();
    _g.dispose();
    super.dispose();
  }

  void _ok() {
    final l = _label.text.trim();
    final g = parseNumber(_g.text);
    if (l.isEmpty || g == null || g <= 0) {
      Toasts.error(context, 'Un nom et une quantité, s\'il te plaît.');
      return;
    }
    Navigator.of(context).pop(Portion(label: l, grammes: g));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.portion == null ? 'Nouvelle portion' : 'Modifier la portion', style: context.textStyles.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _label, autofocus: true, decoration: const InputDecoration(labelText: 'Nom', hintText: 'tranche, pot, cuillère…')),
              const SizedBox(height: 12),
              NumberField(controller: _g, label: 'Quantité', suffix: widget.unite),
              const SizedBox(height: 18),
              Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                PillButton.ghost(label: 'Annuler', onPressed: () => Navigator.of(context).pop()),
                PillButton(label: 'Valider', onPressed: _ok),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
