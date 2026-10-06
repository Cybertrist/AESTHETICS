import 'package:flutter/material.dart';

/// Jetons de la direction artistique : noir pur, cartes gris foncé arrondies,
/// police Figtree, accent corail réglable.
abstract final class AppTokens {
  // Fonds, du plus bas au plus haut.
  /// Fond de page : noir pur.
  static const bg = Color(0xFF000000);

  /// Carte, tuile, ligne groupée.
  static const surface = Color(0xFF131315);

  /// Surface plus claire : fond d'image d'exercice, bouton gris, champ.
  static const surface2 = Color(0xFF1D1D20);

  /// Cadre fin, piste de barre, surface la plus claire.
  static const surface3 = Color(0xFF2A2A2E);

  /// Survol, pression.
  static const hover = Color(0xFF48454E);

  /// Séparateur.
  static const line = Color(0xFF222226);

  /// Cadre fin (encadré Durée / Volume / Séries, puces).
  static const frame = Color(0xFF3A3A3C);

  /// Champ de recherche en pilule (gris violacé).
  static const searchFill = Color(0xFF48454E);

  // Anciens voiles : gardés pour les écrans qui s'en servent, désormais
  // des gris pleins.
  static const veil = Color(0xFF1C1C1E);
  static const veil2 = Color(0xFF2C2C2E);
  static const veilBorder = Color(0xFF3A3A3C);
  static const veilActive = Color(0xFF2C2C2E);

  // Texte.
  static const text = Color(0xFFFFFFFF);
  static const text2 = Color(0xFF8E8E93);
  /// Tertiaire : éclairci (il valait #5C5C61) pour passer 4,5 de contraste
  /// sur le fond et sur les cartes.
  static const text3 = Color(0xFF7E7E84);

  // Couleurs fonctionnelles.
  /// Vert de la coche ronde d'une série validée.
  static const success = Color(0xFF22D85F);

  /// Vert forêt : coche d'une série ou d'un exercice validé.
  static const foret = Color(0xFF228B22);

  /// Bouton principal : blanc, texte noir, quel que soit l'accent.
  static const bouton = Color(0xFFFFFFFF);
  static const onBouton = Color(0xFF000000);

  /// Fond de la ligne d'une série validée (vert très sombre).
  static const setDone = Color(0xFF12261A);
  static const warning = Color(0xFFFFC857);

  /// Orange de la flamme (série de semaines) et des muscles encore en
  /// récupération.
  static const orange = Color(0xFFFFA928);

  /// Page de la série : disque des jours de séance, coeur jaune de la grande
  /// flamme, et bande sombre des semaines tenues.
  static const feu = Color(0xFFFF9A00);
  static const feuJaune = Color(0xFFFFCB1F);
  static const feuBande = Color(0xFF4A2D00);

  /// Bleu des muscles secondaires (corps et légende de la fiche d'exercice).
  static const muscleSecondaire = Color(0xFF5AA2FF);

  /// Bleu du minuteur de repos, et rien d'autre (pilule du haut, ligne
  /// « Minuteur de repos », anneau, numéros de série du tableau).
  static const minuteur = Color(0xFF1E9BF0);

  /// Vert clair des cases actives (carte d'activité, série en cours).
  static const foretClair = Color(0xFF3FAE4A);

  /// Poignée d'un panneau du bas, bouton gris clair.
  static const poignee = Color(0xFF48454E);
  static const error = Color(0xFFFF453A);

  /// Barres de volume par muscle (rouge rosé) et leur piste.
  static const muscleBar = Color(0xFFF0294B);
  static const track = Color(0xFF3A3A3C);

  // Personnage : muscles travaillés en rouge orangé, repos en gris.
  static const muscle = Color(0xFFE0393E);
  static const muscleIdle = Color(0xFF5C6069);

  /// Texte posé sur l'accent par défaut (bleu) : blanc. Pour un accent
  /// clair, lire `context.colors.onAccent`.
  static const onAccent = Color(0xFFFFFFFF);

  // Couleurs des domaines (icônes, graphiques), à doser : l'appli reste
  // noire et blanche, l'accent fait le reste.
  static const domainTraining = Color(0xFF1E9BE9);
  static const domainNutrition = Color(0xFF4CD137);
  static const domainSleep = Color(0xFF9D8CFF);
  static const domainHeart = Color(0xFFF0294B);
  static const domainCoach = Color(0xFF3CE0FF);
  static const domainWeight = Color(0xFFFFC857);

  // Coins.
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r14 = 14.0;
  static const r16 = 16.0;
  static const r18 = 18.0;
  static const r26 = 26.0;
  static const rPill = 999.0;

  static const radius8 = BorderRadius.all(Radius.circular(r8));
  static const radius12 = BorderRadius.all(Radius.circular(r12));
  static const radius14 = BorderRadius.all(Radius.circular(r14));
  static const radius16 = BorderRadius.all(Radius.circular(r16));
  static const radius18 = BorderRadius.all(Radius.circular(r18));
  static const radius26 = BorderRadius.all(Radius.circular(r26));
  static const radiusPill = BorderRadius.all(Radius.circular(rPill));

  // Espacements.
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  /// Marge latérale des pages.
  static const gutter = 16.0;

  // Durées d'animation.
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 400);

  // Police : Figtree partout, embarquée (400 à 800).
  static const fontUi = 'Figtree';
  static const fontDisplay = 'Figtree';

  /// Montserrat (600 à 900), embarquée : gros titres du bilan du mois, des
  /// cartes de fin de séance et de la carte « Résumé mensuel », rien d'autre.
  static const fontBilan = 'Montserrat';

  /// Chiffres de largeur égale, pour que les colonnes s'alignent.
  static const tabular = [FontFeature.tabularFigures()];

  /// Plus de halo : gardés pour compatibilité, sans effet.
  static const haloHeight = 0.0;
  static const haloAlpha = 0.0;
}

/// Accents proposés dans Réglages > Apparence. Corail par défaut.
enum AccentChoice {
  corail('Corail', Color(0xFFFF5A5F)),
  bleu('Bleu', Color(0xFF1E9BE9)),
  ambre('Ambre', Color(0xFFFFA928)),
  lavande('Lavande', Color(0xFF9D8CFF)),
  lagon('Lagon', Color(0xFF3CE0FF)),
  peche('Pêche', Color(0xFFFF8A65));

  const AccentChoice(this.label, this.color);

  /// Ancien accent Ciel, fondu dans le bleu (même famille) : gardé pour le
  /// code qui le nomme. Absent de `values`.
  static const ciel = AccentChoice.bleu;
  final String label;
  final Color color;

  /// Texte posé sur l'accent : blanc sur le corail et le bleu, noir sur les accents clairs.
  Color get onColor => this == AccentChoice.corail || this == AccentChoice.bleu ? Colors.white : Colors.black;

  /// Texte à poser sur une couleur d'accent quelconque.
  static Color onColorFor(Color accent) {
    for (final a in AccentChoice.values) {
      if (a.color == accent) return a.onColor;
    }
    return accent.computeLuminance() > 0.35 ? Colors.black : Colors.white;
  }

  static AccentChoice fromName(String? name) =>
      AccentChoice.values.firstWhere((a) => a.name == name,
          orElse: () => AccentChoice.corail);
}

/// Les domaines de l'appli : couleur et icône, pour `IconHalo.domain` et
/// les graphiques.
enum AppDomain {
  entrainement('Entraînement', AppTokens.domainTraining, Icons.fitness_center_rounded),
  nutrition('Nutrition', AppTokens.domainNutrition, Icons.restaurant_rounded),
  sommeil('Sommeil', AppTokens.domainSleep, Icons.bedtime_rounded),
  coeur('Cœur', AppTokens.domainHeart, Icons.favorite_rounded),
  coach('Coach', AppTokens.domainCoach, Icons.auto_awesome_rounded),
  poids('Poids', AppTokens.domainWeight, Icons.monitor_weight_rounded);

  const AppDomain(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}
