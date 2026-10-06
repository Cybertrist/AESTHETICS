import 'package:flutter/material.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';

/// Données que le coach a le droit de lire.
enum CoachPartage {
  profil('Profil', 'Âge, taille, objectif, niveau, matériel', Icons.person_rounded, AppDomain.coach),
  seances('Séances', 'Exercices, séries, charges et durées récentes', Icons.fitness_center_rounded, AppDomain.entrainement),
  routines('Routines et programme', 'Tes routines enregistrées et le programme actif', Icons.view_list_rounded, AppDomain.entrainement),
  records('Records', 'Meilleures charges et 1RM estimés', Icons.emoji_events_rounded, AppDomain.entrainement),
  recuperation('Récupération', 'Fatigue estimée de chaque muscle', Icons.battery_charging_full_rounded, AppDomain.coeur),
  nutrition('Nutrition', 'Calories, macros, eau et objectifs', Icons.restaurant_rounded, AppDomain.nutrition),
  sommeil('Sommeil', 'Durée et qualité des dernières nuits', Icons.bedtime_rounded, AppDomain.sommeil),
  mesures('Poids et mensurations', 'Pesées, masse grasse, tours', Icons.monitor_weight_rounded, AppDomain.poids);

  const CoachPartage(this.label, this.description, this.icon, this.domain);
  final String label;
  final String description;
  final IconData icon;
  final AppDomain domain;
}

/// Profondeur de réflexion, envoyée comme niveau d'effort à l'API.
enum CoachReflexion {
  rapide('Rapide', 'Réponses vives, idéal pour discuter', 'low'),
  equilibree('Équilibrée', 'Le bon compromis', 'medium'),
  approfondie('Approfondie', 'Plus lent, pour les programmes et les bilans', 'high');

  const CoachReflexion(this.label, this.description, this.effort);
  final String label;
  final String description;
  final String effort;
}

/// Ton du coach (gardé dans AppSettings.coachTon).
enum CoachTon {
  bienveillant('Bienveillant', 'Encourageant, positif, patient'),
  direct('Direct', 'Franc et concis, sans détour'),
  exigeant('Exigeant', 'Pousse à se dépasser, ne laisse rien passer'),
  pedagogue('Pédagogue', 'Explique le pourquoi de chaque conseil');

  const CoachTon(this.label, this.description);
  final String label;
  final String description;

  static CoachTon parse(String? v) => CoachTon.values.firstWhere((t) => t.name == v, orElse: () => CoachTon.bienveillant);
}

enum CoachLongueur {
  courte('Courtes', 'L\'essentiel en quelques lignes'),
  detaillee('Détaillées', 'Explications complètes et exemples');

  const CoachLongueur(this.label, this.description);
  final String label;
  final String description;
}

/// Réglages propres au coach (hors clé, modèle et ton, rangés dans AppSettings).
class CoachPrefs {
  const CoachPrefs({
    this.partage = const {...CoachPartage.values},
    this.periodeJours = 30,
    this.reflexion = CoachReflexion.equilibree,
    this.longueur = CoachLongueur.courte,
    this.phraseIa = true,
    this.bilanDimanche = true,
    this.phraseDate,
    this.phraseTexte,
    this.phraseParIa = false,
    this.bilans = const {},
    this.actionsAppliquees = const {},
    this.modelesApi = const [],
  });

  final Set<CoachPartage> partage;

  /// Fenêtre d'historique envoyée au coach.
  final int periodeJours;
  final CoachReflexion reflexion;
  final CoachLongueur longueur;

  /// Phrase du jour rédigée par l'IA (sinon calculée sur le téléphone).
  final bool phraseIa;

  /// Bilan de la semaine rédigé tout seul le dimanche.
  final bool bilanDimanche;

  /// Phrase du jour en cache : date (aaaa-mm-jj), texte, origine.
  final String? phraseDate;
  final String? phraseTexte;
  final bool phraseParIa;

  /// Bilans rédigés par le coach, par semaine (clé : lundi aaaa-mm-jj).
  final Map<String, String> bilans;

  /// Actions déjà appliquées (idMessage#rang).
  final Set<String> actionsAppliquees;

  /// Modèles lus sur l'API avec la clé (id et nom affiché).
  final List<(String, String)> modelesApi;

  bool peut(CoachPartage p) => partage.contains(p);

  CoachPrefs copyWith({
    Set<CoachPartage>? partage,
    int? periodeJours,
    CoachReflexion? reflexion,
    CoachLongueur? longueur,
    bool? phraseIa,
    bool? bilanDimanche,
    String? phraseDate,
    String? phraseTexte,
    bool? phraseParIa,
    bool clearPhrase = false,
    Map<String, String>? bilans,
    Set<String>? actionsAppliquees,
    List<(String, String)>? modelesApi,
  }) =>
      CoachPrefs(
        partage: partage ?? this.partage,
        periodeJours: periodeJours ?? this.periodeJours,
        reflexion: reflexion ?? this.reflexion,
        longueur: longueur ?? this.longueur,
        phraseIa: phraseIa ?? this.phraseIa,
        bilanDimanche: bilanDimanche ?? this.bilanDimanche,
        phraseDate: clearPhrase ? null : (phraseDate ?? this.phraseDate),
        phraseTexte: clearPhrase ? null : (phraseTexte ?? this.phraseTexte),
        phraseParIa: clearPhrase ? false : (phraseParIa ?? this.phraseParIa),
        bilans: bilans ?? this.bilans,
        actionsAppliquees: actionsAppliquees ?? this.actionsAppliquees,
        modelesApi: modelesApi ?? this.modelesApi,
      );

  factory CoachPrefs.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? v, T def) =>
        values.firstWhere((e) => e.name == v, orElse: () => def);
    final partageRaw = j['partage'];
    return CoachPrefs(
      partage: partageRaw is List
          ? {for (final p in partageRaw) ...CoachPartage.values.where((e) => e.name == p)}
          : const {...CoachPartage.values},
      periodeJours: (j['periodeJours'] as num?)?.toInt() ?? 30,
      reflexion: byName(CoachReflexion.values, j['reflexion'], CoachReflexion.equilibree),
      longueur: byName(CoachLongueur.values, j['longueur'], CoachLongueur.courte),
      phraseIa: j['phraseIa'] as bool? ?? true,
      bilanDimanche: j['bilanDimanche'] as bool? ?? true,
      phraseDate: j['phraseDate'] as String?,
      phraseTexte: j['phraseTexte'] as String?,
      phraseParIa: j['phraseParIa'] as bool? ?? false,
      bilans: (j['bilans'] is Map) ? (j['bilans'] as Map).map((k, v) => MapEntry('$k', '$v')) : const {},
      actionsAppliquees: (j['actionsAppliquees'] is List) ? {for (final a in j['actionsAppliquees'] as List) '$a'} : const {},
      modelesApi: (j['modelesApi'] is List)
          ? [
              for (final m in j['modelesApi'] as List)
                if (m is Map && m['id'] != null) ('${m['id']}', '${m['nom'] ?? m['id']}'),
            ]
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'partage': partage.map((p) => p.name).toList(),
        'periodeJours': periodeJours,
        'reflexion': reflexion.name,
        'longueur': longueur.name,
        'phraseIa': phraseIa,
        'bilanDimanche': bilanDimanche,
        if (phraseDate != null) 'phraseDate': phraseDate,
        if (phraseTexte != null) 'phraseTexte': phraseTexte,
        'phraseParIa': phraseParIa,
        'bilans': bilans,
        'actionsAppliquees': actionsAppliquees.toList(),
        'modelesApi': [for (final (id, nom) in modelesApi) {'id': id, 'nom': nom}],
      };
}

/// Tient les réglages du coach, rangés dans la collection `coach_reglages`.
/// Une instance par Store (la démo a son propre dossier).
class CoachPrefsController extends ChangeNotifier {
  CoachPrefsController._(this.store) {
    _load();
  }

  static final _instances = Expando<CoachPrefsController>('coach');

  static CoachPrefsController of(Store store) => _instances[store] ??= CoachPrefsController._(store);

  static const collection = 'coach_reglages';

  final Store store;
  CoachPrefs _prefs = const CoachPrefs();
  bool _loaded = false;
  Future<void>? _loading;

  CoachPrefs get prefs => _prefs;
  bool get loaded => _loaded;

  Future<void> ready() => _loading ?? Future.value();

  void _load() {
    _loading = () async {
      try {
        final j = await store.readObject(collection);
        if (j != null) _prefs = CoachPrefs.fromJson(j);
      } catch (_) {
        // Fichier illisible : on repart des valeurs par défaut.
      }
      _loaded = true;
      notifyListeners();
    }();
  }

  Future<void> update(CoachPrefs Function(CoachPrefs p) change) async {
    await ready();
    _prefs = change(_prefs);
    notifyListeners();
    await store.write(collection, _prefs.toJson());
  }

  Future<void> markApplied(String key) => update((p) => p.copyWith(actionsAppliquees: {...p.actionsAppliquees, key}));

  Future<void> reset() async {
    _prefs = const CoachPrefs();
    notifyListeners();
    await store.write(collection, _prefs.toJson());
  }
}
