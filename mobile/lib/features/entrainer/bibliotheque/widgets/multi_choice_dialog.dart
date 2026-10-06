import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';

/// Choix multiple dans une carte centrée (pas de feuille du bas).
/// Rend la nouvelle sélection, ou null si annulé.
Future<Set<T>?> showMultiChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  Set<T> selected = const {},
  Map<T, int> counts = const {},
  IconData? Function(T)? iconOf,
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (_) => _MultiChoiceDialog<T>(title: title, options: options, initial: selected, counts: counts, iconOf: iconOf),
  );
}

class _MultiChoiceDialog<T> extends StatefulWidget {
  const _MultiChoiceDialog({required this.title, required this.options, required this.initial, required this.counts, this.iconOf});

  final String title;
  final List<(T, String)> options;
  final Set<T> initial;
  final Map<T, int> counts;
  final IconData? Function(T)? iconOf;

  @override
  State<_MultiChoiceDialog<T>> createState() => _MultiChoiceDialogState<T>();
}

class _MultiChoiceDialogState<T> extends State<_MultiChoiceDialog<T>> {
  late final Set<T> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppType.screenTitle().copyWith(fontSize: 20))),
                  if (_sel.isNotEmpty)
                    TextButton(onPressed: () => setState(_sel.clear), child: const Text('Tout effacer')),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final (value, label) in widget.options)
                    InkWell(
                      onTap: () => setState(() => _sel.contains(value) ? _sel.remove(value) : _sel.add(value)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        child: Row(
                          children: [
                            if (widget.iconOf?.call(value) case final icon?) ...[
                              Icon(icon, size: 20, color: c.text2),
                              const SizedBox(width: 12),
                            ],
                            Expanded(child: Text(label, style: AppType.rowTitle())),
                            if (widget.counts[value] case final n?)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text('$n', style: AppType.rowSubtitle()),
                              ),
                            _Check(on: _sel.contains(value)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(child: BoutonSecondaire(label: 'Annuler', petit: true, fond: c.surface3, onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BoutonPrincipal(
                      petit: true,
                      label: _sel.isEmpty ? 'Tout afficher' : 'Appliquer (${_sel.length})',
                      onPressed: () => Navigator.pop(context, _sel),
                    ),
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

/// Case ronde cochée.
class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => SelectionCheck(on: on);
}

/// Pastille de sélection ronde : blanche avec coche, ou filet gris.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.on, this.size = 24, this.label});

  final bool on;
  final double size;

  /// Numéro d'ordre à la place de la coche.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppTokens.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.bouton : Colors.transparent,
        border: Border.all(color: on ? c.bouton : c.text3, width: 1.6),
      ),
      alignment: Alignment.center,
      child: on
          ? (label != null
              ? Text(label!, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w800, color: c.onBouton))
              : Icon(Icons.check_rounded, size: size * 0.7, color: c.onBouton))
          : null,
    );
  }
}
