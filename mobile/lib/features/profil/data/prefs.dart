import 'package:flutter/foundation.dart';

import '../../../core/data/store.dart';
import '../../../core/models/json.dart';

/// Unité de longueur (taille, tours de corps).
enum UniteLongueur {
  cm('cm', 'Centimètres'),
  pouce('in', 'Pouces');

  const UniteLongueur(this.label, this.nom);
  final String label;
  final String nom;
}

/// Unité d'énergie (nutrition, dépense).
enum UniteEnergie {
  kcal('kcal', 'Kilocalories'),
  kj('kJ', 'Kilojoules');

  const UniteEnergie(this.label, this.nom);
  final String label;
  final String nom;
}

/// Taille du texte de l'appli.
enum TailleTexte {
  petite('Petite', 0.9),
  normale('Normale', 1.0),
  grande('Grande', 1.12),
  tresGrande('Très grande', 1.25);

  const TailleTexte(this.label, this.facteur);
  final String label;
  final double facteur;
}

/// Une barre disponible pour le calculateur de disques.
class Barre {
  const Barre({required this.id, required this.nom, required this.poidsKg, this.active = true});

  final String id;
  final String nom;
  final double poidsKg;
  final bool active;

  Barre copyWith({String? nom, double? poidsKg, bool? active}) =>
      Barre(id: id, nom: nom ?? this.nom, poidsKg: poidsKg ?? this.poidsKg, active: active ?? this.active);

  factory Barre.fromJson(Json j) => Barre(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Barre',
        poidsKg: asDouble(j['poidsKg']) ?? 20,
        active: asBool(j['active'], true),
      );

  Json toJson() => {'id': id, 'nom': nom, 'poidsKg': poidsKg, 'active': active};
}

/// Un disque disponible : son poids et le nombre de paires.
class Disque {
  const Disque({required this.poidsKg, this.paires = 2});

  final double poidsKg;

  /// Nombre de paires (un disque de chaque côté de la barre par paire).
  final int paires;

  Disque copyWith({double? poidsKg, int? paires}) => Disque(poidsKg: poidsKg ?? this.poidsKg, paires: paires ?? this.paires);

  factory Disque.fromJson(Json j) => Disque(poidsKg: asDouble(j['poidsKg']) ?? 20, paires: asInt(j['paires']) ?? 2);

  Json toJson() => {'poidsKg': poidsKg, 'paires': paires};
}

/// Réglages tenus par le module profil, absents d'AppSettings : unités de
/// longueur et d'énergie, taille du texte, minuteur automatique, barres et
/// disques, détails des rappels, mode développeur.
class ProfilPrefs {
  const ProfilPrefs({
    this.longueur = UniteLongueur.cm,
    this.energie = UniteEnergie.kcal,
    this.tailleTexte = TailleTexte.normale,
    this.minuteurAuto = true,
    this.barres = barresParDefaut,
    this.barreParDefaut = 'olympique',
    this.disques = disquesParDefaut,
    this.heureComplements = '08:00',
    this.eauDebut = '09:00',
    this.eauFin = '21:00',
    this.eauIntervalleMin = 120,
    this.devDebloque = false,
  });

  static const barresParDefaut = [
    Barre(id: 'olympique', nom: 'Barre olympique', poidsKg: 20),
    Barre(id: 'femme', nom: 'Barre de 15 kg', poidsKg: 15),
    Barre(id: 'ez', nom: 'Barre EZ', poidsKg: 10),
    Barre(id: 'courte', nom: 'Barre courte', poidsKg: 7.5, active: false),
    Barre(id: 'trap', nom: 'Trap bar', poidsKg: 25, active: false),
  ];

  static const disquesParDefaut = [
    Disque(poidsKg: 25, paires: 2),
    Disque(poidsKg: 20, paires: 4),
    Disque(poidsKg: 15, paires: 2),
    Disque(poidsKg: 10, paires: 2),
    Disque(poidsKg: 5, paires: 2),
    Disque(poidsKg: 2.5, paires: 2),
    Disque(poidsKg: 1.25, paires: 2),
  ];

  final UniteLongueur longueur;
  final UniteEnergie energie;
  final TailleTexte tailleTexte;

  /// Lance le repos tout seul quand une série est cochée.
  final bool minuteurAuto;
  final List<Barre> barres;
  final String barreParDefaut;
  final List<Disque> disques;
  final String heureComplements;
  final String eauDebut;
  final String eauFin;
  final int eauIntervalleMin;
  final bool devDebloque;

  Barre? get barre => barres.where((b) => b.id == barreParDefaut).firstOrNull ?? barres.where((b) => b.active).firstOrNull;

  ProfilPrefs copyWith({
    UniteLongueur? longueur,
    UniteEnergie? energie,
    TailleTexte? tailleTexte,
    bool? minuteurAuto,
    List<Barre>? barres,
    String? barreParDefaut,
    List<Disque>? disques,
    String? heureComplements,
    String? eauDebut,
    String? eauFin,
    int? eauIntervalleMin,
    bool? devDebloque,
  }) =>
      ProfilPrefs(
        longueur: longueur ?? this.longueur,
        energie: energie ?? this.energie,
        tailleTexte: tailleTexte ?? this.tailleTexte,
        minuteurAuto: minuteurAuto ?? this.minuteurAuto,
        barres: barres ?? this.barres,
        barreParDefaut: barreParDefaut ?? this.barreParDefaut,
        disques: disques ?? this.disques,
        heureComplements: heureComplements ?? this.heureComplements,
        eauDebut: eauDebut ?? this.eauDebut,
        eauFin: eauFin ?? this.eauFin,
        eauIntervalleMin: eauIntervalleMin ?? this.eauIntervalleMin,
        devDebloque: devDebloque ?? this.devDebloque,
      );

  factory ProfilPrefs.fromJson(Json j) => ProfilPrefs(
        longueur: enumByName(UniteLongueur.values, j['longueur'], UniteLongueur.cm),
        energie: enumByName(UniteEnergie.values, j['energie'], UniteEnergie.kcal),
        tailleTexte: enumByName(TailleTexte.values, j['tailleTexte'], TailleTexte.normale),
        minuteurAuto: asBool(j['minuteurAuto'], true),
        barres: j['barres'] is List
            ? (j['barres'] as List).whereType<Map>().map((m) => Barre.fromJson(Map<String, dynamic>.from(m))).toList()
            : barresParDefaut,
        barreParDefaut: asString(j['barreParDefaut']) ?? 'olympique',
        disques: j['disques'] is List
            ? (j['disques'] as List).whereType<Map>().map((m) => Disque.fromJson(Map<String, dynamic>.from(m))).toList()
            : disquesParDefaut,
        heureComplements: asString(j['heureComplements']) ?? '08:00',
        eauDebut: asString(j['eauDebut']) ?? '09:00',
        eauFin: asString(j['eauFin']) ?? '21:00',
        eauIntervalleMin: asInt(j['eauIntervalleMin']) ?? 120,
        devDebloque: asBool(j['devDebloque']),
      );

  Json toJson() => {
        'longueur': longueur.name,
        'energie': energie.name,
        'tailleTexte': tailleTexte.name,
        'minuteurAuto': minuteurAuto,
        'barres': barres.map((b) => b.toJson()).toList(),
        'barreParDefaut': barreParDefaut,
        'disques': disques.map((d) => d.toJson()).toList(),
        'heureComplements': heureComplements,
        'eauDebut': eauDebut,
        'eauFin': eauFin,
        'eauIntervalleMin': eauIntervalleMin,
        'devDebloque': devDebloque,
      };
}

/// Dépôt des réglages du module profil, collection `preferences` du Store
/// (comprise dans la sauvegarde). Instance unique, lisible par les autres
/// modules : `await PrefsRepo.ensure(context.read<Store>())`, puis
/// `PrefsRepo.instance.prefs`.
class PrefsRepo extends ChangeNotifier {
  PrefsRepo._(this.store);

  static const file = 'preferences';
  static PrefsRepo? _instance;

  /// Instance courante (null tant que [ensure] n'a pas été appelé).
  static PrefsRepo? get maybeInstance => _instance;

  static PrefsRepo get instance {
    final i = _instance;
    if (i == null) throw StateError('PrefsRepo.ensure(store) doit être appelé avant.');
    return i;
  }

  /// Crée (au besoin) le dépôt pour ce stockage et le relit. La relecture à
  /// chaque appel garde les préférences justes après une restauration ou un
  /// effacement faits par un autre module (le fichier a changé sous lui).
  static Future<PrefsRepo> ensure(Store store) async {
    var i = _instance;
    if (i == null || !identical(i.store, store)) {
      i = PrefsRepo._(store);
      _instance = i;
    }
    await i.load();
    return i;
  }

  /// Pour les tests.
  @visibleForTesting
  static void reset() => _instance = null;

  final Store store;
  ProfilPrefs _prefs = const ProfilPrefs();
  bool _loaded = false;

  ProfilPrefs get prefs => _prefs;
  bool get loaded => _loaded;

  Future<void> load() async {
    final j = await store.readObject(file);
    _prefs = j == null ? const ProfilPrefs() : ProfilPrefs.fromJson(j);
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(ProfilPrefs p) async {
    _prefs = p;
    notifyListeners();
    await store.write(file, p.toJson());
  }

  Future<void> update(ProfilPrefs Function(ProfilPrefs p) change) => save(change(_prefs));
}

/// Conversions d'affichage des unités de longueur et d'énergie.
abstract final class Unites {
  static const cmParPouce = 2.54;
  static const kjParKcal = 4.184;

  static double longueurAffichee(double cm, UniteLongueur u) => u == UniteLongueur.cm ? cm : cm / cmParPouce;
  static double longueurStockee(double v, UniteLongueur u) => u == UniteLongueur.cm ? v : v * cmParPouce;
  static double energieAffichee(double kcal, UniteEnergie u) => u == UniteEnergie.kcal ? kcal : kcal * kjParKcal;

  /// « 181 cm » ou « 5 pi 11 ».
  static String taille(double? cm, UniteLongueur u) {
    if (cm == null) return '-';
    if (u == UniteLongueur.cm) return '${cm.round()} cm';
    final pouces = (cm / cmParPouce).round();
    return '${pouces ~/ 12} pi ${pouces % 12}';
  }
}
