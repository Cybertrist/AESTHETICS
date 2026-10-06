import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'dialogs.dart';

/// Sélecteur numérique : − valeur +, appui long pour répéter, toucher la valeur pour la saisir.
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.decimals = 0,
    this.unit,
    this.label,
    this.compact = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final String? unit;
  final String? label;

  /// Version réduite pour les listes.
  final bool compact;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  Timer? _repeat;

  String get _text {
    final v = widget.value;
    if (widget.decimals == 0 || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(widget.decimals).replaceAll('.', ',');
  }

  void _bump(int dir) {
    final next = (widget.value + dir * widget.step).clamp(widget.min, widget.max);
    final rounded = double.parse(next.toStringAsFixed(widget.decimals.clamp(0, 4) + 2));
    if (rounded != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(rounded);
    }
  }

  void _startRepeat(int dir) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => _bump(dir));
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  Future<void> _edit() async {
    final v = await showNumberInputDialog(
      context,
      title: widget.label ?? 'Valeur',
      initial: widget.value,
      unit: widget.unit,
      decimal: widget.decimals > 0,
    );
    if (v != null) widget.onChanged(v.clamp(widget.min, widget.max));
  }

  Widget _btn(IconData icon, int dir) {
    final c = context.colors;
    final size = widget.compact ? 34.0 : 44.0;
    final enabled = dir < 0 ? widget.value > widget.min : widget.value < widget.max;
    final quoi = widget.label == null ? '' : ' ${widget.label}';
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${dir < 0 ? 'Diminuer' : 'Augmenter'}$quoi',
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeat(dir) : null,
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: Material(
          color: AppTokens.veil2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _bump(dir) : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: size * 0.5, color: enabled ? c.text : c.text3),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    final value = InkWell(
      borderRadius: AppTokens.radius8,
      onTap: _edit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_text, style: AppType.number(widget.compact ? 20 : 28)),
            if (widget.unit != null) ...[
              const SizedBox(width: 4),
              Text(widget.unit!, style: t.bodyMedium?.copyWith(color: c.text2)),
            ],
          ],
        ),
      ),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, -1),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.compact ? 64 : 96),
          child: Center(child: value),
        ),
        _btn(Icons.add_rounded, 1),
      ],
    );
    if (widget.label == null || widget.compact) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label!.toUpperCase(), style: AppType.overline()),
        const SizedBox(height: 8),
        row,
      ],
    );
  }
}
