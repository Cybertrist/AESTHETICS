/// Petits outils de lecture JSON tolérants, partagés par les modèles.
typedef Json = Map<String, dynamic>;

double? asDouble(Object? v) {
  if (v == null) return null;
  double? d;
  if (v is num) d = v.toDouble();
  if (v is String) d = double.tryParse(v.replaceAll(',', '.'));
  // « NaN » ou « Infinity » dans un fichier : valeur absente.
  return d == null || !d.isFinite ? null : d;
}

int? asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.round() : null;
  if (v is String) {
    final i = int.tryParse(v);
    if (i != null) return i;
    final d = double.tryParse(v.replaceAll(',', '.'));
    return d == null || !d.isFinite ? null : d.round();
  }
  return null;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return fallback;
}

String? asString(Object? v) => v?.toString();

/// Les « \u00E9 » laissés tels quels par l'export d'une autre appli
/// redeviennent « é » : « S\u00E9ance du soir » → « Séance du soir ».
final _echappe = RegExp(r'\\u([0-9A-Fa-f]{4})');
String desechapper(String s) => s.contains(r'\u') ? s.replaceAllMapped(_echappe, (m) => String.fromCharCode(int.parse(m[1]!, radix: 16))) : s;

/// Un texte écrit par l'utilisateur (nom, note), réparé de ses « \u00E9 ».
String? asTexte(Object? v) {
  final s = asString(v);
  return s == null ? null : desechapper(s);
}

/// Exercices du catalogue fondus dans un autre : la même machine sous deux noms.
const exercicesFondus = {'machine-chest-fly': 'pec-deck'};

/// L'identifiant d'exercice d'un fichier, ramené à celui qui reste au catalogue.
String asExercice(Object? v) {
  final id = asString(v) ?? '';
  return exercicesFondus[id] ?? id;
}

DateTime? asDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String? dateOut(DateTime? d) => d?.toIso8601String();

List<String> asStringList(Object? v) =>
    v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : <String>[];

List<T> asList<T>(Object? v, T Function(Json) f) => v is List
    ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList()
    : <T>[];

Json? asJson(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Retire les clés nulles pour garder des fichiers compacts.
Json compact(Json m) => m..removeWhere((_, v) => v == null);
