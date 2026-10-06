import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show IsolateNameServer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'editeur.dart';

/// Nom du port par lequel les boutons de la notification du repos rejoignent
/// le minuteur : Android les remet à un second isolat, sans rouvrir l'appli.
const _portActionsRepos = 'aesthetics.repos.actions';

/// Reçoit, hors de l'appli, un bouton de la notification du repos et le
/// passe au minuteur.
@pragma('vm:entry-point')
void reposActionEnFond(NotificationResponse r) {
  IsolateNameServer.lookupPortByName(_portActionsRepos)?.send(r.actionId);
}

/// Minuteur de repos partagé par toute l'appli : il continue quand on change
/// d'onglet, prévient par une notification si l'appli passe en arrière-plan,
/// et note le repos réellement pris sur la série qui l'a lancé.
class ReposMinuteur extends ChangeNotifier with WidgetsBindingObserver {
  ReposMinuteur._();

  static final instance = ReposMinuteur._();

  static const _notifId = 4207;

  /// L'heure du téléphone : le minuteur ne compte pas des tops, il compare
  /// des heures, donc il reste juste quand l'appli dort en arrière-plan.
  @visibleForTesting
  DateTime Function() horloge = DateTime.now;

  /// Retard au-delà duquel la fin du repos n'est plus annoncée (son,
  /// vibration) au retour dans l'appli : la notification l'a déjà fait.
  static const retardMuet = Duration(seconds: 3);

  DateTime? _debut;
  DateTime? _fin;
  int _total = 0;
  Timer? _tick;
  bool _son = true;
  bool _vibration = true;

  /// Volume du carillon et force de la vibration : 0, 1 ou 2.
  int _volume = 2;
  int _force = 1;

  /// Décompte vocal des cinq dernières secondes, « go » à la fin.
  bool _voix = false;
  int _secondeDite = 0;
  bool _observe = false;
  bool _enFond = false;

  /// En arrière-plan, l'appli encore éveillée à la fin du repos sonne
  /// elle-même : elle a alors retiré la notification programmée.
  bool _relais = false;
  String? titre;

  SessionRepo? _repo;
  String? _seId;
  String? _setId;

  final _notifs = FlutterLocalNotificationsPlugin();
  bool _notifsPretes = false;
  AudioPlayer? _lecteur;

  bool get actif => _fin != null;
  int get total => _total;

  Duration get restant {
    final f = _fin;
    if (f == null) return Duration.zero;
    final d = f.difference(horloge());
    return d.isNegative ? Duration.zero : d;
  }

  /// Part écoulée, de 0 à 1.
  double get progression {
    if (!actif || _total <= 0) return 0;
    return (1 - restant.inMilliseconds / (_total * 1000)).clamp(0, 1);
  }

  /// Autorisation et canal des notifications, à appeler en ouvrant la séance.
  Future<void> preparer() async {
    unawaited(Bip.charger());
    if (_notifsPretes) return;
    try {
      tzdata.initializeTimeZones();
      await _notifs.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: _reponse,
        onDidReceiveBackgroundNotificationResponse: reposActionEnFond,
      );
      _ecouterActions();
      await _notifs
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _notifsPretes = true;
    } catch (_) {
      // Pas de notifications (tests, plateforme sans plugin) : le minuteur marche quand même.
    }
  }

  void demarrer(
    int secondes, {
    String? titre,
    bool son = true,
    bool vibration = true,
    int volume = 2,
    int force = 1,
    bool voix = false,
    SessionRepo? repo,
    String? seId,
    String? setId,
  }) {
    if (secondes <= 0) return;
    _noterRepos();
    if (!_observe) {
      WidgetsBinding.instance.addObserver(this);
      _observe = true;
    }
    this.titre = titre;
    _son = son;
    _vibration = vibration;
    _volume = volume;
    _force = force;
    _voix = voix;
    _secondeDite = 0;
    if (voix) unawaited(Bip.chargerVoix());
    _repo = repo;
    _seId = seId;
    _setId = setId;
    _total = secondes;
    _debut = horloge();
    _fin = _debut!.add(Duration(seconds: secondes));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _verifier());
    _secondeNotifiee = -1;
    _relais = false;
    if (_enFond) _programmer();
    _majNotifRepos();
    notifyListeners();
  }

  /// Ajoute ou retire du temps (15 s par défaut).
  void ajuster(int secondes) {
    final f = _fin;
    if (f == null) return;
    final nouvelle = f.add(Duration(seconds: secondes));
    if (!nouvelle.isAfter(horloge())) {
      passer();
      return;
    }
    _fin = nouvelle;
    _total = math.max(1, _total + secondes);
    if (_enFond) _programmer();
    _secondeNotifiee = -1;
    _majNotifRepos();
    notifyListeners();
  }

  void passer() => _arreter(alerte: false);

  /// Arrête le repos lancé par la série [setId] (elle vient d'être dévalidée)
  /// sans rien noter dessus. Un repos lancé par une autre série continue.
  void annulerPour(String setId) {
    if (_setId != setId) return;
    _repo = null;
    _seId = null;
    _setId = null;
    _arreter(alerte: false);
  }

  void _verifier() {
    final f = _fin;
    if (f != null && !horloge().isBefore(f)) {
      // Fini depuis un moment (appli endormie en arrière-plan) : la
      // notification a déjà prévenu, on ne sonne pas une seconde fois.
      final tard = _notifsPretes && horloge().difference(f) > retardMuet;
      _arreter(alerte: true, muet: tard);
    } else {
      // À une seconde et demie de la fin, hors de l'appli mais encore
      // éveillée : elle prend le relais de la notification programmée, pour
      // jouer son propre carillon (il s'entend téléphone en silencieux).
      if (_enFond && !_relais && f != null && f.difference(horloge()) <= const Duration(milliseconds: 1500)) {
        _relais = true;
        _annulerNotif();
      }
      _decompte(f);
      _majNotifRepos();
      notifyListeners();
    }
  }

  /// Dernière seconde du décompte déjà signalée par une vibration.
  int _secondeVibree = 0;

  /// Trois secondes avant la fin, un petit coup de vibreur par seconde.
  void _decompte(DateTime? fin) {
    if (fin != null && _voix && _son && !_enFond) {
      final r = (fin.difference(horloge()).inMilliseconds / 1000).ceil();
      final mot = Bip.voix['$r'];
      if (r >= 1 && r <= 5 && r != _secondeDite && mot != null) {
        _secondeDite = r;
        _jouer(mot, _volume);
      }
    }
    if (fin == null || !_vibration || _enFond) return;
    final reste = (fin.difference(horloge()).inMilliseconds / 1000).ceil();
    if (reste < 1 || reste > 3 || reste == _secondeVibree) return;
    _secondeVibree = reste;
    surDecompte?.call(reste);
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    // Un tic net, à la force réglée : le même pour 3, 2 et 1.
    Vibration.vibrate(duration: dureeTic(_force), amplitude: amplitudeVibration(_force)).catchError((_) {});
  }

  /// Pour les tests : appelé à chaque vibration du décompte (3, 2, 1).
  @visibleForTesting
  void Function(int reste)? surDecompte;

  void _arreter({required bool alerte, bool muet = false}) {
    _secondeVibree = 0;
    _noterRepos(fini: alerte);
    _tick?.cancel();
    _tick = null;
    _fin = null;
    _debut = null;
    _retirerNotifRepos();
    final relais = _relais;
    _relais = false;
    // En arrière-plan, appli endormie : la notification programmée prévient.
    if (!(alerte && _enFond)) _annulerNotif();
    if (alerte && !muet && (!_enFond || relais)) _alerter();
    // Appli éveillée en arrière-plan : elle a sonné, il reste à l'écrire.
    if (alerte && _enFond && relais) _montrerFin();
    notifyListeners();
  }

  /// Enregistre sur la série le repos réellement pris ; pour un repos allé à
  /// son terme ([fini]), jamais plus que sa durée, même constaté en retard.
  void _noterRepos({bool fini = false}) {
    final debut = _debut;
    final repo = _repo;
    final seId = _seId;
    final setId = _setId;
    _repo = null;
    _seId = null;
    _setId = null;
    if (debut == null || repo == null || seId == null || setId == null) return;
    final a = repo.active;
    if (a == null) return;
    for (final e in a.exercices) {
      if (e.id != seId) continue;
      for (final s in e.series) {
        if (s.id == setId) {
          final pris = horloge().difference(debut).inSeconds;
          final sec = fini ? math.min(pris, _total) : pris;
          unawaited(repo.updateSet(seId, s.copyWith(tempsReposSec: sec)));
          return;
        }
      }
    }
  }

  /// Joue un son de la séance. Dans une zone protégée : sans lecteur audio
  /// (tests, appareil sans son), l'erreur ne remonte pas dans l'appli.
  void _jouer(Uint8List son, int volume, {bool baisserMusique = false}) {
    // Pas de lecteur audio pendant les tests automatiques.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    runZonedGuarded(() async {
      _lecteur ??= AudioPlayer();
      await _lecteur!.stop();
      await _lecteur!.setVolume(const [0.3, 0.6, 1.0][volume.clamp(0, 2)]);
      await _lecteur!.play(BytesSource(son), ctx: baisserMusique ? AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build() : null);
    }, (_, _) {});
  }

  /// Petite fanfare d'un record battu pendant la séance.
  Future<void> jouerRecord(int volume) async => _jouer(Bip.record(), volume, baisserMusique: true);

  /// Fait entendre le décompte vocal en entier, pour l'essayer.
  Future<void> essayerVoix(int volume) async {
    await Bip.chargerVoix();
    for (final m in const ['5', '4', '3', '2', '1', 'go']) {
      final mot = Bip.voix[m];
      if (mot != null) _jouer(mot, volume);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Fait entendre le son de fin de repos à ce volume (0, 1 ou 2), pour
  /// le choisir dans les réglages.
  Future<void> essayerSon(int volume) async => _jouer(Bip.carillon(), volume);

  /// Vibration de fin de repos : un seul coup franc, plus long que les tics
  /// du décompte, d'autant plus long que la force est grande.
  static List<int> motifVibration(int force) => switch (force.clamp(0, 2)) {
        0 => const [0, 180],
        1 => const [0, 320],
        _ => const [0, 500],
      };

  /// Puissance du vibreur (1 à 255) pour une force : légère, moyenne, forte.
  static int amplitudeVibration(int force) => const [80, 170, 255][force.clamp(0, 2)];

  /// Durée d'un tic du décompte, en millisecondes.
  static int dureeTic(int force) => const [50, 80, 120][force.clamp(0, 2)];

  /// Fait vibrer la fin de repos à cette force.
  static Future<void> vibrerFin(int force) =>
      Vibration.vibrate(pattern: motifVibration(force), intensities: [0, amplitudeVibration(force)]);

  /// Pour les tests : appelé à chaque alerte de fin de repos (son, vibration).
  @visibleForTesting
  VoidCallback? surAlerte;

  Future<void> _alerter() async {
    surAlerte?.call();
    if (_vibration) {
      try {
        await vibrerFin(_force);
      } catch (_) {
        HapticFeedback.heavyImpact();
      }
    }
    if (_son) {
      try {
        _lecteur ??= AudioPlayer();
        await _lecteur!.setVolume(const [0.3, 0.6, 1.0][_volume.clamp(0, 2)]);
        await _lecteur!.play(
          BytesSource(_voix ? (Bip.voix['go'] ?? Bip.carillon()) : Bip.carillon()),
          ctx: AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build(),
        );
      } catch (_) {
        SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fond = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (fond == _enFond) return;
    _enFond = fond;
    if (fond) {
      _programmer();
    } else {
      _annulerNotif();
      _verifier();
    }
    // À chaque passage au premier ou à l'arrière-plan, la notification de
    // séance est reposée.
    _majNotifSeance();
  }

  String get _corpsFin => titre == null ? 'À toi de jouer pour la série suivante.' : 'Série suivante : $titre';

  /// « Repos terminé », affichée tout de suite et sans son : l'appli vient
  /// de jouer le carillon elle-même.
  Future<void> _montrerFin() async {
    if (!_notifsPretes) return;
    try {
      await _notifs.show(
        id: _notifId,
        title: 'Repos terminé',
        body: _corpsFin,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'repos_fin_muet',
            'Fin du repos (sans son)',
            channelDescription: 'Prévient quand le repos entre deux séries est terminé',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: false,
            enableVibration: false,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _programmer() async {
    final f = _fin;
    if (f == null || !_notifsPretes) return;
    _relais = false;
    await _annulerNotif();
    final quand = tz.TZDateTime.from(f, tz.UTC);
    final details = NotificationDetails(
      // Le canal sonne comme une alarme : le carillon de l'appli s'entend
      // téléphone en silencieux, au volume des alarmes. Un canal ne change
      // plus une fois créé, d'où un canal muet à part.
      android: AndroidNotificationDetails(
        _son ? 'repos_fin' : 'repos_fin_muet',
        _son ? 'Fin du repos' : 'Fin du repos (sans son)',
        channelDescription: 'Prévient quand le repos entre deux séries est terminé',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: _son,
        sound: _son ? const RawResourceAndroidNotificationSound('fin_repos') : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: _vibration,
      ),
    );
    const texte = 'Repos terminé';
    final corps = _corpsFin;
    try {
      await _notifs.zonedSchedule(
        id: _notifId,
        scheduledDate: quand,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: texte,
        body: corps,
      );
    } catch (_) {
      try {
        await _notifs.zonedSchedule(
          id: _notifId,
          scheduledDate: quand,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: texte,
          body: corps,
        );
      } catch (_) {}
    }
  }

  Future<void> _annulerNotif() async {
    if (!_notifsPretes) return;
    try {
      await _notifs.cancel(id: _notifId);
    } catch (_) {}
  }

  static const _notifReposId = 4209;
  ReceivePort? _portActions;
  int _secondeNotifiee = -1;

  /// Les boutons de la notification du repos arrivent par un port nommé.
  void _ecouterActions() {
    if (_portActions != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portActionsRepos);
    IsolateNameServer.registerPortWithName(port.sendPort, _portActionsRepos);
    port.listen((m) => actionNotif(m is String ? m : null));
    _portActions = port;
  }

  /// Un bouton de la notification du repos : « Ignorer », « -10 s », « +10 s ».
  @visibleForTesting
  void actionNotif(String? id) {
    switch (id) {
      case 'repos_ignorer':
        passer();
      case 'repos_moins':
        ajuster(-10);
      case 'repos_plus':
        ajuster(10);
    }
  }

  /// La notification du repos en cours : le compte à rebours (tenu par
  /// Android, juste même si l'appli dort), une barre qui se vide, la série
  /// qui suit, et trois boutons. Pas d'image : le compte à rebours seul. Elle se retire d'elle-même à la fin.
  Future<void> _majNotifRepos() async {
    final f = _fin;
    if (f == null || !_notifsPretes) return;
    final reste = f.difference(horloge());
    final secondes = (reste.inMilliseconds / 1000).ceil();
    if (secondes <= 0 || secondes == _secondeNotifiee) return;
    _secondeNotifiee = secondes;
    final active = _seances?.active;
    final p = serieAFaire(active);
    String? suite;
    if (active != null && p != null) {
      final (nom, serie) = texteNotifSeance(active, (id) => _exercices?.nameOf(id) ?? '', _profil?.unite ?? UnitePoids.kg);
      suite = [if (nom.isNotEmpty) 'Suivant : $nom', ?serie].join('\n');
    }
    try {
      await _notifs.show(
        id: _notifReposId,
        title: 'Repos',
        body: suite?.split('\n').first,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'repos_cours',
            'Repos en cours',
            channelDescription: 'Le compte à rebours du repos entre deux séries',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            category: AndroidNotificationCategory.stopwatch,
            usesChronometer: true,
            chronometerCountDown: true,
            when: f.millisecondsSinceEpoch,
            timeoutAfter: reste.inMilliseconds,
            showProgress: true,
            maxProgress: math.max(1, _total),
            progress: secondes.clamp(0, math.max(1, _total)),
            styleInformation: suite == null ? null : BigTextStyleInformation(suite),
            actions: const [
              AndroidNotificationAction('repos_ignorer', 'Ignorer', cancelNotification: false),
              AndroidNotificationAction('repos_moins', '-10 s', cancelNotification: false),
              AndroidNotificationAction('repos_plus', '+10 s', cancelNotification: false),
            ],
          ),
        ),
      );
    } catch (_) {}
    // Fini pendant l'envoi : rien ne doit rester affiché.
    if (_fin == null) _retirerNotifRepos();
  }

  Future<void> _retirerNotifRepos() async {
    _secondeNotifiee = -1;
    if (!_notifsPretes) return;
    try {
      await _notifs.cancel(id: _notifReposId);
    } catch (_) {}
  }

  static const _notifSeanceId = 4208;
  SessionRepo? _seances;
  SettingsRepo? _reglagesSeance;
  ExerciseRepo? _exercices;
  ProfileRepo? _profil;
  String? _seanceAffichee;

  /// L'écran de la séance, quand il est ouvert : prévenu d'une série validée
  /// depuis la notification (il lance le repos et ouvre l'exercice suivant).
  void Function(SessionExercise se, WorkoutSet set)? surSerieValidee;

  /// Tient la notification de séance à jour : l'exercice et la série à faire,
  /// avec « Terminer la série ». Affichée tant qu'une séance est ouverte et
  /// que le réglage le veut, retirée sinon.
  void suivreSeance(SessionRepo seances, SettingsRepo reglages, {ExerciseRepo? exercices, ProfileRepo? profil}) {
    if (!identical(_seances, seances)) {
      _seances?.removeListener(_majNotifSeance);
      _seances = seances..addListener(_majNotifSeance);
    }
    if (!identical(_reglagesSeance, reglages)) {
      _reglagesSeance?.removeListener(_majNotifSeance);
      _reglagesSeance = reglages..addListener(_majNotifSeance);
    }
    _exercices = exercices ?? _exercices;
    _profil = profil ?? _profil;
    _majNotifSeance();
  }

  /// La prochaine série à faire de la séance, dans l'ordre des exercices.
  static ({SessionExercise se, WorkoutSet set, int rang})? serieAFaire(WorkoutSession? s) {
    if (s == null) return null;
    for (final e in s.exercices) {
      for (var i = 0; i < e.series.length; i++) {
        if (!e.series[i].fait) return (se: e, set: e.series[i], rang: i);
      }
    }
    return null;
  }

  /// Titre et texte de la notification de séance.
  @visibleForTesting
  static (String, String?) texteNotifSeance(WorkoutSession s, String Function(String id) nom, UnitePoids unite) {
    final p = serieAFaire(s);
    if (p == null) return ('Séance en cours', s.exercices.isEmpty ? null : 'Toutes les séries sont faites');
    final x = p.set;
    final valeur = (x.reps ?? 0) > 0 || (x.poids ?? 0) > 0
        ? Fmt.charge(x.poids, x.reps, unite)
        : ((x.dureeSec ?? 0) > 0 ? Fmt.minSec(x.dureeSec!) : null);
    final serie = 'Série ${p.rang + 1}/${p.se.series.length}';
    return (nom(p.se.exerciseId), valeur == null ? serie : '$serie · $valeur');
  }

  Future<void> _majNotifSeance() async {
    if (!_notifsPretes) return;
    final active = _seances?.active;
    final voulue = active != null && (_reglagesSeance?.settings.notifSeance ?? true);
    // Rien à retirer deux fois ; en revanche on la repose à chaque changement
    // de la séance : si elle a été balayée, elle revient d'elle-même.
    if (!voulue && _seanceAffichee == null) return;
    try {
      if (!voulue) {
        _seanceAffichee = null;
        await _notifs.cancel(id: _notifSeanceId);
        return;
      }
      final (titre, texte) = texteNotifSeance(active, (id) => _exercices?.nameOf(id) ?? 'Séance en cours', _profil?.unite ?? UnitePoids.kg);
      final p = serieAFaire(active);
      _seanceAffichee = '$titre|$texte';
      await _notifs.show(
        id: _notifSeanceId,
        title: titre,
        body: texte,
        payload: p == null ? null : '${p.se.id}|${p.set.id}',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'seance',
            'Séance en cours',
            channelDescription: 'L’exercice et la série en cours pendant une séance',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            category: AndroidNotificationCategory.workout,
            actions: [
              // L'appli revient au premier plan : la série est validée là où
              // vit la séance, et le repos démarre comme d'habitude.
              if (p != null) const AndroidNotificationAction('valider', 'Terminer la série', showsUserInterface: true, cancelNotification: false),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  /// « Terminer la série » dans la notification : la série visée est validée.
  Future<void> _reponse(NotificationResponse r) async {
    if (r.actionId != 'valider') return;
    final repo = _seances;
    final ids = (r.payload ?? '').split('|');
    if (repo == null || ids.length != 2) return;
    final se = repo.active?.exercices.where((e) => e.id == ids[0]).firstOrNull;
    final set = se?.series.where((x) => x.id == ids[1]).firstOrNull;
    if (se == null || set == null || set.fait) return;
    final ed = EditeurDirect(repo);
    try {
      if (!await ed.validerSerie(se.id, set, fait: true)) return;
    } finally {
      ed.dispose();
    }
    final ecran = surSerieValidee;
    if (ecran != null) {
      ecran(se, set);
    } else if (se.reposSec > 0) {
      // Séance réduite : le repos démarre quand même.
      final g = _reglagesSeance?.settings;
      demarrer(se.reposSec, son: g?.sonMinuteur ?? true, vibration: g?.vibrationMinuteur ?? true, volume: g?.volumeMinuteur ?? 2, force: g?.forceVibration ?? 1, voix: g?.decompteVocal ?? false, repo: repo, seId: se.id, setId: set.id);
    }
  }

  /// Pour les tests : fait comme si les notifications étaient autorisées.
  @visibleForTesting
  set notificationsPretes(bool v) => _notifsPretes = v;

  /// Pour les tests : remet le minuteur à zéro.
  @visibleForTesting
  void reinitialiser() {
    _tick?.cancel();
    _tick = null;
    _fin = null;
    _debut = null;
    _repo = null;
    _seId = null;
    _setId = null;
    _enFond = false;
    _notifsPretes = false;
    horloge = DateTime.now;
    surAlerte = null;
    notifyListeners();
  }
}

/// Sons de la séance, synthétisés (pas de fichier son à embarquer).
abstract final class Bip {
  static Uint8List? _cache;
  static Uint8List? _cacheRecord;

  /// Fin de repos : quatre notes pures égrenées très vite (la, ré, mi, la),
  /// qui restent tenues ensemble puis s'arrêtent net.
  static Uint8List carillon() => _fichier ?? (_cache ??= _wav(const [(440.0, 0.0), (587.33, 0.10), (659.25, 0.18), (880.0, 0.30)], 0.82, tenue: true));

  /// Le son de fin de repos embarqué (`assets/sons/fin-repos.wav`), une fois
  /// chargé ; tant qu'il ne l'est pas, les quatre notes calculées.
  static Uint8List? _fichier;

  /// Les mots du décompte vocal (« 5 » à « 1 », « go »), une fois chargés.
  static final voix = <String, Uint8List>{};

  static Future<void> chargerVoix() async {
    for (final m in const ['5', '4', '3', '2', '1', 'go']) {
      if (voix.containsKey(m)) continue;
      try {
        final d = await rootBundle.load('assets/sons/decompte/$m.wav');
        voix[m] = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
      } catch (_) {}
    }
  }

  /// Le son de record embarqué (`assets/sons/record.wav`), une fois chargé.
  static Uint8List? _fichierRecord;

  static Future<Uint8List?> _lire(String chemin) async {
    try {
      final d = await rootBundle.load(chemin);
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> charger() async {
    _fichier ??= await _lire('assets/sons/fin-repos.wav');
    _fichierRecord ??= await _lire('assets/sons/record.wav');
  }

  /// Record battu : le son embarqué ; tant qu'il n'est pas chargé, deux
  /// notes douces qui montent.
  static Uint8List record() => _fichierRecord ?? (_cacheRecord ??= _wav(const [(783.99, 0.0), (1174.66, 0.15)], 1.0));

  /// Une note pure par entrée (fréquence, instant de départ). [tenue] : la
  /// note frappe puis reste à mi-voix jusqu'à la fin ; sinon elle s'éteint.
  static Uint8List _wav(List<(double, double)> notes, double duree, {bool tenue = false}) {
    const rate = 44100;
    final n = (rate * duree).round();
    final samples = <int>[];
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      var v = 0.0;
      for (final (note, depart) in notes) {
        final u = t - depart;
        if (u < 0) continue;
        // Attaque en cinq millisecondes : pas de claquement.
        final corps = tenue ? 0.32 + 0.68 * math.exp(-16 * u) : math.exp(-6 * u);
        v += math.sin(2 * math.pi * note * u) * math.min(1.0, u / 0.005) * corps;
      }
      final fin = math.min(1.0, (n - i) / (rate * 0.03));
      samples.add((v * fin * 32767 * (tenue ? 0.42 : 0.5)).round().clamp(-32768, 32767));
    }
    final data = ByteData(44 + samples.length * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
