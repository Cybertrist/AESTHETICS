import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../store.dart';

/// Réglages de l'appli.
class SettingsRepo extends ChangeNotifier {
  SettingsRepo(this.store);
  final Store store;
  static const file = 'reglages';

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final j = await store.readObject(file);
    _settings = j == null ? const AppSettings() : AppSettings.fromJson(j);
    notifyListeners();
  }

  Future<void> save(AppSettings s) async {
    _settings = s;
    notifyListeners();
    await store.write(file, s.toJson());
  }

  /// Modifie une partie des réglages : `repo.update((s) => s.copyWith(...))`.
  Future<void> update(AppSettings Function(AppSettings s) change) => save(change(_settings));
}
