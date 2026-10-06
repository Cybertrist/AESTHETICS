import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/models/models.dart';
import 'prefs.dart';

/// Rappels planifiés : séances, compléments et eau. Identifiants réservés
/// 7100 à 7199 (séance 7100+jour, compléments 7110+, eau 7130+, essai 7199).
abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;

  static const idSeance = 7100;
  static const idComplements = 7110;
  static const idEau = 7130;
  static const idEssai = 7199;

  static bool get _supporte => !kIsWeb && Platform.isAndroid;

  static const _canal = AndroidNotificationDetails(
    'rappels',
    'Rappels',
    channelDescription: 'Rappels de séance, de compléments et d\'eau',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );
  static const _details = NotificationDetails(android: _canal);

  static Future<void> init() async {
    if (_pret || !_supporte) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _pret = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Notifications permises par Android.
  static Future<bool> autorisees() async {
    if (!_supporte) return false;
    await init();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Demande l'autorisation d'afficher des notifications.
  static Future<bool> demander() async {
    if (!_supporte) return false;
    await init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> ouvrirReglagesSysteme() async {
    if (!_supporte) return;
    await init();
    await _plugin.openAppNotificationSettings();
  }

  static (int, int) _hm(String s) {
    final p = s.split(':');
    return (int.tryParse(p.first) ?? 8, p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  static tz.TZDateTime _prochain(int h, int m, {int? jour}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (jour != null) {
      while (t.weekday != jour) {
        t = t.add(const Duration(days: 1));
      }
    }
    if (!t.isAfter(now)) t = t.add(Duration(days: jour == null ? 1 : 7));
    return t;
  }

  /// Heures des rappels d'eau entre le début et la fin, selon l'intervalle.
  static List<(int, int)> heuresEau(ProfilPrefs p) {
    final (h1, m1) = _hm(p.eauDebut);
    final (h2, m2) = _hm(p.eauFin);
    final debut = h1 * 60 + m1;
    final fin = h2 * 60 + m2;
    final pas = p.eauIntervalleMin.clamp(30, 600);
    final out = <(int, int)>[];
    for (var t = debut; t <= fin && out.length < 20; t += pas) {
      out.add((t ~/ 60, t % 60));
    }
    return out;
  }

  /// Replanifie tous les rappels d'après les réglages.
  static Future<void> planifier(AppSettings s, ProfilPrefs p, {List<Supplement> complements = const []}) async {
    if (!_supporte) return;
    await init();
    for (var id = idSeance; id < idEssai; id++) {
      await _plugin.cancel(id: id);
    }
    if (!await autorisees()) return;
    const mode = AndroidScheduleMode.inexactAllowWhileIdle;

    if (s.rappelsEntrainement) {
      final (h, m) = _hm(s.heureRappel);
      for (final j in s.joursRappel.toSet()) {
        await _plugin.zonedSchedule(
          id: idSeance + j,
          scheduledDate: _prochain(h, m, jour: j),
          notificationDetails: _details,
          androidScheduleMode: mode,
          title: 'C\'est l\'heure de s\'entraîner',
          body: 'Ta séance t\'attend. Quelques séries et c\'est gagné.',
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }

    if (s.rappelsComplements) {
      final actifs = complements.where((c) => c.actif).toList();
      final heures = <String>{for (final c in actifs) ...c.heures};
      if (heures.isEmpty) heures.add(p.heureComplements);
      var i = 0;
      for (final hs in heures.take(20)) {
        final (h, m) = _hm(hs);
        final noms = actifs.where((c) => c.heures.isEmpty || c.heures.contains(hs)).map((c) => c.nom).toList();
        await _plugin.zonedSchedule(
          id: idComplements + i++,
          scheduledDate: _prochain(h, m),
          notificationDetails: _details,
          androidScheduleMode: mode,
          title: 'Tes compléments',
          body: noms.isEmpty ? 'Pense à prendre tes compléments.' : 'À prendre : ${noms.join(', ')}.',
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }

    if (s.rappelsEau) {
      var i = 0;
      for (final (h, m) in heuresEau(p)) {
        await _plugin.zonedSchedule(
          id: idEau + i++,
          scheduledDate: _prochain(h, m),
          notificationDetails: _details,
          androidScheduleMode: mode,
          title: 'Un verre d\'eau ?',
          body: 'Bois un peu et note-le dans ta journée.',
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  /// Notification d'essai, tout de suite.
  static Future<void> essai() async {
    if (!_supporte) return;
    await init();
    await _plugin.show(id: idEssai, title: 'Aesthetics', body: 'Les rappels fonctionnent.', notificationDetails: _details);
  }

  /// Rappels en attente (page développeur).
  static Future<List<PendingNotificationRequest>> enAttente() async {
    if (!_supporte) return const [];
    await init();
    return _plugin.pendingNotificationRequests();
  }

  static Future<void> toutAnnuler() async {
    if (!_supporte) return;
    await init();
    for (var id = idSeance; id <= idEssai; id++) {
      await _plugin.cancel(id: id);
    }
  }
}
