import 'package:flutter/foundation.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/json.dart';

/// Façon dont les charges évoluent au fil d'un programme.
enum ProgressionType {
  aucune('Aucune', 'Les séries restent celles de la routine.'),
  charge('Charge progressive', 'Toutes les répétitions réussies la dernière fois : la charge monte d\'un incrément.'),
  doubleProgression('Double progression', 'On gagne une répétition par séance jusqu\'au haut de la fourchette, puis la charge monte et les répétitions repartent du bas.'),
  ondulee('Ondulée par semaine', 'Les semaines alternent lourd (5 reps), moyen (8 reps) et léger (12 reps).');

  const ProgressionType(this.label, this.description);
  final String label;
  final String description;
}

/// Réglages d'un programme qui ne tiennent pas dans le modèle commun :
/// progression, décharge et jours d'entraînement.
@immutable
class ProgramPlan {
  const ProgramPlan({
    required this.programId,
    this.progression = ProgressionType.charge,
    this.incrementKg = 2.5,
    this.dechargeToutesLes = 0,
    this.jours = const [],
    this.modeleId,
    this.photo,
  });

  final String programId;
  final ProgressionType progression;
  final double incrementKg;

  /// Une semaine de décharge toutes les N semaines (0 : jamais).
  final int dechargeToutesLes;

  /// Jours prévus (1 = lundi ... 7 = dimanche), vide si libre.
  final List<int> jours;

  /// Modèle d'origine, s'il y en a un.
  final String? modeleId;

  /// Photo de couverture choisie dans la galerie (recopiée dans le dossier
  /// de l'appli) ; sans elle, la couverture dessinée.
  final String? photo;

  /// Vrai si la semaine (0 = première) est une semaine de décharge.
  bool estDecharge(int semaine) => dechargeToutesLes > 0 && (semaine + 1) % dechargeToutesLes == 0;

  ProgramPlan copyWith({ProgressionType? progression, double? incrementKg, int? dechargeToutesLes, List<int>? jours, String? programId}) => ProgramPlan(
        programId: programId ?? this.programId,
        progression: progression ?? this.progression,
        incrementKg: incrementKg ?? this.incrementKg,
        dechargeToutesLes: dechargeToutesLes ?? this.dechargeToutesLes,
        jours: jours ?? this.jours,
        modeleId: modeleId,
        photo: photo,
      );

  factory ProgramPlan.fromJson(Json j) => ProgramPlan(
        programId: asString(j['programId']) ?? '',
        progression: enumByName(ProgressionType.values, j['progression'], ProgressionType.charge),
        incrementKg: asDouble(j['incrementKg']) ?? 2.5,
        dechargeToutesLes: asInt(j['dechargeToutesLes']) ?? 0,
        jours: [for (final v in (j['jours'] as List? ?? const [])) if (v is num) v.toInt()],
        modeleId: asString(j['modeleId']),
        photo: asString(j['photo']),
      );

  Json toJson() => compact({
        'programId': programId,
        'progression': progression.name,
        'incrementKg': incrementKg,
        'dechargeToutesLes': dechargeToutesLes,
        'jours': jours,
        'modeleId': modeleId,
        'photo': photo,
      });
}

/// Petite collection propre au module : `programmes_plans` dans le store.
class ProgramPlanRepo extends ChangeNotifier {
  ProgramPlanRepo._(this.store);

  static final _instances = Expando<ProgramPlanRepo>();

  /// Un dépôt par store, chargé à la première demande.
  static ProgramPlanRepo of(Store store) => _instances[store] ??= (ProgramPlanRepo._(store)..load());

  static const collection = 'programmes_plans';

  final Store store;
  final Map<String, ProgramPlan> _plans = {};
  bool _loaded = false;
  Object? _error;

  bool get loaded => _loaded;
  Object? get error => _error;

  Future<void> load() async {
    try {
      final list = await store.readList(collection);
      _plans
        ..clear()
        ..addEntries(list.map(ProgramPlan.fromJson).where((p) => p.programId.isNotEmpty).map((p) => MapEntry(p.programId, p)));
      _error = null;
    } catch (e) {
      _error = e;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Le plan d'un programme ; un plan par défaut s'il n'a jamais été réglé.
  ProgramPlan planFor(String programId) => _plans[programId] ?? ProgramPlan(programId: programId);

  bool hasPlan(String programId) => _plans.containsKey(programId);

  Future<void> save(ProgramPlan plan) async {
    _plans[plan.programId] = plan;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String programId) async {
    if (_plans.remove(programId) == null) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => store.write(collection, _plans.values.map((p) => p.toJson()).toList());
}
