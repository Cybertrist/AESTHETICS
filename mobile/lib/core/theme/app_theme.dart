import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'tokens.dart';

/// Styles de texte hors TextTheme : chiffres, étiquettes, titres d'écran.
/// Roboto partout (400, 500, 700), chiffres tabulaires.
abstract final class AppType {
  /// Un chiffre ou un montant : Roboto gras, chiffres tabulaires
  /// (« 197 248kg » en 34, « 0:00:54 » en 16).
  static TextStyle number(double size,
          {FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(
        fontFamily: AppTokens.fontDisplay,
        fontSize: size,
        fontWeight: weight,
        height: 1.15,
        letterSpacing: size > 24 ? -0.3 : 0,
        color: color ?? AppTokens.text,
        fontFeatures: AppTokens.tabular,
      );

  /// Petite étiquette en capitales grises (SET, PREVIOUS, KG, REPS), en tête
  /// de colonne ou de carte. Passer le texte en capitales soi-même ou
  /// utiliser `SectionLabel`.
  static TextStyle overline({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: color ?? AppTokens.text2,
      );

  /// Titre d'écran (« Progress », « Focus Area ») : 20, medium.
  static TextStyle screenTitle({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontDisplay,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w500,
        color: color ?? AppTokens.text,
      );

  /// Titre d'une ligne de liste (« Bench Press ») : 16, regular.
  static TextStyle rowTitle({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w400,
        color: color ?? AppTokens.text,
      );

  /// Sous-titre gris d'une ligne (« 0/3 Done », « Chest »).
  static TextStyle rowSubtitle({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w400,
        color: color ?? AppTokens.text2,
      );

  /// Valeur à droite d'une ligne (poids, durée) : medium, tabulaire.
  static TextStyle rowValue({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: color ?? AppTokens.text,
        fontFeatures: AppTokens.tabular,
      );
}

abstract final class AppTheme {
  static TextTheme _textTheme() {
    const f = AppTokens.fontUi;
    const t = AppTokens.text;
    const t2 = AppTokens.text2;
    const tab = AppTokens.tabular;
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: f, fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1, color: t, fontFeatures: tab),
      displayMedium: TextStyle(fontFamily: f, fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.1, color: t, fontFeatures: tab),
      displaySmall: TextStyle(fontFamily: f, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.15, color: t, fontFeatures: tab),
      headlineLarge: TextStyle(fontFamily: f, fontSize: 32, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.2, color: t),
      headlineMedium: TextStyle(fontFamily: f, fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.2, color: t),
      headlineSmall: TextStyle(fontFamily: f, fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.25, color: t),
      titleLarge: TextStyle(fontFamily: f, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.3, color: t),
      titleMedium: TextStyle(fontFamily: f, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.35, color: t),
      titleSmall: TextStyle(fontFamily: f, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.3, color: t),
      bodyLarge: TextStyle(fontFamily: f, fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.45, color: t),
      bodyMedium: TextStyle(fontFamily: f, fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.45, color: t),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.4, color: t2),
      labelLarge: TextStyle(fontFamily: f, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.2, color: t),
      labelMedium: TextStyle(fontFamily: f, fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.2, color: t2),
      labelSmall: TextStyle(fontFamily: f, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2, height: 1.2, color: t2),
    );
  }

  /// Thème sombre complet pour un accent donné.
  static ThemeData dark(Color accent) {
    final colors = AppColors.forAccent(accent);
    final on = colors.onAccent;
    // Couleur des commandes (boutons texte, curseur, sélection) et de ce qui
    // se pose dessus.
    const commande = AppTokens.bouton;
    const surCommande = AppTokens.onBouton;
    final text = _textTheme();
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: on,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: accent,
      secondary: accent,
      onSecondary: on,
      secondaryContainer: AppTokens.surface2,
      onSecondaryContainer: AppTokens.text,
      tertiary: AppTokens.text2,
      onTertiary: AppTokens.bg,
      error: AppTokens.error,
      onError: Colors.white,
      surface: AppTokens.surface,
      onSurface: AppTokens.text,
      onSurfaceVariant: AppTokens.text2,
      surfaceContainerLowest: AppTokens.bg,
      surfaceContainerLow: AppTokens.surface,
      surfaceContainer: AppTokens.surface,
      surfaceContainerHigh: AppTokens.surface2,
      surfaceContainerHighest: AppTokens.surface3,
      outline: AppTokens.frame,
      outlineVariant: AppTokens.line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppTokens.text,
      onInverseSurface: AppTokens.bg,
      inversePrimary: accent,
    );

    const pillShape = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 12);
    final labelStyle = text.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w500);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: AppTokens.radius12,
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppTokens.fontUi,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: AppTokens.bg,
      canvasColor: AppTokens.bg,
      dividerColor: AppTokens.line,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      splashColor: Colors.white.withValues(alpha: 0.06),
      hoverColor: Colors.white.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [colors],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: AppTokens.bg),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTokens.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppTokens.gutter,
        titleTextStyle: AppType.screenTitle(),
        iconTheme: const IconThemeData(color: AppTokens.text, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppTokens.bg,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      iconTheme: const IconThemeData(color: AppTokens.text, size: 22),
      cardTheme: const CardThemeData(
        color: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.radius12),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: const DividerThemeData(color: AppTokens.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.bouton,
          foregroundColor: AppTokens.onBouton,
          disabledBackgroundColor: AppTokens.bouton.withValues(alpha: 0.25),
          disabledForegroundColor: AppTokens.text3,
          shape: pillShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 44),
          textStyle: labelStyle,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.surface2,
          foregroundColor: AppTokens.text,
          shape: pillShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 44),
          textStyle: labelStyle,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.text,
          side: const BorderSide(color: AppTokens.frame),
          shape: pillShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 44),
          textStyle: labelStyle,
        ),
      ),
      // Commandes en blanc : le corail est réservé aux muscles, aux étiquettes
      // de muscle et au point de notification (design du 2 octobre).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: commande,
          shape: pillShape,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppTokens.text),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppTokens.bouton,
        foregroundColor: AppTokens.onBouton,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle: labelStyle,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppTokens.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: text.bodyMedium!.copyWith(color: AppTokens.text3),
        labelStyle: text.bodyMedium!.copyWith(color: AppTokens.text2),
        floatingLabelStyle: text.bodyMedium!.copyWith(color: AppTokens.text2),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: AppTokens.error),
        prefixIconColor: AppTokens.text2,
        suffixIconColor: AppTokens.text2,
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(commande),
        errorBorder: border(AppTokens.error),
        focusedErrorBorder: border(AppTokens.error),
        disabledBorder: border(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: commande,
        selectionColor: commande.withValues(alpha: 0.3),
        selectionHandleColor: commande,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius16),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: AppTokens.text2),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppTokens.surface,
        showDragHandle: true,
        dragHandleColor: AppTokens.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r16)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppTokens.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius12),
        textStyle: text.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppTokens.surface2),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppTokens.radius12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.surface,
        selectedColor: AppTokens.surface2,
        disabledColor: AppTokens.surface,
        checkmarkColor: AppTokens.text,
        deleteIconColor: AppTokens.text2,
        labelStyle: text.labelLarge!.copyWith(color: AppTokens.text2),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: AppTokens.text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppTokens.text,
        unselectedLabelColor: AppTokens.text2,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall!.copyWith(fontWeight: FontWeight.w400),
        indicatorColor: AppTokens.text,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppTokens.line,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppTokens.text, width: 3),
          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.surface2,
        contentTextStyle: text.bodyMedium,
        actionTextColor: commande,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: commande,
        inactiveTrackColor: AppTokens.track,
        thumbColor: AppTokens.text,
        overlayColor: commande.withValues(alpha: 0.16),
        valueIndicatorColor: AppTokens.surface2,
        valueIndicatorTextStyle: text.labelLarge,
        trackHeight: 4,
      ),
      // Interrupteur de la maquette : allumé, piste blanche et pastille noire
      // (jamais de corail sur une commande).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppTokens.onBouton : AppTokens.text2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppTokens.bouton : AppTokens.surface2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppTokens.bouton : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppTokens.onBouton),
        side: const BorderSide(color: AppTokens.text3, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppTokens.bouton : AppTokens.text3,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: commande,
        linearTrackColor: AppTokens.track,
        circularTrackColor: AppTokens.track,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppTokens.text,
        textColor: AppTokens.text,
        titleTextStyle: AppType.rowTitle(),
        subtitleTextStyle: AppType.rowSubtitle(),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            color: s.contains(WidgetState.selected) ? AppTokens.text : AppTokens.text3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppTokens.text : AppTokens.text3,
            size: 24,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppTokens.bg,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppTokens.text),
        unselectedIconTheme: const IconThemeData(color: AppTokens.text3),
        selectedLabelTextStyle: text.labelSmall!.copyWith(color: AppTokens.text),
        unselectedLabelTextStyle: text.labelSmall!.copyWith(color: AppTokens.text3),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppTokens.surface,
          foregroundColor: AppTokens.text2,
          selectedBackgroundColor: AppTokens.surface3,
          selectedForegroundColor: AppTokens.text,
          side: BorderSide.none,
          textStyle: text.labelLarge,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: AppTokens.surface2, borderRadius: AppTokens.radius8),
        textStyle: text.bodySmall!.copyWith(color: AppTokens.text),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppTokens.surface,
        headerForegroundColor: AppTokens.text,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius16),
        // Comme dans l'appli : le jour choisi est un disque blanc, chiffre noir.
        todayBorder: const BorderSide(color: commande),
        // Sans cette ligne, aujourd'hui choisi prend la couleur d'accent.
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? commande : Colors.transparent,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? surCommande : commande,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? surCommande : AppTokens.text,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? commande : Colors.transparent,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? surCommande : AppTokens.text,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? commande : Colors.transparent,
        ),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: commande),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppTokens.text2),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppTokens.surface,
        hourMinuteColor: AppTokens.surface2,
        hourMinuteTextColor: AppTokens.text,
        dialBackgroundColor: AppTokens.surface2,
        dialHandColor: commande,
        dialTextColor: AppTokens.text,
        dayPeriodColor: AppTokens.surface2,
        entryModeIconColor: AppTokens.text2,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.radius16),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: commande),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppTokens.text2),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppTokens.error,
        textColor: Colors.white,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppTokens.text2,
        collapsedIconColor: AppTokens.text3,
        shape: Border(),
        collapsedShape: Border(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.2)),
        radius: const Radius.circular(8),
      ),
    );
  }
}
