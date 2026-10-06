import 'package:flutter/material.dart';

import '../../commun/palette.dart';
import 'formulaire.dart';

/// Sept pastilles L M M J V S D : disque blanc quand le jour est retenu.
class JoursSelecteur extends StatelessWidget {
  const JoursSelecteur({super.key, required this.jours, required this.onChanged});

  /// Jours retenus (1 = lundi).
  final Set<int> jours;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => RangeePastilles<int>(
        ronde: true,
        choix: [for (var d = 1; d <= 7; d++) (d, joursEntiers[d - 1][0].toUpperCase(), joursEntiers[d - 1])],
        choisies: jours,
        onChanged: (d) => onChanged(jours.contains(d) ? ({...jours}..remove(d)) : {...jours, d}),
      );
}
