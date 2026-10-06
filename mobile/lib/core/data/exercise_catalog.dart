import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';

/// Catalogue d'exercices embarqué : assets/data/exercises.json.
/// Absent ou abîmé, il se charge vide sans bloquer l'appli.
abstract final class ExerciseCatalog {
  static const assetPath = 'assets/data/exercises.json';

  /// Les compléments du catalogue : unilatéral, tout le matériel.
  static const plusPath = 'assets/data/exercices_plus.json';

  static Future<List<Exercise>> load({AssetBundle? bundle}) async {
    try {
      ExercicesPlus.charger(jsonDecode(await (bundle ?? rootBundle).loadString(plusPath, cache: false)));
    } catch (_) {
      // Sans la table, chaque exercice garde ses règles par défaut.
    }
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath, cache: false);
      // Plus de 1 300 exercices, environ 2 Mo : décodés hors du fil de l'interface.
      return await compute(_parse, raw, debugLabel: 'catalogue d\'exercices');
    } catch (_) {
      return [];
    }
  }

  static List<Exercise> _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['exercices'] ?? decoded['exercises'] : decoded;
      if (list is! List) return [];
      final out = <Exercise>[];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          final ex = Exercise.fromJson(Map<String, dynamic>.from(e));
          if (ex.id.isNotEmpty) out.add(ex);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
