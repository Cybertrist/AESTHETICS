import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

/// Couleurs propres aux pages du bilan du mois (maquette validée) : chaque
/// page a sa couleur, en dégradé vers le noir. Elles ne servent nulle part
/// ailleurs.
abstract final class CouleursBilan {
  static const noir = Color(0xFF000000);

  // Haut et bas du dégradé de chaque page.
  static const ouverture = (noir, noir);
  static const seances = (Color(0xFF2C2C30), Color(0xFF050506));
  static const regularite = (Color(0xFF226640), noir);
  static const volume = (Color(0xFF175673), noir);
  static const serie = (Color(0xFF8A3B14), noir);
  static const muscles = (Color(0xFF0D1838), Color(0xFF02040A));
  static const records = (Color(0xFF7D5C12), noir);
  static const favoris = (Color(0xFF0E2B2B), Color(0xFF020606));
  static const resume = (Color(0xFF8A3B14), noir);

  /// Texte et traits.
  static const encre = Color(0xFFFFFFFF);

  /// Texte secondaire : blanc à 60 %.
  static const encre2 = Color(0x99FFFFFF);

  /// Segment de la barre du haut pas encore atteint.
  static const segment = Color(0x47FFFFFF);

  /// Écart en baisse, en hausse.
  static const baisse = Color(0xFFFF6B6B);
  static const hausse = Color(0xFF86F05A);

  /// Cases de la régularité.
  static const caseVide = Color(0x21FFFFFF);
  static const caseFaite = Color(0xFF86F05A);

  /// Barres des douze mois.
  static const barre = Color(0x52FFFFFF);

  /// Toile des muscles : le mois, le mois d'avant, la grille.
  static const toileMois = Color(0xFF4D8DFF);
  static const toileAvant = Color(0xFFA0A0AA);
  static const toileGrille = Color(0x4DFFFFFF);
  static const toileAxe = Color(0x2EFFFFFF);

  /// Bandeau penché et vignettes claires des exercices favoris.
  static const bandeau = Color(0xFFE9FBF8);
  static const bandeauEncre = Color(0xFF0D2A2A);
}

/// Style Montserrat des pages du bilan.
TextStyle tb(double taille, FontWeight poids, {Color couleur = CouleursBilan.encre, double? hauteur, double? espace}) => TextStyle(
      fontFamily: AppTokens.fontBilan,
      fontSize: taille,
      fontWeight: poids,
      color: couleur,
      height: hauteur,
      letterSpacing: espace,
      fontFeatures: AppTokens.tabular,
    );
