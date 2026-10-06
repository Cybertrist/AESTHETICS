import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/models/models.dart';

/// Envoi d'une séance terminée vers Health Connect (une séance d'exercice :
/// type, début, fin, nom). Sans Health Connect, sans autorisation ou hors
/// Android, l'envoi est simplement abandonné : il ne bloque jamais
/// l'enregistrement.
abstract final class EnvoiSante {
  /// Remplaçable dans les tests : reçoit la séance, rend vrai si elle est partie.
  static Future<bool> Function(WorkoutSession s) envoyeur = _versHealthConnect;

  static HealthWorkoutActivityType typeDe(TypeSeance t) => switch (t) {
        TypeSeance.musculation => HealthWorkoutActivityType.STRENGTH_TRAINING,
        TypeSeance.cardio => HealthWorkoutActivityType.OTHER,
        TypeSeance.hiit => HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
        TypeSeance.hybride => HealthWorkoutActivityType.OTHER,
        TypeSeance.crossTraining => HealthWorkoutActivityType.OTHER,
        TypeSeance.aviron => HealthWorkoutActivityType.ROWING,
      };

  /// Rend vrai si la séance a été écrite.
  static Future<bool> envoyer(WorkoutSession s) async {
    if (s.fin == null || !s.fin!.isAfter(s.debut)) return false;
    try {
      return await envoyeur(s);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _versHealthConnect(WorkoutSession s) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final h = Health();
    await h.configure();
    const types = [HealthDataType.WORKOUT];
    const acces = [HealthDataAccess.WRITE];
    var ok = await h.hasPermissions(types, permissions: acces) ?? false;
    if (!ok) ok = await h.requestAuthorization(types, permissions: acces);
    if (!ok) return false;
    return h.writeWorkoutData(
      activityType: typeDe(s.type),
      start: s.debut,
      end: s.fin!,
      title: s.nom,
      recordingMethod: RecordingMethod.active,
    );
  }
}
