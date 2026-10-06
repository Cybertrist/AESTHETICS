import 'json.dart';

enum MealType {
  petitDejeuner('Petit-déjeuner', 8),
  dejeuner('Déjeuner', 12),
  collation('Collation', 16),
  diner('Dîner', 20);

  const MealType(this.label, this.heure);
  final String label;

  /// Heure habituelle, pour proposer le bon repas par défaut.
  final int heure;

  static MealType pourHeure(int h) {
    if (h < 11) return petitDejeuner;
    if (h < 15) return dejeuner;
    if (h < 18) return collation;
    return diner;
  }
}

/// Valeurs nutritionnelles pour une quantité donnée.
class Macros {
  const Macros({this.kcal = 0, this.proteines = 0, this.glucides = 0, this.lipides = 0, this.fibres = 0, this.sucres = 0, this.sel = 0});

  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;
  final double fibres;
  final double sucres;
  final double sel;

  static const zero = Macros();

  Macros operator +(Macros o) => Macros(
        kcal: kcal + o.kcal,
        proteines: proteines + o.proteines,
        glucides: glucides + o.glucides,
        lipides: lipides + o.lipides,
        fibres: fibres + o.fibres,
        sucres: sucres + o.sucres,
        sel: sel + o.sel,
      );

  Macros scale(double f) => Macros(
        kcal: kcal * f,
        proteines: proteines * f,
        glucides: glucides * f,
        lipides: lipides * f,
        fibres: fibres * f,
        sucres: sucres * f,
        sel: sel * f,
      );

  factory Macros.fromJson(Json? j) => j == null
      ? zero
      : Macros(
          kcal: asDouble(j['kcal']) ?? 0,
          proteines: asDouble(j['proteines']) ?? 0,
          glucides: asDouble(j['glucides']) ?? 0,
          lipides: asDouble(j['lipides']) ?? 0,
          fibres: asDouble(j['fibres']) ?? 0,
          sucres: asDouble(j['sucres']) ?? 0,
          sel: asDouble(j['sel']) ?? 0,
        );

  Json toJson() => {
        'kcal': kcal,
        'proteines': proteines,
        'glucides': glucides,
        'lipides': lipides,
        'fibres': fibres,
        'sucres': sucres,
        'sel': sel,
      };
}

/// Portion nommée d'un aliment (« 1 œuf », « 1 bol »).
class Portion {
  const Portion({required this.label, required this.grammes});
  final String label;
  final double grammes;

  factory Portion.fromJson(Json j) => Portion(label: asString(j['label']) ?? 'Portion', grammes: asDouble(j['grammes']) ?? 100);
  Json toJson() => {'label': label, 'grammes': grammes};
}

/// Aliment, valeurs pour 100 g (ou 100 ml).
class Food {
  const Food({
    required this.id,
    required this.nom,
    this.marque,
    this.codeBarres,
    this.pour100g = Macros.zero,
    this.portions = const [],
    this.source = 'perso',
    this.favori = false,
    this.image,
    this.liquide = false,
  });

  final String id;
  final String nom;
  final String? marque;
  final String? codeBarres;
  final Macros pour100g;
  final List<Portion> portions;

  /// « perso », « catalogue », « openfoodfacts ».
  final String source;
  final bool favori;
  final String? image;
  final bool liquide;

  Macros pour(double grammes) => pour100g.scale(grammes / 100);

  Food copyWith({String? nom, String? marque, String? codeBarres, Macros? pour100g, List<Portion>? portions, bool? favori, String? image, bool? liquide}) =>
      Food(
        id: id,
        nom: nom ?? this.nom,
        marque: marque ?? this.marque,
        codeBarres: codeBarres ?? this.codeBarres,
        pour100g: pour100g ?? this.pour100g,
        portions: portions ?? this.portions,
        source: source,
        favori: favori ?? this.favori,
        image: image ?? this.image,
        liquide: liquide ?? this.liquide,
      );

  factory Food.fromJson(Json j) => Food(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Aliment',
        marque: asString(j['marque']),
        codeBarres: asString(j['codeBarres']),
        pour100g: Macros.fromJson(asJson(j['pour100g'])),
        portions: asList(j['portions'], Portion.fromJson),
        source: asString(j['source']) ?? 'perso',
        favori: asBool(j['favori']),
        image: asString(j['image']),
        liquide: asBool(j['liquide']),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'marque': marque,
        'codeBarres': codeBarres,
        'pour100g': pour100g.toJson(),
        'portions': portions.isEmpty ? null : portions.map((p) => p.toJson()).toList(),
        'source': source,
        'favori': favori ? true : null,
        'image': image,
        'liquide': liquide ? true : null,
      });
}

/// Aliment noté dans le journal d'un jour.
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.date,
    required this.repas,
    required this.nom,
    required this.quantiteG,
    required this.macros,
    this.foodId,
    this.portionLabel,
  });

  final String id;
  final DateTime date;
  final MealType repas;

  /// Nom et valeurs copiés au moment de l'ajout : le journal ne bouge plus.
  final String nom;
  final double quantiteG;
  final Macros macros;
  final String? foodId;
  final String? portionLabel;

  FoodEntry copyWith({DateTime? date, MealType? repas, double? quantiteG, Macros? macros, String? portionLabel}) => FoodEntry(
        id: id,
        date: date ?? this.date,
        repas: repas ?? this.repas,
        nom: nom,
        quantiteG: quantiteG ?? this.quantiteG,
        macros: macros ?? this.macros,
        foodId: foodId,
        portionLabel: portionLabel ?? this.portionLabel,
      );

  factory FoodEntry.fromJson(Json j) => FoodEntry(
        id: asString(j['id']) ?? '',
        date: asDate(j['date']) ?? DateTime.now(),
        repas: enumByName(MealType.values, j['repas'], MealType.dejeuner),
        nom: asString(j['nom']) ?? '',
        quantiteG: asDouble(j['quantiteG']) ?? 0,
        macros: Macros.fromJson(asJson(j['macros'])),
        foodId: asString(j['foodId']),
        portionLabel: asString(j['portionLabel']),
      );

  Json toJson() => compact({
        'id': id,
        'date': dateOut(date),
        'repas': repas.name,
        'nom': nom,
        'quantiteG': quantiteG,
        'macros': macros.toJson(),
        'foodId': foodId,
        'portionLabel': portionLabel,
      });
}

/// Élément d'un repas enregistré.
class MealItem {
  const MealItem({required this.foodId, required this.nom, required this.grammes, required this.macros});
  final String foodId;
  final String nom;
  final double grammes;
  final Macros macros;

  factory MealItem.fromJson(Json j) => MealItem(
        foodId: asString(j['foodId']) ?? '',
        nom: asString(j['nom']) ?? '',
        grammes: asDouble(j['grammes']) ?? 0,
        macros: Macros.fromJson(asJson(j['macros'])),
      );

  Json toJson() => {'foodId': foodId, 'nom': nom, 'grammes': grammes, 'macros': macros.toJson()};
}

/// Repas enregistré (recette ou habitude) qu'on ajoute d'un coup.
class Meal {
  const Meal({required this.id, required this.nom, this.items = const [], this.repas, this.favori = false});

  final String id;
  final String nom;
  final List<MealItem> items;
  final MealType? repas;
  final bool favori;

  Macros get macros => items.fold(Macros.zero, (a, i) => a + i.macros);

  Meal copyWith({String? nom, List<MealItem>? items, MealType? repas, bool? favori}) =>
      Meal(id: id, nom: nom ?? this.nom, items: items ?? this.items, repas: repas ?? this.repas, favori: favori ?? this.favori);

  factory Meal.fromJson(Json j) => Meal(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Repas',
        items: asList(j['items'], MealItem.fromJson),
        repas: j['repas'] == null ? null : enumByName(MealType.values, j['repas'], MealType.dejeuner),
        favori: asBool(j['favori']),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'items': items.map((i) => i.toJson()).toList(),
        'repas': repas?.name,
        'favori': favori ? true : null,
      });
}

/// Eau bue.
class WaterLog {
  const WaterLog({required this.id, required this.date, required this.ml});
  final String id;
  final DateTime date;
  final int ml;

  factory WaterLog.fromJson(Json j) =>
      WaterLog(id: asString(j['id']) ?? '', date: asDate(j['date']) ?? DateTime.now(), ml: asInt(j['ml']) ?? 0);
  Json toJson() => {'id': id, 'date': dateOut(date), 'ml': ml};
}

/// Objectifs du jour.
class NutritionGoals {
  const NutritionGoals({
    this.kcal = 2400,
    this.proteinesG = 160,
    this.glucidesG = 270,
    this.lipidesG = 75,
    this.fibresG = 30,
    this.eauMl = 2500,
  });

  final double kcal;
  final double proteinesG;
  final double glucidesG;
  final double lipidesG;
  final double fibresG;
  final int eauMl;

  NutritionGoals copyWith({double? kcal, double? proteinesG, double? glucidesG, double? lipidesG, double? fibresG, int? eauMl}) =>
      NutritionGoals(
        kcal: kcal ?? this.kcal,
        proteinesG: proteinesG ?? this.proteinesG,
        glucidesG: glucidesG ?? this.glucidesG,
        lipidesG: lipidesG ?? this.lipidesG,
        fibresG: fibresG ?? this.fibresG,
        eauMl: eauMl ?? this.eauMl,
      );

  factory NutritionGoals.fromJson(Json j) => NutritionGoals(
        kcal: asDouble(j['kcal']) ?? 2400,
        proteinesG: asDouble(j['proteinesG']) ?? 160,
        glucidesG: asDouble(j['glucidesG']) ?? 270,
        lipidesG: asDouble(j['lipidesG']) ?? 75,
        fibresG: asDouble(j['fibresG']) ?? 30,
        eauMl: asInt(j['eauMl']) ?? 2500,
      );

  Json toJson() => {
        'kcal': kcal,
        'proteinesG': proteinesG,
        'glucidesG': glucidesG,
        'lipidesG': lipidesG,
        'fibresG': fibresG,
        'eauMl': eauMl,
      };
}
