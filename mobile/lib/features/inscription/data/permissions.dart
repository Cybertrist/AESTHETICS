import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Résultat d'une demande d'autorisation.
enum EtatAutorisation {
  inconnu,
  accordee,
  refusee,

  /// Refus définitif : il faut passer par les réglages du téléphone.
  bloquee,

  /// Health Connect absent ou à mettre à jour.
  indisponible,
}

/// Demandes d'autorisation de l'inscription (Health Connect, notifications).
abstract final class Autorisations {
  /// Données lues depuis Health Connect.
  static const typesLus = [
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Séances écrites dans Health Connect.
  static const typesEcrits = [HealthDataType.WORKOUT];

  static bool get plateformeMobile => Platform.isAndroid || Platform.isIOS;

  static Future<EtatAutorisation> etatSante() async {
    if (!plateformeMobile) return EtatAutorisation.indisponible;
    try {
      final h = Health();
      await h.configure();
      if (Platform.isAndroid && !await h.isHealthConnectAvailable()) return EtatAutorisation.indisponible;
      final types = [...typesLus, ...typesEcrits];
      final ok = await h.hasPermissions(types, permissions: _acces(types));
      return ok == true ? EtatAutorisation.accordee : EtatAutorisation.inconnu;
    } catch (_) {
      return EtatAutorisation.indisponible;
    }
  }

  static List<HealthDataAccess> _acces(List<HealthDataType> types) =>
      [for (final t in types) typesEcrits.contains(t) ? HealthDataAccess.READ_WRITE : HealthDataAccess.READ];

  static Future<EtatAutorisation> demanderSante() async {
    if (!plateformeMobile) return EtatAutorisation.indisponible;
    try {
      final h = Health();
      await h.configure();
      if (Platform.isAndroid && !await h.isHealthConnectAvailable()) return EtatAutorisation.indisponible;
      final types = [...typesLus, ...typesEcrits];
      final ok = await h.requestAuthorization(types, permissions: _acces(types));
      return ok ? EtatAutorisation.accordee : EtatAutorisation.refusee;
    } catch (_) {
      return EtatAutorisation.refusee;
    }
  }

  /// Ouvre la fiche d'installation de Health Connect.
  static Future<void> installerSante() async {
    try {
      await Health().installHealthConnect();
    } catch (_) {}
  }

  static Future<EtatAutorisation> etatNotifications() async {
    if (!plateformeMobile) return EtatAutorisation.indisponible;
    try {
      return _depuis(await Permission.notification.status);
    } catch (_) {
      return EtatAutorisation.indisponible;
    }
  }

  static Future<EtatAutorisation> demanderNotifications() async {
    if (!plateformeMobile) return EtatAutorisation.indisponible;
    try {
      return _depuis(await Permission.notification.request());
    } catch (_) {
      return EtatAutorisation.refusee;
    }
  }

  static Future<void> ouvrirReglages() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  static EtatAutorisation _depuis(PermissionStatus s) => switch (s) {
        PermissionStatus.granted || PermissionStatus.limited || PermissionStatus.provisional => EtatAutorisation.accordee,
        PermissionStatus.permanentlyDenied || PermissionStatus.restricted => EtatAutorisation.bloquee,
        PermissionStatus.denied => EtatAutorisation.inconnu,
      };
}
