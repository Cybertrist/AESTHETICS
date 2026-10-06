import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/data/store.dart';
import '../../../core/models/json.dart';
import '../../../core/models/nutrition.dart';

/// Un produit trouvé en ligne : l'aliment et son Nutri-Score.
class OnlineFood {
  const OnlineFood({required this.food, this.nutriscore, this.quantite});
  final Food food;

  /// Lettre a..e, si connue.
  final String? nutriscore;

  /// Contenance affichée sur l'emballage (« 400 g »).
  final String? quantite;

  Json toJson() => compact({'food': food.toJson(), 'ns': nutriscore, 'q': quantite});

  factory OnlineFood.fromJson(Json j) => OnlineFood(
        food: Food.fromJson(asJson(j['food']) ?? const {}),
        nutriscore: asString(j['ns']),
        quantite: asString(j['q']),
      );
}

/// Erreur de la recherche en ligne, avec un message à afficher.
class OnlineFoodError implements Exception {
  const OnlineFoodError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Base alimentaire ouverte (Open Food Facts) : recherche en français et
/// lecture d'un code-barres, avec un cache local pour relire sans réseau.
class OpenFoodFactsClient {
  OpenFoodFactsClient(this.store, {http.Client? client}) : _http = client ?? http.Client();

  final Store store;
  final http.Client _http;

  static final Expando<OpenFoodFactsClient> _instances = Expando('base-en-ligne');

  /// Le client lié au stockage de l'appli (un seul cache en mémoire).
  static OpenFoodFactsClient forStore(Store store) => _instances[store] ??= OpenFoodFactsClient(store);

  static const _agent = 'Aesthetic/1.0 (Android; fr.cybertrist.aesthetic)';
  static const _fields =
      'code,product_name,product_name_fr,generic_name_fr,brands,nutriments,nutriscore_grade,serving_quantity,serving_size,image_front_small_url,quantity';
  static const _timeout = Duration(seconds: 12);
  static const _maxRecherches = 60;
  static const _maxProduits = 500;
  static const _dureeCache = Duration(days: 14);

  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _readCache() async {
    if (_cache != null) return _cache!;
    final raw = await store.readObject('nutrition_cache_en_ligne') ?? {};
    _cache = {
      'recherches': asJson(raw['recherches']) ?? <String, dynamic>{},
      'produits': asJson(raw['produits']) ?? <String, dynamic>{},
    };
    return _cache!;
  }

  Future<void> _writeCache() async {
    final c = _cache;
    if (c == null) return;
    final r = c['recherches'] as Map<String, dynamic>;
    if (r.length > _maxRecherches) {
      final keys = r.keys.toList()..sort((a, b) => (asInt(asJson(r[a])?['t']) ?? 0).compareTo(asInt(asJson(r[b])?['t']) ?? 0));
      for (final k in keys.take(r.length - _maxRecherches)) {
        r.remove(k);
      }
    }
    final p = c['produits'] as Map<String, dynamic>;
    if (p.length > _maxProduits) {
      for (final k in p.keys.take(p.length - _maxProduits).toList()) {
        p.remove(k);
      }
    }
    await store.write('nutrition_cache_en_ligne', c);
  }

  /// Nombre de produits gardés hors ligne.
  Future<int> cacheSize() async => ((await _readCache())['produits'] as Map).length;

  Future<void> clearCache() async {
    _cache = {'recherches': <String, dynamic>{}, 'produits': <String, dynamic>{}};
    await store.delete('nutrition_cache_en_ligne');
  }

  static String _key(String q) => q.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Résultats gardés pour cette recherche, même anciens (mode hors ligne).
  Future<List<OnlineFood>?> cachedSearch(String query) async {
    final c = await _readCache();
    final entry = asJson((c['recherches'] as Map)[_key(query)]);
    if (entry == null) return null;
    final produits = c['produits'] as Map;
    return [
      for (final code in asStringList(entry['codes']))
        if (produits[code] is Map) OnlineFood.fromJson(Map<String, dynamic>.from(produits[code] as Map)),
    ];
  }

  /// Recherche en français. Relit le cache s'il est récent ; en cas d'échec
  /// réseau, rend le cache ancien s'il existe, sinon lève [OnlineFoodError].
  Future<List<OnlineFood>> search(String query, {int pageSize = 30}) async {
    final key = _key(query);
    if (key.length < 2) return [];
    final c = await _readCache();
    final entry = asJson((c['recherches'] as Map)[key]);
    final t = asInt(entry?['t']);
    if (t != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(t)) < _dureeCache) {
      final cached = await cachedSearch(query);
      if (cached != null) return cached;
    }
    try {
      final list = await _searchRemote(key, pageSize);
      final produits = c['produits'] as Map<String, dynamic>;
      for (final f in list) {
        final code = f.food.codeBarres;
        if (code != null) produits[code] = f.toJson();
      }
      (c['recherches'] as Map<String, dynamic>)[key] = {
        't': DateTime.now().millisecondsSinceEpoch,
        'codes': [for (final f in list) if (f.food.codeBarres != null) f.food.codeBarres],
      };
      await _writeCache();
      return list;
    } on OnlineFoodError {
      final cached = await cachedSearch(query);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<OnlineFood>> _searchRemote(String q, int pageSize) async {
    // Moteur de recherche récent en premier, ancien point d'accès en secours.
    final primary = Uri.https('search.openfoodfacts.org', '/search', {
      'q': q,
      'langs': 'fr',
      'page_size': '$pageSize',
      'fields': _fields,
    });
    try {
      final body = await _get(primary);
      final hits = body['hits'];
      if (hits is List) return _parseList(hits);
    } on OnlineFoodError catch (e) {
      if (e.message == _horsLigne) rethrow;
    }
    final fallback = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'lc': 'fr',
      'page_size': '$pageSize',
      'fields': _fields,
    });
    final body = await _get(fallback);
    final products = body['products'];
    return products is List ? _parseList(products) : [];
  }

  List<OnlineFood> _parseList(List raw) {
    final out = <OnlineFood>[];
    final seen = <String>{};
    for (final p in raw.whereType<Map>()) {
      final f = parseProduct(Map<String, dynamic>.from(p));
      if (f == null) continue;
      if (!seen.add(f.food.codeBarres ?? f.food.id)) continue;
      out.add(f);
    }
    return out;
  }

  /// Lit un code-barres : cache d'abord, puis la base en ligne.
  /// Null si le produit n'existe pas ; [OnlineFoodError] si le réseau manque.
  Future<OnlineFood?> product(String code) async {
    final c = await _readCache();
    final produits = c['produits'] as Map<String, dynamic>;
    if (produits[code] is Map) return OnlineFood.fromJson(Map<String, dynamic>.from(produits[code] as Map));
    final uri = Uri.https('world.openfoodfacts.org', '/api/v2/product/$code', {'fields': _fields, 'lc': 'fr'});
    final body = await _get(uri, notFoundIsNull: true);
    if (body.isEmpty) return null;
    if (asInt(body['status']) != 1 || body['product'] is! Map) return null;
    final f = parseProduct(Map<String, dynamic>.from(body['product'] as Map), fallbackCode: code);
    if (f == null) return null;
    produits[code] = f.toJson();
    await _writeCache();
    return f;
  }

  static const _horsLigne = 'Pas de connexion. Vérifie le réseau et réessaie.';

  Future<Map<String, dynamic>> _get(Uri uri, {bool notFoundIsNull = false}) async {
    http.Response r;
    try {
      r = await _http.get(uri, headers: {'User-Agent': _agent, 'Accept': 'application/json'}).timeout(_timeout);
    } on TimeoutException {
      throw const OnlineFoodError('La base en ligne met trop de temps à répondre.');
    } catch (_) {
      throw const OnlineFoodError(_horsLigne);
    }
    if (r.statusCode == 404 && notFoundIsNull) return {};
    if (r.statusCode == 429) throw const OnlineFoodError('Trop de recherches d\'un coup. Patiente quelques secondes.');
    if (r.statusCode >= 400) throw OnlineFoodError('La base en ligne ne répond pas (erreur ${r.statusCode}).');
    try {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      throw const OnlineFoodError('Réponse illisible de la base en ligne.');
    }
  }

  /// Transforme un produit brut en aliment ; null sans nom ni calories.
  static OnlineFood? parseProduct(Map<String, dynamic> p, {String? fallbackCode}) {
    final code = asString(p['code']) ?? fallbackCode;
    String? nom = _text(p['product_name_fr']) ?? _text(p['product_name']) ?? _text(p['generic_name_fr']);
    if (nom == null || code == null) return null;
    final n = asJson(p['nutriments']) ?? const {};
    double? v(String k) => asDouble(n['${k}_100g']) ?? asDouble(n[k]);
    var kcal = v('energy-kcal');
    final kj = v('energy-kj') ?? v('energy');
    if (kcal == null && kj != null) kcal = kj / 4.184;
    if (kcal == null) return null;
    final brands = p['brands'];
    final marque = brands is List ? (brands.isEmpty ? null : _text(brands.first)) : _text(brands?.toString().split(',').first);
    final serving = asDouble(p['serving_quantity']);
    final servingLabel = _text(p['serving_size']);
    final quantite = _text(p['quantity']);
    final liquide = RegExp(r'\b(ml|cl|l)\b', caseSensitive: false).hasMatch('${quantite ?? ''} ${servingLabel ?? ''}');
    final portions = <Portion>[
      if (serving != null && serving > 0) Portion(label: servingLabel == null ? 'portion' : 'portion ($servingLabel)', grammes: serving),
    ];
    final ns = asString(p['nutriscore_grade'])?.toLowerCase();
    return OnlineFood(
      food: Food(
        id: 'off-$code',
        nom: _cap(nom),
        marque: marque,
        codeBarres: code,
        pour100g: Macros(
          kcal: kcal,
          proteines: v('proteins') ?? 0,
          glucides: v('carbohydrates') ?? 0,
          lipides: v('fat') ?? 0,
          fibres: v('fiber') ?? 0,
          sucres: v('sugars') ?? 0,
          sel: v('salt') ?? 0,
        ),
        portions: portions,
        source: 'openfoodfacts',
        image: _text(p['image_front_small_url']),
        liquide: liquide,
      ),
      nutriscore: (ns != null && ns.length == 1 && 'abcde'.contains(ns)) ? ns : null,
      quantite: quantite,
    );
  }

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
