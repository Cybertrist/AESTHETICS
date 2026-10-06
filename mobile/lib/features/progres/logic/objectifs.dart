import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../profil/data/mensurations.dart';

/// Ce qu'un objectif personnel vise.
enum TypeObjectif {
  charge('Une charge sur un exercice', 'Par exemple 100 kg au développé couché'),
  poids('Mon poids', 'Atteindre un poids, à la hausse ou à la baisse'),
  seances('Des séances par semaine', 'Tenir un rythme sur une semaine'),
  mensuration('Une mensuration', 'Tour de bras, de taille, de cuisses…');

  const TypeObjectif(this.label, this.detail);
  final String label;
  final String detail;
}

/// Un objectif fixé par l'utilisateur. Les valeurs sont en unités de
/// stockage : kilogrammes, centimètres, nombre de séances.
class ObjectifPerso {
  const ObjectifPerso({
    required this.id,
    required this.type,
    required this.cible,
    required this.creeLe,
    this.depart,
    this.exerciseId,
    this.zone,
    this.atteintLe,
  });

  final String id;
  final TypeObjectif type;
  final double cible;

  /// Valeur au moment où l'objectif a été fixé : le début de la jauge, et le
  /// sens à suivre (perdre ou prendre).
  final double? depart;
  final String? exerciseId;
  final ZoneMesure? zone;
  final DateTime creeLe;

  /// Jour où l'objectif a été atteint ; null tant qu'il est en cours.
  final DateTime? atteintLe;

  bool get atteint => atteintLe != null;

  /// Vrai quand il faut descendre pour atteindre la cible (perte de poids).
  bool get enBaisse => depart != null && cible < depart!;

  ObjectifPerso avecAtteinte(DateTime quand) =>
      ObjectifPerso(id: id, type: type, cible: cible, creeLe: creeLe, depart: depart, exerciseId: exerciseId, zone: zone, atteintLe: quand);

  factory ObjectifPerso.fromJson(Json j) => ObjectifPerso(
        id: asString(j['id']) ?? newId(),
        type: enumByName(TypeObjectif.values, j['type'], TypeObjectif.poids),
        cible: asDouble(j['cible']) ?? 0,
        depart: asDouble(j['depart']),
        exerciseId: asString(j['exerciseId']),
        zone: ZoneMesure.values.asNameMap()[asString(j['zone']) ?? ''],
        creeLe: asDate(j['creeLe']) ?? DateTime.now(),
        atteintLe: asDate(j['atteintLe']),
      );

  Json toJson() => compact({
        'id': id,
        'type': type.name,
        'cible': cible,
        'depart': depart,
        'exerciseId': exerciseId,
        'zone': zone?.name,
        'creeLe': dateOut(creeLe),
        'atteintLe': dateOut(atteintLe),
      });
}

/// Les objectifs personnels, gardés sur le téléphone.
class ObjectifsRepo extends ChangeNotifier {
  ObjectifsRepo._(this.store);

  static const file = 'objectifs';
  static ObjectifsRepo? _instance;

  /// Instance courante (null tant que [ensure] n'a pas été appelé).
  static ObjectifsRepo? get maybeInstance => _instance;

  /// Crée (au besoin) le dépôt pour ce stockage et le relit.
  static Future<ObjectifsRepo> ensure(Store store) async {
    var i = _instance;
    if (i == null || !identical(i.store, store)) {
      i = ObjectifsRepo._(store);
      _instance = i;
    }
    await i.load();
    return i;
  }

  @visibleForTesting
  static void reset() => _instance = null;

  final Store store;
  List<ObjectifPerso> _liste = const [];
  bool _loaded = false;

  List<ObjectifPerso> get liste => _liste;
  bool get loaded => _loaded;

  Future<void> load() async {
    final j = await store.readObject(file);
    final l = j?['objectifs'];
    _liste = [
      if (l is List)
        for (final x in l)
          if (x is Map) ObjectifPerso.fromJson(Map<String, dynamic>.from(x)),
    ];
    _loaded = true;
    notifyListeners();
  }

  Future<void> _ecrire(List<ObjectifPerso> l) async {
    _liste = l;
    notifyListeners();
    await store.write(file, {'objectifs': [for (final o in l) o.toJson()]});
  }

  Future<void> ajouter(ObjectifPerso o) => _ecrire([..._liste, o]);
  Future<void> supprimer(String id) => _ecrire([for (final o in _liste) if (o.id != id) o]);
  Future<void> remplacer(ObjectifPerso o) => _ecrire([for (final x in _liste) x.id == o.id ? o : x]);
}

/// Calculs des objectifs : valeur du moment, avancée, atteinte.
abstract final class Objectifs {
  /// Valeur du moment pour cet objectif, null quand rien n'est connu.
  static double? valeur(
    ObjectifPerso o, {
    required List<WorkoutSession> sessions,
    required List<BodyMeasurement> mesures,
    DateTime? now,
    int premierJour = DateTime.monday,
  }) {
    switch (o.type) {
      case TypeObjectif.charge:
        final id = o.exerciseId;
        return id == null ? null : Strength.bests(id, sessions.where((s) => !s.enCours)).poidsMax?.valeur;
      case TypeObjectif.poids:
        return Mensurations.seriePoids(mesures).lastOrNull?.valeur;
      case TypeObjectif.seances:
        final debut = Dates.debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
        final fin = DateTime(debut.year, debut.month, debut.day + 7);
        return sessions.where((s) => !s.enCours && !s.debut.isBefore(debut) && s.debut.isBefore(fin)).length.toDouble();
      case TypeObjectif.mensuration:
        final z = o.zone;
        return z == null ? null : Mensurations.serie(mesures, z).lastOrNull?.valeur;
    }
  }

  /// Vrai quand la valeur a rejoint la cible, dans le bon sens.
  static bool atteint(ObjectifPerso o, double? v) {
    if (v == null) return false;
    return o.enBaisse ? v <= o.cible + 1e-9 : v >= o.cible - 1e-9;
  }

  /// Part du chemin faite, de 0 à 1.
  static double part(ObjectifPerso o, double? v) {
    if (v == null) return 0;
    final d = o.type == TypeObjectif.seances ? 0.0 : (o.depart ?? 0);
    if ((o.cible - d).abs() < 1e-9) return atteint(o, v) ? 1 : 0;
    return ((v - d) / (o.cible - d)).clamp(0.0, 1.0);
  }

  /// Nombre d'objectifs atteints de chaque type : les badges secrets.
  static Map<TypeObjectif, int> atteintsParType(Iterable<ObjectifPerso> l) => {
        for (final t in TypeObjectif.values) t: l.where((o) => o.type == t && o.atteint).length,
      };

  /// Jours où deux séances au moins ont été faites.
  static int joursDoubles(Iterable<WorkoutSession> sessions) {
    final parJour = <DateTime, int>{};
    for (final s in sessions.where((s) => !s.enCours)) {
      final j = Dates.jour(s.debut);
      parJour[j] = (parJour[j] ?? 0) + 1;
    }
    return parJour.values.where((n) => n >= 2).length;
  }

  /// Reprises après trente jours d'arrêt ou plus.
  static int retours(Iterable<WorkoutSession> sessions) {
    final dates = [for (final s in sessions.where((s) => !s.enCours)) s.debut]..sort();
    var n = 0;
    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays >= 30) n++;
    }
    return n;
  }
}
