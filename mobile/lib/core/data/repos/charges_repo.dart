import 'package:flutter/foundation.dart';

import '../../logic/graduation.dart';
import '../../models/models.dart';
import '../store.dart';
import 'exercise_repo.dart';
import 'session_repo.dart';
import 'settings_repo.dart';

/// Les charges de chaque exercice : la graduation réglée à la main sur la
/// fiche (fichier `charges`), sinon celle que disent les séances, sinon
/// celle du matériel.
class ChargesRepo extends ChangeNotifier {
  ChargesRepo(this.store, {required this.sessions, required this.exercises, required this.settings}) {
    // Un exercice modifié (son matériel) peut changer de graduation.
    exercises.addListener(_deduites.clear);
  }

  final Store store;
  final SessionRepo sessions;
  final ExerciseRepo exercises;
  final SettingsRepo settings;
  static const file = 'charges';

  Map<String, Graduation> _reglages = {};

  /// Les déductions, refaites quand l'historique ou le pas des réglages change.
  final Map<String, ({Graduation graduation, OrigineCharges origine})> _deduites = {};
  List<WorkoutSession>? _vues;
  double? _pasVu;

  Future<void> load() async {
    final j = await store.readObject(file);
    final out = <String, Graduation>{};
    for (final e in (j ?? const <String, dynamic>{}).entries) {
      final v = e.value;
      if (v is! Map) continue;
      try {
        out[e.key] = Graduation.fromJson(Map<String, dynamic>.from(v));
      } catch (_) {
        // Réglage illisible : l'exercice revient à la déduction.
      }
    }
    _reglages = out;
    _deduites.clear();
    notifyListeners();
  }

  Future<void> _save() => store.write(file, {for (final e in _reglages.entries) e.key: e.value.toJson()});

  /// La graduation choisie à la main pour [exerciseId], s'il y en a une.
  Graduation? reglage(String exerciseId) => _reglages[exerciseId];

  /// Fixe les charges de [exerciseId] ; elles l'emportent sur la déduction.
  Future<void> regler(String exerciseId, Graduation g) async {
    _reglages[exerciseId] = g;
    notifyListeners();
    await _save();
  }

  /// Oublie le réglage : l'exercice revient à ce que disent ses séances.
  Future<void> revenirALaDeduction(String exerciseId) async {
    if (_reglages.remove(exerciseId) == null) return;
    notifyListeners();
    await _save();
  }

  /// Les charges notées sur [exerciseId], une par séance et par charge.
  List<double> chargesNotees(String exerciseId) => [
        for (final s in sessions.sessions)
          ...{
            for (final e in s.exercices)
              if (e.exerciseId == exerciseId)
                for (final x in e.seriesFaites)
                  if ((x.poids ?? 0) > 0) (x.poids! * 10).round() / 10,
          },
      ];

  /// La graduation retenue pour [exerciseId] et d'où elle vient.
  ({Graduation graduation, OrigineCharges origine}) pour(String exerciseId) {
    final r = _reglages[exerciseId];
    if (r != null) return (graduation: r, origine: OrigineCharges.reglage);
    final pas = settings.settings.incrementPoidsKg;
    if (!identical(_vues, sessions.sessions) || _pasVu != pas) {
      _deduites.clear();
      _vues = sessions.sessions;
      _pasVu = pas;
    }
    final deja = _deduites[exerciseId];
    if (deja != null) return deja;
    final ex = exercises.byId(exerciseId);
    final d = Graduations.pour(ex, chargesNotees(exerciseId), pas: pas);
    // Un exercice pas encore chargé n'est pas retenu : son matériel compte.
    if (ex != null) _deduites[exerciseId] = d;
    return d;
  }

  /// La graduation retenue pour [exerciseId].
  Graduation graduation(String exerciseId) => pour(exerciseId).graduation;

  /// Ce que l'appli utilise, en clair : « Pile de 15 lb, appoint de 5 lb ·
  /// déduit de tes séances ».
  String resume(String exerciseId) {
    final p = pour(exerciseId);
    return '${p.graduation.description} · ${p.origine.label}';
  }
}
