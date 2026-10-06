import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/data/data.dart';
import '../core/theme/accent_controller.dart';
import 'orientation.dart';
import 'router.dart';
import '../features/ecran_accueil/atelier.dart';

/// Racine de l'appli : dépôts fournis par Provider, thème selon l'accent.
class AestheticApp extends StatefulWidget {
  const AestheticApp({super.key, required this.data, required this.accent});

  final AppData data;
  final AccentController accent;

  /// Plafond du texte agrandi par le système.
  static const texteMax = 1.3;

  @override
  State<AestheticApp> createState() => _AestheticAppState();
}

class _AestheticAppState extends State<AestheticApp> {
  late final GoRouter _router = createRouter(widget.data);
  late final RetourTelephone _retour = RetourTelephone(_router, widget.data);

  @override
  void initState() {
    super.initState();
    // Le geste de retour passe toujours par l'appli (voir [_retourGere]).
    SystemNavigator.setFrameworkHandlesBack(true);
    // Un appui sur un widget de l'écran du téléphone ouvre l'appli à la
    // bonne page (lancer la routine du jour, la série, les records...).
    if (Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST')) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_ouvrirLien).catchError((_) {});
      _liens = HomeWidget.widgetClicked.listen(_ouvrirLien, onError: (_) {});
    }
  }

  StreamSubscription<Uri?>? _liens;

  void _ouvrirLien(Uri? lien) {
    final chemin = cheminDuLien(lien);
    if (chemin == null || !widget.data.profile.hasProfile) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _router.go(chemin));
  }

  @override
  void dispose() {
    _liens?.cancel();
    _router.dispose();
    super.dispose();
  }

  /// Avec le retour prédictif d'Android, le système demande à l'appli si elle
  /// gère le retour. Les navigateurs imbriqués (onglets, pages plein écran)
  /// répondent chacun pour soi, et le dernier à parler peut dire « non »
  /// alors qu'une sous-page est ouverte : le geste fermait alors l'appli.
  /// On répond toujours « oui » ; [RetourTelephone] décide de la suite, et
  /// ferme l'appli seulement depuis l'accueil.
  static bool _retourGere(NavigationNotification n) {
    SystemNavigator.setFrameworkHandlesBack(true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MultiProvider(
      providers: [
        Provider<AppData>.value(value: d),
        Provider<Store>.value(value: d.store),
        ChangeNotifierProvider<AccentController>.value(value: widget.accent),
        ChangeNotifierProvider<ProfileRepo>.value(value: d.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: d.settings),
        ChangeNotifierProvider<ExerciseRepo>.value(value: d.exercises),
        ChangeNotifierProvider<RoutineRepo>.value(value: d.routines),
        ChangeNotifierProvider<ProgramRepo>.value(value: d.programs),
        ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
        ChangeNotifierProvider<NutritionRepo>.value(value: d.nutrition),
        ChangeNotifierProvider<HealthRepo>.value(value: d.health),
        ChangeNotifierProvider<CoachRepo>.value(value: d.coach),
      ],
      child: Consumer<AccentController>(
        builder: (context, accent, _) => MaterialApp.router(
          title: 'Aesthetics',
          debugShowCheckedModeBanner: false,
          theme: accent.theme,
          darkTheme: accent.theme,
          themeMode: ThemeMode.dark,
          routeInformationProvider: _router.routeInformationProvider,
          routeInformationParser: _router.routeInformationParser,
          routerDelegate: _router.routerDelegate,
          backButtonDispatcher: _retour,
          // Texte agrandi du système : suivi jusqu'à 1,3. Au-delà, les écrans
          // denses (saisie des séries, mensurations) se chevauchent.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: AestheticApp.texteMax,
            // Portrait sur téléphone, libre sur pliant ouvert et tablette.
            child: NotificationListener<NavigationNotification>(
              onNotification: _retourGere,
              child: AtelierEcranAccueil(child: VerrouOrientation(child: child ?? const SizedBox.shrink())),
            ),
          ),
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
