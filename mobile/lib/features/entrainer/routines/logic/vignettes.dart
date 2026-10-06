import 'package:flutter/foundation.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/json.dart';

/// Vignette d'une routine : une carte de jour, une photo personnelle, ou
/// aucune image ([sans] : une tuile neutre avec le sigle de la routine).
@immutable
class VignetteRoutine {
  const VignetteRoutine({this.jour, this.photo, this.sans = false});

  /// 1 = lundi ... 7 = dimanche.
  final int? jour;

  /// Chemin d'une photo du téléphone.
  final String? photo;

  /// Aucune image : ni photo, ni carte de jour.
  final bool sans;

  static VignetteRoutine? fromJson(Json j) {
    final jour = asInt(j['jour']);
    final photo = asString(j['photo']);
    if (asBool(j['sans'])) return const VignetteRoutine(sans: true);
    if (photo != null && photo.isNotEmpty) return VignetteRoutine(photo: photo);
    if (jour != null && jour >= 1 && jour <= 7) return VignetteRoutine(jour: jour);
    return null;
  }

  Json toJson(String id) => compact({'id': id, 'jour': jour, 'photo': photo, 'sans': sans ? true : null});
}

/// Jour affiché sur la carte d'une routine : celui qu'on a choisi, sinon
/// son rang dans la liste (la première sur « Lun », la deuxième sur « Mar »...).
int jourDeVignette(VignetteRoutine? choisie, int rang) => choisie?.jour ?? (rang % 7) + 1;

/// Réglages propres à l'onglet, gardés dans le store : vignettes et
/// favoris des routines (`routines_vignettes`, `routines_favoris`) et la
/// suggestion écartée pour la journée (`routines_suggestion`).
class RoutinePrefs extends ChangeNotifier {
  RoutinePrefs._(this.store);

  static final _instances = Expando<RoutinePrefs>();

  /// Un dépôt par store, chargé à la première demande.
  static RoutinePrefs of(Store store) => _instances[store] ??= (RoutinePrefs._(store)..load());

  static const fichierVignettes = 'routines_vignettes';
  static const fichierFavoris = 'routines_favoris';
  static const fichierSuggestion = 'routines_suggestion';

  final Store store;
  final Map<String, VignetteRoutine> _vignettes = {};
  final Set<String> _favoris = {};
  String? _suggestionEcartee;
  final List<String> _ecartees = [];
  bool _charge = false;
  Future<void>? _chargement;

  bool get charge => _charge;
  Set<String> get favoris => Set.unmodifiable(_favoris);

  /// Attend la fin de la lecture (utile avant une première écriture).
  Future<void> load() => _chargement ??= _lire();

  Future<void> _lire() async {
    try {
      for (final j in await store.readList(fichierVignettes)) {
        final id = asString(j['id']);
        final v = VignetteRoutine.fromJson(j);
        if (id != null && v != null) _vignettes[id] = v;
      }
      final fav = await store.read(fichierFavoris);
      if (fav is List) _favoris.addAll(fav.map((e) => e.toString()));
      final sug = await store.read(fichierSuggestion);
      if (sug is Map) {
        _suggestionEcartee = asString(sug['ecartee']);
        final ids = sug['routines'];
        if (ids is List) _ecartees.addAll(ids.map((e) => e.toString()));
      }
    } catch (_) {
      // Un fichier illisible ne doit pas bloquer l'onglet : on repart à vide.
    }
    _charge = true;
    notifyListeners();
  }

  VignetteRoutine? vignetteDe(String routineId) => _vignettes[routineId];

  Future<void> choisirJour(String routineId, int jour) => _poser(routineId, VignetteRoutine(jour: jour));

  /// Aucune image pour cette routine.
  Future<void> choisirSansImage(String routineId) => _poser(routineId, const VignetteRoutine(sans: true));

  Future<void> choisirPhoto(String routineId, String chemin) => _poser(routineId, VignetteRoutine(photo: chemin));

  Future<void> _poser(String routineId, VignetteRoutine v) async {
    await load();
    _vignettes[routineId] = v;
    notifyListeners();
    await store.write(fichierVignettes, [for (final e in _vignettes.entries) e.value.toJson(e.key)]);
  }

  /// Retire la photo ou le jour choisi : la routine reprend sa carte de jour
  /// par défaut.
  Future<void> retirerVignette(String routineId) async {
    await load();
    if (_vignettes.remove(routineId) == null) return;
    notifyListeners();
    await store.write(fichierVignettes, [for (final e in _vignettes.entries) e.value.toJson(e.key)]);
  }

  bool estFavori(String routineId) => _favoris.contains(routineId);

  Future<void> basculerFavori(String routineId) async {
    await load();
    if (!_favoris.remove(routineId)) _favoris.add(routineId);
    notifyListeners();
    await store.write(fichierFavoris, _favoris.toList());
  }

  /// Oublie une routine supprimée.
  Future<void> oublier(String routineId) async {
    await load();
    final v = _vignettes.remove(routineId) != null;
    final f = _favoris.remove(routineId);
    if (!v && !f) return;
    notifyListeners();
    if (v) await store.write(fichierVignettes, [for (final e in _vignettes.entries) e.value.toJson(e.key)]);
    if (f) await store.write(fichierFavoris, _favoris.toList());
  }

  /// Recopie la vignette d'une routine sur sa copie.
  Future<void> copier(String de, String vers) async {
    final v = _vignettes[de];
    if (v != null) await _poser(vers, v);
  }

  static String _cle(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Vrai si « Une autre » a été touché aujourd'hui.
  bool suggestionEcartee(DateTime jour) => _suggestionEcartee == _cle(jour);

  /// Les routines écartées aujourd'hui par « Une autre », dans l'ordre.
  List<String> ecarteesLe(DateTime jour) => suggestionEcartee(jour) ? List.unmodifiable(_ecartees) : const [];

  /// « Une autre » : écarte [routineId] jusqu'au lendemain.
  Future<void> ecarterSuggestion(DateTime jour, [String? routineId]) async {
    await load();
    final cle = _cle(jour);
    if (_suggestionEcartee != cle) _ecartees.clear();
    _suggestionEcartee = cle;
    if (routineId != null && !_ecartees.contains(routineId)) _ecartees.add(routineId);
    notifyListeners();
    await store.write(fichierSuggestion, {'ecartee': cle, if (_ecartees.isNotEmpty) 'routines': List<String>.from(_ecartees)});
  }
}
