import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../store.dart';
import '../../logic/unites.dart';

/// Profil de l'utilisateur. Sans profil, le routeur envoie vers l'inscription.
class ProfileRepo extends ChangeNotifier {
  ProfileRepo(this.store);
  final Store store;
  static const file = 'profil';

  UserProfile? _profile;
  bool _loaded = false;

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  bool get loaded => _loaded;
  UnitePoids get unite => _profile?.unitePoids ?? UnitePoids.kg;

  /// Les unités d'affichage suivent le profil.
  void _unites() {
    Affichage.pouces = _profile?.pouces ?? false;
    Affichage.miles = _profile?.miles ?? false;
  }

  Future<void> load() async {
    final j = await store.readObject(file);
    _profile = j == null ? null : UserProfile.fromJson(j);
    _unites();
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(UserProfile p) async {
    _profile = p;
    _unites();
    notifyListeners();
    await store.write(file, p.toJson());
  }

  /// Modifie le profil existant.
  Future<void> update(UserProfile Function(UserProfile p) change) async {
    final p = _profile;
    if (p == null) return;
    await save(change(p));
  }

  Future<void> clear() async {
    _profile = null;
    _unites();
    notifyListeners();
    await store.delete(file);
  }
}
