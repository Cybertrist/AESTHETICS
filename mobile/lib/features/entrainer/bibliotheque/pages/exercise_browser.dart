import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_images.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/corps_colore.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/exercise_index.dart';
import '../widgets/exercise_media.dart';
import '../widgets/multi_choice_dialog.dart';

/// Index partagé : le catalogue n'est normalisé qu'une fois pour toute l'appli.
final _index = ExerciseIndex();

/// Grille ou liste, gardé pendant la vie de l'appli.
bool _grilleParDefaut = true;

/// Raccourcis par muscle de la rangée du haut : le buste (ou les jambes)
/// du personnage, le groupe allumé.
class MuscleGroup {
  const MuscleGroup(this.label, this.muscles, this.view, [this.framing = BodyFraming.buste, this.zoom = 1, this.centreY = 0]);
  final String label;
  final Set<Muscle> muscles;
  final BodyView view;
  final BodyFraming framing;

  /// Grossissement de la vignette et point fixe vertical (de -1 en haut à 1 en bas).
  final double zoom;
  final double centreY;

  static const all = [
    // Haut du corps : mêmes resserrements que les vignettes de la récupération.
    MuscleGroup('Pecs', {Muscle.pectoraux}, BodyView.front, BodyFraming.buste, 1.5, -0.55),
    MuscleGroup('Abdos', {Muscle.abdominaux, Muscle.obliques}, BodyView.front, BodyFraming.buste, 1.4, 0.15),
    MuscleGroup('Biceps', {Muscle.biceps}, BodyView.front, BodyFraming.buste, 1.3, -0.25),
    MuscleGroup('Dos', {Muscle.grandDorsal, Muscle.trapezes, Muscle.rhomboides, Muscle.lombaires}, BodyView.back, BodyFraming.buste, 1.3, -0.35),
    MuscleGroup('Épaules', {Muscle.deltoidesLateraux, Muscle.deltoidesAnterieurs, Muscle.deltoidesPosterieurs}, BodyView.front, BodyFraming.buste, 1.45, -0.7),
    MuscleGroup('Triceps', {Muscle.triceps}, BodyView.back, BodyFraming.buste, 1.3, -0.25),
    MuscleGroup('Avant-bras', {Muscle.avantBras}, BodyView.front, BodyFraming.buste, 1.3, 0.4),
    MuscleGroup('Cuisses', {Muscle.quadriceps, Muscle.adducteurs}, BodyView.front, BodyFraming.jambes, 1.9, -0.86),
    MuscleGroup('Ischios', {Muscle.ischios}, BodyView.back, BodyFraming.jambes, 1.9, -0.8),
    MuscleGroup('Fessiers', {Muscle.fessiers, Muscle.abducteurs}, BodyView.back, BodyFraming.jambes, 2.2, -1),
    MuscleGroup('Mollets', {Muscle.mollets}, BodyView.back, BodyFraming.jambes, 2, 0.68),
  ];
}

/// Raccourcis par catégorie, à la suite des muscles : ce qui ne se range pas
/// sous un muscle (tapis, vélo, rameur, étirements). La tuile montre le
/// personnage du pack dans une pose de la catégorie.
class CategorieRaccourci {
  const CategorieRaccourci(this.label, this.categorie, this.pose);
  final String label;
  final String categorie;
  final String pose;

  static const all = [
    CategorieRaccourci('Cardio', 'cardio', 'assets/exercises/poses/treadmill-running-main.webp'),
    CategorieRaccourci('Étirements', 'etirements', 'assets/exercises/poses/seated-forward-fold-main.webp'),
  ];
}

/// État de la liste : filtres, recherche, grille ou liste, et historique
/// mis en cache (fréquences, récents).
class ExerciseBrowserController extends ChangeNotifier {
  ExerciseBrowserController({LibraryFilters initial = const LibraryFilters()})
      : _f = initial,
        query = TextEditingController(text: initial.query);

  LibraryFilters _f;
  final TextEditingController query;
  bool _grille = _grilleParDefaut;
  List<WorkoutSession>? _sessionsRef;
  Map<String, int> freq = const {};
  List<String> recents = const [];

  LibraryFilters get filters => _f;
  bool get grille => _grille;

  set filters(LibraryFilters f) {
    _f = f;
    notifyListeners();
  }

  set grille(bool v) {
    _grille = _grilleParDefaut = v;
    notifyListeners();
  }

  void clearAll() {
    query.clear();
    filters = const LibraryFilters().copyWith(sort: _f.sort);
  }

  void syncHistory(SessionRepo sessions) {
    if (identical(sessions.sessions, _sessionsRef)) return;
    _sessionsRef = sessions.sessions;
    freq = frequencesExercices(sessions.sessions);
    recents = sessions.recentExerciseIds(limit: 60);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }
}

/// Réglages d'affichage de la liste (consultation ou sélection).
class BrowserConfig {
  const BrowserConfig({
    this.onOpen,
    this.onInfo,
    this.selection,
    this.onToggle,
    this.dejaPresents = const {},
    this.selectedId,
    this.onCreate,
    this.onMuscles,
    this.autofocus = false,
    this.numbered = false,
    this.search = true,
  });

  /// Toucher un exercice (mode consultation) : ouvre sa fiche.
  final ValueChanged<Exercise>? onOpen;

  /// « ? » en mode sélection : ouvre la fiche.
  final ValueChanged<Exercise>? onInfo;

  /// Mode sélection : ids choisis, dans l'ordre.
  final List<String>? selection;
  final ValueChanged<Exercise>? onToggle;

  /// Exercices déjà présents (routine, séance) : signalés.
  final Set<String> dejaPresents;

  /// Exercice surligné (fiche ouverte dans le volet voisin).
  final String? selectedId;

  /// « Créer un exercice », avec le texte cherché comme nom de départ.
  final ValueChanged<String>? onCreate;

  /// Puce « Muscles » : ouvre l'explorateur de muscles. Sans elle, la puce
  /// ouvre le filtre par muscle (sélecteur).
  final VoidCallback? onMuscles;
  final bool autofocus;

  /// Numéro d'ordre dans la pastille de sélection.
  final bool numbered;

  /// Champ de recherche en tête (masqué si la page a le sien).
  final bool search;
}

/// Liste filtrable autonome (bibliothèque, sélecteur).
class ExerciseBrowser extends StatefulWidget {
  const ExerciseBrowser({super.key, this.initial = const LibraryFilters(), this.config = const BrowserConfig()});

  final LibraryFilters initial;
  final BrowserConfig config;

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser> {
  late final _ctrl = ExerciseBrowserController(initial: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) => CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          ...exerciseBrowserSlivers(context, _ctrl, widget.config),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

/// Muscles attendus en premier pour une catégorie. Le catalogue range les
/// muscles principaux sans ordre d'importance : sans cela, un squat
/// s'afficherait « Fessiers » et des tractions en supination « Biceps ».
const _musclesDeCategorie = <String, List<Muscle>>{
  'pectoraux': [Muscle.pectoraux],
  'dos': [Muscle.grandDorsal, Muscle.trapezes, Muscle.rhomboides, Muscle.lombaires],
  'biceps': [Muscle.biceps],
  'triceps': [Muscle.triceps],
  'avantBras': [Muscle.avantBras],
  'jambes': [Muscle.quadriceps, Muscle.adducteurs, Muscle.abducteurs],
  'ischios': [Muscle.ischios],
  'fessiers': [Muscle.fessiers, Muscle.abducteurs],
  'mollets': [Muscle.mollets],
  'abdos': [Muscle.abdominaux, Muscle.obliques],
  'cou': [Muscle.cou],
};

/// Le muscle principal à nommer : celui de la catégorie s'il est ciblé en
/// principal, sinon le premier de la liste.
Muscle? musclePrincipalDe(Exercise e) {
  if (e.musclesPrincipaux.isEmpty) return null;
  for (final m in _musclesDeCategorie[e.categorie] ?? const <Muscle>[]) {
    if (e.musclesPrincipaux.contains(m)) return m;
  }
  return e.musclesPrincipaux.first;
}

/// Sous-titre d'un exercice dans la grille : son muscle principal.
String sousTitreExercice(Exercise e, {bool dejaPresent = false}) {
  final muscle = musclePrincipalDe(e)?.label ?? e.categorieLabel;
  if (dejaPresent) return 'Déjà ajouté · $muscle';
  return e.perso ? '$muscle · Perso' : muscle;
}

/// Les éléments de la liste en slivers, pour les poser aussi dans le volet
/// Exercices de l'onglet. À reconstruire quand [ctrl] change.
List<Widget> exerciseBrowserSlivers(BuildContext context, ExerciseBrowserController ctrl, BrowserConfig cfg) {
  final repo = context.watch<ExerciseRepo>();
  final sessions = context.watch<SessionRepo>();
  ctrl.syncHistory(sessions);
  final c = context.colors;
  final f = ctrl.filters;

  final header = <Widget>[
    if (cfg.search)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 12.5),
          child: RecherchePilule(
            controller: ctrl.query,
            autofocus: cfg.autofocus,
            hint: 'Rechercher un exercice',
            onChanged: (q) => ctrl.filters = ctrl.filters.copyWith(query: q),
          ),
        ),
      ),
    SliverToBoxAdapter(child: _Raccourcis(ctrl: ctrl)),
    SliverToBoxAdapter(child: _Filtres(ctrl: ctrl, repo: repo, cfg: cfg)),
    if (f.equipements.isNotEmpty || _categoriesHorsRaccourci(f) || _musclesHorsRaccourci(f)) SliverToBoxAdapter(child: _FiltresActifs(ctrl: ctrl)),
  ];

  if (!repo.loaded) {
    return [...header, const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 12), child: SkeletonList(count: 8)))];
  }
  if (repo.all.isEmpty) {
    return [
      ...header,
      SliverFillRemaining(
        hasScrollBody: false,
        child: Vide(
          titre: 'Catalogue introuvable',
          message: 'La liste des exercices n’a pas pu être chargée.',
          action: 'Réessayer',
          onAction: () => repo.load(),
        ),
      ),
    ];
  }

  final list = _index.filtrer(
    catalogue: repo.catalogue,
    perso: repo.perso,
    filtres: f,
    favoris: repo.favoris,
    recents: ctrl.recents,
    frequences: ctrl.freq,
  );

  final titre = switch (f.scope) {
    LibraryScope.tous => f.query.trim().isEmpty && f.actifs == 0 ? 'Tous les exercices' : 'Résultats',
    LibraryScope.favoris => 'Favoris',
    LibraryScope.recents => 'Récents',
    LibraryScope.effectues => 'Déjà effectués',
    LibraryScope.perso => 'Mes exercices',
  };
  final ligneTitre = SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(margeEcran, 10, margeEcran - 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: titre, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
                TextSpan(
                  text: '  ${Fmt.n(list.length, decimals: 0)}',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, fontWeight: FontWeight.w400, color: c.text2, fontFeatures: AppTokens.tabular),
                ),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BoutonNu(
            trait: Trait.trier,
            label: 'Trier',
            largeur: 45,
            onTap: () async {
              final r = await showPanneauBas<LibrarySort>(
                context,
                titre: 'Trier par',
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in LibrarySort.values)
                      ChoixPanneau(label: s.label, selected: s == f.sort, onTap: () => Navigator.pop(context, s)),
                  ],
                ),
              );
              if (r != null) ctrl.filters = ctrl.filters.copyWith(sort: r);
            },
          ),
          BoutonNu(
            trait: ctrl.grille ? Trait.liste : Trait.grille,
            label: ctrl.grille ? 'Afficher en liste' : 'Afficher en grille',
            largeur: 45,
            onTap: () => ctrl.grille = !ctrl.grille,
          ),
          if (cfg.onCreate != null)
            BoutonNu(trait: Trait.plus, label: 'Créer un exercice', largeur: 45, onTap: () => cfg.onCreate!(f.query.trim())),
        ],
      ),
    ),
  );

  if (list.isEmpty) {
    return [...header, ligneTitre, SliverFillRemaining(hasScrollBody: false, child: _vide(ctrl, cfg))];
  }

  final sel = cfg.selection;
  void apercu(Exercise e) => showExerciseApercu(context, e, onFiche: cfg.onOpen == null && cfg.onInfo == null ? null : () => (cfg.onInfo ?? cfg.onOpen)!(e));
  void toucher(Exercise e) => sel != null ? cfg.onToggle?.call(e) : (cfg.onOpen != null ? cfg.onOpen!(e) : apercu(e));
  // Le « ? » : la fiche en mode sélection, l'aperçu animé sinon.
  void aide(Exercise e) => sel != null && cfg.onInfo != null ? cfg.onInfo!(e) : apercu(e);

  if (ctrl.grille) {
    return [
      ...header,
      ligneTitre,
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: margeEcran),
        sliver: SliverLayoutBuilder(builder: (context, contraintes) {
          const ecart = 10.0;
          final colonnes = (contraintes.crossAxisExtent / 230).floor().clamp(2, 6);
          final largeur = (contraintes.crossAxisExtent - ecart * (colonnes - 1)) / colonnes;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              mainAxisSpacing: ecart,
              crossAxisSpacing: ecart,
              mainAxisExtent: CarteExercice.hauteurPour(largeur, MediaQuery.textScalerOf(context)),
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              final pos = sel?.indexOf(e.id) ?? -1;
              return CarteExercice(
                key: ValueKey(e.id),
                exercise: e,
                sousTitre: sousTitreExercice(e, dejaPresent: cfg.dejaPresents.contains(e.id)),
                favori: repo.isFavori(e.id),
                onFavori: () => repo.toggleFavori(e.id),
                onAide: () => aide(e),
                onTap: () => toucher(e),
                choisi: sel != null ? pos >= 0 : cfg.selectedId == e.id,
                numero: sel != null && cfg.numbered && pos >= 0 ? pos + 1 : null,
                coche: sel != null && pos >= 0,
              );
            },
          );
        }),
      ),
    ];
  }

  return [
    ...header,
    ligneTitre,
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: margeEcran),
      sliver: SliverList.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final e = list[i];
          final n = ctrl.freq[e.id];
          var sous = sousTitreExercice(e, dejaPresent: cfg.dejaPresents.contains(e.id));
          if (n != null && n > 0 && !cfg.dejaPresents.contains(e.id)) sous = '$sous · $n fois';
          final pos = sel?.indexOf(e.id) ?? -1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: LigneExercice(
              key: ValueKey(e.id),
              exercise: e,
              sousTitre: sous,
              choisi: sel != null ? pos >= 0 : cfg.selectedId == e.id,
              onTap: () => toucher(e),
              onLongPress: sel != null ? () => aide(e) : () => repo.toggleFavori(e.id),
              fin: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (repo.isFavori(e.id)) const Padding(padding: EdgeInsets.only(right: 4), child: Signet(plein: true, taille: 20)),
                  if (sel != null) ...[
                    _Aide(onTap: () => aide(e)),
                    SelectionCheck(on: pos >= 0, label: cfg.numbered && pos >= 0 ? '${pos + 1}' : null),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  ];
}

bool _estRaccourci(LibraryFilters f) =>
    f.muscles.isEmpty || MuscleGroup.all.any((g) => g.muscles.length == f.muscles.length && g.muscles.containsAll(f.muscles));

bool _musclesHorsRaccourci(LibraryFilters f) => !_estRaccourci(f);

/// Une seule catégorie, celle d'une tuile du haut : la tuile allumée suffit.
bool _categoriesHorsRaccourci(LibraryFilters f) =>
    f.categories.isNotEmpty && !(f.categories.length == 1 && CategorieRaccourci.all.any((r) => r.categorie == f.categories.first));

Widget _vide(ExerciseBrowserController ctrl, BrowserConfig cfg) {
  final f = ctrl.filters;
  final q = f.query.trim();
  final filtres = f.actifs > 0 || q.isNotEmpty;
  if (!filtres) {
    switch (f.scope) {
      case LibraryScope.favoris:
        return const Vide(trait: Trait.signet, titre: 'Aucun favori', message: 'Touche le signet d’un exercice pour le retrouver ici.');
      case LibraryScope.perso:
        return Vide(
          trait: Trait.personne,
          titre: 'Aucun exercice perso',
          message: 'Crée tes propres exercices avec leurs muscles, leur matériel et une photo.',
          action: cfg.onCreate == null ? null : 'Créer un exercice',
          onAction: cfg.onCreate == null ? null : () => cfg.onCreate!(''),
        );
      case LibraryScope.recents:
        return const Vide(trait: Trait.horlogeGrande, titre: 'Rien de récent', message: 'Les exercices de tes dernières séances apparaîtront ici.');
      case LibraryScope.effectues:
        return const Vide(trait: Trait.coche, titre: 'Aucun exercice effectué', message: 'Les exercices de ton historique apparaîtront ici, dès leur première série validée.');
      case LibraryScope.tous:
        break;
    }
  }
  return Vide(
    trait: Trait.loupe,
    titre: q.isEmpty ? 'Aucun exercice' : 'Aucun résultat pour « $q »',
    message: 'Essaie un autre mot (français ou anglais) ou retire un filtre.',
    action: 'Effacer la recherche et les filtres',
    onAction: ctrl.clearAll,
  );
}

class _Aide extends StatelessWidget {
  const _Aide({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Voir la fiche',
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 40,
            height: 44,
            child: Center(
              child: Text('?', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.text2)),
            ),
          ),
        ),
      );
}

/// Carte d'exercice de la grille : image sur une tuile grise, signet en
/// haut à gauche, « ? » en haut à droite, nom et muscle dessous.
class CarteExercice extends StatelessWidget {
  const CarteExercice({
    super.key,
    required this.exercise,
    required this.sousTitre,
    this.favori = false,
    this.onFavori,
    this.onAide,
    this.onTap,
    this.choisi = false,
    this.coche = false,
    this.numero,
  });

  final Exercise exercise;
  final String sousTitre;
  final bool favori;
  final VoidCallback? onFavori;
  final VoidCallback? onAide;
  final VoidCallback? onTap;

  /// Cadre blanc (sélection, fiche ouverte à côté).
  final bool choisi;

  /// Pastille blanche à la place du « ? » (sélection multiple).
  final bool coche;
  final int? numero;

  /// Hauteur d'une carte selon sa largeur : la tuile est carrée.
  /// Les deux lignes de texte grandissent avec la taille de texte du téléphone.
  static double hauteurPour(double largeur, [TextScaler echelle = TextScaler.noScaling]) => largeur + 15.8 + echelle.scale(40.2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = poseDe(exercise);
    final gris = c.text2;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17.5),
        side: choisi ? BorderSide(color: c.text, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12.5)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: src == null
                            ? Center(child: TraitIcone(AppIcone.haltere, size: 44, color: c.text3))
                            : mediaImage(src, cacheWidth: 540, error: (_) => Center(child: TraitIcone(AppIcone.haltere, size: 44, color: c.text3))),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Tooltip(
                          message: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                          child: InkResponse(
                            onTap: onFavori,
                            radius: 24,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(7.5, 7.5, 14, 14),
                              child: Signet(plein: favori, taille: 20, couleur: favori ? c.text : gris),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: coche
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle),
                                  child: numero == null
                                      ? IconeTrait(Trait.coche, size: 17, color: c.onBouton)
                                      : Text('$numero', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.5, fontWeight: FontWeight.w800, color: c.onBouton)),
                                ),
                              )
                            : Tooltip(
                                message: 'Aperçu',
                                child: InkResponse(
                                  onTap: onAide,
                                  radius: 24,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 6, 11, 14),
                                    child: Text('?', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, height: 1.35, fontWeight: FontWeight.w600, color: gris)),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                exercise.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, height: 1.35, fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                sousTitre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.8, height: 1.35, fontWeight: FontWeight.w400, color: c.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne d'un exercice : tuile, nom, détail. En carte grise sur demande.
class LigneExercice extends StatelessWidget {
  const LigneExercice({
    super.key,
    required this.exercise,
    required this.sousTitre,
    this.onTap,
    this.onLongPress,
    this.fin,
    this.carte = false,
    this.choisi = false,
  });

  final Exercise exercise;
  final String sousTitre;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? fin;
  final bool carte;
  final bool choisi;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: carte ? c.surface : (choisi ? c.surface : Colors.transparent),
      borderRadius: BorderRadius.circular(17.5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(carte ? 10 : 6),
          child: Row(
            children: [
              TuileExercice(exercise, taille: carte ? 65 : 56),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exercise.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.ligne(context)),
                    Text(sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context).copyWith(fontSize: 13.75)),
                  ],
                ),
              ),
              ?fin,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile d'un raccourci : une vignette carrée, cerclée de blanc une fois
/// choisie, et son libellé dessous.
class TuileRaccourci extends StatelessWidget {
  const TuileRaccourci({super.key, required this.label, required this.choisi, required this.onTap, required this.child});
  final String label;
  final bool choisi;
  final VoidCallback onTap;
  final Widget child;

  /// Hauteur de la tuile ; le libellé suit la taille de texte du téléphone.
  static double hauteur(BuildContext context) => 67.5 + 5 + MediaQuery.textScalerOf(context).scale(18);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: choisi,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 67.5,
              height: 67.5,
              clipBehavior: Clip.antiAlias,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: choisi ? Border.all(color: c.text, width: 1.9) : null,
              ),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(15)),
              child: child,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, height: 1.35, fontWeight: choisi ? FontWeight.w600 : FontWeight.w400, color: choisi ? c.text : c.text2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le personnage resserré sur un groupe de muscles, le groupe allumé.
class VignetteGroupe extends StatelessWidget {
  const VignetteGroupe(this.groupe, {super.key});
  final MuscleGroup groupe;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        // Les jambes sont resserrées sur le muscle visé.
        child: Transform.scale(
          scale: groupe.zoom,
          alignment: Alignment(0, groupe.centreY),
          child: CorpsColore(view: groupe.view, framing: groupe.framing, couleurs: allumer(groupe.muscles)),
        ),
      );
}

/// Rangée du haut : Favoris, les raccourcis par muscle sur le buste du
/// personnage, puis le cardio et les étirements.
class _Raccourcis extends StatelessWidget {
  const _Raccourcis({required this.ctrl});
  final ExerciseBrowserController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = ctrl.filters;
    final favoris = f.scope == LibraryScope.favoris;
    Widget tuile({required String label, required bool choisi, required VoidCallback onTap, required Widget child}) => Padding(
          padding: const EdgeInsets.only(right: 12.5),
          child: TuileRaccourci(label: label, choisi: choisi, onTap: onTap, child: child),
        );
    return SizedBox(
      height: TuileRaccourci.hauteur(context) + 12.5,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran - 12.5, 12.5),
        children: [
          tuile(
            label: 'Favoris',
            choisi: favoris,
            onTap: () => ctrl.filters = f.copyWith(scope: favoris ? LibraryScope.tous : LibraryScope.favoris),
            child: Center(child: Signet(plein: favoris, taille: 30)),
          ),
          for (final g in MuscleGroup.all)
            () {
              final on = f.muscles.length == g.muscles.length && f.muscles.containsAll(g.muscles);
              return tuile(
                label: g.label,
                choisi: on,
                // Un muscle remplace le cardio ou les étirements, jamais les deux à la fois.
                onTap: () => ctrl.filters = f.copyWith(
                  muscles: on ? {} : g.muscles,
                  principauxSeulement: !on,
                  categories: _categoriesHorsRaccourci(f) ? null : {},
                ),
                child: VignetteGroupe(g),
              );
            }(),
          for (final r in CategorieRaccourci.all)
            () {
              final on = f.categories.length == 1 && f.categories.first == r.categorie;
              return tuile(
                label: r.label,
                choisi: on,
                onTap: () => ctrl.filters = f.copyWith(
                  categories: on ? {} : {r.categorie},
                  muscles: _estRaccourci(f) ? {} : null,
                ),
                child: mediaImage(r.pose, cacheWidth: 270, error: (_) => Center(child: TraitIcone(AppIcone.haltere, size: 30, color: c.text3))),
              );
            }(),
        ],
      ),
    );
  }
}

/// Rangée de filtres : Récents, Effectués, Matériel, Mes exercices. Les muscles et les
/// catégories se choisissent par les tuiles du haut.
class _Filtres extends StatelessWidget {
  const _Filtres({required this.ctrl, required this.repo, required this.cfg});

  final ExerciseBrowserController ctrl;
  final ExerciseRepo repo;
  final BrowserConfig cfg;

  /// « Matériel » : un panneau du bas, une grille de familles en images.
  /// On en coche plusieurs, puis on valide.
  Future<void> _materiel(BuildContext context) async {
    final counts = <String, int>{};
    // Un exercice compte sous chaque matériel qu'il demande.
    for (final e in repo.all) {
      for (final m in e.materiels) {
        counts[m] = (counts[m] ?? 0) + 1;
      }
    }
    final r = await ouvrirFiltreMateriel(
      context,
      counts: counts,
      choisis: ctrl.filters.equipements,
      compter: (sel) => _index
          .filtrer(
            catalogue: repo.catalogue,
            perso: repo.perso,
            filtres: ctrl.filters.copyWith(equipements: sel),
            favoris: repo.favoris,
            recents: ctrl.recents,
            frequences: ctrl.freq,
          )
          .length,
    );
    if (r != null) ctrl.filters = ctrl.filters.copyWith(equipements: r);
  }

  @override
  Widget build(BuildContext context) {
    final f = ctrl.filters;
    void scope(LibraryScope s) => ctrl.filters = f.copyWith(scope: f.scope == s ? LibraryScope.tous : s);
    Widget puce(Widget p) => Padding(padding: const EdgeInsets.only(right: 10), child: Center(child: p));
    return SizedBox(
      height: 45 + 25,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran - 10, 12.5),
        children: [
          puce(PuceAction(trait: Trait.horlogeGrande, label: 'Récents', active: f.scope == LibraryScope.recents, onTap: () => scope(LibraryScope.recents))),
          puce(PuceAction(trait: Trait.coche, label: 'Effectués', active: f.scope == LibraryScope.effectues, onTap: () => scope(LibraryScope.effectues))),
          puce(PuceAction(trait: Trait.grille, label: 'Matériel', active: f.equipements.isNotEmpty, onTap: () => _materiel(context))),
          puce(PuceAction(trait: Trait.personne, label: 'Mes exercices', active: f.scope == LibraryScope.perso, onTap: () => scope(LibraryScope.perso))),
        ],
      ),
    );
  }
}

/// Filtres en service (muscles, matériel, catégorie), retirables un par un.
class _FiltresActifs extends StatelessWidget {
  const _FiltresActifs({required this.ctrl});
  final ExerciseBrowserController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = ctrl.filters;
    void poser(LibraryFilters n) => ctrl.filters = n;
    Widget puce(String label, VoidCallback retirer) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            button: true,
            label: 'Retirer le filtre $label',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: retirer,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                decoration: BoxDecoration(color: c.surface2, borderRadius: AppTokens.radiusPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text)),
                    const SizedBox(width: 5),
                    IconeTrait(Trait.fermer, size: 14, color: c.text2),
                  ],
                ),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 8),
        children: [
          if (_musclesHorsRaccourci(f))
            for (final m in f.muscles) puce(m.label, () => poser(f.copyWith(muscles: {...f.muscles}..remove(m)))),
          for (final e in f.equipements) puce(Equipements.label(e), () => poser(f.copyWith(equipements: {...f.equipements}..remove(e)))),
          if (_categoriesHorsRaccourci(f))
            for (final k in f.categories) puce(Categories.label(k), () => poser(f.copyWith(categories: {...f.categories}..remove(k)))),
        ],
      ),
    );
  }
}

/// Familles de matériel, dans l'ordre de la grille : (clé du catalogue,
/// image). « Poids du corps » montre le personnage du pack.
const famillesMateriel = <(String, String)>[
  ('barre', 'assets/exercises/materiel/barre.webp'),
  ('halteres', 'assets/exercises/materiel/halteres.webp'),
  ('poids du corps', 'assets/exercises/poses/push-up-start.webp'),
  ('kettlebell', 'assets/exercises/materiel/kettlebell.webp'),
  ('barre ez', 'assets/exercises/materiel/barre-ez.webp'),
  ('barre trapeze', 'assets/exercises/materiel/barre-trapeze.webp'),
  ('poulie', 'assets/exercises/materiel/poulie.webp'),
  ('machine', 'assets/exercises/materiel/machine.webp'),
  ('presse', 'assets/exercises/materiel/presse.webp'),
  ('smith', 'assets/exercises/materiel/smith.webp'),
  ('barre de traction', 'assets/exercises/materiel/barre-de-traction.webp'),
  ('banc', 'assets/exercises/materiel/banc.webp'),
  ('disque', 'assets/exercises/materiel/disque.webp'),
  ('elastique', 'assets/exercises/materiel/elastique.webp'),
  ('mini-bande', 'assets/exercises/materiel/mini-bande.webp'),
  ('suspension', 'assets/exercises/materiel/suspension.webp'),
  ('medecine-ball', 'assets/exercises/materiel/medecine-ball.webp'),
  ('ballon', 'assets/exercises/materiel/ballon.webp'),
  ('bosu', 'assets/exercises/materiel/bosu.webp'),
  ('corde ondulatoire', 'assets/exercises/materiel/corde-ondulatoire.webp'),
  ('roue abdominale', 'assets/exercises/materiel/roue-abdominale.webp'),
  ('corde a sauter', 'assets/exercises/materiel/corde-a-sauter.webp'),
  ('traineau', 'assets/exercises/materiel/traineau.webp'),
  ('cardio', 'assets/exercises/materiel/cardio.webp'),
  ('autre', 'assets/exercises/materiel/autre.webp'),
];

/// Ouvre le filtre par matériel dans un panneau du bas. Rend l'ensemble des
/// familles retenues (vide : tout afficher), ou null si le panneau est fermé
/// sans valider.
Future<Set<String>?> ouvrirFiltreMateriel(
  BuildContext context, {
  required Map<String, int> counts,
  required Set<String> choisis,
  required int Function(Set<String>) compter,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => FiltreMateriel(counts: counts, choisis: choisis, compter: compter),
  );
}

/// Le filtre par matériel : une grille de ronds, plusieurs choix possibles,
/// « Tout effacer » et « Afficher N exercices » en bas.
class FiltreMateriel extends StatefulWidget {
  const FiltreMateriel({super.key, required this.counts, required this.choisis, required this.compter});

  /// Nombre d'exercices par famille ; une famille absente n'est pas montrée.
  final Map<String, int> counts;
  final Set<String> choisis;

  /// Nombre d'exercices que donnerait ce choix, les autres filtres gardés.
  final int Function(Set<String>) compter;

  @override
  State<FiltreMateriel> createState() => _FiltreMaterielState();
}

class _FiltreMaterielState extends State<FiltreMateriel> {
  late final Set<String> _sel = {...widget.choisis};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    final connues = {for (final f in famillesMateriel) f.$1};
    final familles = [
      for (final f in famillesMateriel)
        if ((widget.counts[f.$1] ?? 0) > 0 || _sel.contains(f.$1)) f,
      // Une famille du catalogue sans image : l'haltère au trait.
      for (final k in widget.counts.keys.where((k) => !connues.contains(k))) (k, ''),
    ];
    final n = widget.compter(_sel);
    TextStyle txt(double taille, FontWeight graisse, Color couleur) =>
        TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, height: 1.25, fontWeight: graisse, color: couleur);
    // Dans un panneau du bas, la marge de la barre d'état n'est plus dans le
    // MediaQuery : on la relit sur la fenêtre. Le panneau s'arrête nettement
    // sous la barre d'état, la page reste visible derrière ses coins arrondis.
    final barreEtat = MediaQueryData.fromView(View.of(context)).padding.top;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height - barreEtat - 28, maxWidth: 640),
      child: Material(
        color: c.surface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 20, 12),
                child: Row(
                  children: [
                    BoutonNu(trait: Trait.fermer, label: 'Fermer', largeur: 46, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Filtrer', style: txt(22, FontWeight.w800, c.text))),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: PanneauBas.filet),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    const marge = 16.0;
                    final colonnes = ((box.maxWidth - marge * 2) / 92).floor().clamp(3, 6);
                    final cote = (box.maxWidth - marge * 2) / colonnes;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(marge + 5, 20, marge, 12),
                            child: Text('Matériel', style: txt(17, FontWeight.w600, c.text)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(marge, 0, marge, 20),
                          sliver: SliverGrid.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: colonnes,
                              mainAxisExtent: cote + MediaQuery.textScalerOf(context).scale(46),
                            ),
                            itemCount: familles.length,
                            itemBuilder: (context, i) {
                              final (cle, image) = familles[i];
                              final on = _sel.contains(cle);
                              // Dès qu'un choix est fait, les autres s'effacent un peu.
                              final efface = _sel.isNotEmpty && !on;
                              Widget secours() => Center(child: TraitIcone(AppIcone.haltere, size: 30, color: c.text3));
                              return Semantics(
                                button: true,
                                selected: on,
                                label: '${Equipements.label(cle)}, ${Fmt.pluriel(widget.counts[cle] ?? 0, 'exercice')}',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => on ? _sel.remove(cle) : _sel.add(cle)),
                                  child: AnimatedOpacity(
                                    duration: AppTokens.fast,
                                    opacity: efface ? 0.45 : 1,
                                    child: Column(
                                      children: [
                                        AnimatedContainer(
                                          duration: AppTokens.fast,
                                          width: cote - 10,
                                          height: cote - 10,
                                          padding: EdgeInsets.all((cote - 10) * 0.17),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: c.surface3,
                                            border: Border.all(color: on ? c.text : AppTokens.frame, width: on ? 2 : 1),
                                          ),
                                          child: image.isEmpty
                                              ? secours()
                                              : Image.asset(image, fit: BoxFit.contain, cacheWidth: 240, errorBuilder: (_, _, _) => secours()),
                                        ),
                                        const SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: Text(
                                            Equipements.label(cle),
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: txt(13, on ? FontWeight.w800 : FontWeight.w500, c.text),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1, thickness: 1, color: PanneauBas.filet),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _sel.isEmpty ? null : () => setState(_sel.clear),
                      child: Text('Tout effacer', style: txt(15.5, FontWeight.w700, _sel.isEmpty ? c.text3 : c.text)),
                    ),
                    const Spacer(),
                    Material(
                      color: c.bouton,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, {..._sel}),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          alignment: Alignment.center,
                          child: Text(
                            n == 0 ? 'Aucun exercice' : 'Afficher ${Fmt.pluriel(n, 'exercice')}',
                            maxLines: 1,
                            style: txt(16, FontWeight.w700, c.onBouton),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
