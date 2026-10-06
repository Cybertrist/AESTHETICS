import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../profil/data/prefs.dart';
import '../../profil/data/reminders.dart';

/// Rappels des compléments. La planification appartient au module Profil
/// (`Reminders.planifier`, un rappel par heure distincte, sous l'interrupteur
/// `rappelsComplements`) : on s'y branche pour ne jamais doubler une
/// notification.
abstract final class RappelsComplements {
  /// Replanifie tous les rappels d'après les réglages et les compléments.
  static Future<void> replanifier({required Store store, required SettingsRepo settings, required HealthRepo sante}) async {
    try {
      final prefs = await PrefsRepo.ensure(store);
      await Reminders.planifier(settings.settings, prefs.prefs, complements: sante.supplements);
    } catch (_) {
      // Pas de notifications possibles (tests, bureau) : rien à faire.
    }
  }

  /// Heure du rappel général, pour les compléments sans heure propre.
  static Future<String> heureGenerale(Store store) async {
    try {
      return (await PrefsRepo.ensure(store)).prefs.heureComplements;
    } catch (_) {
      return '08:00';
    }
  }

  /// Active l'interrupteur des rappels et demande l'autorisation d'Android.
  /// Rend faux si l'utilisateur refuse les notifications.
  static Future<bool> activer({required Store store, required SettingsRepo settings, required HealthRepo sante}) async {
    var ok = true;
    try {
      if (!kIsWeb && Platform.isAndroid) ok = await Reminders.autorisees() || await Reminders.demander();
    } catch (_) {}
    if (!ok) return false;
    await settings.update((s) => s.copyWith(rappelsComplements: true));
    await replanifier(store: store, settings: settings, sante: sante);
    return true;
  }

  static Future<void> desactiver({required Store store, required SettingsRepo settings, required HealthRepo sante}) async {
    await settings.update((s) => s.copyWith(rappelsComplements: false));
    await replanifier(store: store, settings: settings, sante: sante);
  }

  static Future<void> ouvrirReglagesSysteme() async {
    try {
      await Reminders.ouvrirReglagesSysteme();
    } catch (_) {}
  }
}
