import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// État de Health Connect sur le téléphone.
enum EtatSante { indisponible, aMettreAJour, disponible, autorise }

/// Une donnée lue ou écrite dans Health Connect.
class DonneeSante {
  const DonneeSante(this.type, this.label, this.icon, this.acces);
  final HealthDataType type;
  final String label;
  final IconData icon;
  final HealthDataAccess acces;
}

/// Lien avec Health Connect : disponibilité, autorisations.
abstract final class HealthLink {
  static final _health = Health();
  static bool _configure = false;

  static const donnees = [
    DonneeSante(HealthDataType.STEPS, 'Pas', Icons.directions_walk_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.SLEEP_SESSION, 'Sommeil', Icons.bedtime_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.WEIGHT, 'Poids', Icons.monitor_weight_rounded, HealthDataAccess.READ_WRITE),
    DonneeSante(HealthDataType.BODY_FAT_PERCENTAGE, 'Masse grasse', Icons.percent_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.HEART_RATE, 'Fréquence cardiaque', Icons.favorite_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.RESTING_HEART_RATE, 'Fréquence au repos', Icons.monitor_heart_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.TOTAL_CALORIES_BURNED, 'Dépense énergétique', Icons.local_fire_department_rounded, HealthDataAccess.READ),
    DonneeSante(HealthDataType.WORKOUT, 'Séances', Icons.fitness_center_rounded, HealthDataAccess.READ_WRITE),
    DonneeSante(HealthDataType.WATER, 'Hydratation', Icons.water_drop_rounded, HealthDataAccess.READ_WRITE),
    DonneeSante(HealthDataType.NUTRITION, 'Nutrition', Icons.restaurant_rounded, HealthDataAccess.READ_WRITE),
  ];

  static bool get supporte => !kIsWeb && Platform.isAndroid;

  static Future<void> _init() async {
    if (_configure) return;
    await _health.configure();
    _configure = true;
  }

  static Future<EtatSante> etat() async {
    if (!supporte) return EtatSante.indisponible;
    try {
      await _init();
      final s = await _health.getHealthConnectSdkStatus();
      if (s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) return EtatSante.aMettreAJour;
      if (s != HealthConnectSdkStatus.sdkAvailable) return EtatSante.indisponible;
      final ok = await _health.hasPermissions(
        [for (final d in donnees) d.type],
        permissions: [for (final d in donnees) d.acces],
      );
      return ok == true ? EtatSante.autorise : EtatSante.disponible;
    } catch (_) {
      return EtatSante.indisponible;
    }
  }

  /// Ouvre la demande d'autorisations. Vrai si tout est accordé.
  static Future<bool> autoriser() async {
    if (!supporte) return false;
    await _init();
    return _health.requestAuthorization(
      [for (final d in donnees) d.type],
      permissions: [for (final d in donnees) d.acces],
    );
  }

  /// Autorise la lecture de l'historique de plus de 30 jours.
  static Future<bool> autoriserHistorique() async {
    if (!supporte) return false;
    await _init();
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    if (await _health.isHealthDataHistoryAuthorized()) return true;
    return _health.requestHealthDataHistoryAuthorization();
  }

  static Future<bool> historiqueAutorise() async {
    if (!supporte) return false;
    try {
      await _init();
      return await _health.isHealthDataHistoryAuthorized();
    } catch (_) {
      return false;
    }
  }

  static Future<void> revoquer() async {
    if (!supporte) return;
    await _init();
    await _health.revokePermissions();
  }

  static Future<void> installer() async {
    if (!supporte) return;
    await _init();
    await _health.installHealthConnect();
  }
}
