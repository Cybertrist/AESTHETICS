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
