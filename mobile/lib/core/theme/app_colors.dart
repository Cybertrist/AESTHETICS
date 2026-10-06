import 'package:flutter/material.dart';

import 'tokens.dart';

/// Couleurs propres à l'appli, lues par `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.hover,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.muscle,
    required this.muscleIdle,
  });

  factory AppColors.forAccent(Color accent) => AppColors(
        bg: AppTokens.bg,
        surface: AppTokens.surface,
        surface2: AppTokens.surface2,
        surface3: AppTokens.surface3,
        hover: AppTokens.hover,
        line: AppTokens.line,
        text: AppTokens.text,
        text2: AppTokens.text2,
        text3: AppTokens.text3,
        accent: accent,
        onAccent: AccentChoice.onColorFor(accent),
        success: AppTokens.success,
        warning: AppTokens.warning,
        error: AppTokens.error,
        muscle: AppTokens.muscle,
        muscleIdle: AppTokens.muscleIdle,
      );

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color hover;
  final Color line;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color error;
  final Color muscle;
  final Color muscleIdle;

  /// Accent très atténué, pour les fonds de pastilles et d'icônes.
  Color get accentSoft => accent.withValues(alpha: 0.16);

  /// Accent à peine visible, pour les fonds sélectionnés.
  Color get accentFaint => accent.withValues(alpha: 0.08);

  /// Bordure teintée d'accent (boutons secondaires, puces actives).
  Color get accentBorder => accent.withValues(alpha: 0.5);

  // Voiles blancs (voir AppTokens).
  Color get veil => AppTokens.veil;
  Color get veil2 => AppTokens.veil2;
  Color get veilBorder => AppTokens.veilBorder;
  Color get veilActive => AppTokens.veilActive;

  // Couleurs des domaines, pour les icônes à halo et les graphiques.
  Color get training => AppTokens.domainTraining;
  Color get nutrition => AppTokens.domainNutrition;
  Color get sleep => AppTokens.domainSleep;
  Color get heart => AppTokens.domainHeart;
  Color get coach => AppTokens.domainCoach;
  Color get weight => AppTokens.domainWeight;

  /// Couleur d'un domaine.
  Color domain(AppDomain d) => d.color;

  // Couleurs propres aux écrans d'entraînement.
  /// Fond de la ligne d'une série validée.
  Color get setDone => AppTokens.setDone;

  /// Coche ronde d'une série validée.
  Color get check => AppTokens.foret;

  /// Bleu réservé au minuteur de repos.
  Color get minuteur => AppTokens.minuteur;

  /// Orange de la flamme et des muscles en récupération.
  Color get orange => AppTokens.orange;

  /// Bleu des muscles secondaires.
  Color get muscleSecondaire => AppTokens.muscleSecondaire;

  /// Vert forêt (série ou exercice validé) et son clair.
  Color get foret => AppTokens.foret;
  Color get foretClair => AppTokens.foretClair;

  /// Bouton principal et son texte.
  Color get bouton => AppTokens.bouton;
  Color get onBouton => AppTokens.onBouton;

  /// Barre de volume par muscle et sa piste.
  Color get muscleBar => AppTokens.muscleBar;
  Color get track => AppTokens.track;

  /// Cadre fin et champ de recherche en pilule.
  Color get frame => AppTokens.frame;
  Color get searchFill => AppTokens.searchFill;

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? hover,
    Color? line,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? error,
    Color? muscle,
    Color? muscleIdle,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surface2: surface2 ?? this.surface2,
        surface3: surface3 ?? this.surface3,
        hover: hover ?? this.hover,
        line: line ?? this.line,
        text: text ?? this.text,
        text2: text2 ?? this.text2,
        text3: text3 ?? this.text3,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        muscle: muscle ?? this.muscle,
        muscleIdle: muscleIdle ?? this.muscleIdle,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      hover: l(hover, other.hover),
      line: l(line, other.line),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      muscle: l(muscle, other.muscle),
      muscleIdle: l(muscleIdle, other.muscleIdle),
    );
  }
}

extension AppThemeContext on BuildContext {
  /// Couleurs de l'appli (accent compris).
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      AppColors.forAccent(AccentChoice.corail.color);

  /// Styles de texte du thème.
  TextTheme get textStyles => Theme.of(this).textTheme;
}
