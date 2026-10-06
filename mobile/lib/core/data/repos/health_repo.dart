import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../logic/dates.dart';
import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Sommeil, mesures corporelles, photos de progression, compléments.
class HealthRepo extends ChangeNotifier {
  HealthRepo(this.store)
      : _sleep = JsonCollection(store: store, name: 'sommeil', fromJson: SleepEntry.fromJson, toJson: (s) => s.toJson(), idOf: (s) => s.id),
        _measures = JsonCollection(store: store, name: 'mesures', fromJson: BodyMeasurement.fromJson, toJson: (m) => m.toJson(), idOf: (m) => m.id),
        _photos = JsonCollection(store: store, name: 'photos', fromJson: ProgressPhoto.fromJson, toJson: (p) => p.toJson(), idOf: (p) => p.id),
        _supplements = JsonCollection(store: store, name: 'complements', fromJson: Supplement.fromJson, toJson: (s) => s.toJson(), idOf: (s) => s.id),
        _intakes = JsonCollection(store: store, name: 'prises_complements', fromJson: SupplementIntake.fromJson, toJson: (i) => i.toJson(), idOf: (i) => i.id);

  final Store store;
  final JsonCollection<SleepEntry> _sleep;
  final JsonCollection<BodyMeasurement> _measures;
  final JsonCollection<ProgressPhoto> _photos;
  final JsonCollection<Supplement> _supplements;
  final JsonCollection<SupplementIntake> _intakes;

  Future<void> load() async {
    await Future.wait([_sleep.load(), _measures.load(), _photos.load(), _supplements.load(), _intakes.load()]);
    notifyListeners();
  }

  Future<void> clear() async {
    await Future.wait([_sleep.clear(), _measures.clear(), _photos.clear(), _supplements.clear(), _intakes.clear()]);
    notifyListeners();
  }

  // Sommeil

  /// Nuits, la plus récente d'abord.
  List<SleepEntry> get sleep => [..._sleep.items]..sort((a, b) => b.lever.compareTo(a.lever));

  SleepEntry? sleepFor(DateTime day) => _sleep.items.firstWhereOrNull((s) => Dates.memeJour(s.lever, day));

  SleepEntry? get lastSleep => sleep.firstOrNull;

  /// Durée moyenne des [days] dernières nuits notées.
  Duration? averageSleep({int days = 7, DateTime? now}) {
    final from = Dates.jour(now ?? DateTime.now()).subtract(Duration(days: days));
    final list = _sleep.items.where((s) => s.lever.isAfter(from)).toList();
    if (list.isEmpty) return null;
    final total = list.fold<int>(0, (a, s) => a + s.duree.inMinutes);
    return Duration(minutes: total ~/ list.length);
  }

  Future<SleepEntry> saveSleep(SleepEntry s) async {
    final e = s.id.isEmpty ? SleepEntry.fromJson({...s.toJson(), 'id': newId()}) : s;
    await _sleep.upsert(e);
    notifyListeners();
    return e;
  }

  Future<void> addSleepAll(List<SleepEntry> list) async {
    await _sleep.upsertAll(list);
    notifyListeners();
  }

  Future<void> deleteSleep(String id) async {
    await _sleep.remove(id);
    notifyListeners();
  }

  // Mesures

  /// Mesures, la plus récente d'abord.
  List<BodyMeasurement> get measurements => [..._measures.items]..sort((a, b) => b.date.compareTo(a.date));

  BodyMeasurement? get latestWeightEntry => measurements.firstWhereOrNull((m) => m.poidsKg != null);
  double? get latestWeight => latestWeightEntry?.poidsKg;
  double? get latestBodyFat => measurements.firstWhereOrNull((m) => m.masseGrassePct != null)?.masseGrassePct;

  /// Série de poids, du plus ancien au plus récent.
  List<({DateTime date, double kg})> weightSeries({DateTime? since}) => [
        for (final m in measurements.reversed)
          if (m.poidsKg != null && (since == null || !m.date.isBefore(since))) (date: m.date, kg: m.poidsKg!),
      ];

  /// Dernière valeur connue d'un tour.
  double? latestTour(TourCorps t) => measurements.firstWhereOrNull((m) => m.tours[t] != null)?.tours[t];

  Future<BodyMeasurement> saveMeasurement(BodyMeasurement m) async {
    final e = m.id.isEmpty ? BodyMeasurement.fromJson({...m.toJson(), 'id': newId()}) : m;
    await _measures.upsert(e);
    notifyListeners();
    return e;
  }

  Future<void> addMeasurementsAll(List<BodyMeasurement> list) async {
    await _measures.upsertAll(list);
    notifyListeners();
  }

  Future<void> deleteMeasurement(String id) async {
    await _measures.remove(id);
    notifyListeners();
  }

  // Photos

  List<ProgressPhoto> get photos => [..._photos.items]..sort((a, b) => b.date.compareTo(a.date));

  /// Copie l'image dans le dossier privé et l'enregistre.
  Future<ProgressPhoto> addPhoto(String sourcePath, {DateTime? date, PhotoVue vue = PhotoVue.face, double? poidsKg, String? note}) async {
    final id = newId();
    final dir = await store.mediaDir();
    // L'extension se lit sur le nom du fichier, pas sur ses dossiers.
    final nom = sourcePath.split(RegExp(r'[/\\]')).last;
    final ext = nom.lastIndexOf('.') > 0 ? nom.substring(nom.lastIndexOf('.')) : '.jpg';
    final dest = '${dir.path}${Platform.pathSeparator}photo_$id$ext';
    await File(sourcePath).copy(dest);
    final p = ProgressPhoto(id: id, date: date ?? DateTime.now(), chemin: dest, vue: vue, poidsKg: poidsKg, note: note);
    await _photos.upsert(p);
    notifyListeners();
    return p;
  }

  Future<void> savePhoto(ProgressPhoto p) async {
    await _photos.upsert(p);
    notifyListeners();
  }

  Future<void> deletePhoto(String id) async {
    final p = _photos.byId(id);
    if (p != null) {
      try {
        final f = File(p.chemin);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _photos.remove(id);
    notifyListeners();
  }

  // Compléments

  List<Supplement> get supplements => _supplements.items;
  List<Supplement> get activeSupplements => _supplements.items.where((s) => s.actif).toList();

  Future<Supplement> saveSupplement(Supplement s) async {
    final e = s.id.isEmpty ? Supplement.fromJson({...s.toJson(), 'id': newId()}) : s;
    await _supplements.upsert(e);
    notifyListeners();
    return e;
  }

  Future<void> deleteSupplement(String id) async {
    await _supplements.remove(id);
    await _intakes.removeWhere((i) => i.supplementId == id);
    notifyListeners();
  }

  List<SupplementIntake> intakesFor(DateTime day) => _intakes.items.where((i) => Dates.memeJour(i.date, day)).toList();

  bool takenOn(String supplementId, DateTime day) => intakesFor(day).any((i) => i.supplementId == supplementId);

  /// Coche ou décoche la prise du jour.
  Future<void> toggleIntake(String supplementId, DateTime day) async {
    final existing = intakesFor(day).firstWhereOrNull((i) => i.supplementId == supplementId);
    if (existing != null) {
      await _intakes.remove(existing.id);
    } else {
      final now = DateTime.now();
      final date = Dates.memeJour(now, day) ? now : DateTime(day.year, day.month, day.day, 12);
      await _intakes.upsert(SupplementIntake(id: newId(), supplementId: supplementId, date: date));
    }
    notifyListeners();
  }

  Future<void> addIntakesAll(List<SupplementIntake> list) async {
    await _intakes.upsertAll(list);
    notifyListeners();
  }
}
