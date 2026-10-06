import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/data.dart';
import '../../core/env.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import 'data/draft.dart';

/// Étapes du parcours, dans l'ordre.
enum Etape {
  prenom('prenom', 'Prénom', Icons.badge_rounded),
  sexe('sexe', 'Sexe', Icons.wc_rounded),
  naissance('naissance', 'Date de naissance', Icons.cake_rounded),
  taille('taille', 'Taille', Icons.height_rounded),
  poids('poids', 'Poids', Icons.monitor_weight_rounded),
  objectif('objectif', 'Objectif', Icons.flag_rounded),
  niveau('niveau', 'Niveau', Icons.trending_up_rounded),
  activite('activite', 'Quotidien', Icons.directions_walk_rounded),
  frequence('frequence', 'Semaine type', Icons.calendar_month_rounded),
  materiel('materiel', 'Matériel', Icons.fitness_center_rounded),
  muscles('muscles', 'Muscles prioritaires', Icons.accessibility_new_rounded),
  nutrition('nutrition', 'Nutrition', Icons.restaurant_rounded),
  historique('historique', 'Historique', Icons.history_rounded),
  autorisations('autorisations', 'Autorisations', Icons.verified_user_rounded),
  recapitulatif('recapitulatif', 'Récapitulatif', Icons.fact_check_rounded);

  const Etape(this.slug, this.label, this.icon);
  final String slug;
  final String label;
  final IconData icon;

  static Etape? fromSlug(String? s) {
    for (final e in values) {
      if (e.slug == s) return e;
    }
    return null;
  }

  /// Étapes qu'on peut passer sans répondre.
  bool get facultative => this == Etape.muscles || this == Etape.historique || this == Etape.autorisations;

  /// Étapes hors musculation (dépense du quotidien, objectifs nutritionnels).
  bool get horsMuscu => this == Etape.activite || this == Etape.nutrition;

  /// Les étapes du parcours, dans l'ordre : sans les étapes hors
  /// musculation tant que l'appli s'en tient à la musculation.
  static final List<Etape> parcours = [
    for (final e in values)
      if (!(Env.muscuSeule && e.horsMuscu)) e,
  ];

  /// Nombre de questions posées (le récapitulatif n'en est pas une).
  static int get questions => parcours.length - 1;

  /// Rang dans le parcours (0 en tête). Une étape retirée du parcours
  /// renvoie à celle qui la suit.
  int get rang {
    final i = parcours.indexWhere((e) => e.index >= index);
    return i < 0 ? parcours.length - 1 : i;
  }

  /// Étapes proposées en mode édition depuis le profil.
  bool get modifiable => this != Etape.historique && this != Etape.recapitulatif;
}

/// État du parcours : le brouillon, l'étape courante, la sauvegarde.
class InscriptionController extends ChangeNotifier {
  InscriptionController(this.store, {this.edition = false});

  final Store store;

  /// Mode édition : on modifie le profil existant, rien n'est mis en brouillon.
  final bool edition;

  Draft draft = Draft();
  bool loaded = false;

  /// Une réponse a changé depuis le chargement.
  bool modifie = false;
  Object? erreur;
  Timer? _debounce;

  Etape get etape => Etape.parcours[index];
  /// Rang de l'étape courante dans le parcours.
  int get index => Etape.values[draft.etape.clamp(0, Etape.values.length - 1)].rang;
  int get total => Etape.parcours.length;
  double get avancement => (index + 1) / total;
  bool get premiere => index == 0;
  bool get derniere => etape == Etape.recapitulatif;

  /// Charge le brouillon en cours (parcours) ou part du profil (édition).
  Future<void> load({UserProfile? profil, AppSettings? settings}) async {
    try {
      if (edition && profil != null) {
        final x = await ProfileExtras.load(store);
        draft = Draft.fromProfile(profil, x, settings ?? const AppSettings());
      } else {
        final j = await store.readObject(Draft.collection);
        draft = j == null ? Draft() : Draft.fromJson(j);
      }
      erreur = null;
    } catch (e) {
      erreur = e;
      draft = Draft();
    }
    loaded = true;
    notifyListeners();
  }

  /// Modifie le brouillon et le sauve un peu plus tard.
  void set(void Function(Draft d) change) {
    change(draft);
    modifie = true;
    notifyListeners();
    _planifier();
  }

  void _planifier() {
    if (edition) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), sauver);
  }

  Future<void> sauver() async {
    _debounce?.cancel();
    if (edition) return;
    await store.write(Draft.collection, draft.toJson());
  }

  Future<void> oublier() async {
    _debounce?.cancel();
    await store.delete(Draft.collection);
  }

  void aller(Etape e) {
    draft.etape = e.index;
    notifyListeners();
    _planifier();
  }

  void suivant() {
    if (derniere) return;
    _preparer(Etape.parcours[index + 1]);
    aller(Etape.parcours[index + 1]);
  }

  void precedent() {
    if (premiere) return;
    aller(Etape.parcours[index - 1]);
  }

  /// Valeurs par défaut posées quand on arrive sur une étape à curseur.
  void _preparer(Etape e) {
    final d = draft;
    switch (e) {
      case Etape.taille:
        d.tailleCm ??= d.sexe == Sexe.femme ? 165 : 177;
      case Etape.poids:
        d.poidsKg ??= d.sexe == Sexe.femme ? 62 : 76;
      case Etape.naissance:
        d.naissance ??= DateTime(DateTime.now().year - 25, 1, 1);
      default:
    }
  }

  /// L'étape a-t-elle une réponse suffisante pour continuer ?
  bool valide(Etape e) {
    final d = draft;
    return switch (e) {
      Etape.prenom => d.prenom.trim().isNotEmpty,
      Etape.sexe => d.sexe != null,
      Etape.naissance => d.age != null && d.age! >= 13 && d.age! <= 100,
      Etape.taille => d.tailleCm != null && d.tailleCm! >= 120 && d.tailleCm! <= 230,
      Etape.poids => d.poidsKg != null && d.poidsKg! >= 30 && d.poidsKg! <= 250,
      Etape.objectif => d.objectif != null,
      Etape.niveau => d.niveau != null,
      Etape.activite => d.activite != null || !Etape.parcours.contains(e),
      Etape.frequence => d.jours.isNotEmpty,
      Etape.materiel => d.materiel.isNotEmpty,
      _ => true,
    };
  }

  /// Première étape obligatoire sans réponse (pour le récapitulatif).
  Etape? get premiereIncomplete {
    for (final e in Etape.parcours) {
      if (!valide(e)) return e;
    }
    return null;
  }

  /// Objectifs nutritionnels effectifs du brouillon.
  NutritionGoals get objectifsCalcules => NutritionCalc.objectifs(draft.toProfile());
  NutritionGoals get objectifsEffectifs => draft.nutritionAuto ? objectifsCalcules : (draft.objectifsNutrition ?? objectifsCalcules);

  /// Enregistre le profil, ses compléments et les réglages liés.
  Future<UserProfile> enregistrer({
    required ProfileRepo profils,
    required SettingsRepo reglages,
    required HealthRepo sante,
  }) async {
    final ancien = profils.profile;
    final profil = draft.toProfile();
    await profils.save(profil);
    await draft.toExtras().save(store);
    await reglages.update((s) => s.copyWith(
          santeConnectee: draft.santeConnectee,
          rappelsEntrainement: draft.rappels,
          heureRappel: draft.heureRappel,
          joursRappel: (draft.jours.toList()..sort()),
        ));
    // Première pesée, ou nouvelle pesée si le poids a changé.
    final poids = profil.poidsKg;
    if (poids != null && (ancien?.poidsKg == null || (ancien!.poidsKg! - poids).abs() >= 0.05)) {
      await sante.saveMeasurement(BodyMeasurement(id: '', date: DateTime.now(), poidsKg: poids, source: 'profil'));
    }
    if (!edition) await oublier();
    return profil;
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      if (!edition) store.write(Draft.collection, draft.toJson());
    }
    super.dispose();
  }
}
