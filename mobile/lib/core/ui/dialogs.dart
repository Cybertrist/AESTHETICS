import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'pill_button.dart';

/// Boîte de confirmation (pas de feuille du bas pour les décisions).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel = 'Annuler',
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // Le clavier réduit la place : la boîte défile au lieu de couper
        // ses boutons.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 28, color: destructive ? c.error : c.text),
                const SizedBox(height: 14),
              ],
              Text(title, style: t.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!, style: t.bodyMedium?.copyWith(color: c.text2)),
              ],
              const SizedBox(height: 22),
              // Deux libellés courts tiennent côte à côte, à droite ; sinon
              // les boutons s'empilent sur toute la largeur, l'action d'abord.
              if (confirmLabel.length + cancelLabel.length <= 22)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PillButton.ghost(label: cancelLabel, onPressed: () => Navigator.of(context).pop(false)),
                    const SizedBox(width: 8),
                    PillButton(
                      label: confirmLabel,
                      variant: destructive ? PillVariant.danger : PillVariant.primary,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                )
              else ...[
                PillButton(
                  label: confirmLabel,
                  variant: destructive ? PillVariant.danger : PillVariant.primary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 8),
                PillButton.ghost(label: cancelLabel, expand: true, onPressed: () => Navigator.of(context).pop(false)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Demande une confirmation ; vrai si l'utilisateur accepte.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
  IconData? icon,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return r ?? false;
}

/// Saisie d'un texte court (nom de routine, de dossier…).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirmLabel = 'Enregistrer',
  int maxLines = 1,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      maxLength: maxLength,
      numeric: false,
    ),
  );
}

/// Saisie d'un nombre (virgule acceptée). Null si annulé.
Future<double?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  double? initial,
  String? unit,
  bool decimal = true,
  String confirmLabel = 'Valider',
}) async {
  final r = await showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      initial: initial == null ? '' : _fmt(initial),
      hint: '0',
      suffix: unit,
      confirmLabel: confirmLabel,
      numeric: true,
      decimal: decimal,
    ),
  );
  if (r == null) return null;
  return double.tryParse(r.replaceAll(',', '.').replaceAll(' ', ''));
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.numeric,
    this.hint,
    this.suffix,
    this.decimal = true,
    this.maxLines = 1,
    this.maxLength,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? suffix;
  final String confirmLabel;
  final bool numeric;
  final bool decimal;
  final int maxLines;
  final int? maxLength;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _ctrl = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: t.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                textCapitalization: widget.numeric ? TextCapitalization.none : TextCapitalization.sentences,
                keyboardType: widget.numeric ? TextInputType.numberWithOptions(decimal: widget.decimal) : TextInputType.text,
                inputFormatters: widget.numeric
                    ? [FilteringTextInputFormatter.allow(RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]'))]
                    : null,
                style: widget.numeric ? t.headlineSmall : t.bodyLarge,
                onSubmitted: (_) => _submit(),
                // Le compteur n'apparaît qu'à l'approche de la limite.
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                    maxLength == null || currentLength < maxLength * 0.8 ? null : Text('$currentLength / $maxLength', style: t.bodySmall),
                decoration: InputDecoration(hintText: widget.hint, suffixText: widget.suffix),
              ),
              const SizedBox(height: 18),
              // Deux boutons de même largeur : rien ne déborde en petit écran.
              Row(
                children: [
                  Expanded(child: PillButton.ghost(label: 'Annuler', onPressed: () => Navigator.of(context).pop())),
                  const SizedBox(width: 8),
                  Expanded(child: PillButton(label: widget.confirmLabel, onPressed: _submit)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix dans une courte liste, en boîte de dialogue.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? message,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final c = context.colors;
      final t = context.textStyles;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleLarge),
                    if (message != null) ...[
                      const SizedBox(height: 6),
                      Text(message, style: t.bodySmall),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final (value, label) in options)
                      InkWell(
                        onTap: () => Navigator.of(context).pop(value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: t.bodyLarge?.copyWith(
                                    color: c.text,
                                    fontWeight: value == selected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (value == selected) Icon(Icons.check_rounded, color: c.text, size: 20),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Petit menu d'actions en feuille (toléré pour des menus courts).
Future<T?> showActionMenu<T>(
  BuildContext context, {
  String? title,
  required List<ActionMenuItem<T>> items,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final c = context.colors;
      final t = context.textStyles;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 0, AppTokens.gutter, 8),
              child: Text(title, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          for (final item in items)
            InkWell(
              onTap: () => Navigator.of(context).pop(item.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 4, vertical: 14),
                child: Row(
                  children: [
                    Icon(item.icon, color: item.destructive ? c.error : c.text2, size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(item.label, style: t.bodyLarge?.copyWith(color: item.destructive ? c.error : c.text)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

class ActionMenuItem<T> {
  const ActionMenuItem({required this.value, required this.label, required this.icon, this.destructive = false});
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}
