import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Champ de recherche en pilule gris violacé (#48454E), loupe et effacement.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Rechercher',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Bouton en fin de champ (scanner, filtres).
  final Widget? trailing;
  final FocusNode? focusNode;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_refresh);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _ctrl,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: context.textStyles.bodyLarge?.copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: c.searchFill,
          hintStyle: context.textStyles.bodyLarge?.copyWith(fontSize: 16, color: const Color(0xFFE5E5EA)),
          focusedBorder: const OutlineInputBorder(borderRadius: AppTokens.radiusPill, borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.search_rounded, color: c.text)),
          border: const OutlineInputBorder(borderRadius: AppTokens.radiusPill, borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderRadius: AppTokens.radiusPill, borderSide: BorderSide.none),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ctrl.text.isNotEmpty)
                IconButton(
                  tooltip: 'Effacer',
                  icon: Icon(Icons.close_rounded, color: c.text2, size: 20),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged?.call('');
                  },
                ),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}
