import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Couleurs propres à l'onglet Entraîner, toutes rangées ici : les dégradés
/// des cartes de jour, le bleu des muscles secondaires et les fonds des
/// couvertures de programme. Le reste vient du thème.
abstract final class PaletteEntrainer {
  /// Dégradé de chaque jour (indice 0 = lundi) : début, fin.
  static const jours = <(Color, Color)>[
    (Color(0xFFFF5A5F), Color(0xFFFF9A5A)),
    (Color(0xFFFFB02E), Color(0xFFFFE066)),
    (Color(0xFF34D399), Color(0xFFA3E635)),
    (Color(0xFF22D3EE), Color(0xFF3B82F6)),
    (Color(0xFF818CF8), Color(0xFFC084FC)),
    (Color(0xFFF472B6), Color(0xFFFB7185)),
    (Color(0xFFE2E8F0), Color(0xFF94A3B8)),
  ];

  /// Muscles secondaires sur le corps et dans la légende.
  static const secondaire = AppTokens.muscleSecondaire;

  /// Fond des couvertures d'idées de programme (du centre vers le bord).
  static const couvertureClair = Color(0xFF3A3A3F);
  static const couvertureSombre = Color(0xFF17171A);

  /// En-tête flou de la page d'un programme.
  static const heroHaut = Color(0xFF2A2A2C);
  static const heroTaches = <Color>[Color(0xFFAA7855), Color(0xFFBE9678), Color(0xFF969696)];

  /// Tuile de couverture d'un programme.
  static const tuileCouverture = Color(0xFF3A3A3D);
}

/// Jours abrégés des cartes (1 = lundi).
const joursAbreges = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const joursEntiers = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
