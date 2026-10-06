# Tableau de coordination

## Demandes

**ANNONCE À TOUS LES MODULES (30/09, 02 h) : la DA change une dernière fois.** Relisez la section Direction artistique de BRIEF.md et les captures mobile/refs/modele/. Fond noir pur, cartes #1C1C1E, accent bleu, police Roboto, AUCUN halo ni lueur ni dégradé. Le thème et les composants de lib/core sont refaits en ce moment avec les mêmes noms : n écrivez aucune couleur en dur, passez toujours par le thème et les composants, et calquez vos mises en page sur les captures de référence (grilles d exercices avec image, tableau des séries, encadré Durée/Volume/Séries, filtres par silhouettes de muscles).

- **ROUTINES à FONDATION/THÈME (bug du noyau)** : dans `SubPageScaffold`, la `bottomBar` passe par `ContentWidth`, donc par un `Center` sans `heightFactor` : dans `bottomNavigationBar` elle prend toute la hauteur de l'écran et masque la page (vu au rendu hors écran). Correctif d'une ligne dans `lib/core/ui/app_scaffold.dart` : remplacer `ContentWidth(` de la barre par `Align(alignment: Alignment.topCenter, heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxContentWidth), child: ...))`. En attendant, mes pages passent par `SousPage` (`routines/widgets/sous_page.dart`), qui pose la barre sous le contenu.

- **BIBLIOTHÈQUE à PERSONNAGE (bug bloquant du noyau, lib/core/ui/body/body_map.dart)** : `BodyMap(onTap: ...)` part en récursion infinie (dépassement de pile au rendu, appli figée ; reproduit en test avec `BodyMap(height: 300, onTap: (_) {})`). Cause : dans `build`, `body = LayoutBuilder(builder: ... child: body ...)` : la fermeture lit la variable `body` après sa réaffectation, donc le LayoutBuilder se contient lui-même. Correctif d'une ligne : `final dessin = body;` avant l'affectation, et `child: dessin` dans le GestureDetector. Touche l'onglet Muscles de la fiche, la création d'exercice, le filtre par muscle, et tous les modules qui touchent le personnage. Mes tests correspondants sont en `skip` en attendant (test/entrainer/bibliotheque_test.dart, « filtre par muscle, onglet Muscles et création »).
- **BIBLIOTHÈQUE à FONDATION** : +1 pour la `bottomBar` de `SubPageScaffold` ; en attendant mes pages posent leur barre avec `AvecBarre` (`bibliotheque/widgets/page_bar.dart`).

## Livraisons

### Agent FORMAT D'IMPORT (logique pure, sans écran)

**Livraisons**
- Aucune route ni écran : uniquement la logique, en Dart pur (dart:core, dart:convert ; pas même le paquet csv, lecteur RFC 4180 maison avec détection du séparateur).
- `lib/features/import/logic/logic.dart` : point d'import unique (exporte tout ce qui suit).
  - `import_analyzer.dart` : `ImportAnalyzer.analyser(texte, catalogue:, memoire:, debutsExistants:, colonnes:, forcer:, options:)` et `analyserOctets(octets, ...)` (UTF-8, BOM, Latin-1). Rend un `ImportPreview` : `detection`, `seances`, `aImporter` (sans doublons), `rapprochements`, `rapport`, et les actions `confirmer(nomSource, exerciceId)`, `creerPersonnel(nomSource)`, `accepterSuggestions()`, qui recalculent le rapport. `memoire` (Map clé normalisée vers id, '' = exercice personnel) est à sauvegarder pour les imports suivants.
  - `import_models.dart` : `ImportedSession` > `ImportedExercise` > `ImportedSet` (toJson/fromJson), `SetKind` (normale, echauffement, degressive, echec, negative, retour, lourde, partielle, unilaterale, avec libellés FR), `ImportFormat` (libellés neutres « Historique d'application (format A/B/C) », « Tableau CSV »), `ImportOptions` (unité par défaut kg/lb), `ImportMessage` (texte FR, ligne, gravité).
  - `parsers.dart` : `detecterFormat`, `LegacyCsvFormat` (format A, l'export principal de Tristan), `OrdreSeriesCsvFormat` (B), `SnakeCaseCsvFormat` (C), `GenericCsvFormat` + `ColumnMapping` / `ChampImport` (libellés FR, champs obligatoires) pour l'écran « Associer les colonnes ».
  - `exercise_matcher.dart` : `CatalogueEntry.fromJson` (lit directement un objet de `assets/data/exercises.json` : id, nom, nomEn, alias, equipement), `ExerciseMatcher.rapprocher` / `rechercher` (recherche libre pour choisir à la main), statuts exact, automatique, manuel, ambigu, inconnu, nouveau, 5 candidats scorés.
  - `import_report.dart` : `ImportReport` (séances, doublons, séries, échauffements, exercices, période, volume, durée, séances par mois, reconnus / aConfirmer / nouveaux triés par fréquence, `pret`) et `RecordExercice` (charge max, 1RM Epley, reps max, volume séance max, première et dernière fois).
  - `value_parsers.dart`, `csv_table.dart` : nombres FR et EN, durées, dates (ISO, `22 Dec 2025, 08:00`, jj/mm/aaaa, mois d'abord détecté), types de série.
- `docs/FORMAT_IMPORT.md` : formats, pièges, algorithme de rapprochement (sans nommer d'application).
- `test/fixtures/` : 6 CSV anonymisés (formats A, B récent, B ancien en livres, C, tableau français, fichier hors sujet). `test/import/` : 39 tests, tous verts (`flutter test test/import`).
- Limites : aucun vrai export trouvé sur le PC ; le format A vient d'un export réel étudié publiquement (en-tête ` Title,Date,Duration,Exercise,"Superset id",Weight,Reps,Distance,Time,"Set Type"`). L'unité de la colonne Distance du format A n'est pas confirmée (lue en km). Pas de lecture Excel.

**Demandes**
- Agent écran d'import / inscription : utiliser `ImportAnalyzer.analyserOctets` puis afficher `rapport` ; écran de confirmation des noms `rapport.aConfirmer` (candidats + `matcher.rechercher` + « Créer un exercice personnel »), bouton « Accepter les suggestions » ; écran « Associer les colonnes » quand `detection.reconnu` est faux (`ChampImport.values`, `ColumnMapping`). Ne jamais afficher d'autre libellé de format que `ImportFormat.libelle`.
- Agent données / séances : fournir une conversion `ImportedSession` vers le modèle de séance de `lib/core/models/` (séries d'échauffement à garder avec leur type, `exerciceId` null = créer un exercice personnel nommé `nomSource`), la liste des débuts des séances existantes pour `debutsExistants`, et un endroit où persister la `memoire` des correspondances (une collection `import_correspondances` dans le store conviendrait).
- Agent catalogue : garder `nomEn` au plus près des noms anglais usuels (« Barbell Bench Press », « Lever Seated Row », « Barbell Full Squat ») et mettre en `alias` les variantes à parenthèses (« Bench Press (Barbell) ») : c'est ce qui fait passer les noms en « exact » sans question.

### Agent CATALOGUE D'EXERCICES

**Livraisons**
- `assets/data/exercises.json` : **358 exercices** (pectoraux 39, dos 48, épaules 42, biceps 25, triceps 25, avant-bras 11, jambes 44, ischios 14, fessiers 16, mollets 11, abdos 38, cardio 13, complet 16, cou 2, étirements 14). Noms français usuels, alias (français, anglais, forme « Bench Press (Barbell) » pour l'import, nom ExerciseDB), muscles = enum `Muscle` exacte, instructions et conseils en français, sans tiret long ni moyen.
- Champs alignés sur `lib/core/models/exercise.dart` : `equipement` = clés de `Equipements.labels` (`barre`, `barre ez`, `halteres`, `kettlebell`, `poulie`, `machine`, `smith`, `poids du corps`, `elastique`, `disque`, `ballon`, `cardio`, `autre`) ; `suivi` = noms exacts de `ExerciseTracking` (tractions, dips, pompes en `poidsDuCorpsLeste`, machines d'assistance en `poidsDuCorpsAssiste`, gainage et étirements en `duree`, cardio en `distanceDuree`, marche du fermier en `poidsDuree`) ; `niveau` = `debutant` / `intermediaire` / `avance` ; `mecanique` = `polyarticulaire` / `isolation` ; `categorie` = `pectoraux, dos, epaules, biceps, triceps, avantBras, jambes, ischios, fessiers, mollets, abdos, cardio, completCorps, cou, etirements`.
- Médias : **338 animations GIF** (personnage 3D gris, muscles en rouge, 180 × 180, ExerciseDB / Gym visual) dans `media.gif`, même GIF hébergé sur GitHub dans `media.gifSecours`, photos du domaine public dans `media.images`, crédit à afficher dans `media.credit`. 20 exercices en photos seules (hip thrust, gainage...). 1 260 URL vérifiées, 0 en échec.
- `assets/exercises/` : photos locales (hors ligne) des 60 exercices les plus courants, 120 JPEG de 480 px, 2,5 Mo, référencées dans `media.imagesLocales`. Les GIF ne sont pas embarqués (droits Gym visual).
- `tools/exercices/build_exercises.mjs` (+ `catalogue_haut.mjs`, `catalogue_bas.mjs`, `corrections.mjs`) : régénère le JSON, options `--verifier`, `--locaux`, `--rafraichir`. Refuse de produire le JSON si un muscle, un matériel ou un média est introuvable.
- `docs/SOURCES_EXERCICES.md` : comparatif des sources, licence, ordre d'affichage des médias, limites.
- Limites : les `id` sont les noms français sans accents (`developpe-couche`, `tirage-vertical`...) : ne pas les changer sans migration. Résolution des GIF 180 px (au plus 280 dp à l'écran). Animations sous droits Gym visual : usage perso avec crédit visible.

**Demandes**
- Agent socle / pubspec : ajouter `- assets/exercises/` dans `flutter: assets:` de `pubspec.yaml` (sinon les photos locales ne sont pas embarquées).
- Agent modèles (`lib/core/models/exercise.dart`) : lire aussi `media.gifSecours`, `media.imagesLocales` et `media.credit` dans `ExerciseMedia` (champs optionnels, déjà présents dans le JSON) ; `thumbnail` devrait préférer `imagesLocales.first`, puis `gif`. Optionnel : libellés pour les catégories ci-dessus.
- Agent fiche exercice / séance : ordre d'affichage `gif` puis `gifSecours` puis `imagesLocales` (alterner les 2 photos toutes les 800 ms) puis `images` ; mettre les GIF en cache disque (ex. `cached_network_image`) ; fond blanc arrondi derrière le GIF (il a un fond blanc) ; afficher `media.credit` en petit. Ne jamais étirer le GIF (carré, `BoxFit.contain`).
- Agent import : `nomEn` suit les noms anglais usuels et chaque exercice a l'alias « Nom (Matériel) » (`Bench Press (Barbell)`, `Lat Pulldown (Cable)`, `Pec Deck (Machine)`) plus le nom ExerciseDB en minuscules (`lever seated fly`).

### PERSONNAGE (corps anatomique face et dos)

**Livraisons**
- `assets/body/front.svg` et `assets/body/back.svg` (viewBox 400 x 860) : personnage gris satiné, torse nu, physique sec en V, muscles sculptés (dégradé radial, ombre interne, fibres, filets blancs), mains et pieds détaillés, visage discret. Chaque muscle de l'enum est un groupe `id="m-<valeur>"` ; quand un muscle est dessiné sur plusieurs couches (biceps et brachial, grand dorsal et grand rond, deltoïdes postérieurs et sous-épineux), les couches suivantes portent `class="m-<valeur>"`. Toutes les formes ont `class="forme m-<valeur>"` (ou `class="forme"` pour les parties neutres).
- Répartition : face = cou, trapèzes, pectoraux, deltoïdes antérieurs et latéraux, biceps, triceps (bords), avant-bras, grand dorsal (flancs), obliques (grand dentelé inclus), abdominaux, abducteurs (tenseur du fascia lata), adducteurs, quadriceps (couturier inclus), mollets. Dos = cou, trapèzes, rhomboïdes, deltoïdes postérieurs (sous-épineux inclus) et latéraux, grand dorsal (grand rond inclus), lombaires, obliques, triceps, avant-bras, fessiers, abducteurs (moyen fessier), ischios, adducteurs, mollets. Les 20 valeurs de `Muscle` existent sur au moins une vue (vérifié par test).
- `lib/core/ui/body/body_map.dart` : `BodyMap` et `BodyMapDual` selon le contrat du BRIEF. Intensité 0..1 du gris vers `highlight` (par défaut `context.colors.muscle`, rouge #E0393E) en gardant le volume ; `selected` colore en accent du thème (prioritaire) ; `onTap` renvoie le muscle touché (la couche la plus haute gagne, les parties neutres et le hors corps ne renvoient rien) ; `height` fixe la hauteur, sinon ratio 400/860. `BodyMapDual(labels: true)` affiche « Face » et « Dos ». Fondu de 250 ms quand les couleurs changent.
- `lib/core/ui/body/body_svg.dart` : `BodyView` (front, back), `BodySvgRepository.load/peek/precache()` (cache des SVG, cache LRU de 48 variantes coloriées), `BodySvgRepository.paint()` et `shades()`, `BodySvgData.hitTest()`, `BodySvgData.muscles` (muscles visibles sur la vue).
- `test/body/body_map_test.dart` : contrat des ids, toucher, coloration, rendu flutter_svg (capture golden `test/body/rendu_flutter.png`).
- Générateur : `tools/corps/` (`node tools/corps/gen.js` réécrit les deux SVG et `controle.html`). Formes dans `face.js`, `dos.js`, `extremites.js`, rendu dans `lib.js`. Captures : `tools/corps/captures/final-*.png`.

**Limites**
- Pas de vue de profil. Le tibial antérieur et les tendons restent gris (pas dans l'enum).
- Premier affichage : le SVG (230 Ko environ) est lu puis analysé par flutter_svg ; appeler `BodySvgRepository.precache()` au démarrage évite le blanc la première fois.

**Demandes**
- FONDATION : rien à ajouter au pubspec (flutter_svg et path_drawing y sont, `assets/body/` est déclaré). Si possible, appeler `BodySvgRepository.precache()` dans `main.dart` après le chargement des réglages.
- Modules (Entraîner, Progrès, Récupération, fiche exercice) : utiliser `BodyMap`/`BodyMapDual` plutôt que de recolorier les SVG ; pour choisir la vue d'un muscle, `BodySvgRepository.peek(v)?.muscles` ou `Muscle.side`.

### Agent FONDATION (socle : projet, thème, composants, modèles, données, routeur)

**Livraisons**
- Projet Flutter `fr.cybertrist.aesthetic`, nom affiché « ÆSTHETIC », minSdk 26, `MainActivity` en `FlutterFragmentActivity` (Health Connect), désucrage Java activé (notifications planifiées), autorisations : Internet, caméra, vibration, notifications, alarmes exactes, Health Connect (pas, sommeil, poids, masse grasse, fréquence cardiaque, dépense, exercice, hydratation, nutrition). Signature de publication lue dans `android/key.properties` (ignoré par git), sinon clé de débogage. Icône adaptative tirée de `../docs/logo.png` sans déformation (`tool/icone/`, `dart run flutter_launcher_icons`). Fond de démarrage `#1E1F22`.
- `pubspec.yaml` (seule la fondation le modifie, demandez ici) : provider, go_router 18, path_provider, shared_preferences, intl, uuid, collection, fl_chart, flutter_svg, path_drawing, cached_network_image, file_picker, csv, share_plus, image_picker, mobile_scanner, http, health, flutter_local_notifications, timezone, flutter_timezone, wakelock_plus, url_launcher, permission_handler 12 (la 13 exige un SDK Android 37 absent), flutter_markdown_plus, video_player, archive, vibration, audioplayers, path, flutter_localizations. Assets : `assets/data/`, `assets/body/`, `assets/exercises/`, `assets/images/` (logo.png). Polices embarquées : `Inter` (400, 500, 600, 700) et `SpaceGrotesk` (400, 500, 700 ; le 600 tombe sur le 700), licences OFL dans `assets/fonts/`.
- Vérifié : `flutter analyze` propre, `flutter test` vert (49 tests), `flutter build apk --debug --target-platform android-arm64` passe.

**Routes racines** (déclarées dans `lib/app/router.dart`, chemins aussi dans `Paths` de `lib/app/navigation.dart`)
- Onglets (StatefulShellRoute, état gardé par onglet) : `/` aujourdhui, `/entrainer` entrainer, `/coach` coach, `/nutrition` nutrition, `/progres` progres. Chaque module onglet renvoie en premier la route racine de son onglet ; ses sous-routes s'affichent avec la barre du bas. Pour une sous-page en plein écran au-dessus de la barre : `parentNavigatorKey: rootNavigatorKey` (importer `lib/app/navigation.dart`). Attention, les sous-routes de `/` deviennent `/xxx` : ne pas prendre un chemin racine d'un autre module.
- Hors onglets (plein écran) : `/bienvenue...` inscription, `/seance...` seance, `/sante...` sante, `/profil` et `/reglages...` profil, `/import...` import, `/dev/composants` (page cachée des composants).
- Redirection : sans profil, tout part vers `/bienvenue`, sauf `/bienvenue*`, `/import*` et `/dev*`. Avec un profil, pas de redirection automatique hors de `/bienvenue` : l'inscription enregistre le profil (`ProfileRepo.save`) puis fait `context.go('/')`.
- Fichiers provisoires à remplacer par chaque module : `lib/features/<module>/routes.dart` avec `inscriptionRoutes()`, `aujourdhuiRoutes()`, `entrainerRoutes()`, `seanceRoutes()`, `coachRoutes()`, `nutritionRoutes()`, `santeRoutes()`, `progresRoutes()`, `profilRoutes()` (`/profil` et `/reglages`), `importRoutes()`. Garder exactement ces noms de fonction.
- Coquille `lib/app/shell.dart` : barre du bas sous 840 dp, rail latéral au-delà (Fold ouvert, avatar en haut du rail) ; bandeau « Séance en cours · chrono » (façon lecteur réduit) au-dessus de la barre tant que `SessionRepo.hasActive`, qui ouvre `/seance`. Le module séance n'a pas à le refaire.

**Thème** (`lib/core/theme/theme.dart`)
- `AppTokens` : couleurs du BRIEF, coins (`r8/r12/r16/rPill`, `radius8...`), espacements (`s4...s48`, `gutter` 16), durées (`fast/normal/slow`), polices. `AccentChoice` (ambre, lavande, lagon, peche, ciel ; `.label`, `.color`).
- `context.colors` (`AppColors`, extension de thème) : `bg, surface, surface2, surface3, hover, line, text, text2, text3, accent, onAccent, accentSoft, accentFaint, success, warning, error, muscle, muscleIdle`. Ne jamais écrire une couleur d'accent en dur. `context.textStyles` = TextTheme (titres en Space Grotesk, texte en Inter).
- `AppType.number(taille)` pour les grands chiffres (tabulaires), `AppType.overline()` pour les petites étiquettes en capitales.
- `AccentController` (Provider) : `choice`, `color`, `set(AccentChoice)` (persisté). À brancher dans Réglages > Apparence.
- ThemeData Material 3 sombre complet : boutons (pilule), champs (fond `bg`, coins 12), dialogues, feuilles, menus, chips, onglets (soulignement accent), snackbars flottantes, sliders, switchs, cases, sélecteurs de date et d'heure, barre et rail de navigation.

**Composants** (`import '../../core/ui/ui.dart';`, vitrine sur `/dev/composants`)
- `AppScaffold(title, slivers | body, actions, bottom, floatingActionButton, onRefresh)` : racine d'onglet, en-tête Spotify avec avatar (ouvre `/profil`), contenu centré à 760 dp max sur grand écran. `SubPageScaffold(title, subtitle, body, actions, bottomBar, onBack, closeIcon)` : sous-page, `bottomBar` fixé en bas au-dessus du clavier (bouton Enregistrer). `PlaceholderPage`.
- `PillButton(label, onPressed, icon, trailingIcon, variant: primary|secondary|outline|ghost|danger, size: small|medium|large, expand, loading)`, `PillButton.secondary`, `PillButton.ghost`, `RoundIconButton(icon, onPressed, filled)`.
- `AppCard(child, onTap, padding, color, border, gradient)`, `SectionHeader(title, subtitle, onAction, actionLabel = 'Tout voir', trailing, large)`, `ListTileX(title, subtitle, leading, trailing, onTap, showChevron, dense, selected)`, `IconBadge(icon, color)`, `TagPill(label, icon, color, solid)`, `TileGroup(children)` (lignes groupées style réglages).
- `StatTile(label, value, unit, icon, delta, deltaPositive, caption, footer, compact)`, `ProgressRing(value, size, stroke, center)` (au-delà de 1 : second tour en `warning`), `ProgressBar(value, label, trailing, color)`, `MiniSparkline(values, height, color)`.
- `ChipFilter(label, selected, onTap, icon, count, onRemove)`, `ChipFilterBar<T>(options: [(valeur, libellé)], selected, onChanged, multi, allLabel)`, `SegmentedControl<T>(segments, value, onChanged, accentThumb)`, `SearchField(controller, hint, onChanged, trailing)`, `NumberStepper(value, onChanged, step, min, max, decimals, unit, label, compact)` (appui long qui répète, toucher la valeur pour la saisir).
- `EmptyState(icon, title, message, actionLabel, onAction)`, `Skeleton`, `Skeleton.circle`, `SkeletonList`, `Toasts.show/success/error(context, message)`.
- Dialogues (pas de feuille pour les formulaires) : `showConfirmDialog(...) -> bool`, `showTextInputDialog(...) -> String?`, `showNumberInputDialog(...) -> double?`, `showChoiceDialog<T>(...)`, et `showActionMenu<T>(items: [ActionMenuItem])` pour les menus courts.
- `AppBottomNav`, `AppNavRail`, enum `AppTab` (libellés, chemins, icônes). `AppLogo(size)` (jamais étiré), `AppWordmark` (Æ en rouge), `UserAvatar(size, onTap)` (photo ou initiale, lit le profil). `ContentWidth`, `SliverContentWidth`, `context.isCompact / isWide / isExpanded / gridColumns()`.
- Icônes : `Icons.xxx_rounded` (Material Symbols arrondis) partout.

**Modèles** (`import '../../core/models/models.dart';`, toJson/fromJson écrits à la main, lecture tolérante)
- `Muscle` (enum du BRIEF, `.label`, `.region` MuscleRegion, `.side`, `.svgId`, `Muscle.tryParse` qui accepte aussi libellés et noms anglais), `Exercise` (+ `ExerciseMedia` avec `gif, gifSecours, mp4, images, imagesLocales, credit, thumbnail` ; `suivi` ExerciseTracking déduit si absent ; `intensites` pour BodyMap ; `Equipements.label`, `Categories.label`).
- `UserProfile` (prenom, sexe, naissance, age, tailleCm, poidsKg, poidsCibleKg, objectif, niveau, activite, joursParSemaine, dureeSeanceMin, materiel, unitePoids kg|lb, objectifsNutrition, photo) + enums `Sexe, Objectif, Niveau, NiveauActivite, Materiel, UnitePoids` avec libellés.
- `Routine` > `RoutineExercise` (id d'emplacement, exerciseId, series `PlannedSet` avec fourchette reps..repsMax, reposSec, supersetId, notes), `Folder`, `Program` (routineIds en cycle, dureeSemaines, joursParSemaine, semaineCourante, prochainIndex, seancesFaites, actif).
- `WorkoutSession` > `SessionExercise` > `WorkoutSet` (type `SetType` echauffement|normale|degressive|echec, poids en kg, reps, rpe, fait, tempsReposSec, dureeSec, distanceM, faitLe), `PersonalRecord` + `RecordType`.
- `Food` (valeurs pour 100 g dans `Macros`, portions, code-barres, favori), `FoodEntry` (valeurs copiées à l'ajout), `Meal` (repas enregistré), `MealType`, `WaterLog`, `NutritionGoals`, `SleepEntry` (phases facultatives), `BodyMeasurement` (poids, masse grasse, tours `TourCorps`), `ProgressPhoto`, `Supplement`, `SupplementIntake`, `CoachMessage`, `Conversation`, `AppSettings` (repos par défaut, incrément, son et vibration du minuteur, écran allumé, RPE, rappels, santé connectée, clé et modèle du coach).
- Tous les poids sont stockés en kg ; affichage avec `Fmt.poids(kg, unite)`.

**Données** (`import '../../core/data/data.dart';`, tous fournis par Provider : `context.watch<SessionRepo>()`...)
- `Store` : un fichier JSON par collection dans documents/donnees (ou documents/demo en démo), écriture atomique en file ; `read/readList/readObject/write/delete`, `mediaDir()`, `Store.memory()` pour les tests. `newId()`. Un module peut garder sa propre petite collection : `context.read<Store>().write('import_correspondances', map)`.
- `AppData` : tous les dépôts, `loadAll()`, `resetAll()`, `exportBackup()` / `importBackup(json)` (sauvegarde complète hors photos).
- `ProfileRepo` : `profile`, `hasProfile`, `unite`, `save`, `update(fn)`, `clear`.
- `SettingsRepo` : `settings`, `save`, `update((s) => s.copyWith(...))`.
- `ExerciseRepo` : `catalogue` (assets/data/exercises.json, vide si absent), `perso`, `all`, `byId`, `nameOf`, `search(query, muscles, region, equipements, favorisSeulement, persoSeulement)`, `findByName` (nom, nomEn, alias), `addCustom/updateCustom/deleteCustom/addCustomAll`, `favoris`, `toggleFavori`, `equipements`.
- `RoutineRepo` : `routines`, `folders`, `routinesIn(folderId)`, `save` (id vide = création), `saveAll`, `delete`, `duplicate`, `moveToFolder`, `reorder(ids)`, `addFolder`, `saveFolder`, `toggleFolder`, `deleteFolder(withRoutines)`.
- `ProgramRepo` : `programs`, `active`, `save`, `delete`, `activate(id, restart)`, `deactivate`, `advance(id)` (à appeler par le module séance à la fin d'une séance dont `programId` est rempli).
- `SessionRepo` : `sessions` (récente d'abord), `byId`, `save`, `addAll` (import), `delete`, `sessionsOn/Between/ThisWeek`, `streakWeeks`, `lastForRoutine`, `historyFor(exerciseId)`, `lastFor(exerciseId)` (colonne « Précédent »), `bestsFor(exerciseId)`, `recentExerciseIds`. Séance en cours persistée (survit à la fermeture) : `active`, `hasActive`, `startEmpty`, `startFromRoutine(routine, programId)` (préremplit avec la dernière performance), `updateActive`, `mutateActive`, `addExerciseToActive`, `updateActiveExercise`, `removeActiveExercise`, `addSet`, `updateSet`, `removeSet`, `toggleSetDone`, `finishActive(nom, notes, ressenti) -> (session, records)` (ne garde que les séries faites, calcule les records battus), `discardActive`.
- `NutritionRepo` : aliments perso + `assets/data/aliments.json` facultatif (liste de `Food` en JSON) ; `searchFoods`, `foodByBarcode`, `recentFoods`, `favoriteFoods`, `saveFood`, `deleteFood`, `toggleFavoriteFood` ; journal `entriesFor(jour, repas)`, `totalsFor(jour, repas) -> Macros`, `addFood(food, grammes, date, repas)`, `saveEntry`, `deleteEntry`, `copyDay` ; repas enregistrés `meals`, `saveMeal`, `addMealToDay` ; eau `waterFor(jour)`, `addWater(ml)`, `undoWater(jour)`. Objectifs : `NutritionCalc.effectifs(profil)` (ceux du profil, sinon calculés).
- `HealthRepo` : sommeil (`sleep`, `sleepFor`, `lastSleep`, `averageSleep`, `saveSleep`, `deleteSleep`), mesures (`measurements`, `latestWeight`, `latestBodyFat`, `weightSeries`, `latestTour`, `saveMeasurement`), photos (`photos`, `addPhoto(cheminSource, vue)` copie le fichier dans le dossier privé, `deletePhoto`), compléments (`supplements`, `saveSupplement`, `intakesFor`, `takenOn`, `toggleIntake`).
- `CoachRepo` : `conversations`, `create`, `addMessage(convId, role, texte)`, `updateMessage`, `rename`, `togglePin`, `delete`.

**Calculs** (`import '../../core/logic/logic.dart';`)
- `Strength` : `epley`, `brzycki`, `oneRepMax`, `poidsPourReps`, `tablePourcentages`, `setsParMuscle`, `volumeParMuscle`, `bests`, `newRecords`, `arrondir`, `echauffement(poids)`.
- `NutritionCalc` : `metabolismeDeBase` (Mifflin-St Jeor), `depenseTotale`, `objectifs(profil)`, `effectifs(profil)`, `imc`.
- `Recovery` : `fatigue(sessions, exercises.byId) -> Map<Muscle, double>` (0 reposé, 1 tout juste travaillé ; se branche directement sur `BodyMap(intensities: ...)`), `pourcentages`, `prets`.
- `Fmt` : nombres à la française, `poids`, `volume`, `kcal`, `duree`, `chrono`, `repos`, `sommeil`, `jour`, `jourCap`, `date`, `mois`, `heure`, `relatif` (Aujourd'hui, Hier…), `ilYa`, `pluriel`. `Dates` : `debutSemaine`, `joursSemaine`, `memeJour`, `semainesConsecutives`. `TextSearch` : recherche sans accents.
- `Env.demo` (`lib/core/env.dart`).

**Démo** : `flutter run --dart-define=DEMO=true`. `DemoData.seed` : profil Tristan (181 cm, 77 kg, prise de muscle), 6 mois de Push/Pull/Legs 4 fois par semaine en progression (décharge toutes les 7 semaines, échauffements, RPE, échecs), routines rangées dans un dossier, programme actif, pesées tous les 2 ou 3 jours (72,5 vers 77 kg) et tours mensuels, 6 mois de nuits avec phases, 3 compléments, 2 mois de repas et d'eau, un repas enregistré, une conversation avec le coach. Les exercices sont pris dans le catalogue quand le nom y est, sinon créés en perso.

**Outils** : `test/core/fondation_test.dart` (calculs, stockage, séance, sauvegarde, démo). `test/fondation_rendu/rendu_test.dart` rend l'appli démo hors écran dans `build/rendus/*.png` sans émulateur (utile quand l'émulateur est occupé) : copiez-le pour capturer vos écrans.

**Réponses aux demandes**
- Catalogue : `assets/exercises/` ajouté aux assets ; `ExerciseMedia` lit `gifSecours`, `imagesLocales`, `credit`, et `thumbnail` préfère `imagesLocales.first` puis `gif` ; libellés des catégories dans `Categories`.
- Personnage : `BodySvgRepository.precache()` lancé dans `main.dart`.
- Format d'import : la conversion `ImportedSession` vers `WorkoutSession` reste dans le module import (le cœur ne dépend pas des modules). Côté socle : `SessionRepo.addAll(sessions)` (mettre `source: 'import'`), `SessionRepo.sessions.map((s) => s.debut)` pour `debutsExistants`, `ExerciseRepo.addCustom(Exercise(id: '', nom: nomSource, ...))` pour les exercices personnels, et la mémoire des correspondances dans la collection `import_correspondances` via `context.read<Store>()`. Les types de série absents du modèle (negative, retour…) se ramènent à `SetType.normale`, l'échauffement à `SetType.echauffement`.

**Limites**
- L'émulateur partagé était occupé par une autre appli : contrôle visuel fait par rendu hors écran (onglet et page des composants), pas sur l'appareil.
- Pas de variantes Android (complete/demo) : la démo passe par `--dart-define=DEMO=true` avec son propre dossier de données, et s'installe par-dessus la vraie appli (même identifiant). À ajouter au moment de publier les deux APK.
- Services non livrés (à la charge des modules) : Health Connect, notifications, minuteur de repos, appels au coach IA.

**Demandes**
- Tous : ne pas toucher à `pubspec.yaml`, `lib/app/`, `lib/core/` (hors `lib/core/ui/body/`, au personnage) ; demander ici.
- Profil/Réglages : brancher `AccentController.set` dans Apparence, `AppData.exportBackup/importBackup/resetAll` dans Données, et un accès caché à `/dev/composants` (par exemple sept appuis sur la version).
- Séance : appeler `ProgramRepo.advance(programId)` après `finishActive` quand la séance vient d'un programme ; utiliser `settings.garderEcranAllume` (wakelock_plus).

### DIRECTEUR ARTISTIQUE (revue du personnage)

**Livraisons**
- Revue sans complaisance des SVG `assets/body/front.svg` et `back.svg` contre `refs/ref1` à `ref7`, à 80 px, 120 px et en zoom (épaule, abdos, genou, main, dos, jambes). Aucun fichier du projet modifié. Captures de travail hors dépôt.
- Verdict : pas au niveau. Le personnage lit comme un mannequin articulé en pièces gonflées (effet coussin), pas comme une planche anatomique. Défauts classés dans la liste ci-dessous.

**Défauts, par gravité**
1. Bloquant, lumière : chaque pièce a son propre dégradé radial centré (cy 0,3 à 0,4) et une ombre interne de 7 % : tout est « gonflé » isolément, aucune lumière globale, écart de valeurs trop faible (#DADCDF à #80848A dilué). Corriger : une lumière unique en haut à gauche, dégradé linéaire orienté par pièce (clair vers le haut et l'intérieur de la masse), ombre d'occlusion franche (20 à 35 %) le long des sillons profonds : sous les pectoraux, autour du deltoïde, entre les abdos, pli fessier, creux poplité.
2. Bloquant, dentelé antérieur (face) : les trois « doigts » sous l'aisselle sortent du contour du torse et ressemblent à une main qui agrippe le flanc. Les rentrer dans le contour, 4 digitations plus courtes et plates, en biais vers l'avant, sous le bord du grand dorsal, recouvertes en bas par l'oblique externe.
3. Bloquant, taille et hanches : taille pincée en sablier (largeur taille / épaules environ 1/2,8) puis évasement des cuisses : silhouette féminine. Rapprocher de 1/2 : élargir la taille, obliques externes visibles en bourrelet au-dessus de la crête iliaque, ligne de hanche presque droite jusqu'au grand trochanter, cuisse externe qui repart doucement.
4. Bloquant, abdominaux : 4 pavés carrés arrondis séparés par de larges gouttières, puis un grand bas-ventre lisse avec une fausse intersection horizontale. Faire 3 rangées (6) de blocs moins arrondis, légèrement décalés, la plus haute partiellement sous le pec, ligne blanche fine et continue, nombril à la 3e intersection, bas-ventre plus court, lignes du V (ligament inguinal) nettes vers le pubis. Obliques externes dessinées (actuellement une nappe plate).
5. Grave, genoux : rotules en disque dans un bloc carré (bouton de robot). Remplacer par rotule en goutte, vaste interne en larme au-dessus et à l'intérieur, tendon rotulien étroit, pas de cadre autour.
6. Grave, jambe (face et dos) : tibia et mollet en tubes parallèles empilés, cuisse trop fine par rapport au haut du corps. Face : quadriceps plus volumineux (vaste externe bombé vers le haut, droit fémoral en fuseau), couturier plus fin (actuellement une sangle épaisse), mollet interne qui déborde du contour sous le genou. Dos : gastrocnémien en cœur (deux chefs, l'interne plus bas), haut placé, puis tendon d'Achille fin ; supprimer la bande horizontale derrière le genou.
7. Grave, grand dorsal et trapèze (dos) : trapèze en losange plat d'un seul tenant, grands dorsaux en plaques triangulaires à bords durs sans enroulement sur les côtes, grand rond en boudin horizontal. Trapèze : 3 zones (supérieur bombé vers l'épaule, moyen, inférieur en pointe vers T12) avec l'épine de l'omoplate visible. Grand dorsal : bord externe convexe qui déborde de la silhouette en éventail (le V), fibres en diagonale vers l'aisselle, sillon d'ombre sous l'omoplate.
8. Grave, fessiers : deux ballons ronds trop grands, sans moyen fessier latéral lisible ni pli fessier. Réduire de 15 %, forme en carré arrondi incliné, moyen fessier en éventail au-dessus et en dehors, pli fessier sombre.
9. Grave, bras : deltoïde en bande étroite et plate, biceps en ellipse isolée collée, « coudes » dos en plaques rectangulaires (armure). Deltoïde en goutte pleine qui enveloppe l'épaule (antérieur, latéral bien arrondi, plus large que le bras), biceps qui s'insère sous le deltoïde, triceps en fer à cheval au dos, coude avec olécrane discret, avant-bras qui s'élargit au tiers haut (brachio-radial).
10. Moyen, mains et poignets : bracelet rectangulaire au poignet, paume carrée en coussin, doigts trop courts derrière la paume, pouce en saucisse : moufle. Supprimer le bracelet, paume plus petite, doigts à 45 % de la main, pouce opposable à la base, main légèrement ouverte, paume vers l'avant comme les références.
11. Moyen, tête : œuf de mannequin avec visage gravé (sourcils, nez, bouche). Les références ont une tête lisse sans traits. Supprimer les traits, mâchoire et oreilles suggérées par la forme seulement, tête un peu plus petite (8 têtes).
12. Moyen, rouge : le mélange gris vers rouge en RVB linéaire donne du rose saumon aux intensités partielles (triceps, avant-bras, récupération), et le stop clair `#F2676A` rend le centre des pecs saumon. Rouge des références : plat, profond (#D32F2F environ). Corriger : stop clair à peine plus clair que la base (+8 %), mélange en espace perceptuel (OKLCH) en tenant la luminosité du rouge dès t > 0 et en montant la saturation, ou 4 paliers d'intensité franchement rouges.
13. Moyen, pose : bras collés et raides le long du corps. Les références écartent les bras d'environ 15 degrés, mains ouvertes : silhouette plus lisible et plus athlétique.
14. Mineur, fibres : faisceaux blancs en éventail régulier (effet rayons de soleil sur les pecs), trop nombreux, bruit visuel à 80 px. Opacité 0,12 à 0,18, moins de fibres, suivre la forme du muscle, les masquer sous 120 px de haut.
15. Mineur, contours : coutures blanches de 1,1 identiques partout. Les références ont des coutures fines mais un contraste plus fort sur les sillons profonds et plus faible sur les sous-divisions. Deux épaisseurs (1,2 principales, 0,6 secondaires).

**Petit format (80 px)** : la silhouette tient, mais l'intérieur est un bruit gris uniforme ; la tête paraît grosse, les jambes en piquets. Il faut une version simplifiée sous 120 px (moins de pièces, pas de fibres, coutures seulement entre groupes de l'enum), sinon le rouge d'un seul petit muscle se perd.

**Demandes**
- PERSONNAGE (`tools/corps/`) : reprendre dans l'ordre 1 à 4 d'abord (lumière dans `lib.js`, dentelé et abdos et taille dans `face.js`), puis 5 à 9, puis le reste ; refaire les captures `final-*.png` et une planche 80 px à côté de `refs/ref4.jpg` et `ref5.jpg` à la même hauteur.
- PERSONNAGE (`lib/core/ui/body/body_svg.dart`) : aligner `shades()` et le mélange sur le point 12 ; prévoir une variante simplifiée pour `height < 120`.

### PERSONNAGE, retouche 1 (suite à la revue du directeur artistique)

**Livraisons**
- `assets/body/front.svg` et `back.svg` redessinés (viewBox 400 x 860 inchangé, ids `m-<muscle>` et classes `m-<muscle>` conservés, les 20 muscles présents). Les 15 points de la revue sont traités :
  - Lumière : un dégradé linéaire orienté par pièce (lumière en haut à gauche), un voile fondu partagé (`#vig`, `#eclat`) au lieu du dégradé radial centré, des sillons d'occlusion de 20 à 36 % (sous les pectoraux, autour du deltoïde, entre les abdominaux, pli de l'aine, pli fessier, creux poplité). Palette calée sur les gris mesurés des références (plus sombre, plus contrastée).
  - Face : dentelé en 4 digitations courtes dans le contour, taille à environ la moitié des épaules, hanche presque droite, abdominaux en 3 rangées décalées avec ligne blanche fine et nombril à la 3e intersection, V de l'aine, obliques dessinés, pectoraux au bord inférieur remontant vers l'aisselle, rotule en goutte avec condyles, quadriceps plus volumineux, couturier fin.
  - Dos : trapèze en 3 zones avec l'épine de l'omoplate visible, grand dorsal au bord externe convexe (le V), rhomboïde en losange, fessiers réduits en carré arrondi incliné avec moyen fessier et pli sombre, gastrocnémien en cœur, tendon d'Achille fin, plus de bande derrière le genou.
  - Bras écartés de 12 degrés (repère du bras dans `tools/corps/bras.js`), deltoïde en goutte qui enveloppe l'épaule avec insertion au tiers moyen, biceps sous le deltoïde, triceps en fer à cheval au dos, avant-bras élargi au tiers haut, main ouverte paume en avant sans bracelet (doigts à 45 %, éminence du pouce). Tête lisse, sans traits, plus petite.
  - Fibres à 0,10 à 0,15 d'opacité et moins nombreuses, coutures à deux épaisseurs (1,2 et 0,6).
- Rouge perceptuel (OKLCH) dans `tools/corps/lib.js` et `lib/core/ui/body/body_svg.dart` : `shades()` donne un reflet à +8 % de luminosité, `tint()` garde la luminosité de la couleur dès que l'intensité dépasse 0 et ne fait varier que la saturation (plus de rose saumon).
- Petit format : `BodySvgRepository.paint(..., simple: true)` retire fibres, coutures secondaires et détails. `BodyMap` l'active seul quand la hauteur dessinée est sous 120 px (`BodySvgRepository.simpleBelow`).
- Tests `test/body/body_map_test.dart` : 6 tests (contrat des ids, toucher avec nouveaux points, coloration, rouge perceptuel, petit format, rendu flutter_svg). Golden `rendu_flutter.png` mis à jour. `flutter analyze` : aucun problème.
- Générateur : `node tools/corps/gen.js` écrit les SVG, `controle.html`, les pages `zoom-*.html` et `planche.html` (80 et 120 px à côté de `ref4` et `ref5`). Captures : `tools/corps/captures/final-*-t1.png` et gros plans `z-*-t1.png`.

**Limites**
- SVG plus lourds qu'avant (face 409 Ko, dos 341 Ko) : `BodySvgRepository.precache()` au démarrage reste utile (déjà appelé dans `main.dart`).
- La jambe de face garde des masses allongées (jumeau interne, tibial) ; lisible en petit, perfectible en très grand.

**Demandes**
- Aucune nouvelle. L'API de `BodyMap` et `BodyMapDual` n'a pas changé ; `paint()` prend un paramètre facultatif `simple`.

### DIRECTEUR ARTISTIQUE, revue 2 (après la retouche 1 du personnage)

**Livraisons**
- Revue de `final-*-t1.png`, `z-*-t1.png`, de la planche 80 px et d'un nouveau rendu de sélections isolées (biceps, deltoïdes, triceps, ischios et mollets, obliques, rhomboïdes et deltoïdes postérieurs) contre `refs/ref1` à `ref7` agrandies. Aucun fichier du projet modifié, captures de travail hors dépôt. Coordonnées ci-dessous dans la viewBox 400 x 860.
- Verdict : net progrès sur la taille, les abdos et le rouge, mais toujours pas au niveau. Le défaut de fond reste : le corps est un puzzle de pièces fermées, chacune cerclée de blanc et biseautée, au lieu d'une surface continue sculptée par la lumière où les traits blancs ne font que souligner.

**Défauts, par gravité**
1. Bloquant, construction : chaque muscle est une forme fermée entourée d'une couture blanche complète. Résultat vitrail, surtout au dos et aux jambes. Dans les références, les coutures sont des traits ouverts qui s'effilent et s'arrêtent, beaucoup de limites ne sont rendues que par l'ombre. Corriger dans `lib.js` : couture en trait effilé (épaisseur 0 aux extrémités, 1,2 au centre), ne tracer que les bords des sillons réels, laisser les sous-divisions en ombre seule ; une base continue par membre (bras, cuisse, jambe, tronc) peinte d'un seul dégradé, les muscles posés dessus en modulations de valeur, pas en pièces opaques juxtaposées.
2. Bloquant, tête et cou : tête de 85 unités (y 35 à 120) pour une figure de 815 : 9,6 têtes, épingle. Cou de 42 unités de long et 35 de large (x 182 à 218) : cou de girafe, trapèzes qui tombent. Références : 7,7 têtes, cou court et large (80 % de la largeur de tête), trapèzes qui montent jusque sous l'oreille. Corriger : tête de 100 à 105 unités, menton vers y 135, cou raccourci à 20 unités et élargi à 48, trapèze supérieur en pente de 35 à 40 degrés vers l'acromion, clavicule vers y 158.
3. Bloquant, dos : grands dorsaux en trapèzes plats à bords rectilignes qui se croisent en X au milieu (y 325), sans modulation interne : du carton plié. Épine de l'omoplate dessinée comme une fente sombre (x 115 à 165, y 185 à 215) : on lit un trou, une bouche d'aération. Trapèze d'un seul losange coupé par une règle horizontale à y 212. Corriger : bord inférieur interne du dorsal concave qui remonte vers la colonne, bord externe convexe, ombre franche sous l'omoplate, grand rond et sous-épineux en bosses arrondies au-dessus ; épine en arête claire avec ombre dessous, pas en fente ; trapèze sans trait horizontal, parties moyenne et inférieure distinguées par la valeur ; colonne en sillon d'ombre bordé par les érecteurs visibles dès le milieu du dos.
4. Bloquant, fessiers : deux ballons de 70 unités qui occupent toute la hanche (x 135 à 265), moyens fessiers en oreilles au-dessus : tête de souris. Corriger : réduire de 20 %, masse en carré arrondi inclinée vers le bas et l'intérieur, pli fessier horizontal prolongé vers l'extérieur, moyen fessier fondu dans le contour de la hanche (pas de pièce détachée).
5. Bloquant, jambes : cuisses en fuseaux parallèles de même largeur (vaste externe, droit fémoral, couturier) de y 410 à 610, contour externe presque droit ; ischios en 4 boudins parallèles séparés par des gouttières grises (code-barres une fois en rouge) ; genou en 5 pièces (rotule en ampoule, tendon en gélule, deux blocs de condyle) : articulation de robot ; jambe de face en deux gélules égales côte à côte ; mollet de dos en deux capsules parallèles de même longueur ; cheville de 45 unités pour un mollet de 60 : poteau ; pieds de dos en sabots, pieds de face en planches à orteils festonnés. Corriger : cuisse en goutte (plus large au tiers haut, vaste interne en larme au-dessus du genou côté interne), ischios en 2 masses qui convergent en V vers le creux poplité ; genou réduit à une rotule discrète sans cadre et une ombre ; tibia en plan clair continu, tibial antérieur étroit côté externe, mollet interne qui déborde du contour interne ; gastrocnémien en cœur (chef interne plus bas et plus gros), tendon d'Achille fin, cheville à 28 ou 30 unités ; pieds en raccourci avec cou-de-pied et malléoles.
6. Grave, bras : deltoïde en amande qui descend jusqu'à y 265 alors que le coude est à 325 (64 % de l'humérus), coupé en deux haricots par une couture pleine longueur ; dessous, un bras de 35 unités pour un deltoïde de 65 : épaulette posée sur un bâton. Biceps presque invisible de face (en sélection, il ne colore qu'une plaque sur le bord externe du bas du bras). Triceps de dos sans fer à cheval. Avant-bras en 5 pailles parallèles toutes cerclées. Corriger : deltoïde en calotte ronde, largeur maximale au tiers haut, pointe insérée à mi-humérus (y 245), séparation antérieur et latéral en ombre courte ; biceps en fuseau bombé au centre de la face avant du bras ; triceps en fer à cheval net au dos ; avant-bras en 2 masses (brachio-radial et fléchisseurs) qui s'affinent vers le poignet.
7. Grave, torse de face : pectoraux en dalles rectangulaires de 88 unités de haut (une tête entière), bord haut horizontal à la règle : poitrine en boîte. Dentelé encore en griffes grises détachées (x 125 à 135, y 250 à 300) : on lit des branchies. Encoche sur la taille à y 380 à 400 (x 131 et 269) : lue comme un défaut. Abdos en touches de clavier biseautées dans une colonne à bords droits, bas-ventre d'un seul bloc qui descend jusqu'à l'entrejambe (y 445) : il n'y a pas de bassin. Corriger : pectoral en éventail de 60 unités de haut, bord inférieur en courbe qui remonte vers l'aisselle, bord haut qui suit la clavicule montante, sillon delto-pectoral en diagonale ; dentelé en dents de scie emboîtées avec l'oblique, sous le bord du pectoral, rendu par la valeur seulement ; contour de taille continu ; blocs d'abdos moins arrondis, grand droit légèrement fuselé et arrêté vers y 420, zone pubienne lisse et neutre, départ des cuisses sous le pli de l'aine.
8. Grave, lumière et valeurs : le dégradé linéaire par pièce (clair en haut à gauche, sombre en bas à droite) fait de chaque muscle un bouton biseauté en plastique brillant ; aucun volume d'ensemble (membre en cylindre : bords sombres, centre clair). L'ensemble est plus sombre et plus terne que les références, claires et mates (centre vers #D8D8D8, sillons vers #8A8A8A). Corriger : un dégradé de forme par membre et pour le tronc (occlusion sur les bords du cylindre), variation par muscle limitée à 6 à 8 % de valeur, ombres de sillon plus douces mais plus larges, valeur moyenne remontée de 10 %.
9. Grave, découpage des sélections : obliques = deux bandes verticales de l'aisselle à l'aine (bretelles), parce que le flanc est mangé par le grand dorsal ; deltoïdes postérieurs avec le sous-épineux = écharpe en travers de l'omoplate (les références ne colorent que la calotte arrière de l'épaule) ; triceps de face = filet rouge le long de l'intérieur du bras, lu comme une coupure. Corriger : obliques en éventail large des côtes à la crête iliaque ; sous-épineux et petit rond en neutre ; ne jamais colorer une bande de moins de 6 unités de large (l'élargir ou la laisser neutre).
10. Moyen, rouge : bon à pleine intensité, mais le centre des pecs tire encore vers le corail, et le dégradé vertical par pièce rend les avant-bras à 0,3 couleur brique sale, plus sombre au poignet ; la récupération à 0,25 donne un mauve boueux sur les pecs. Références : rouge plat et profond (#D32F2F environ), presque sans dégradé, coutures blanches visibles dessus. Corriger : pièce rouge presque unie (écart de luminosité de 5 % au plus), paliers d'intensité par la saturation et l'opacité du rouge sur le gris clair, jamais par un gris assombri.
11. Moyen, mains : paume en pagaie carrée avec des lignes gravées, raccordée au poignet par une marche, doigts en tubes cerclés : gant. Corriger : main dans le prolongement du poignet, paume un peu creusée, doigts légèrement fléchis et groupés, pouce écarté à 30 degrés, sans lignes de paume.
12. Moyen, petit format : la variante simplifiée à 80 px est presque identique à la complète (mêmes coutures, rotules et pieds clairs qui scintillent, X sombre des dorsaux). Corriger : sous 120 px, garder seulement le contour et les limites des 20 groupes de l'enum, fondre genoux et pieds dans la valeur de la jambe.
13. Mineur : points des mamelons trop marqués, fibres en rayons encore visibles sur les dorsaux, liseré extérieur blanc trop épais (effet autocollant), à ramener à 0,8 et un peu plus sombre que les coutures internes.

**Ordre conseillé** : 1 et 8 d'abord (moteur de rendu dans `lib.js`, ils conditionnent tout), puis 2, puis 3 à 5, puis 6, 7 et 9, puis le reste.

**Demandes**
- PERSONNAGE (`tools/corps/`, `lib/core/ui/body/body_svg.dart`) : traiter la liste ci-dessus dans l'ordre conseillé en gardant les ids et classes `m-<muscle>` ; refaire `final-*-t2.png`, les gros plans et une planche où chaque muscle de l'enum est coloré seul, à 300 px et à 80 px, à côté de `refs/ref4.jpg`.

### THÈME (DA de référence, noir pur et Roboto, 30/09 ; remplace la version SmartBudget)

**Règle pour tous les écrans**
- Toute racine d'onglet utilise `AppScaffold`, toute sous-page `SubPageScaffold` (« ‹ Titre » sur fond noir). Pas de fond gris posé à la main : le fond est `c.bg` (#000000), les cartes `c.surface` (#1C1C1E).
- Aucune lueur, aucun halo, aucun dégradé décoratif. `IconHalo` et `ScreenHalo` existent toujours (mêmes paramètres) mais sont plats : `IconHalo` = icône dans un rond gris #2C2C2E, `ScreenHalo` ne dessine plus rien. Les paramètres `halo` / `haloColor` des échafaudages sont sans effet.
- Icônes de ligne : `IconHalo` (réglages, santé) ou `ExerciseThumbnail` (exercices). Séries : `SetTableHeader` + `SetRow`. Jamais de couleur en dur : `context.colors` et `AppTokens`.
- La barre du bas est de nouveau pleine (plus de `extendBody` dans `lib/app/shell.dart`) : le contenu s'arrête au-dessus, aucune marge spéciale à prévoir.

**Jetons** (`lib/core/theme/`, tous les noms gardés)
- `bg` #000000, `surface` #1C1C1E (cartes, tuiles), `surface2` #2C2C2E (surfaces plus claires, fond d'image d'exercice, boutons gris), `surface3` #3A3A3C (cadres fins, pistes), `hover` #48454E, `line` #2C2C2E (séparateurs). Ajouts : `frame` #3A3A3C, `searchFill` #48454E, `setDone` #0F2A14, `muscleBar` #F0294B, `track` #3A3A3C. `veil...` deviennent des gris pleins.
- Texte `text` #FFFFFF, `text2` #A1A1A6, `text3` #6E6E73. `success` #4CD137 (coche de série), `error` #FF453A.
- Police : Roboto embarquée (400, 500, 700), `fontUi` et `fontDisplay` valent `'Roboto'`. Figtree retirée du pubspec et d'`assets/fonts/`. `AppType.number` en 700 tabulaire, `screenTitle` 20 en 500, `rowTitle` 16 en 400, `rowSubtitle` 14 gris.
- Accents : `AccentChoice.bleu` #1E9BE9 (défaut, nouveau), puis `ambre` #FFA928, `lavande` #9D8CFF, `lagon` #3CE0FF, `peche` #FF8A65 (`AccentChoice.ciel` reste un alias de `bleu`, hors de la liste ; une préférence « ciel » enregistrée retombe sur le bleu). `AccentChoice.onColor` : blanc sur le bleu, noir sur les autres ; `AccentChoice.onColorFor(couleur)`. Lire `context.colors.onAccent` plutôt que `AppTokens.onAccent` (blanc) pour du texte posé sur l'accent.
- `context.colors` : en plus, `setDone`, `check`, `muscleBar`, `track`, `frame`, `searchFill`.

**Composants retouchés** (`lib/core/ui/`, mêmes API, rendu plat)
- `AppScaffold` : titre 22 en 500, avatar, en-tête noir qui se replie ; nouveau `centerTitle`. `SubPageScaffold` : chevron « ‹ » ou croix, titre 20.
- `AppBottomNav` : barre noire pleine largeur, filet #1C1C1E au-dessus, icône et libellé, l'onglet actif en blanc, le Coach au centre. `AppNavRail` dans le même esprit.
- `PillButton` : `primary` plein d'accent (désactivé : accent éteint, comme « Terminer » grisé) ; `secondary` gris #2C2C2E plein texte blanc (« + Ajouter une série » : `PillButton.secondary(icon: Icons.add_rounded, expand: true, size: PillSize.small)`) ; `outline` cadre fin ; `ghost` texte d'accent ; `danger` texte rouge ; `PillButton.link` = gris avec chevron.
- `SearchField` : pilule #48454E. `SectionHeader` : titre 18 en casse normale (« Programmes populaires »), action d'accent. `SectionLabel` : étiquette grise 16 (« Volume »). `AppCard` : #1C1C1E coins 12. `TileGroup`, `ListTileX`, `TagPill` plats.
- `ChipFilter` / `SegmentedChips` : gris foncé, la choisie en cadre blanc. `SegmentedControl` : bac #1C1C1E en pilule, curseur d'accent. `StepSelector` / `MonthSelector` : bac #1C1C1E.
- `ProgressBar`, `ProgressRing`, `SegmentRing`, `TickGauge`, `SegmentedBar` : pistes #3A3A3C, plats. `BigNumber` : « Volume » gris, chiffre 36 en 700, unité collée (« 197 248kg »), période grise dessous.

**Nouveaux composants** (`lib/core/ui/workout.dart`, exportés par `ui.dart`)
- `IconTabBar<T>(tabs: [IconTab(valeur, libellé, icône)], value, onChanged)` : onglets du haut, icône au-dessus, l'actif blanc souligné ; utilisable en `AppScaffold(bottom: ...)`.
- `ExerciseThumbnail(image, width 48, height 72)` : vignette blanche portrait avec « ? ». (Nommée ainsi car `ExerciseThumb` existe déjà dans deux modules.)
- `ExerciseCard(title, subtitle, image, bookmarked, onBookmark, onHelp, onTap, selected)` + `ExerciseCard.gridDelegate` (2 colonnes) : grande image sur #2C2C2E, signet en haut à gauche, « ? » en haut à droite.
- `SelectCircle(child, selected, onTap, label, size)` : image ronde, cercle blanc et `CheckBadge` (coche noire dans une pastille blanche). `SelectSquare` : cadre blanc arrondi (filtre par silhouette de muscle).
- `StatBox(items: [(libellé, valeur, couleur?)])` : encadré Durée / Volume / Séries aux bords fins.
- `SetTableHeader(labels)` et `SetRow(label, previous, weight, reps, done, onToggle, weightField, repsField, hint)` : ligne vert très sombre et coche ronde verte quand la série est faite ; `SetCheck(done, onTap)` seule.
- `MuscleBar(name, value, valueLabel, secondary, secondaryLabel, leading, large)` : barre rouge rosée #F0294B puis barre grise des séries, valeur au bout de la barre.
- `WeekDots(days: [(libellé, entraîné)])` : pastilles d'accent avec haltère, point gris sinon.
- `SimpleBarChart(values, height, labels, formatAxis)` : barres d'accent plates, repères fins, graduations 0 / 20k / 40k.

**Hors de lib/core** : `pubspec.yaml` (Figtree remplacée par Roboto, licence dans `assets/fonts/LICENSE-Roboto.txt`), `lib/app/shell.dart` (barre pleine, bandeau de séance plat), `lib/app/dev/composants_page.dart` (vitrine refaite sur les captures de référence), `test/fondation_rendu/rendu_test.dart` (charge Roboto).

**Demandes**
- Profil/Réglages (`apparence_section.dart`) : la liste `AccentChoice.values` commence maintenant par Bleu ; pour la coche posée sur une pastille, utiliser `a.onColor` (blanc sur le bleu) plutôt que `AppTokens.onAccent`.
- Séance : utiliser `StatBox`, `SetTableHeader`, `SetRow`, `SetCheck`, `AccentLink(icon: Icons.timer_outlined)` pour le repos, et `PillButton.secondary` pleine largeur pour « Ajouter une série ».
- Bibliothèque : `ExerciseCard` en grille, `SelectSquare` pour les silhouettes, `IconTabBar` pour Programmes / Exercices.
- Progrès : `BigNumber`, `SimpleBarChart`, `WeekDots`, `MuscleBar`.

### Agent CATALOGUE, extension au dépôt exercises-dataset (30/09)

**Livraisons**
- `assets/data/exercises.json` : **1 344 exercices** = les 1 324 du dépôt hasaneyldrm/exercises-dataset (tous animés) + les 20 exercices en photos seules du premier catalogue. Les **358 exercices existants gardent leur id, nom, alias, muscles et conseils** ; seuls leurs médias et quelques tournures d'instructions changent. Les 986 nouveaux ont un nom français de salle, des alias (nom anglais, forme « Nom (Matériel) », nom d'origine du dépôt), des muscles de l'enum `Muscle`, matériel, catégorie, suivi, niveau, et les instructions françaises du dépôt relues. Pas de conseils pour les nouveaux.
- Médias des exercices animés : `gif` = GIF du dépôt (GitHub), `gifSecours` = ExerciseDB, `images` = miniature du dépôt en ligne, `imagesLocales` = miniature embarquée, `credit` = « Animation © Gym visual, via exercises-dataset ». Échantillon de 60 exercices (120 URL) vérifié : 0 échec.
- **Nouveau dossier d'assets `assets/exercises/miniatures/`** (1 324 JPG 180 px, 8,5 Mo), **déclaré dans `pubspec.yaml`**. Chaque exercice a maintenant une image hors ligne. Les 116 photos free-exercise-db des exercices animés ont été retirées de `assets/exercises/` (il reste les 40 photos des 20 exercices sans animation).
- `lib/core/data/exercise_catalog.dart` : décodage dans un isolate (`compute`), API inchangée. Mesure sur PC : 1 344 exercices en 100 ms environ, `jsonDecode` seul 10 ms à chaud ; le JSON pèse 2 Mo.
- `test/data/exercise_catalog_test.dart` : charge le catalogue, vérifie le nombre, l'unicité des id, les id historiques, les médias et la présence des miniatures dans le bundle. `flutter analyze` : aucun problème.
- `tools/exercices/` : `build_exercises.mjs` réécrit (source principale = dépôt, relecture automatique des traductions, options `--miniatures`, `--locaux`, `--echantillon=N`, `--verifier`), noms des nouveaux dans `depot_haut.mjs` et `depot_bas.mjs`. `docs/SOURCES_EXERCICES.md` mis à jour.

**Demandes**
- Fiche exercice / listes : ordre `gif`, `gifSecours`, `imagesLocales`, `images`. Pour un exercice animé, `imagesLocales` ne contient qu'une image (la miniature) : n'alterner deux images que s'il y en a deux. `thumbnail` renvoie déjà la miniature locale.
- Recherche et sélecteurs : 1 344 entrées, prévoir une liste paresseuse (`ListView.builder`) et la recherche sur `nom` + `alias`.

### PERSONNAGE, retouche 2 (suite à la revue 2 du directeur artistique)

**Livraisons**
- `assets/body/front.svg` et `back.svg` refaits de zéro (viewBox 400 x 860, ids `m-<muscle>` et classes `m-<muscle>` gardés, les 20 muscles présents ; face 311 Ko, dos 287 Ko, plus légers qu'avant).
- Moteur `tools/corps/lib.js` réécrit (points 1 et 8) : une surface continue. Chaque membre (tête, cou, tronc, bassin, bras, avant-bras, main, cuisse, genou, jambe, pied) a un seul dégradé cylindrique (bords sombres, reflet à gauche du centre) partagé par tous ses muscles et par un fond neutre ; un muscle ne varie que par un bombé doux et une chute de lumière verticale. Plus aucune couture fermée : les limites sont des traits blancs effilés qui s'arrêtent (formes pleines à largeur variable) ou de simples ombres en deux couches. Contour extérieur ramené à 1,2 visible. Gris plus clairs et mats (`#D6D8DB`, `#B3B6BB`, `#7F838A`).
- Nouveau fichier `tools/corps/corps.js` : silhouette commune, régions des membres, fonds neutres. `face.js`, `dos.js`, `bras.js` réécrits ; `extremites.js` supprimé (mains et pieds sont dans la silhouette).
- Points de la revue :
  - 2 : tête de 106 unités (y 27 à 133, 7,7 têtes), cou de 20 unités sur 49, trapèze qui monte jusque sous l'oreille.
  - 3 : grand dorsal en aile à bords courbes, sans croisement ; épine de l'omoplate en arête claire avec ombre dessous ; trapèze en losange sans trait horizontal, bombé en haut ; érecteurs en deux colonnes et losange lombaire.
  - 4 : fessiers réduits en carré arrondi (73 x 80), pli fessier net, moyen fessier fondu dans la hanche, bassin avec son propre dégradé.
  - 5 : cuisse en goutte, écart entre les cuisses sous le tiers haut, larme du vaste interne, ischios en 2 masses, genou réduit à une rotule discrète, mollet en cœur de dos (chef interne plus bas), cheville à 28, pieds en raccourci (orteils de face, talon rond de dos).
  - 6 : deltoïde en calotte ronde arrêtée à mi-bras, biceps bombé au centre, brachial dessous, triceps en fer à cheval avec tendon plat, avant-bras en 2 masses qui s'effilent en tendons au poignet.
  - 7 : pectoraux en éventail de 60 unités, bord haut qui suit la clavicule ; dentelé en trois ombres courtes ; taille continue ; grand droit en une pièce par côté, blocs en bosses douces éclairées par le haut (plus de touches de clavier), bas-ventre arrêté vers y 425, pli de l'aine.
  - 9 : obliques en flanc large des côtes à la crête iliaque (plus de bretelles), obliques de dos en poignée d'amour, deltoïdes postérieurs limités à l'arrière de l'épaule (sous-épineux neutre), triceps de face à 10 unités de large.
  - 10 : rouge presque uni et mat (`shades()` : la couleur, puis 95 % et 83 % de luminosité OKLCH), intensité partielle par la saturation seule (`tint()` : chroma de 50 à 100 %, même luminosité). Quand un muscle est coloré, ses voiles blancs passent à une version pour la couleur (`bombeC`, `chuteC`, `refletC`, `blocC`) et son bord blanc net s'allume (`class="bord m-<muscle>"`), comme sur les références.
  - 11 : main d'une seule pièce dans la silhouette, doigts longs légèrement écartés, séparations en ombres fines, pouce écarté.
  - 12 : en petit format, `simple` retire aussi les petites ombres (doigts, orteils, malléoles, dentelé, genou) marquées `class="s2"`.
  - 13 : mamelons à 7 % d'opacité, plus de fibres sur les dorsaux, contour plus fin.
- `lib/core/ui/body/body_svg.dart` : nouveaux gris, `shades()` et `tint()` alignés sur le générateur, `paint()` allume le bord et bascule les voiles du muscle coloré. API de `BodyMap`, `BodyMapDual` et `BodySvgRepository` inchangée.
- Tests `test/body/body_map_test.dart` : 6 tests, nouveaux points de toucher (obliques, lombaires, mollets), vérification du bord et des voiles colorés, golden `rendu_flutter.png` mis à jour. `flutter analyze` : aucun problème.
- Générateur : `node tools/corps/gen.js` écrit aussi `planche-muscles.html` (chaque muscle de l'enum coloré seul, face et dos, à 300 px et à 80 px, à côté de `ref4`) ; `tools/corps/vue.sh fichier.svg sortie.png échelle [x y l h]` capture une vue ou une zone. Captures dans `tools/corps/captures/` : `final-controle-t2`, `final-face-t2`, `final-dos-t2`, `final-face-rouge-t2`, `final-dos-rouge-t2`, `final-planche-muscles-t2`, `final-planche-80px-t2`, `final-rendu-flutter-t2`, gros plans `z-torse`, `z-abdos`, `z-tete`, `z-epaule`, `z-main`, `z-genou`, `z-pied`, `z-dos`, `z-fessiers`, `z-mollets`, `z-bras-dos` (tous en `-t2`).

**Limites**
- Les trapèzes et le cou restent de petites zones vues de face (anatomiquement étroites) ; ils se lisent surtout de dos.
- À 0,15 d'intensité, un muscle garde un rouge désaturé proche du vieux rose : c'est le prix d'une luminosité constante.

**Demandes**
- DIRECTEUR ARTISTIQUE : revue 3 sur les captures `-t2` et `planche-muscles.html`.
- Aucune demande aux autres modules : l'API ne change pas.

### ENTRAÎNER, BIBLIOTHÈQUE D'EXERCICES (annonce de début, API figée)

**Qui possède quoi**
- `lib/features/entrainer/routes.dart` (fonction `entrainerRoutes()`) et la page racine `/entrainer` : à moi (bibliothèque). Mon code vit dans `lib/features/entrainer/bibliotheque/`, la page racine dans `lib/features/entrainer/accueil/`.
- Agent ROUTINES : merci d'exposer dans `lib/features/entrainer/routines/routines_routes.dart` une fonction `List<RouteBase> routinesSubRoutes()` qui rend des routes **relatives** (sans `/` en tête, ex. `routines/:id`, `programmes`, `dossiers/:id`, `historique`), je les pose sous `/entrainer` dans `entrainerRoutes()`. Si elle n'existe pas encore quand je termine, je laisse un import commenté et je le branche dès qu'elle apparaît. Chemins que la page racine ouvre (à créer de ton côté, dis-moi si tu en changes un) : `/entrainer/routines/nouvelle`, `/entrainer/routines/:id`, `/entrainer/programmes`, `/entrainer/programmes/:id`, `/entrainer/dossiers/:id`, `/entrainer/historique`, `/entrainer/historique/:sessionId`.
- La page racine lit directement `RoutineRepo`, `ProgramRepo`, `SessionRepo` pour ses aperçus (routines, programme actif, dernières séances) et lance une séance vide avec `SessionRepo.startEmpty()` puis `context.push('/seance')`.

**Routes de la bibliothèque** (toutes sous `/entrainer`, plein écran avec `parentNavigatorKey: rootNavigatorKey`)
- `/entrainer/exercices` : bibliothèque (recherche, filtres muscle / matériel / catégorie, récents, favoris, perso).
- `/entrainer/exercices/nouveau` : création d'un exercice perso.
- `/entrainer/exercices/:id` : fiche (onglets Comment faire, Muscles, Historique, Graphiques, Records). Paramètre de requête facultatif `?onglet=historique|graphiques|records|muscles`.
- `/entrainer/exercices/:id/modifier` : édition d'un exercice perso.

**API du sélecteur réutilisable** (routines, séance, import...)
```dart
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';

// Plein écran par-dessus tout (navigateur racine). Rend les id choisis dans
// l'ordre de sélection, ou null si annulé. Jamais de liste vide.
final ids = await pickExercises(
  context,
  multi: true,                 // false : un seul, validé au toucher
  dejaPresents: {'developpe-couche'}, // marqués « Déjà ajouté », restent choisissables
  titre: 'Ajouter des exercices',
  boutonLabel: 'Ajouter',      // devient « Ajouter (3) »
  musclesInitiaux: const {},   // filtre de départ facultatif
);
// Remplacer un exercice (séance, routine) :
final id = await pickExercise(context, titre: 'Remplacer', remplace: 'developpe-couche');
```
- Le sélecteur propose aussi « Créer un exercice » (l'exercice créé revient sélectionné).
- Widgets réutilisables exportés par le même fichier : `ExerciseThumb(exercise, size: 48)` (vignette carrée fond blanc arrondi, jamais étirée), `ExerciseMediaView(exercise)` (animation en grand avec secours et crédit), `ExerciseTile(exercise, onTap, trailing)` (ligne de liste standard), et `ouvrirFicheExercice(context, id)`.

### ENTRAÎNER, ROUTINES ET PROGRAMMES (annonce ; voir la section finale plus bas)

**Routes annoncées** (sous-routes de `/entrainer`, fournies par `routinesSubRoutes()` de `lib/features/entrainer/routines/routines_routes.dart`, à mettre dans `routes:` de la route `/entrainer`)
- `/entrainer/routines` liste des routines en dossiers ; `/entrainer/routines/nouvelle?dossier=<id>` éditeur (plein écran) ; `/entrainer/routines/:id` aperçu avec bouton Démarrer ; `/entrainer/routines/:id/modifier` éditeur.
- `/entrainer/programmes` programme actif, mes programmes, modèles ; `/entrainer/programmes/modele/:modeleId` ; `/entrainer/programmes/nouveau` ; `/entrainer/programmes/:id` ; `/entrainer/programmes/:id/modifier`.

**Widgets réutilisables** (`import '.../entrainer/routines/routines.dart';`)
- `ProchaineSeanceCard()` : programme actif, semaine, prochaine séance, bouton Démarrer (pour Aujourd'hui et l'accueil Entraîner).
- `RoutinesApercu(max: 4)` : les routines en liste courte avec « Tout voir › ».
- `demarrerRoutine(context, routine, {programId})` : gère la séance déjà en cours, applique la progression du programme, puis ouvre `/seance`.

**Demande à l'agent BIBLIOTHÈQUE** : merci d'annoncer ici la signature de votre sélecteur. J'attends `Future<List<String>?> choisirExercices(BuildContext context, {bool multi = true, Set<String> dejaChoisis = const {}, String titre})` (ids choisis dans l'ordre de sélection) et la route de la fiche exercice (`/entrainer/exercices/:id` ?). En attendant, je code contre un sélecteur local de secours dans mon dossier.

### ENTRAÎNER, BIBLIOTHÈQUE : réponse à ROUTINES (en cours)
- Sélecteur : `pickExercises` est annoncé plus haut ; j'exporte aussi exactement ta signature `choisirExercices(BuildContext context, {bool multi = true, Set<String> dejaChoisis = const {}, String titre = 'Ajouter des exercices'})` -> `Future<List<String>?>`, depuis `lib/features/entrainer/bibliotheque/bibliotheque.dart`. Fiche : route `/entrainer/exercices/:id`, mais depuis une page hors de l'onglet (séance, éditeur plein écran) préfère `ouvrirFicheExercice(context, id)` (push sur le navigateur racine, sans remonter la coquille).
- Je branche `routinesSubRoutes()` sous `/entrainer` dans `entrainerRoutes()` et j'utilise `ProchaineSeanceCard()`, `RoutinesApercu(max: 4)` et `demarrerRoutine` sur la page racine dès qu'ils existent.
- Dossiers : la page racine ouvre `/entrainer/routines` (qui montre les dossiers). Historique : **je ne le fais pas**, SÉANCE l'annonce dans `seance_paths.dart` (`/seance/historique`, `/seance/historique/:id`). La page racine et l'onglet Historique de la fiche y renvoient. `/entrainer/historique` reste valable : c'est une redirection vers `/seance/historique` (pour IMPORT). Agent SÉANCE : mon sélecteur `pickExercises` et ma fiche `ouvrirFicheExercice` existent, libre à toi de t'en servir pour `/seance/choisir` et `/seance/exercice/:id`.

### PROFIL ET RÉGLAGES (annonce, en cours)

**Routes** (hors onglets, plein écran) : `/profil` (profil), `/profil/modifier?section=identite|corps|objectif|entrainement|materiel|photo`, `/profil/badges`, `/profil/carriere`, `/reglages` (liste, volets côte à côte sur le Fold ouvert), `/reglages/apparence`, `/reglages/unites`, `/reglages/entrainement`, `/reglages/entrainement/disques` (barres, disques, calculateur), `/reglages/notifications`, `/reglages/sante`, `/reglages/coach`, `/reglages/donnees`, `/reglages/a-propos`, `/reglages/dev` (page cachée : 7 appuis sur la version).

**Préférences lisibles par tous** (`lib/features/profil/data/prefs.dart`, collection `preferences` du Store, donc dans la sauvegarde) : `await PrefsRepo.ensure(context.read<Store>())` puis `PrefsRepo.instance.prefs` (ChangeNotifier) : `longueur` (cm / in), `energie` (kcal / kJ), `tailleTexte.facteur`, `minuteurAuto` (lancer le repos quand une série est cochée), `barres`, `barre` (barre par défaut), `disques` (poids en kg + paires). Calculateur : `Plates.charger(cibleKg, barreKg, disques)` dans `lib/features/profil/data/plates.dart`. Conversions : `Unites.taille(cm, u)`, `Unites.energieAffichee(kcal, u)`.

**Rappels** : `Reminders.planifier(settings, prefs, complements:)` dans `lib/features/profil/data/reminders.dart` (ids 7100 à 7199 réservés : séance, compléments, eau).

**Questions**
- IMPORT : je vois `lib/features/import/data/sauvegarde.dart` et `exporters.dart`. Si tu fais des écrans d'export et de sauvegarde / restauration (avec médias en zip), annonce leurs routes : Réglages > Données y renverra plutôt que de refaire. Sinon je garde mes écrans simples (JSON d'`AppData.exportBackup`, CSV des séances).
- INSCRIPTION : pour « Modifier le profil », j'ai besoin de savoir si tes étapes (`PrenomStep`, `TailleStep`...) s'utilisent hors du parcours (constructeur `valeur` + `onChanged`) ou si tu exposes une route d'édition. En attendant, `/profil/modifier` a son propre formulaire complet.
- COACH : as-tu une page de réglages (clé, modèle, ton) ? Donne la route, Réglages > Coach y renverra.

### IMPORT / EXPORT (annonce, en cours ; section complète à la fin)

**Réponse à PROFIL** : oui, je fais les écrans d'export et de sauvegarde / restauration (JSON ou ZIP avec photos). Réglages > Données peut y renvoyer :
- `/import` : accueil (importer, exporter, sauvegarde, imports précédents). Paramètre facultatif `?retour=<chemin>` : où revenir à la fin d'un import (l'inscription s'en sert).
- `/import/export` : export CSV ou JSON (séances, exercices perso, mesures, sommeil, journal alimentaire, eau), période, séparateur, partager ou enregistrer.
- `/import/sauvegarde` : créer une sauvegarde (complète en ZIP avec photos, ou données seules en JSON), restaurer (`/import/sauvegarde/restaurer` après choix du fichier).
- `/import/journal` : imports précédents, annulation d'un import.
- INSCRIPTION : l'étape « importer mon historique » peut faire `context.push('/import?retour=/bienvenue/...')` ; sans profil, l'accueil cache l'export. Après l'import, le bouton « Continuer » fait `context.go(retour)`.
- Historique : le résumé d'import renvoie vers `/entrainer/historique` (annoncé par BIBLIOTHÈQUE).

### COACH IA (annonce, en cours ; section complète à la fin)
- Réponse à PROFIL : oui, les réglages du coach sont sur `/coach/reglages` (clé `/coach/reglages/cle`, modèle `/coach/reglages/modele`, données partagées `/coach/reglages/donnees`, aperçu `/coach/reglages/contexte`). Réglages > Coach peut faire `context.push('/coach/reglages')`.
- Pour AUJOURD'HUI : `import '.../features/coach/coach.dart';` puis `const CoachDailyCard()` (phrase du jour, un toucher ouvre le coach) et `const CoachWeekCard()` (bilan de la semaine, mis en avant le dimanche). `openCoachChat(context, question: '...')` ouvre le coach sur une question.

### ENTRAÎNER, ROUTINES ET PROGRAMMES (livré)

**Routes** (relatives sous `/entrainer`, via `routinesSubRoutes()`, déjà branchées par BIBLIOTHÈQUE dans `entrainerRoutes()`)
- `/entrainer/routines` : routines rangées en dossiers repliables, recherche (au-delà de 5), mode Réorganiser (glisser les routines, flèches pour les dossiers), nouveau dossier ; menu de dossier (ouvrir, nouvelle routine ici, renommer, partager en texte, supprimer en gardant ou non ses routines) ; menu de routine (démarrer, modifier, renommer, dupliquer, déplacer, partager en texte, supprimer avec annulation et avertissement si un programme l'utilise). États vide, chargement, recherche sans résultat.
- `/entrainer/routines/nouvelle?dossier=<id>&retour=1` et `/entrainer/routines/:id/modifier` (plein écran) : éditeur. Nom, notes, dossier, ajout via `pickExercises` de la bibliothèque, glisser pour réordonner, carte d'exercice calquée sur la référence (vignette, « Ajouter une note... », « Minuteur de repos : 2:30 », tableau SÉRIE / CIBLE / KG / RPE, « + Ajouter une série »), boîte de série (type échauffement / normale / dégressive / échec, reps ou fourchette ou libres, durée, distance, charge ou « auto », RPE visé, appliquer à toutes, supprimer), glisser une série pour la supprimer, menu par exercice (remplacer, fiche, superset avec le suivant, sortir du superset, repos, note, échauffement auto à 50 %, dupliquer, retirer avec annulation), mode superset (cocher plusieurs exercices puis Lier, lettre et couleur par groupe), partager en texte, confirmation avant d'abandonner. Avec `retour=1`, la page rend l'id créé (utilisé par l'éditeur de programme). Fold ouvert : formulaire et personnage à gauche, exercices à droite.
- `/entrainer/routines/:id?programme=<id>` : aperçu avant de lancer. Encadré Durée / Volume / Séries, dernière fois, notes, personnage face et dos (`BodyMapDual`, intensité par séries) et barres `MuscleBar` par muscle, exercices avec leurs séries, supersets. Avec `programme`, la progression du programme est appliquée (charges, reps, décharge) et affichée par exercice. Bouton Démarrer.
- `/entrainer/dossiers/:id` : page d'un dossier (routines, durée totale, muscles couverts, renommer, partager, supprimer, nouvelle routine).
- `/entrainer/programmes` : programme actif (`ProchaineSeanceCard`), mes programmes (terminé, en pause, pas commencé), 6 modèles : Débutant 3 jours, Full body 3 jours, 5x5, Haut/Bas 4 jours, Push Pull Legs 6 jours, Arnold split (ids du catalogue, avec des ids de secours ; test : aucun exercice manquant).
- `/entrainer/programmes/modele/:modeleId` : description, progression, conseils, muscles sur un cycle, séances ; « Utiliser ce programme » (durée, jours de la semaine, le suivre tout de suite) crée un dossier du même nom, les routines, le programme et son plan.
- `/entrainer/programmes/nouveau` et `/:id/modifier` (plein écran) : nom, description, semaines, séances par semaine, jours L M M J V S D, niveau, progression (aucune, charge progressive, double progression, ondulée par semaine), incrément, décharge toutes les N semaines, cycle de routines (ajouter, créer, glisser, retirer).
- `/entrainer/programmes/:id` : avancement, prochaine séance, progression, semaine par semaine (faite, prochaine, à venir, décharge ou phase), cycle A B C, séances faites ; suivre, mettre en pause, reprendre, recommencer, dupliquer, partager, supprimer.

**Réutilisable** (`lib/features/entrainer/routines/routines.dart`) : `ProchaineSeanceCard(masquerSiVide:)`, `RoutinesApercu(max:)`, `RoutineTile`, `RoutineMenuButton`, `demarrerRoutine(context, routine, programId:)` (séance déjà en cours : reprendre ou abandonner ; progression appliquée ; ouvre `/seance`), `routinePrevue`, `ProgramPlanRepo.of(store)`.

**Données** : collection `programmes_plans` dans le Store (progression, incrément, décharge, jours, modèle d'origine), par programme ; le reste passe par `RoutineRepo` et `ProgramRepo` sans rien changer au noyau.

**Tests** : `test/entrainer/routines_test.dart` (8 tests : séries par muscle, supersets, charge progressive, double progression, décharge, JSON du plan, création des 6 modèles avec le vrai catalogue). `test/entrainer/routines_rendu_test.dart` rend les pages en démo dans `build/rendus/routines/` (Fold fermé et ouvert). `flutter analyze` : aucun problème.

**Limites**
- La séance est lancée avec la routine ajustée ; les séries « auto » reprennent la dernière performance (`startFromRoutine`).
- Les séances de la démo n'ont pas de `programId` : « Séances faites » du programme de démo reste vide.

**Demandes**
- SÉANCE : à la fin d'une séance lancée par `demarrerRoutine(..., programId:)`, appeler `ProgramRepo.advance(programId)` (déjà demandé par la fondation), sinon le programme n'avance pas.
- FONDATION : le correctif de `SubPageScaffold` ci-dessus (Demandes) ; ensuite `SousPage` pourra redevenir un simple `SubPageScaffold`.
- DÉMO (fondation) : mettre `programId` sur les séances Push/Pull/Legs générées pour que le programme de démo ait son historique.

### NUTRITION (module complet, 30/09)

**Routes** (`nutritionRoutes()` dans `lib/features/nutrition/routes.dart` ; ouvertures typées dans `lib/features/nutrition/nav.dart`, classe `NutritionNav`)
- Dans l'onglet (barre du bas visible) : `/nutrition` journal (paramètre facultatif `?jour=2026-09-30` pour ouvrir un jour précis, utile à AUJOURD'HUI), `/nutrition/calendrier`, `/nutrition/repas/:repas?jour=` (`petitDejeuner|dejeuner|collation|diner`, ou `journee` pour tout le jour), `/nutrition/eau`, `/nutrition/objectifs`, `/nutrition/statistiques`, `/nutrition/aliments`, `/nutrition/repas-enregistres`, `/nutrition/recettes`, `/nutrition/reglages`.
- Plein écran (navigateur racine) : `/nutrition/ajouter?jour=&repas=&scan=1` (recherche, onglets Récents / Favoris / Mes aliments / Repas / Recettes ; `?choisir=1` rend un `MealItem`), `/nutrition/scanner` (rend le code lu), `/nutrition/aliment` (extra `FoodPageArgs` : ajouter, modifier une entrée, choisir), `/nutrition/aliment-perso?code=&nom=` (extra `Food` pour modifier, rend l'aliment), `/nutrition/ajout-rapide?jour=&repas=` (extra `FoodEntry` pour modifier), `/nutrition/repas-enregistres/edition` (extra `Meal`), `/nutrition/recettes/edition` (extra `Recipe`), `/nutrition/recettes/fiche/:id?jour=&repas=`.

**Écrans et sous-pages**
- Journal : sélecteur ‹ Aujourd'hui › (toucher = calendrier ou retour à aujourd'hui), bande de la semaine avec anneau de calories par jour, carte CALORIES (restantes en grand, anneau, barres protéines / glucides / lipides / fibres, étiquette jour d'entraînement ou de repos si cyclage), bouton Ajouter + scan + ajout rapide, carte Eau (verres cliquables, +verre, autre quantité, annuler), quatre repas renommables (entrées : toucher = modifier, glisser = supprimer avec annulation, appui long = déplacer, dupliquer, copier vers un jour, favori), « Copier celui de la veille » sur un repas vide, menu de repas (copier depuis / vers un jour, enregistrer comme repas, en faire une recette, renommer, détail, vider), menu général (objectifs, listes, copier un jour entier, réglages). Fold ouvert : résumé à gauche, repas à droite.
- Ajouter : recherche locale + base en ligne (Open Food Facts, moteur `search.openfoodfacts.org` en français, secours `cgi/search.pl`, lecture du code `api/v2/product`), anti-rebond, états chargement / erreur réseau avec Réessayer / aucun résultat / recherche coupée, recherches récentes, ajout direct « + » avec annulation, création d'aliment si introuvable, changement de repas et de jour. Cache local 14 jours (collection `nutrition_cache_en_ligne`, relu hors ligne).
- Scanner plein écran (mobile_scanner) : cadre, lampe, saisie manuelle du code, lecture depuis une photo, écran d'erreur si caméra refusée (ouvrir les réglages). Produit inconnu : création de l'aliment avec le code prérempli.
- Fiche aliment : quantité (±, saisie), unités g/ml et portions, valeurs de la quantité ou pour 100, anneau de répartition, fibres / sucres / sel, Nutri-Score A à E, favori, modifier (perso ou recette), supprimer (mode modifier).
- Aliment perso (valeurs de l'étiquette pour 100 ou pour une autre base, calcul des kcal depuis les macros, contrôle d'écart, portions, code-barres scanné, boisson), Mes aliments (Créés / Favoris / Enregistrés, filtre, menu), Repas enregistrés (liste, éditeur avec réordonnancement, ajout au journal), Recettes (liste, éditeur avec portions et poids cuit, fiche avec nombre de portions et ajout). Chaque recette est aussi un aliment `recette-<id>` (recherche, récents, favoris).
- Ajout rapide (kcal ou macros seules, nom facultatif), Eau (anneau, historique des verres, sept jours, objectif, taille du verre), Objectifs (Mifflin-St Jeor détaillé depuis le profil, « Utiliser » le recommandé, grammes ou pourcentages, ajustement des glucides, fibres, eau, cyclage par jours de semaine et/ou séances enregistrées), Statistiques (7 / 30 / 90 jours : moyenne, jours notés, série, barres de calories avec objectif, courbe des protéines, macros moyennes, respect des objectifs, eau, aliments les plus notés, calories par repas), Calendrier (mois, pastille par jour selon l'objectif, résumé du mois), Détail d'un repas ou de la journée, Réglages (noms des repas, verre, recherche en ligne, cache, recherches récentes, rétablir).

**Fichiers** : `lib/features/nutrition/` (`routes.dart`, `nav.dart`, `data/` : `nutrition_extras.dart` réglages du module + recettes + Nutri-Score + jour affiché, collections `nutrition_reglages` et `nutrition_recettes` ; `off_client.dart` ; `nutrition_logic.dart` objectifs du jour, totaux, série, extension `NutritionRepoX` (déplacer, dupliquer, copier un repas, supprimer plusieurs) ; `recipe.dart`), `pages/` (15 pages), `widgets/` (`nutri_widgets.dart`, `journal_actions.dart`, `nutri_page.dart`). Tests : `test/nutrition/nutrition_logic_test.dart` (4 tests verts), `test/nutrition/rendu_nutrition_test.dart` (captures Fold fermé et ouvert dans `build/rendus/nutrition/`, lancé seulement avec `--dart-define=RENDU=true`).

**Réutilisable par les autres** : `NutritionNav.addFood(context, jour:, repas:)`, `NutritionNav.quickAdd(...)`, `context.go('/nutrition?jour=...')`, `NutritionLogic.goalsFor(jour, profil:, cyclage: NutritionExtras.of(context).cyclage, sessions:)` pour afficher les objectifs du jour (cyclage compris) sur Aujourd'hui, `NutritionExtras.of(context).nomRepas(MealType)` pour les noms personnalisés.

**Limites**
- Couleurs des macros prises dans les domaines (protéines bleu, glucides jaune, lipides lavande ; calories à l'accent). Seule couleur écrite en dur : les cinq teintes officielles du logo Nutri-Score (`NutriScoreBadge`).
- `NutritionExtras` garde ses réglages en mémoire : après `AppData.resetAll()` ou une restauration de sauvegarde, ils ne sont relus qu'au redémarrage (les fichiers, eux, sont bien effacés ou restaurés).
- Pas de synchronisation Health Connect de la nutrition ni de rappel d'eau (le rappel d'eau est annoncé côté PROFIL, ids 7100 à 7199).
- Scanner non testé sur appareil (pas d'émulateur libre) ; contrôle visuel par rendu hors écran seulement.

**Demandes**
- FONDATION/THÈME : +1 à la demande de ROUTINES sur la `bottomBar` de `SubPageScaffold` (elle prend toute la hauteur). En attendant, mes pages passent par `NutriSubPage` (`widgets/nutri_page.dart`) ; une fois corrigé, un simple remplacement par `SubPageScaffold` suffit.
- FONDATION : `NutritionRepo` n'a pas de suppression d'un verre précis (seulement `undoWater`) ; un `deleteWater(id)` permettrait de retirer un verre au choix dans l'historique de l'eau.
- FONDATION : le rendu hors écran échoue sur `assets/body/masques/manifeste.json` absent (asset du personnage demandé mais pas encore livré).
- AUJOURD'HUI : pour la carte nutrition, lien vers `/nutrition` (ou `NutritionNav.addFood`) et objectifs via `NutritionLogic.goalsFor` pour tenir compte du cyclage.
- IMPORT/EXPORT : les collections du module (`nutrition_reglages`, `nutrition_recettes`, `nutrition_cache_en_ligne`) sont dans le Store, donc dans la sauvegarde ; le cache en ligne peut être exclu de l'export si besoin.

### SÉANCE EN COURS ET HISTORIQUE (lib/features/seance/)

**Livraisons**
- Routes (toutes en plein écran hors onglets, chemins dans `SeancePaths` de `lib/features/seance/seance_paths.dart`, exporté par `routes.dart`) :
  - `/seance` : séance en cours ; sans séance, écran « Démarrer une séance » (séance vide, programme en cours et sa prochaine routine, mes routines avec bouton lecture, refaire une des 3 dernières séances, accès à l'historique).
  - `/seance/vide`, `/seance/routine/:id?programme=<id>`, `/seance/refaire/:id` : pages d'aiguillage qui démarrent puis ouvrent `/seance` (question « Abandonner et démarrer / Garder l'actuelle » si une séance tourne déjà ; état d'erreur si la routine ou la séance n'existe plus). Pour lancer une séance depuis un autre module, un simple `context.push(SeancePaths.routine(id, programId: ...))` suffit.
  - `/seance/reordonner` (glisser-déposer), `/seance/disques?poids=<kg>&exercice=<id d'emplacement>` (calculateur de disques et d'échauffement), `/seance/terminer` (fin de séance), `/seance/resume/:id?nouveau=1` (résumé), `/seance/historique`, `/seance/historique/:id` (détail), `/seance/historique/:id/modifier`.
- Écran de séance calqué sur les captures de référence : en-tête « ‹ Titre », minuteur manuel, bouton Terminer bleu, menu (renommer, réordonner, disques, minuteur, colonne RPE, cocher les séries remplies, historique, abandonner) ; encadré Durée / Volume / Séries aux bords fins ; exercices à plat (vignette, nom, « 2/4 faites », « ... » en accent), « Ajouter une note... », « Minuteur de repos : 2:30 » cliquable ; tableau SÉRIE / PRÉCÉDENT / KG / RÉPS / (RPE) / coche ; série validée en ligne vert sombre avec coche ronde verte et retour haptique ; « + Ajouter une série » en pilule grise. Colonnes adaptées au suivi de l'exercice (poids et reps, reps seules, lesté « +kg », assisté « -kg », durée, distance et durée, poids et durée). Précédent « 80 kg × 8 » apparié par type (échauffements entre eux), touché = recopié, et repris automatiquement si on coche une ligne vide. Types de série (menu sur le numéro : échauffement É, normale, dégressive D, échec), glisser vers la gauche pour supprimer avec « Annuler », supersets (lier au suivant, retirer, lettre et filet de couleur, le repos ne part qu'après le dernier exercice du superset), notes par exercice, remplacer, monter / descendre, retirer. Fold ouvert : volet de droite avec l'encadré, le minuteur et le personnage des muscles travaillés en direct.
- Minuteur de repos (`logic/repos_minuteur.dart`, `ReposMinuteur.instance`, partagé par toute l'appli) : démarre à la validation d'une série (repos de l'exercice, 60 s max après un échauffement), anneau, -15 / +15, passer, grand minuteur en dialogue, carillon synthétisé (sans fichier son, baisse la musique au lieu de la couper) et vibration selon les réglages, notification locale programmée quand l'appli passe en arrière-plan (id 4207, canal « Minuteur de repos », repli en inexact si l'alarme exacte est refusée), repos réellement pris noté sur la série (`tempsReposSec`). Respecte `PrefsRepo.prefs.minuteurAuto` (profil). Écran gardé allumé (wakelock) pendant la séance si `settings.garderEcranAllume`.
- Barre de séance minimisée : `SeanceMiniBarre()` (`lib/features/seance/routes.dart` l'exporte) : nom, chrono ou repos restant, séries faites, fil de progression, bouton passer le repos ou reprendre ; s'ouvre sur `/seance`. La flèche retour de la séance la réduit sans l'arrêter.
- Fin de séance : durée, volume, séries, avertissement des séries non cochées avec « Cocher les séries remplies », nom, ressenti (5 niveaux), notes, heure de fin corrigeable, enregistrement (`finishActive`, puis `ProgramRepo.advance` si la séance vient d'un programme). Résumé : records battus mis en valeur, muscles travaillés sur le personnage avec intensité et barres par muscle, ressenti et notes, « La prochaine fois » (surcharge progressive par exercice : +charge si tout est réussi, +1 rep dans la fourchette, consolider sous l'objectif ; pas doublé pour les jambes à la barre ou machine), proposition de mettre à jour la routine (charges du jour ou suggérées, ajout des exercices nouveaux, retrait des absents, aperçu avant / après), « Enregistrer comme routine » pour une séance libre, partage texte.
- Historique : mois par mois (sélecteur de mois), calendrier (jours d'entraînement en pastilles d'accent, filtre par jour), séances / volume / temps du mois, liste. Détail : chiffres, records de la séance, muscles, séries de chaque exercice avec 1RM estimé de la meilleure série, ressenti et notes ; actions Refaire, Modifier, Partager, Enregistrer comme routine, Supprimer (avec « Annuler »). Modifier : nom, date et heure, durée, ressenti, notes, exercices et séries (mêmes cartes que la séance), réordonner, confirmation si on quitte sans enregistrer.
- Réutilise : `pickExercises` / `pickExercise` / `ouvrirFicheExercice` / `ExerciseThumb` de la bibliothèque (plus de sélecteur ni de fiche en double), `PrefsRepo` et `Plates.charger` du profil pour le calculateur (barres et disques des réglages, lien « Modifier mon matériel » vers `/reglages/entrainement/disques`).
- Fichiers : `routes.dart`, `seance_paths.dart`, `logic/` (`editeur.dart` : opérations sur la séance en cours ou sur une copie de travail, `repos_minuteur.dart`, `analyse.dart` : bilan, records, surcharge, mise à jour de routine, texte partagé, `lancement.dart`), `pages/` (seance, demarrer_vue, lanceur, reordonner, disques, terminer, resume, historique, detail, modifier), `widgets/` (serie_ligne, exercice_carte, repos_panneau, mini_barre, bilan_widgets, barre_bas). Tests : `test/seance/seance_test.dart` (parcours Fold fermé et ouvert avec la démo, rendus dans `build/rendus/seance/` avec `RENDUS=1`, saisie, précédent, supersets, surcharge et routine). `flutter analyze lib/features/seance` : aucun problème.

**Limites**
- Le parcours de test Fold fermé échoue pour l'instant sur `assets/body/masques/manifeste.json` absent du paquet d'assets de test (fichier créé après la dernière construction de `build/unit_test_assets`) : rien à voir avec le module, il passera au prochain `flutter test` qui reconstruit les assets. Le parcours Fold ouvert et les tests de logique passent.
- La notification de fin de repos n'a pas de bouton d'action (+15 s) : un toucher rouvre l'appli.

**Demandes**
- FONDATION (`lib/app/shell.dart`) : remplacer `ActiveSessionBanner` par `SeanceMiniBarre()` (import `../features/seance/routes.dart`) : elle montre en plus le repos restant, les séries faites et un fil de progression, et permet de passer le repos sans ouvrir la séance. Même encombrement (marges 16, 6, 16, 0 réglables par `padding`).
- FONDATION (`lib/core/ui/app_scaffold.dart`) : bogue de `SubPageScaffold(bottomBar: ...)` : `ContentWidth` est un `Center` qui prend toute la hauteur dans `bottomNavigationBar`, la barre du bas se retrouve au milieu de l'écran et cache le contenu (vu en rendu sur Terminer et Résumé). Correctif : `Center(heightFactor: 1, ...)` dans `ContentWidth`, ou un `Align(alignment: Alignment.topCenter, heightFactor: 1)` pour la barre. En attendant, le module passe par son `SeanceSousPage` / `AvecBarreBas` (widgets/barre_bas.dart).
- AUJOURD'HUI, PROGRÈS, ENTRAÎNER : pour ouvrir une séance passée, `SeancePaths.detail(id)` a toutes les actions (modifier, refaire, partager, supprimer) ; pour lancer, `SeancePaths.vide`, `SeancePaths.routine(id)`, `SeancePaths.refaire(id)` ou `/seance` si `SessionRepo.hasActive`.

### PROGRÈS (onglet Progrès, lib/features/progres/)

**Livraisons**
- `progresRoutes()` remplace la page provisoire. Toutes les sous-pages restent dans l'onglet (barre du bas visible) :
  - `/progres` tableau de bord : périodes 4 sem. / 3 mois / 6 mois / 1 an / Tout ; séances, par semaine, jours actifs, variation contre la période d'avant ; tuiles Volume, Durée, Séries, Par semaine (avec écart) ; graphique Évolution (Séances, Volume, Durée, Séries) par semaine ou par mois avec la moyenne, une barre touchée ouvre ses séances ; records récents ; analyses ; aperçu du calendrier (17 semaines) ; muscles de la semaine sur `BodyMapDual` + muscles sous 10 séries ; carte Corps (poids, variation 30 jours, courbe, masse grasse, taille, bras, lien `/sante`). État vide : « Commencer une séance » (`/entrainer`) et « Importer un historique » (`/import`).
  - `/progres/calendrier` : vue Année en grille de contributions (intensité en accent selon les séries du jour, quartiles de l'historique), année précédente et suivante, séances, jours actifs, plus longue série de semaines, mois le plus actif, barres par mois (un mois touché ouvre la vue Mois) ; vue Mois en calendrier avec la liste des séances du mois. Un jour touché ouvre ses séances dans un dialogue.
  - `/progres/muscles` : semaine par semaine, séries ou volume, personnage face et dos, synthèse (muscles dans la cible de 10 à 20 séries, sous, au-dessus), muscles négligés, barres par muscle (tri volume, A à Z, région), en mode Volume les `MuscleBar` du noyau avec vignette anatomique.
  - `/progres/muscles/:muscle` (nom de l'enum) : séries de la semaine et statut, séries par semaine sur 4 / 12 / 26 semaines avec la bande 10 à 20, exercices qui le travaillent.
  - `/progres/records` : un record par exercice (1RM estimé, ou répétitions max sans charge), recherche, filtres Tout / Ce mois / 3 mois / 1 an et par région, tri (récents, progression, charge, A à Z), gain depuis la première séance, charge max, meilleure série.
  - `/progres/exercices` (choix d'un exercice déjà fait) et `/progres/exercices/:id` : courbe 1RM / Charge / Volume / Répétitions sur 3 mois à Tout, records avec la séance, charges conseillées de 1 à 12 répétitions (arrondies au pas des réglages), historique complet, dialogue des séries d'une séance, lien vers la fiche `/entrainer/exercices/:id`.
  - `/progres/comparer` : Mois, 4 semaines, 3 mois, Année ou périodes au choix (sélecteur de dates) ; chiffres côte à côte avec écart, séries par muscle et par semaine (deux barres), 1RM des exercices communs.
  - `/progres/bilan` (`?mois=2026-09` facultatif) : sélecteur de mois, séances, tuiles contre le mois d'avant, volume semaine par semaine, plus grosse séance, exercices phares, records battus, muscles du mois, poids du mois, partage du bilan en texte.
  - `/progres/seance/:id` : résumé en lecture d'une séance (volume, durée, séries, ressenti, notes, records battus, muscles, séries avec 1RM), boutons Refaire (`SeancePaths.refaire`) et Modifier (`SeancePaths.detail`, qui porte modifier, partager, supprimer).
- Fichiers : `logic/progres_stats.dart` (calculs purs : intervalles, résumés, paquets, records, progression, records battus, séries par muscle, niveaux du calendrier), `ui/progres_widgets.dart` (`BarresProgres` et `CourbeProgres` sur fl_chart, `BarreMuscle`, `CorpsDouble`, `ProgresGarde` qui gère chargement du catalogue et erreur avec « Réessayer »), `ui/calendrier_widgets.dart` (`GrilleContributions`, `LigneSeance`, `showSeancesDialog`), une page par écran.
- Tests : `test/progres/progres_stats_test.dart` (7 tests verts). `test/progres/progres_rendu_test.dart` : banc de rendu autonome (seulement mes routes, sans le routeur global), ignoré par défaut, `RENDU_PROGRES=1 [RENDU_LARGEUR=ferme|ouvert] flutter test test/progres/progres_rendu_test.dart` écrit `build/rendus/progres/*.png` en 380 et 900 de large. `flutter analyze` du module : aucun problème.

**Limites**
- Captures faites sans le personnage : `assets/body/masques/manifeste.json` manquait au moment du rendu, le corps apparaît vide et le banc lève l'erreur d'asset.
- Pas de graphique de poids détaillé ici : la carte Corps renvoie vers `/sante`.

**Demandes**
- SÉANCE : le résumé de séance du module ouvre `SeancePaths.detail(id)` et `SeancePaths.refaire(id)` (import de `seance_paths.dart` seulement) ; merci de garder ces chemins. ENTRAÎNER : la fiche est ouverte par `context.push('/entrainer/exercices/:id')`.
- SANTÉ : si une route directe de pesée existe (par exemple `/sante/poids`), dites-la ici, je pointerai la carte Corps dessus plutôt que sur `/sante`.
- PERSONNAGE : `BodyMap.aspectRatio` sert à caler la hauteur de `BodyMapDual` sur la largeur (sinon il déborde sur le Fold fermé à 300 de haut) ; merci de le garder, ou d'ajouter une taille qui s'adapte à la largeur.
- FONDATION / THÈME : `BigNumber` colle l'unité au chiffre à l'écran (« 12séances », « 76,7kg ») ; une espace fine entre les deux serait plus lisible pour les unités en mots.

### PROFIL ET RÉGLAGES (livré ; remplace l'annonce plus haut)

**Routes** (`profilRoutes()`, hors onglets, plein écran)
- `/profil` : avatar (photo ou initiale, appareil photo / galerie / retirer, copie dans `Store.mediaDir()`), prénom, âge · taille · poids (dernière pesée sinon profil), objectif et niveau en étiquettes, « Modifier le profil », carte Carrière (séances, volume total, heures, séries, semaines de suite, depuis quand ; état vide avec « M'entraîner » et « Importer mon historique »), Badges (4 médailles + prochain palier), Mon corps (âge, taille, poids, poids visé et écart, IMC), Mon entraînement (objectif, rythme, activité, matériel, muscles prioritaires, objectifs nutritionnels, programme conseillé, réglages). Fold ouvert : deux colonnes.
- Édition : **réutilise l'inscription** (`/bienvenue/modifier` et `/bienvenue/modifier/<etape>`). `/profil/modifier?section=identite|corps|objectif|entrainement|materiel` redirige vers l'étape correspondante.
- `/profil/badges` : 21 badges (régularité, volume, temps, constance, style, profil), filtre Tous / Obtenus / À obtenir, détail en dialogue avec date d'obtention ou progression.
- `/profil/carriere` : totaux (volume, heures, séries, reps, par semaine, durée moyenne, exercices avec record), séances des 12 derniers mois en barres, exercices phares (ouvrent `/entrainer/exercices/:id`), faits marquants (jour préféré, séance la plus longue et plus gros volume qui ouvrent `/entrainer/historique/:id`, première séance, série en cours), année par année.
- `/reglages` : carte profil + sections groupées ; sur le Fold ouvert liste à gauche et section à droite (`/reglages/<section>` ouvre aussi la vue à deux volets).
- `/reglages/apparence` : 5 accents (`AccentController.set`) avec aperçu en direct, taille du texte (Petite, Normale, Grande, Très grande) avec aperçu.
- `/reglages/unites` : kg / lb (profil), cm / pouces et kcal / kJ (préférences), début de semaine (`premierJourSemaine`).
- `/reglages/entrainement` : repos par défaut, minuteur automatique, son, vibration (essai à l'activation), écran allumé, RPE, échauffement, incrément (valeurs kg ou lb), barres et disques. `/reglages/entrainement/disques` : barres (ajouter, modifier, défaut, masquer, supprimer), disques (paires +/-), calculateur de charge avec dessin de la barre, remise à zéro en kg ou en livres.
- `/reglages/notifications` : autorisation Android (bandeau si bloquées), rappel de séance (heure, jours L M M J V S D), compléments (heure par défaut, heures propres à chaque complément prioritaires), eau (début, fin, intervalle), notification d'essai, réglages Android. Planification réelle (flutter_local_notifications + fuseau local).
- `/reglages/sante` : état Health Connect (absent, à mettre à jour, disponible, connecté), autoriser, installer, déconnecter (révocation), historique complet, liste des données partagées ; `settings.santeConnectee` suit l'état réel. Lien vers `/sante`.
- `/reglages/coach` : résumé (clé, modèle, ton, conversations) et lien vers `/coach/reglages`.
- `/reglages/donnees` : chiffres et poids des données ; importer (`/import`, `/import/journal`), exporter (`/import/export`), sauvegarde complète et restauration (`/import/sauvegarde`), copie rapide sur le téléphone (JSON, 10 dernières) et `/reglages/donnees/sauvegardes` (restaurer, envoyer, supprimer), `/reglages/donnees/effacer` (liste de ce qui disparaît, copie de sécurité facultative, suppression des copies facultative, saisie de EFFACER, double confirmation, puis `/bienvenue`).
- `/reglages/a-propos` : logo, version, code source, licences (`showLicensePage`), crédits, confidentialité. Sept appuis sur la version débloquent `/reglages/dev` : environnement, collections du Store (`/reglages/dev/collection/:nom`, JSON brut copiable), vitrine `/dev/composants`, remplir avec la démo, rejouer l'inscription, recharger, notifications (essai, replanifier, annuler, nombre en attente), masquer le mode.

**Fichiers** : `lib/features/profil/` (`routes.dart`, `data/` prefs, plates, career, backup_service, reminders, health_link, photo_profil ; `pages/` profil, badges, carrière, réglages et `pages/reglages/*` ; `widgets/`). Tests : `test/profil/profil_test.dart` (calculateur, préférences, rappels d'eau, lecture de sauvegarde, carrière et badges sur la démo, rendu de toutes les pages Fold fermé et ouvert ; `RENDU_PROFIL=1` écrit `build/rendus/profil/`).

**Pour les autres modules** : `PrefsRepo` (`await PrefsRepo.ensure(context.read<Store>())`, puis `PrefsRepo.instance.prefs`) : `minuteurAuto`, `barre`, `barres`, `disques`, `longueur`, `energie`, `tailleTexte`. `Plates.charger(cibleKg, barreKg, disques)`. `Reminders.planifier(...)` (ids 7100 à 7199 réservés).

**Limites**
- Version affichée en dur (`appVersion` dans `a_propos_section.dart`, à tenir égale à pubspec) : pas de package_info.
- Les rappels ne sont replanifiés qu'à la modification des réglages (le système les garde après redémarrage) ; changer ses compléments ne les replanifie pas tout seul.
- Pas vérifié sur appareil (rendu hors écran seulement) : Health Connect, notifications, image_picker.
- `SubPageScaffold.bottomBar` prend toute la hauteur (bug signalé par ROUTINES) : mes pages à bouton fixe passent par `AvecBoutonBas` (`lib/features/profil/widgets/setting_rows.dart`) en attendant le correctif du noyau.

**Demandes**
- FONDATION (`lib/app/app.dart`) : appliquer la taille du texte à toute l'appli. Dans `MaterialApp.router`, ajouter `builder: (context, child) => ListenableBuilder(listenable: PrefsRepo.maybeInstance ?? ChangeNotifier(), builder: (context, _) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2) ... multiplié par PrefsRepo.maybeInstance?.prefs.tailleTexte.facteur ?? 1), child: child!))`, et appeler `await PrefsRepo.ensure(store)` dans `main.dart` avant `runApp`. Sans cela, le réglage est enregistré mais ne s'applique qu'à son aperçu.
- FONDATION : même endroit, après le chargement, `Reminders.planifier(data.settings.settings, PrefsRepo.instance.prefs, complements: data.health.supplements)` une fois au démarrage (rattrape un changement de compléments).
- SÉANCE : lire `PrefsRepo.instance.prefs.minuteurAuto` pour lancer le repos à la série cochée, et proposer le calculateur (`Plates.charger` avec `prefs.barre` et `prefs.disques`).
- NUTRITION : afficher l'énergie en `prefs.energie` (`Unites.energieAffichee`) si tu veux suivre le réglage kJ.
- SANTÉ : afficher les tours et la taille en `prefs.longueur` (`Unites.longueurAffichee`).

### PERSONNAGE, refonte 3D (rendu anatomique réaliste)

**Livraisons**
- Nouveau personnage rendu depuis de vrais maillages 3D (BodyParts3D et Z-Anatomy) : `assets/body/face_base.png`, `dos_base.png` (760 x 1200), `face_buste_base.png`, `dos_buste_base.png` (1100 x 900), les couches de coutures `*_traits.png`, les masques par muscle `assets/body/masques/<vue>_<muscle>.png` et `masques/manifeste.json`. Anciens SVG rangés dans `assets/body/ancien/` (plus chargés).
- `pubspec.yaml` : une seule ligne ajoutée, `- assets/body/masques/` sous `assets:` (nécessaire, les sous-dossiers ne sont pas inclus par `assets/body/`).
- Widget réécrit, même API : `BodyMap(view, intensities, highlight, selected, onTap, height)` et `BodyMapDual(...)`, plus un paramètre facultatif `framing: BodyFraming.corps | BodyFraming.buste`. La couleur est multipliée sur le relief (fibres et ombrage visibles), le toucher lit les masques. `lib/core/ui/body/body_images.dart` (chargement, cache, masques à la demande, toucher), `body_map.dart`. `body_svg.dart` ne garde que `BodySvgRepository.precache()` pour `main.dart`.
- Script reproductible et sources : `tools/corps3d/` (README), planches de contrôle `tools/corps3d/captures/`. Tests `test/body/body_map_test.dart` (4 tests, capture `rendu_flutter.png`).

**Demandes**
- À PROPOS : reprendre l'attribution du personnage : « Personnage anatomique rendu d'après BodyParts3D, © The Database Center for Life Science (CC BY-SA 2.1 JP), et Z-Anatomy (CC BY-SA 4.0). Images du personnage sous licence CC BY-SA 4.0. » (détail dans `docs/SOURCES_CORPS.md`).
- Tous : `BodyMap.aspectRatio` vaut maintenant 760 / 1200 (corps) ; `BodyMap.aspectOf(BodyFraming.buste)` pour le buste. Le rouge par défaut reste `colors.muscle`.

### IMPORT / EXPORT (livraison)

**Livraisons**
- Routes (`importRoutes()` dans `lib/features/import/routes.dart`, plein écran hors onglets) :
  - `/import?retour=<chemin>` accueil : importer (« Une autre application de suivi (CSV) », « Tableau quelconque »), aide, exporter (masqué sans profil), sauvegarde, 3 derniers imports.
  - `/import/fichier` choix du fichier (sélecteur Android, tous types acceptés puis contrôlés : vide, binaire ou xlsx refusés, sauvegarde .json/.zip redirigée vers la restauration), analyse avec progression et erreurs.
  - `/import/apercu` (séances, période, format, séries, exercices, volume, durée, échauffements, doublons, barres par mois, carte des exercices, dernières séances) ; `/import/apercu/seances` (recherche, filtres à importer / déjà présentes) ; `/import/apercu/seances/:index` (séries, superset, correspondance de chaque exercice) ; `/import/apercu/messages`.
  - `/import/colonnes?depuis=apercu` association manuelle (extrait du fichier, 14 champs, obligatoires signalés, une colonne par champ, unité kg/lb/en-tête, ordre des dates, « deviner à nouveau »).
  - `/import/exercices` (onglets À confirmer / Reconnus / Perso, suggestions en un toucher, « Accepter les suggestions », « Créer les inconnus ») ; `/import/exercices/choisir?nom=` (suggestions scorées, recherche dans tout le catalogue avec vignettes, annuler un choix) ; `/import/exercices/nouveau?nom=` (nom, matériel, suivi, muscles sur `BodyMapDual` ou en puces).
  - `/import/options` (ajouter, remplacer les séances importées, tout remplacer avec confirmation ; unité par défaut ; garder les échauffements ; ignorer les séries vides ; récapitulatif) ; `/import/progression` (anneau, étapes, réessai) ; `/import/resume` (séances, séries, volume, perso créés, doublons, remplacées, records recréés, « Voir mon historique » vers `/seance/historique`, « Continuer » vers `retour`, annuler l'import) ; `/import/resume/records`.
  - `/import/export` : séances, exercices perso, mesures, sommeil, journal alimentaire, eau ; CSV (virgule ou point-virgule, kg ou lb, BOM pour Excel) ou JSON ; période (tout, 3 mois, 1 an, dates) ; Partager (plusieurs fichiers) ou Enregistrer (ZIP si plusieurs). Le CSV des séances se réimporte tel quel (vérifié par test).
  - `/import/sauvegarde` : complète (ZIP données + photos, chemins des photos réécrits à la restauration) ou données seules (JSON), date de la dernière sauvegarde ; `/import/sauvegarde/restaurer` (contenu par collection, avertissement, confirmation, écran de fin).
  - `/import/journal` (menu : oublier les correspondances, vider) et `/import/journal/:id` (détail, séances encore présentes, annulation qui retire aussi les exercices perso devenus inutiles).
  - `/import/aide` : formats, colonnes, dates, unités.
- Fichiers : `data/import_flow.dart` (état du parcours, analyse dans un isolat, import, annulation), `data/conversion.dart` (ImportedSession vers WorkoutSession, brouillons d'exercices perso), `data/import_journal.dart` (collections `import_journal` et `import_correspondances`), `data/repo_extensions.dart` (suppression groupée de séances en une écriture), `data/exporters.dart`, `data/fichiers.dart` (choisir, partager, enregistrer ; remplaçable en test), `data/sauvegarde.dart`, `widgets/import_widgets.dart`, `screens/*.dart`.
- Tests : `test/import/import_flow_test.dart` (import complet, doublons au second passage, perso retrouvés, annulation, remplacement, aller-retour CSV avec les deux séparateurs, fichiers invalides, sauvegarde) et `test/import/import_rendu_test.dart` (toutes les pages au Fold fermé et ouvert sans exception ; `RENDU_IMPORT=1` écrit `build/rendus/import/*.png`). `flutter analyze` : aucun problème.

**Limites**
- `PageImport` (dans `widgets/import_widgets.dart`) contourne le bogue de `SubPageScaffold(bottomBar:)` ; à remplacer par `SubPageScaffold` une fois corrigé.
- Pas de lecture Excel (.xlsx) : on demande un CSV. Les photos ne sont que dans la sauvegarde complète, pas dans l'export.
- L'eau est lue directement dans la collection `eau` du Store (NutritionRepo n'a pas d'accès global).

**Demandes**
- FONDATION : +1 sur `ContentWidth`/`bottomBar` (`Center(heightFactor: 1)` ou `Align` dans la barre du bas). Et, si possible, `NutritionRepo.allWaterLogs` et une suppression groupée `SessionRepo.deleteAll(ids)` (l'import a les siennes en extension).
- FONDATION : dans les tests, `assets/data/aliments.json` absent fait échouer tout test qui appelle `AppData.loadAll()` (erreur asynchrone après le test) ; un `[]` dans le dépôt ou un `try/catch` dans `NutritionRepo._loadCatalogue` réglerait ça.
- PROFIL : Réglages > Données peut renvoyer vers `/import/export`, `/import/sauvegarde` et `/import/journal`.
- INSCRIPTION : pour l'étape d'import, `context.push('/import?retour=<chemin de l'étape suivante>')` ; tout le parcours marche sans profil.

### SANTÉ (sommeil, corps, récupération, activité, compléments, Health Connect)

**Livraisons**
- `lib/features/sante/routes.dart` : `santeRoutes()` remplace la page provisoire. Toutes les routes sont hors onglets (plein écran) :
  - `/sante` tableau de bord : cartes Sommeil (dernière nuit, 7 barres), Corps (poids, tendance 30 j, masse grasse, courbe), Récupération (muscles prêts et personnage face et dos), Activité (anneau des pas, calories actives, cœur au repos), Compléments (cases du jour cochables sur place), Photos ; raccourcis (noter ma nuit, me peser, photo, Health Connect) ; bandeau « Relier Health Connect » tant que rien n'est relié. Deux colonnes sur le Fold ouvert.
  - Sommeil : `/sante/sommeil` (dernière nuit avec phases ; stats de la période : moyenne, objectif tenu, coucher et lever moyens, régularité, qualité ; barres 7 j et 1 mois, courbe avec moyenne mobile sur 3 mois et 1 an ; objectif réglable ; 7 dernières nuits), `/sante/sommeil/historique` (par mois), `/sante/sommeil/ajouter`, `/sante/sommeil/nuit/:id` (anneau par rapport à l'objectif, heures, qualité et note modifiables sur place, détail des phases, suppression avec annulation), `/sante/sommeil/nuit/:id/modifier`. Saisie : jour du réveil, coucher, lever (coucher de la veille déduit), qualité de 1 à 5, phases facultatives, note, contrôle des incohérences, doublon du jour proposé au remplacement, confirmation avant d'abandonner.
  - Corps : `/sante/corps` (poids, objectif du profil en jauge, masse grasse, masse maigre, IMC, rythme par semaine, courbe du poids avec moyenne mobile sur 7 jours glissants et ligne d'objectif, courbe de masse grasse, mensurations, photos), `/sante/corps/mesure` (`?id=` pour modifier, `?tours=1` pour ouvrir sur les tours : poids, masse grasse, masse musculaire, 13 tours avec conseil de placement du mètre ruban et dernière valeur en indice), `/sante/corps/mesures` (historique filtrable, modifier, supprimer avec annulation), `/sante/corps/mensurations`, `/sante/corps/tour/:groupe` (`bras, poitrine, taille, hanches, cuisses, mollets, cou, epaules, avantBras` ; courbe et relevés gauche et droite), `/sante/corps/photos` (grille filtrable Face, Profil, Dos ; ajout par l'appareil ou la galerie avec image_picker ; récupération d'une photo perdue quand Android ferme l'appli), `/sante/corps/photos/:id` (plein écran zoomable, date, vue, poids, note, supprimer, comparer), `/sante/corps/comparer?avant=&apres=&vue=` (curseur glissant avant et après, ou côte à côte ; choix des deux photos, inversion, écart de poids).
  - Récupération : `/sante/recuperation` (BodyMapDual coloré par `Recovery.fatigue`, toucher un muscle ouvre son détail, filtres Tous, En récupération, Prêts ; lignes avec vignette du personnage en buste, jauge et délai ; rafraîchi chaque minute ; explication du calcul), `/sante/recuperation/:muscle` (nom de l'enum : % récupéré, « Prêt dans X h », séries et volume sur 7 jours, séances, dernière séance vers `/entrainer/historique/:id`, exercices de la semaine et suggestions vers `/entrainer/exercices/:id`).
  - Activité : `/sante/activite` (jour par jour avec sélecteur, pas par rapport à l'objectif, calories actives et totales, cœur au repos et moyen, barres des pas et des calories sur 7 j et 1 mois, courbe du cœur au repos, objectif de pas réglable, tirer pour synchroniser).
  - Compléments : `/sante/complements` (jour réglable, cases à cocher, grille des 30 derniers jours, interrupteur des rappels, compléments en pause, modèles courants quand la liste est vide), `/sante/complements/ajouter?modele=creatine|whey|vitamine-d|omega-3|magnesium|cafeine`, `/sante/complements/:id` (série de jours, % sur 30 jours, calendrier de 8 semaines où l'on corrige un oubli, historique des prises, pause), `/sante/complements/:id/modifier` (nom, dose, unité, heures de prise, actif, note, supprimer).
  - `/sante/connexion` : explication, état (indisponible, à installer, à mettre à jour, pas autorisé, refusé, connecté), bouton d'autorisation, gestion des refus (après deux refus Android ne montre plus la fenêtre : renvoi vers les réglages de l'appli), ce qui est lu avec Autorisé ou Refusé par famille, « Compléter l'accès », synchroniser (30 jours) ou importer l'historique (12 mois), délier en gardant ou en effaçant les données importées. L'état est revérifié au retour dans l'appli.
- Services : `services/health_connect.dart` (`HealthConnectService.instance` : `etat`, `accordees`, `demanderAcces`, `installer`, `revoquer`, `synchroniser(healthRepo, journal, jours:)` ; nuits `SLEEP_SESSION` et phases, pesées et masse grasse, pas par jour, calories, fréquence cardiaque ; ids `hc-...`, source « health connect » ; une saisie manuelle du même jour reste prioritaire). `services/activite_journal.dart` (`ActiviteJournal.of(store)` : activité par jour, objectifs de pas et de sommeil, état de la synchro, nombre de refus ; collection `sante_activite` du Store, donc dans la sauvegarde ; données inventées en variante démo). `services/rappels_complements.dart` (branché sur `Reminders.planifier` du module Profil, voir Demandes). `connexion/connexion_page.dart` exporte `synchroniserSante(context, jours:)`.
- Calculs et composants du module : `common/sante_calculs.dart` (`Periode`, `SanteCalc.moyenneMobile / variation / ecartCoucher / heureMoyenne / serie`, `RecupCalc.calculer` et `pretDans`, `GroupeTour`), `common/sante_widgets.dart` (`SanteCourbe` et `SanteBarres` sur fl_chart, `CarteCourbe`, `MiniBarres`, `QualitePicker`, `ChampNombre`, `CorpsDouble`, `AvecBarre`).
- Tests : `test/sante/sante_test.dart` (9 tests verts : calculs, récupération, journal, saisie d'une nuit, ajout d'un complément puis case du jour, états vides). `test/sante/rendu_sante_test.dart` parcourt les 19 pages en démo et, avec `--dart-define=RENDU=true`, les rend dans `build/rendus/sante/` (`LARGE=true` pour le Fold ouvert). `flutter analyze lib/features/sante` : aucun problème.

**Limites**
- Lecture seule dans Health Connect, pas d'écriture. Pas de synchronisation en arrière-plan : au bouton, en tirant l'écran Activité, ou après l'autorisation.
- Contrôle visuel fait au rendu hors écran (DA noire définitive), pas sur le Fold. Au dernier passage, les pages avec le personnage ne se rendaient plus à cause du `BodyMap` en cours de refonte (voir Demandes).
- Photos copiées dans le dossier privé par `HealthRepo.addPhoto`, absentes de la sauvegarde JSON (le ZIP de l'agent Import les prend).

**Demandes**
- FONDATION : je confirme la demande de ROUTINES sur `SubPageScaffold.bottomBar` (le `Center` de `ContentWidth` prend toute la hauteur). En attendant, mes formulaires passent par `AvecBarre` (`common/sante_widgets.dart`).
- PERSONNAGE (bug bloquant) : dans `_BodyMapState.build` (`lib/core/ui/body/body_map.dart`, vers la ligne 135), quand `onTap` est donné, `body = LayoutBuilder(builder: ... child: body)` : la fermeture relit la variable `body` déjà réaffectée au `LayoutBuilder`, qui s'imbrique donc sans fin (débordement de pile au layout, vu sur `/sante/recuperation`). Correctif : `final dessin = body;` avant, puis `child: dessin`, et un peu avant `assets/body/masques/manifeste.json` manquait au lot d'assets des tests. Mes pages utilisent `BodyMap(view, intensities, height, framing)`, `BodyMapDual(intensities, selected, onTap, labels, spacing, height)` et `BodyMap.aspectRatio`.
- PROFIL : les rappels de compléments restent chez toi (`Reminders.planifier`, un rappel par heure distincte, sous `rappelsComplements`) : je ne programme aucune notification moi-même. Mes écrans activent l'interrupteur et appellent `Reminders.planifier(settings, prefs, complements: health.supplements)` après chaque ajout, modification, pause ou suppression. Quand tu changes l'interrupteur ou l'heure générale, passe bien `complements: context.read<HealthRepo>().supplements`. Mon lien « Heure générale et autres rappels » ouvre `/reglages/notifications`. Réglages > Santé peut renvoyer vers `/sante/connexion` pour relier, synchroniser et délier.
- AUJOURD'HUI et PROGRÈS : liens utiles : `/sante/sommeil/ajouter`, `/sante/corps/mesure`, `/sante/complements`, `/sante/recuperation`, `/sante/recuperation/<muscle>`, `/sante/activite`, `/sante/corps/comparer`.
- ENTRAÎNER : je renvoie vers `/entrainer/historique/:sessionId` et `/entrainer/exercices/:id` (annoncés) : merci de garder ces chemins.

### COACH IA (livré)

**Livraisons** (tout dans `lib/features/coach/`, rien touché hors du module ; tests dans `test/coach/`)
- Routes (`coachRoutes()`) : `/coach` accueil de l'onglet ; `/coach/discussion/:id` conversation plein écran (navigateur racine), `nouvelle` pour une nouvelle, `?q=` pour poser une question dès l'ouverture ; `/coach/historique` ; `/coach/bilan` (`?semaine=aaaa-mm-jj`) ; `/coach/conseils` ; `/coach/reglages` puis `/cle`, `/modele`, `/donnees`, `/contexte`.
- Accueil : question libre, suggestions tirées des données, phrase du jour (rafraîchissable), carte du bilan, 3 conseils du moment, dernières conversations. Deux colonnes sur le Fold ouvert. Bandeau « Mode hors ligne » avec « Ajouter une clé » quand il n'y a pas de clé.
- Conversation : markdown, réponse en flux (SSE), points « le coach réfléchit », bouton Arrêter, copier, nouvelle réponse, appui long (copier, modifier et renvoyer, supprimer), menu (renommer, épingler, copier la conversation, ce que voit le coach, réglages, supprimer), état vide avec suggestions, erreurs lisibles avec Réessayer et « Vérifier la clé », conversation introuvable. Une réponse continue si l'on quitte la page (moteur `CoachEngine`, un par Store).
- Actions validables d'un geste (blocs ```action du modèle, jamais affichés bruts) : nouvelle routine (aperçu détaillé, exercices introuvables créés en perso), modifier une charge dans les routines qui contiennent l'exercice, ajouter un repas au journal. Carte « appliquée » mémorisée, toast avec « Voir » (`/entrainer/routines/:id`, `/nutrition`).
- API Claude en HTTP direct (`data/claude_client.dart`) : Messages API en flux, modèle `claude-sonnet-5-5` par défaut, effort selon « Réflexion », repli serveur `fallbacks: "default"` sur les modèles qui l'acceptent, refus et réponses coupées gérés, erreurs 401/403/404/429/529 traduites ; liste des modèles lue avec la clé (sert aussi de test de clé).
- Contexte envoyé (`logic/coach_prompt.dart`) selon 8 interrupteurs (profil, séances, routines et programme, records et tendances, récupération, nutrition, sommeil, poids et mensurations) et une période de 14 à 90 jours ; page « Ce que voit le coach » montre le texte exact.
- Hors ligne (`logic/offline_coach.dart`) : conseils calculés (récupération, muscles oubliés, régularité, plateaux et hausses de 1RM, volume par groupe, protéines, calories selon l'objectif, eau, sommeil, poids), réponses du chat par thème, phrase du jour, suggestions.
- Phrase du jour (cache du jour, rédigée par l'IA si clé et réglage, sinon calculée) et bilan de la semaine (`logic/week_report.dart` : séances, volume et écart, séries, records, séries par muscle sur le personnage, nutrition, sommeil, poids ; texte hors ligne ou rédigé par le coach, rédigé tout seul le dimanche si réglé).
- Réglages : clé (afficher, coller, tester, remplacer, supprimer, lien vers la console), modèle (conseillés, disponibles avec la clé, identifiant libre), réflexion, ton, longueur, données partagées, phrase IA, bilan du dimanche, effacer l'historique, réglages par défaut. Réglages propres au coach dans la collection `coach_reglages` ; clé, modèle et ton dans `AppSettings`.
- Pour les autres modules : `import 'package:aesthetic/features/coach/coach.dart';` → `CoachDailyCard()`, `CoachWeekCard()`, `openCoachChat(context, question: ...)`.
- Tests : `test/coach/coach_logic_test.dart` (14 tests : actions, flux SSE simulé, en-têtes, erreurs, historique, moteur en ligne et hors ligne, contexte, bilan, tirets). `test/coach/coach_rendu_test.dart` rend toutes les pages (Fold fermé 380 et ouvert 900, avec et sans clé, réponse simulée et action appliquée) ; `RENDU_COACH=1` écrit `build/rendus/coach/`, `RENDU_CORPS=1` ajoute bilan et conseils (personnage).

**Limites**
- Pas d'outil (tool use) : les actions passent par des blocs JSON dans le texte, validés côté appli. Pas de pièce jointe (photo de repas) dans le chat.
- Le bilan et les conseils utilisent `BodyMapDual` : pendant la refonte du personnage, `assets/body/masques/manifeste.json` manquait et faisait échouer leur rendu en test. `assets/data/aliments.json` absent fait aussi remonter une erreur du socle quand deux tests chargent la démo à la suite : lancer les variantes du rendu une par une (`--plain-name`).

**Demandes**
- FONDATION : `SubPageScaffold(bottomBar: ...)` est cassé : `ContentWidth` (un `Center`) prend toute la hauteur dans `bottomNavigationBar`, la barre se retrouve au milieu de l'écran et le contenu disparaît (vu sur mes captures). Correctif proposé dans `lib/core/ui/app_scaffold.dart` : `Align(heightFactor: 1, ...)` ou `Center(heightFactor: 1, ...)` pour la barre. En attendant, le coach pose sa propre barre (`CoachBottomBar`) ; les autres modules qui utilisent `bottomBar` sont touchés.
- PROFIL : Réglages > Coach peut faire `context.push('/coach/reglages')`. Attention, `AppData.exportBackup` contient la clé API du coach (dans les réglages) : prévenir à l'export ou la retirer.
- AUJOURD'HUI : poser `const CoachDailyCard()` (et `const CoachWeekCard()` le dimanche) sur l'accueil.

### AUJOURD'HUI (onglet d'accueil, livré)

**Livraisons**
- `lib/features/aujourdhui/routes.dart` : `aujourdhuiRoutes()` remplace la page provisoire. Chemins dans `AujourdhuiPaths` (tous sous l'onglet, barre du bas visible) :
  - `/` accueil ; `/aujourdhui/seance-du-jour` ; `/aujourdhui/recuperation` et `/aujourdhui/recuperation/:muscle` (nom de l'enum `Muscle`) ; `/aujourdhui/nutrition` ; `/aujourdhui/sommeil` ; `/aujourdhui/pas` ; `/aujourdhui/poids` ; `/aujourdhui/semaine` ; `/aujourdhui/records` ; `/aujourdhui/seance/:id` (détail d'une séance passée, records battus, « Refaire cette séance »).
- Accueil (`pages/aujourdhui_page.dart`, cartes dans `widgets/cartes.dart`) : salutation selon l'heure + prénom, date en capitales, avatar vers `/profil` (par `AppScaffold`). Cartes : Séance du jour (programme actif sinon routine la plus reposée, muscles sur le personnage, Démarrer, séance libre) ou Séance en cours (chrono, séries faites, Reprendre, Abandonner) ; mot du coach (dernier message de moins de 24 h dans `CoachRepo`, sinon conseil tiré des données, vers `/coach`) ; récupération sur `BodyMapDual` ; nutrition (calories restantes en grand, anneaux P/G/L, eau avec +250 ml) ; sommeil, pas, poids (saisie rapide en dialogue) ; semaine (jours, séances sur objectif du profil, série de semaines, volume) ; derniers records ; 8 raccourcis. Pull-to-refresh relance la lecture des pas. Fold ouvert (>= 700 dp) : deux colonnes, raccourcis sur une ligne.
- Sous-pages : chacune a ses états vides, dialogues, saisies, suppressions avec annulation :
  - Séance du jour : grand personnage, exercices (dernière perf, vers la fiche exercice), programme (semaine, avancement, cycle cliquable), « Faire une autre séance » (autres routines, séance libre). Gère la séance déjà ouverte (reprendre ou remplacer).
  - Récupération : personnage touchable, listes « En récupération » (prêt dans X h) et « Prêts » ; page muscle : %, séries et volume sur 7 jours, exercices les plus faits, séances récentes.
  - Nutrition : jour par jour (‹ ›), anneau segmenté des calories par macro, macros détaillées, fibres/sucres/sel, eau (+250/+500/+750/autre, annuler), repas par moment (toucher = changer la quantité, appui long = retirer), « Copier la veille ».
  - Sommeil : nuit dernière (phases si présentes), 7 nuits en barres, moyennes, historique modifiable ; dialogue « Noter ma nuit » (coucher, lever, qualité).
  - Pas : jauge du jour, 7 jours, objectif réglable, saisie manuelle par jour, lecture Health Connect (`health`, lecture seule des pas).
  - Poids : dernière pesée, écarts 7/30 jours, courbe 1/3/12 mois, poids visé (modifie `poidsCibleKg` du profil), IMC, masse grasse, historique modifiable.
  - Semaine : navigation semaine par semaine, comparaison avec la semaine d'avant, volume par jour, séries par muscle (personnage + barres), liste des séances.
  - Records : 30 jours / 3 mois / 1 an / tout, principaux ou tous les types, groupés par séance.
- Logique : `logic/resume_jour.dart` (`proposerSeance`, `ResumeSemaine`, `historiqueRecords` avec cache, `heuresAvantPret`, `phraseDuJour`, `musclesRoutine`) ; `logic/pas_repo.dart` (`PasRepo.pour(store)`, collection `aujourdhui_pas` : objectif, saisies, relevés Health Connect). Actions partagées dans `widgets/actions.dart` : `demarrerRoutine`, `demarrerSeanceLibre`, `abandonnerSeance`, `saisirPoids`, `saisirPas`, `saisirSommeil`, `ajouterEau`.
- Tests : `test/aujourdhui/` (logique + rendu démo Fold fermé, Fold ouvert, nouvel utilisateur ; `RENDUS=1` écrit les captures dans `build/rendus/aujourdhui/`). L'appli de test ne monte que mes routes (les autres modules ne compilaient pas pendant mon travail). `flutter analyze` : 0 problème sur le module.

**Limites**
- Pas de modification du noyau : contournement local `SousPage` (`widgets/commun.dart`) pour le bogue de `SubPageScaffold(bottomBar:)` ; à remplacer par `SubPageScaffold` une fois corrigé.
- La page Récupération n'est pas capturée en test : `BodyMap(onTap:)` bloque le pompage du test (chargement des masques).
- Les pas ne sont lus que si l'utilisateur a connecté Health Connect depuis la page Pas, ou si `settings.santeConnectee` est vrai ; je ne modifie pas ce réglage.

**Demandes**
- FONDATION : +1 sur le correctif de `SubPageScaffold.bottomBar` / `ContentWidth`. Et `BigNumber` : l'unité en mot (« pas », « kcal », « L ») paraît collée au chiffre ; un espace un peu plus large (ou une espace insécable) aiderait.
- PERSONNAGE : `BodyMap(onTap:)` ne rend jamais la main dans un `testWidgets` (masques chargés en boucle ?) ; à vérifier.
- ENTRAÎNER : je pointe vers `/entrainer/exercices/:id` (fiche), `/entrainer/routines/nouvelle` et `/entrainer/programmes` comme annoncé ; prévenez-moi si un chemin change. Votre `demarrerRoutine` et le mien font la même chose ; je garde le mien pour ne pas dépendre d'un fichier en chantier.
- SANTÉ : si vous faites une lecture Health Connect commune (pas, sommeil, poids), exposez-la et je brancherai `PasRepo` dessus.

### INSCRIPTION (livré, lib/features/inscription/)

**Livraisons**
- Routes (`inscriptionRoutes()`, plein écran hors onglets, toutes accessibles sans profil) :
  - `/bienvenue` : accueil (logo, promesse, quatre atouts), « Commencer », ou « Reprendre où j'en étais » + « Recommencer depuis le début » (confirmation) s'il existe un brouillon ; « Restaurer une sauvegarde » ouvre `/import/sauvegarde/restaurer` puis part sur `/` si un profil est revenu.
  - `/bienvenue/profil` : parcours de 15 étapes plein écran, barre de progression, « Étape n sur 15 », retour (bouton et geste) vers l'étape précédente, « Passer » sur les étapes facultatives, transitions en fondu sans superposition. Fold ouvert : sommaire des étapes à gauche (étapes déjà atteignables touchables), contenu à droite. Étapes : prénom (+ photo facultative : appareil, galerie, retirer), sexe, date de naissance (trois roues jour / mois / année + saisie au calendrier, note sous 16 ans), taille (règle graduée, cm ou ft/in, saisie au clavier), poids (règle, kg ou lb, IMC, poids visé facultatif avec écart), objectif (5), niveau (3), quotidien (5 niveaux d'activité), semaine type (jours L à D, raccourcis 2 à 6 jours, conseil selon le niveau, durée 30 min à 1 h 30), matériel (salle, haltères, maison, poids du corps, sur mesure + détail pièce par pièce), zones prioritaires (grille « zone ciblée » : vignettes rondes du personnage cadrées sur la zone, anneau blanc et coche comme les captures de référence, puis « Muscle par muscle » sur le personnage face et dos touchable + puces, 8 au plus), nutrition (calories, répartition, protéines / glucides / lipides / eau réglables, « d'où vient ce calcul », calcul automatique ou ajusté, retour au calcul), reprendre mon historique (`/import?retour=/bienvenue/profil`, puis résumé des séances présentes), autorisations (Health Connect : ce qui est lu et écrit, état, installation si absent ; rappels d'entraînement : autorisation de notifications, heure, jours ; réglages du téléphone si bloqué, relecture au retour), récapitulatif (chaque ligne rouvre son étape, alerte si une réponse manque) puis « Créer mon profil ».
  - `/bienvenue/programme` (`?premier=1` juste après l'inscription) : programme conseillé calculé depuis le profil (découpage selon les jours : corps complet, haut et bas, poussée tirage jambes, 5 et 6 jours ; séries, répétitions et repos selon l'objectif ; exercices filtrés par le matériel ; +1 série et exercice ajouté pour les zones prioritaires ; une série de moins pour un débutant), encadré séances / semaines / séries, choix du découpage, « Pourquoi ce programme », liste des séances avec personnage coloré. « Adopter » crée un dossier « Programme conseillé » avec les routines, enregistre et active le programme (confirmation s'il remplace le programme actif) ; « Plus tard » ; recalcul.
  - `/bienvenue/programme/seance/:i` : séance proposée (personnage face et dos, exercices avec vignette, séries et repos), renommer, régler (dialogue séries / reps min et max / durée / repos), remplacer, monter, descendre, retirer, ajouter. `/bienvenue/programme/seance/:i/exercice/:j` (remplacer, alternatives classées pour le même muscle) et `.../exercice/ajouter` (recherche, filtre « Mon matériel seulement »).
  - `/bienvenue/modifier` : toutes les réponses (même récapitulatif), liens vers le programme conseillé et l'import. `/bienvenue/modifier/:etape` : une étape seule avec « Enregistrer » (confirmation si on quitte avec des changements ; après objectif, niveau, semaine, matériel ou priorités, proposition de revoir le programme). Slugs : `prenom, sexe, naissance, taille, poids, objectif, niveau, activite, frequence, materiel, muscles, nutrition, autorisations`.
- Données : tout va dans `ProfileRepo.save` (objectifs nutritionnels mis à null en calcul automatique), les réglages `santeConnectee`, `rappelsEntrainement`, `heureRappel`, `joursRappel` via `SettingsRepo.update`, une pesée `BodyMeasurement(source: 'profil')` à la création et à chaque changement de poids. Collection `profil_extras` (dans la sauvegarde) : `ProfileExtras.load(store)` dans `lib/features/inscription/data/draft.dart` donne `musclesPrioritaires`, `uniteTaille` (cm / ftIn), `joursEntrainement` (1 = lundi), `materielPreset`, `nutritionAuto`. Brouillon du parcours dans `inscription_brouillon` (sauvé à chaque réponse, effacé à la création du profil).
- Fichiers : `routes.dart`, `inscription_controller.dart` (enum `Etape`, validation, enregistrement), `data/draft.dart`, `data/program_generator.dart` (`ProgramGenerator.generer`, `alternatives`, `disponible(exercice, matériel)`, `adopter`), `data/proposition.dart`, `data/permissions.dart` (Health Connect via `health`, notifications via `permission_handler`), `pages/` (accueil, parcours, programme, séance proposée, édition), `steps/` (étapes), `widgets/widgets.dart` (`OptionCard`, `RoundChoice`, `RulerPicker`, `WheelColumn`, `HeroValue`, `InfoNote`, `BottomActions`).
- Tests : `test/inscription/inscription_logic_test.dart` (brouillon, validation, programme pour 1 à 6 jours et 4 matériels : exercices existants, disponibles, sans doublon ; priorités ; force) et `test/inscription/inscription_rendu_test.dart` (toutes les étapes, programme, séance, remplacement, édition, Fold fermé et ouvert ; captures dans `build/rendus/inscription/`). 30 tests verts, `flutter analyze` sans problème.

**Limites**
- Les rappels ne sont pas planifiés ici : seuls les réglages sont posés (planification par `Reminders.planifier` du module profil). La synchro Health Connect elle-même reste au module santé.
- Le programme conseillé ne fixe pas de charges (première séance à calibrer) ; pas de semaines de décharge.

**Demandes**
- FONDATION : `ContentWidth` dans `SubPageScaffold(bottomBar:)` prend toute la hauteur (Center sans `heightFactor`) ; contourné par `BottomActions` dans mon dossier. Et dans `BodyMap.build`, quand `onTap` est donné, la closure du `LayoutBuilder` réutilise la variable `body` réaffectée : récursion infinie (dépassement de pile dès qu'on affiche un `BodyMap` ou `BodyMapDual` touchable). Il faut capturer l'enfant avant (`final dessin = body; body = LayoutBuilder(... child: dessin)`). Contourné ici par `TouchBodyDual` (toucher lu avec `BodyImageRepository.hitTest`).
- FONDATION : ajouter `musclesPrioritaires` et `uniteTaille` au `UserProfile` serait plus simple que `profil_extras` ; en attendant, lire `ProfileExtras.load(store)`.
- PROFIL : les liens d'édition vers `/bienvenue/modifier` et `/bienvenue/modifier/<slug>` sont prêts (slugs ci-dessus) ; la photo se change dans l'étape `prenom`.
- ENTRAÎNER : le programme adopté est un `Program` actif ordinaire + ses routines dans le dossier « Programme conseillé » ; un lien « Programme conseillé » vers `/bienvenue/programme` depuis `/entrainer/programmes` serait bienvenu. Quand `pickExercise` sera exporté, je pourrai remplacer mon sélecteur local.


### Catalogue sous licence et recentrage musculation (1er octobre)

**Livraisons**
- Catalogue remplacé par le pack d'exercices acheté : 608 exercices, 496 animations à fond transparent, toutes embarquées (`assets/exercises/anim/`, `assets/exercises/poses/`). Outils : `tools/repdb/medias.mjs` et `tools/repdb/catalogue.mjs`. Détails et licence : `docs/SOURCES_EXERCICES.md`.
- Les identifiants historiques sont gardés quand l'exercice existe dans le pack ; les autres sont les identifiants du pack (en anglais). `ProgramGenerator.disponible` reconnaît les deux.
- Les images d'exercice sont transparentes : toutes les vignettes passent du fond blanc au gris `surface2`.
- `Env.muscuSeule` (vrai par défaut, `--dart-define=COMPLET=true` pour tout remettre) : onglets réduits à Aujourd'hui, Entraîner, Progrès (`AppTab.visibles`) ; l'accueil ne garde que séance du jour, récupération, semaine, records. Les routes Coach et Nutrition restent déclarées, hors onglets.

**Limites**
- Le pack ne doit pas partir dans le dépôt public (voir `.gitignore`).
- L'inscription demande encore la nutrition et les autorisations santé.
- Une séance déjà enregistrée avec un exercice absent du pack garde son identifiant, sans fiche ni image.
- Suite (même jour) : ancien catalogue supprimé pour de bon (`tools/exercices/`, miniatures, crédits). Les identifiants historiques vivent dans `tools/repdb/identifiants.json`. Animations refaites en 720 px à la cadence d'origine, poses en 720 px. Séance : chaque exercice est une carte arrondie repliable (`ExerciceCarte(replie:, onBasculer:)`), l'exercice en cours ouvert, les autres réduits à leur ligne.
- Style (1er octobre, après-midi, demande de Tristan sur maquette) : police Figtree (400 à 800), accent Corail #FF5A5F par défaut (le bleu reste dans Réglages > Apparence), coche de série verte vive carrée arrondie. Séance : lueur de l'accent en haut, titre « EXERCICES DE LA SÉANCE », exercice ouvert en carte, exercices repliés regroupés dans un seul bloc avec filets. Liste d'exercices : toucher une carte ou le « ? » ouvre l'aperçu flottant de la capture de référence (`showExerciseApercu`), la fiche complète est à un toucher ; sur écran large la fiche s'ouvre directement à côté.
- Design validé par Tristan sur maquette (`tools/maquette/maquette.html`, 1er octobre, soir) : une idée par écran, beaucoup d'air, un seul accent. Accueil = séance du jour en héros, semaine en pastilles, deux tuiles (`SemaineAccueil`). Entraîner = onglets en texte (`_OngletsTexte`), programme en cours, routines, deux boutons. Exercices = loupe et filtres à la demande (`BrowserConfig(epure: true)`). Séance = tout à plat, en-tête sur une ligne, repos sous le nom de l'exercice. Progrès = volume en grand, graphique, muscles travaillés. Barre du bas : Accueil, Entraîner, Progrès. Surfaces assombries (#131315, #1D1D20).


### FONDATION, design du 2 octobre

Socle de la maquette validée (`refs/modeles/`). Tout est exporté par `lib/core/ui/ui.dart` et visible sur `/dev/composants` (en tête de page) ; rendus dans `build/rendus/` (`flutter test test/fondation_rendu`). La maquette est dessinée sur 320 de large : les composants sont livrés à l'échelle du téléphone (environ 1,25 fois les cotes du CSS).

**Jetons ajoutés** (`lib/core/theme/tokens.dart`, `app_colors.dart`)
- `AppTokens.minuteur` / `context.colors.minuteur` : bleu #1E9BF0, réservé au minuteur de repos (pilule du haut, ligne « Minuteur de repos », anneau, numéros de série du tableau).
- `AppTokens.foretClair` / `context.colors.foretClair` : #3FAE4A (cases actives, série en cours). `context.colors.foret` : #228B22.
- `AppTokens.poignee` : #48454E (poignée des panneaux, bouton gris clair).
- `AppTokens.fontBilan` : `'Montserrat'`, embarquée (600, 700, 800, 900 dans `assets/fonts/`, licence OFL) : gros titres du bilan, des cartes de fin de séance, de la carte « Résumé mensuel », et rien d'autre.
- Déjà en place et inchangés : fond `bg` #000, carte `surface` #131315, `surface2` #1D1D20, filet `line` #222226, `text2` #8E8E93, `text3` #5C5C61, `foret`, `setDone` #12261A, `warning` (ambre) #FFC857, `success` #22D85F, `bouton` / `onBouton`.

**Modèle** (`lib/core/models/workout.dart`)
- `enum TypeSeance { musculation, cardio, hiit, hybride, crossTraining, aviron }` avec `label`.
- `WorkoutSession.type` (`TypeSeance`, musculation par défaut), dans `copyWith(type:)`, `fromJson` et `toJson` (clé `type`, absente pour la musculation : les fichiers existants restent lisibles).

**Navigation**
- `AppTab` (`lib/core/ui/app_bottom_nav.dart`) gagne `profil` et un champ `trait` (`AppIcone?`). `AppTab.visibles` : Accueil, Entraîner, Progrès, Profil ; avec `--dart-define=COMPLET=true` : Accueil, Entraîner, Coach, Nutrition, Progrès, Profil. `AppTab.rang` donne l'indice dans la barre ; `AppTab.icone({size, color, selected})` rend l'icône.
- `AppBottomNav` : quatre onglets, icône au trait de 26 au-dessus du libellé (12, semi-gras), actif blanc, repos #8E8E93, filet #222226 au-dessus, hauteur 62.
- **Profil est un onglet.** `/profil` et ses sous-pages (`/profil/badges`, `/profil/carriere`, `/profil/modifier`) vivent dans la branche de l'onglet (barre visible) ; `/reglages...` reste en plein écran. Le tri se fait dans `lib/app/router.dart` (`_estProfil`), `features/profil/routes.dart` n'a pas changé. Pour aller au profil depuis une autre page : `context.go('/profil')`, pas `push`. L'avatar d'`AppScaffold` fait déjà `go`.
- `lib/app/shell.dart` : le bandeau de séance en cours est maintenant `SeanceMiniBarre` du module séance (demande de SÉANCE) ; `ActiveSessionBanner` est supprimé.
- `SubPageScaffold(bottomBar:)` est corrigé (la barre ne prend plus toute la hauteur) : les contournements `SousPage`, `AvecBarre`, `NutriSubPage`, etc. peuvent redevenir de simples `SubPageScaffold`.

**Composants** (tous dans `lib/core/ui/`)
- `icones.dart`
  - `enum AppIcone { accueil, haltere, progres, profil, coeur, flamme, boucle, eclair, aviron, coche }` : tracés de la maquette.
  - `TraitIcone(AppIcone icone, {double size = 24, Color? color, double epaisseur = 1.7, String? semanticLabel})`.
  - `IconeHaltere({size, color, epaisseur})`, `IconeCoeur({size, color, epaisseur})` : l'haltère en diagonale et le cœur.
  - `IconeTypeSeance(TypeSeance type, {double size = 22, Color? color, double epaisseur = 1.7})` ; extension `TypeSeance.icone` (`AppIcone`).
  - `PastilleTypeSeance(TypeSeance type, {double taille = 44})` : le rond au contour blanc en tête d'une carte de séance.
- `jours.dart`
  - `typedef SeanceDuJour = TypeSeance? Function(DateTime jour)`.
  - `PastilleJour({required int jour, TypeSeance? type, bool aujourdhui = false, bool cadre = true, bool estompe = false, double taille = 38, VoidCallback? onTap})`.
  - `SemaineJours({required List<DateTime> jours, required SeanceDuJour seance, DateTime? aujourdhui, ValueChanged<DateTime>? onJour, double taille = 38})` et `SemaineJours.semaineDe(DateTime date, {int premierJour})`.
  - `GrilleMois({required DateTime mois, required SeanceDuJour seance, DateTime? aujourdhui, ValueChanged<DateTime>? onJour, int premierJour = DateTime.monday, bool enTetes = true, double taille = 40})` : à poser dans une carte ; complète les lignes avec les jours des mois voisins, en retrait.
  - Codes : aujourd'hui = disque blanc, chiffre noir ; jour fait = cercle gris au contour blanc et icône du type ; autre = la date. Choix à connaître : si la séance d'aujourd'hui est faite, le disque blanc montre l'icône du type en noir (la maquette ne montre pas ce cas).
- `panneau_bas.dart`
  - `Future<T?> showPanneauBas<T>(BuildContext context, {String? titre, Widget? entete, required WidgetBuilder builder, bool fermable = true})` : s'ouvre sur le navigateur racine, par-dessus la barre ; fermer avec `Navigator.pop(context, valeur)`.
  - `PanneauBas({String? titre, Widget? entete, required Widget child})` : le panneau seul (fond #1D1D20, coins de 26, poignée, titre centré, filet).
  - `LigneAction({required Widget icone, required String label, required VoidCallback? onTap, bool destructif = false})`.
  - `ChoixPanneau({required String label, required VoidCallback? onTap, Widget? icone, bool selected = false, String? detail})` : choix encadré, cadre blanc et coche quand il est retenu (type de série, type d'activité).
- `roues.dart`
  - `RoueDuree({required Duration value, required ValueChanged<Duration> onChanged, int maxHeures = 23})` : heures, minutes, secondes entre deux traits, unité à droite.
  - `RoueMinSec({required Duration value, required ValueChanged<Duration> onChanged, int maxMinutes = 59, int pasSecondes = 1, bool libelles = true})` : deux grandes roues et les deux points.
  - `RoueChiffres({required int value, required int count, required ValueChanged<int> onChanged, double extent = 56, String? unite, bool traits = true, bool deuxChiffres = false, double tailleChoisie = 32, double tailleAutre = 27, FontWeight poidsChoisi, Color couleurAutre, int pas = 1})` : la brique, pour un autre réglage. Les roues bouclent et suivent une valeur changée de l'extérieur (durées prédéfinies).
- `boutons.dart`
  - `BoutonPrincipal({required String label, required VoidCallback? onPressed, Widget? icone, bool petit = false})` : blanc, texte noir, pleine largeur, 56 de haut (50 avec `petit`).
  - `BoutonSecondaire({... , Color? fond})` : gris #1D1D20, texte blanc. `BoutonDestructif({... , Color? fond})` : gris, texte rouge. Sur un panneau du bas (déjà gris), passer `fond: AppTokens.surface3`.
  - `SelecteurSegmente<T>({required List<(T, String)> segments, required T value, required ValueChanged<T> onChanged})` : bac gris aux coins de 14, segment choisi noir.
  - `Pastille(String label, {TonPastille ton = TonPastille.neutre, bool grande = false})` avec `enum TonPastille { neutre, ok, alerte, muscle, musclePlein }` (gris, vert, ambre, corail atténué, corail plein).
  - `PillButton` reste disponible (bouton à la largeur de son libellé) ; son libellé principal passe en gras.
- `objet_3d.dart`
  - `Objet3D({required String asset, int? multiple, String? etiquette, Color halo, double hauteur = 290, bool copies = true})` : objet centré et penché, halo de couleur, deux copies floues, pastille blanche « × N ».
  - `Objets3D` : les 37 chemins (`Objets3D.baleine`, `.chat`, `.elephant`, `.fusee`, `.trophee`, `.medailleOr`...).
- `resume_mensuel.dart`
  - `CarteResumeMensuel({required String mois, VoidCallback? onTap, String titre = 'Résumé mensuel'})` : la carte bleue. La règle d'affichage (accueil du 1er au 3 du mois suivant, Progrès tout le mois) est à la charge des modules.

**Assets**
- `assets/objets/` : les 37 PNG de `refs/modeles/objets/`, déclarés dans `pubspec.yaml`. Crédit et licence : `docs/SOURCES_OBJETS.md` (à reprendre dans Réglages > À propos par PROFIL).
- `assets/fonts/Montserrat-{SemiBold,Bold,ExtraBold,Black}.ttf` et `OFL-Montserrat.txt`.

**Ce que les modules doivent utiliser**
- ACCUEIL : `CarteResumeMensuel`, `SemaineJours` (l'ancien `JoursSemaine` de `aujourdhui/widgets/cartes.dart` passe déjà par lui), `PastilleTypeSeance` en tête des cartes de séance.
- SÉANCE : `showPanneauBas` avec `ChoixPanneau` (type de série, type d'activité, à enregistrer dans `WorkoutSession.type`), `LigneAction` (menu), `RoueDuree` (corriger la durée), `RoueMinSec` (repos), `context.colors.minuteur`, `BoutonPrincipal` / `BoutonSecondaire` / `BoutonDestructif`, `Objet3D` et `AppTokens.fontBilan` pour les cartes de fin de séance.
- ENTRAÎNER : `showPanneauBas` et `LigneAction` (actions sur une routine), `SelecteurSegmente`, `Pastille` (muscles).
- PROGRÈS : `GrilleMois` (calendrier), `SemaineJours`, `CarteResumeMensuel`, `Objet3D`, `Pastille` (ok, alerte) pour la récupération.
- PROFIL : la page est maintenant la racine d'un onglet (pas de flèche de retour, barre visible) ; `SelecteurSegmente`, `BoutonDestructif`.
- Dans les tests de rendu, charger les vraies polices (`Figtree-*.ttf`, `Montserrat-*.ttf`, voir `test/fondation_rendu/rendu_test.dart`) et, pour `Objet3D`, appeler `precacheImage` dans `runAsync` avant la capture.

**Non fait, à savoir**
- Pas de carte de séance partagée (`.sea`) : seule sa pastille d'en-tête est fournie ; ACCUEIL garde la carte, PROGRÈS peut lui demander de la remonter dans `core/ui` si besoin.
- Pas de composant pour les cartes de jour des routines (`.jk`, cadre en dégradé) ni pour le fond en dégradé des écrans du bilan : à faire dans ENTRAÎNER et PROGRÈS.
- Les anciens composants (`SegmentedControl` à curseur d'accent, `TagPill`, `WeekDots`, `showActionMenu`, `MonthSelector`) existent toujours pour ne rien casser ; les écrans refaits doivent passer aux nouveaux. `AppCard` garde ses coins de 12 (la maquette est à 16, soit 20 à l'échelle) : passer `radius: 20` en attendant.
- `nutrition/pages/goals_page.dart` et `profil/pages/reglages_page.dart` font encore `context.push('/profil')` : à remplacer par `context.go('/profil')` par leurs modules.
- Le rail latéral (écran large) garde l'avatar en plus de l'onglet Profil ; non revu pour la nouvelle maquette, qui ne montre que le téléphone.
- `DemoData` ne crée que des séances de musculation : aucun cœur dans la semaine de la démo tant qu'une séance n'a pas un autre `type`.
- Bonus : `assets/data/aliments.json` (liste vide) ajouté, pour que `AppData.loadAll()` ne lève plus d'erreur d'asset absent dans les tests (demande d'IMPORT) ; les tests de rendu du coach, qui expiraient, repassent.


### SÉANCE, design du 2 octobre : annonce des deux fichiers partagés (disponibles tout de suite)

Ajouts purement additifs, les fichiers déjà enregistrés restent lisibles. Section complète du module plus bas, en fin de travail.

**`lib/core/models/workout.dart`**
- `SetType` passe à douze valeurs : `echauffement, normale, degressive, echec` (noms inchangés) puis `gauche, droite, negative, partielles, myoReps, feeder, topSet, backOff`. Champs : `label`, `short` (lettre à la place du numéro, toujours vide pour une normale), `lettre` (« # » pour une normale), `argb` et `couleur` (`Color`, couleurs de la maquette 06), `aide` (texte du « ? »). `SetType.ordrePanneau` donne l'ordre des deux colonnes du panneau. Un nom inconnu est relu comme `normale`.
- Changements visibles : `SetType.degressive.short` vaut maintenant « DG » (le « D » est pris par Droite), `SetType.echec.short` vaut « X » et son `label` « Échec ». Seul l'échauffement reste hors volume et hors records (`counts`).
- Tout `switch` exhaustif sur `SetType` doit couvrir les nouveaux cas : j'ai ajouté un cas par défaut dans `entrainer/routines/widgets/serie_dialog.dart` (`couleurType` rend `t.couleur`) et dans `import/data/exporters.dart` (`_type` rend `t.label`). Rien d'autre à faire ailleurs.
- `class SessionMedia { String chemin; bool video; int? dureeSec; }` avec `toJson` / `fromJson`, et `WorkoutSession.medias` (`List<SessionMedia>`, liste vide par défaut, dans `copyWith(medias:)` ; clé `medias` absente du JSON quand la liste est vide). L'ancien champ `photo` est conservé.
- `SessionExercise.note` : alias en lecture de `notes` (le champ existait déjà) ; `copyWith(clearNotes: true)` efface la note.

**`lib/core/logic/equivalents.dart`** (exporté par `logic.dart`)
- `class Equivalent { String asset; String nom; String etiquette; String phrase; Color couleur; Color accent; String fort; double multiple; bool pourcentage; }`. `phrase` tient sur deux lignes (saut de ligne au milieu) ; `fort` est le passage à écrire dans la couleur `accent` (« 80 chats ») et `morceaux` rend le triplet (avant, fort, après) prêt pour un `Text.rich`. `couleur` est le haut du dégradé vers le noir, `accent` le halo de l'objet (`Objet3D(halo: e.accent, etiquette: e.etiquette)`).
- `Equivalent equivalentPour(double kg, {int graine = 0, bool mois = false})` : choisit un objet dont le multiple reste lisible (1 à 99, entier quand l'arrondi ne trahit pas plus de 8 %, sinon une décimale sous 10), le plus juste d'abord ; `graine` fait tourner les objets puis les phrases, une graine sur six sort un burger ou une baguette au multiple absurde ; la statue de la Liberté sort en pourcentage à partir de 10 %. Même graine, même carte. `mois: true` donne les phrases du bilan (« C'est comme soulever\n11 éléphants ! »).
- `objetsEquivalents` : la table (25 objets, poids de référence, accords, phrases, couleurs). Les couleurs de ces cartes sont centralisées là.
- Tests : `test/core/equivalents_test.dart`.

### ACCUEIL, design du 2 octobre

Écran 01 refait d'après `refs/modeles` (échelle 1,25 comme la fondation), branché sur les dépôts.

**Livré** (`lib/features/aujourdhui/`)
- `pages/aujourdhui_page.dart` : plus de titre ni d'avatar, plus de carte « séance du jour », de message de bienvenue ni de raccourcis. De haut en bas : flamme et cloche, carte « Résumé mensuel », carte « Cette semaine », « Dernières séances » (cinq cartes). Fold ouvert (700 et plus) : résumé et semaine à gauche, séances à droite. `AujourdhuiPage(maintenant:)` fige l'horloge pour les tests.
- `widgets/accueil.dart` : `EnTeteAccueil`, `CarteCetteSemaine`, `TitreDernieresSeances`, `CarteSeance`, `AccueilVide`.
- `logic/accueil.dart` : `moisDuResume` (carte bleue du 1er au 3 seulement, pour le mois précédent, s'il compte une séance), `recordsParSeance`, `nouveautes` et `ClocheRepo` (fichier `aujourdhui_cloche` : date de dernière ouverture de la cloche).
- Cloche : panneau du bas avec le résumé du mois écoulé, les records des 14 derniers jours et l'objectif de la semaine atteint ; point corail tant qu'une ligne est plus récente que la dernière ouverture.
- Carte de séance : `PastilleTypeSeance`, nom, date et heure, menu (bilan, refaire, modifier, supprimer avec confirmation), durée, volume, records (rien si zéro). Avec `WorkoutSession.medias` : rangée défilante, étiquettes « Photo · 1 / 3 » et « Vidéo · 0:24 », points de position, sans exercices. Sinon trois vignettes « 3 × Nom » (pose en contraction) et « et N autres exercices ».
- Les blocs coach, nutrition et santé ne s'affichent qu'avec `--dart-define=COMPLET=true`, sous la carte de la semaine.
- Retirés de `widgets/cartes.dart` : `CarteSeanceDuJour`, `SemaineAccueil`, `CarteSemaine`, `CarteRecords`, `Raccourcis` (plus utilisés nulle part).

**Liens** (constantes dans `AujourdhuiPaths`)
- Flamme : `/progres/bilan` (bilan du mois en cours). Carte bleue : `/progres/bilan?mois=2026-9` (route actuelle de Progrès, `context.go`).
- « Historique » : `/progres/calendrier` (comme sur le prototype).
- Jour avec séance, carte de séance : `/seance/resume/<id>` ; menu : `/seance/refaire/<id>`, `/seance/historique/<id>/modifier`.
- « Voir plus » : `/aujourdhui/semaine` (ancienne page du module) faute de route pour l'écran 42.
- État vide : bouton blanc vers `/entrainer`.

**Tests** : `test/aujourdhui/accueil_rendu_test.dart` (données de la maquette au 2 octobre 2026, Fold ouvert, libellés longs en 320 de large, disparition de la carte bleue le 4, règles de `logic/accueil.dart`) et les trois parcours existants. `RENDUS=1 flutter test test/aujourdhui` écrit `build/rendus/aujourdhui/*.png`. Le banc sert maintenant un `AssetManifest.bin` minimal : les poses des exercices apparaissent dans les rendus.

**Non fait, à savoir**
- Flamme en `warning` (#FFC857) : l'orange #FFA928 de la maquette n'a pas de jeton. Fond des médias en dégradé `surface3` vers `surface` (maquette : #34343A vers #17171A).
- Une vidéo n'a pas d'aperçu (tuile sombre et rond de lecture, comme la maquette) ; toucher un média ouvre le bilan de la séance, pas de visionneuse.
- Les anciennes sous-pages du module (`/aujourdhui/seance-du-jour`, `records`, `seance/:id`, `recuperation`...) existent toujours mais l'accueil n'y mène plus, sauf `semaine`.

**Demandes**
- PROGRÈS : une route pour le bilan de la semaine (écran 42) ; je remplace alors `AujourdhuiPaths.bilanSemaine`. Prévenir si `/progres/bilan?mois=AAAA-M` ou `/progres/calendrier` changent. Une route directe vers la page « série de semaines » du bilan serait mieux pour la flamme.
- SÉANCE : garder `/seance/resume/<id>`, `/seance/refaire/<id>` et `/seance/historique/<id>/modifier` ; `SessionMedia.chemin` est lu comme un chemin de fichier absolu (`Image.file`).
- FONDATION : jeton pour l'orange de la flamme ; dans `CarteResumeMensuel`, le titre est coupé (« Résumé men... ») en 320 de large, un `FittedBox` réglerait ça ; `DemoData` sans cardio ni médias, donc la démo ne montre ni cœur ni photos.

### PROFIL, design du 2 octobre (écrans 66 à 73)

**Livré** (`lib/features/profil/`, tests dans `test/profil/`)
- 66 Profil (`pages/profil_page.dart`), racine de l'onglet : avatar (initiale ou photo, toucher pour la changer), prénom, « Inscrit depuis... », bouton réglages ; séances, série en cours, poids ; carte Objectif (ouvre l'étape objectif de l'inscription) ; Mensurations, Photos, Records, Calendrier, Réglages.
- 67 Mensurations (`mensurations/mensurations_page.dart`) : corps de face (`assets/body/pack/face_base.webp`), huit mesures reliées chacune à sa zone, écart depuis la première saisie (rien si inchangé), carte Poids (courbe, écart, taux de gras), lien Historique, « Saisir mes mesures ».
- 68 Une mesure (`mensurations/mesure_page.dart`) : valeur, écart sur la période, puces 3 mois, 6 mois, 1 an, tout, courbe, saisies avec crayon, « Ajouter une mesure ».
- 69 Saisir ou modifier (`mensurations/saisie_page.dart`) : date modifiable, « − » et « + » (0,5 cm, 0,1 kg, 0,1 %), saisie au clavier en touchant la valeur, Enregistrer, « Supprimer cette saisie » en modification. Une seule saisie par jour : une nouvelle saisie un jour déjà saisi complète celle du jour.
- 70 Historique (`mensurations/historique_page.dart`) : saisies et rythme, une ligne par saisie, la plus récente en haut, toucher rouvre la saisie.
- 71 Photos (`photos/photos_page.dart`) : Face, Profil, Dos, grille datée, ajout par `image_picker` (appareil ou galerie, copie par `HealthRepo.addPhoto` dans le dossier documents de l'appli), photo en grand avec suppression.
- 72 Comparer (`photos/comparer_page.dart`) : avant et après côte à côte, poids à chaque date, écart en kilos et en semaines, mesure qui a le plus bougé, « Changer les dates », « Partager » (image par `share_plus`).
- 73 Réglages (`pages/reglages_page.dart`) : groupes Entraînement (Unités, Repos par défaut, Premier jour, Séance et charges, Rappels), Apparence (Accent, Taille du texte), Données (Importer mes séances, Exporter une sauvegarde, Mes données, À propos). Santé et Coach ne s'affichent qu'avec `COMPLET=true`.
- Supprimés : pages Badges et Carrière, leurs routes (`/profil/badges`, `/profil/carriere`), `widgets/badge_tile.dart`, les classes `Badges`, `BadgeDef`, `BadgeEtat`. `CareerStats` reste (séances, série de semaines, nombre de records).
- À propos : crédits des objets 3D (Fluent Emoji, MIT) et de Montserrat ajoutés.

**Routes** (`profilRoutes()`, chemins dans `ProfilPaths` de `features/profil/routes.dart`)
- `/profil` : dans l'onglet (barre visible). Toutes les sous-pages ci-dessous sont déclarées avec `parentNavigatorKey: rootNavigatorKey` : plein écran, par-dessus la barre, ouvrables par `context.push` depuis n'importe quel onglet.
- `/profil/mensurations` (`ProfilPaths.mensurations`), `/profil/mensurations/historique`, `/profil/mensurations/zone/<zone>` (`cou, poitrine, taille, cuisses, epaules, biceps, avantBras, mollets` ; `ProfilPaths.zone(z)`), `/profil/mensurations/saisie` avec `?id=<saisie>` pour corriger (`ProfilPaths.saisie(id:, zone:)`).
- `/profil/photos` (`ProfilPaths.photos`), `/profil/photos/voir/<id>`, `/profil/photos/comparer?vue=face|profil|dos&avant=<id>&apres=<id>` (`ProfilPaths.comparer(...)`).
- `/reglages` et `/reglages/<section>` inchangés (plein écran).
- Records et Calendrier : le profil fait `context.go('/progres/records')` et `context.go('/progres/calendrier')` (bascule sur l'onglet Progrès).

**Modèle** : aucun champ ajouté au modèle partagé. Les huit mesures sont des `ZoneMesure` (`features/profil/data/mensurations.dart`) posées sur `TourCorps` : Biceps = bras gauche et droit, Avant-bras, Cuisses et Mollets de même (valeur = moyenne des côtés saisis ; une saisie écrit les deux côtés ; les hanches et un écart gauche et droite non modifié sont gardés). Calculs réutilisables : `Mensurations.etat / serie / seriePoids / ecart / ecartTexte / historique / poidsA / comparer / photosDe`.

**Tests** : `test/profil/profil_test.dart` (logique : écarts, rien si inchangé, moyenne des côtés, périodes, tri de l'historique, pas d'un demi-centimètre, modification, fusion du même jour, suppression, comparaison de photos, copie d'une photo) ; `test/profil/profil_rendu_test.dart` (rendu des écrans 66 à 73 sur le jeu de la maquette `test/profil/jeu_maquette.dart`, parcours toucher une mesure, crayon, « + », Enregistrer, suppression depuis l'historique, données de la démo et écrans vides, téléphone et écran large ; images dans `build/rendus/profil/`).

**Non fait, à savoir**
- Les pages de détail des réglages (`/reglages/unites`, `/reglages/entrainement`, disques, rappels, données, à propos...) gardent l'ancien habillage (`SubPageScaffold`, `SegmentedControl`) ; la vue à deux volets du Fold ouvert est retirée (contenu centré sur 560 de large).
- Les tours restent en centimètres, même si le réglage Unités est en pouces ; le poids suit kg ou lb.
- Les anciens écrans `features/sante/corps` (`/sante/corps/...`) ne sont pas modifiés : ils restent derrière `/sante`. Les nouveaux écrans sont ceux de `/profil/...`.
- Pas vérifié sur appareil : `image_picker`, partage de l'image, sélecteur de date.
- Avec la démo, l'historique liste aussi les pesées seules (une tous les deux ou trois jours) : la démo n'a pas de saisie d'avant-bras ni de mollets.

**Demandes**
- PROGRÈS : pour les mensurations et les photos, ouvrir `context.push(ProfilPaths.mensurations)` et `context.push(ProfilPaths.photos)` (ou `ProfilPaths.comparer(vue:)`). Merci de garder `/progres/records` et `/progres/calendrier`.
- ACCUEIL, SANTÉ, PROGRÈS : remplacer les liens vers `/sante/corps/mesure`, `/sante/corps/mensurations`, `/sante/corps/photos` par les chemins ci-dessus quand vous y passez.
- FONDATION : `DemoData` pourrait donner des saisies de mensurations plus proches de la maquette (huit tours toutes les deux semaines, valeurs au demi-centimètre, quelques photos) pour que la variante démo ressemble aux écrans 67 à 72. `refs/sauvegarde-avant-portage/test/profil/profil_test.dart` nomme encore `Badges` (dossier privé, non touché) : à exclure de l'analyse ou à supprimer.
- ENTRAÎNER : au moment de ma livraison, `flutter analyze` de tout le projet échoue dans `features/entrainer` (`exercise_detail_page.dart`, `entrainer_page.dart`, travail en cours) : l'appli entière ne compile pas tant que ce n'est pas fini.


### SÉANCE, design du 2 octobre (livré, écrans 02 à 28)

**Écrans** (tous à l'échelle 1,25 de la maquette, rendus dans `build/rendus/seance/`)
- 02 Lancer la séance : `/seance/apercu/:id?programme=<id>` (`SeancePaths.apercu(routineId, programId:)`, `pages/apercu_page.dart`). Muscles visés, durée, trois chiffres, exercices prévus, « Commencer la séance » (qui enchaîne sur `SeancePaths.routine`).
- 03 Séance réduite : `SeanceMiniBarre` (`widgets/mini_barre.dart`), « Entraînement en cours » et chrono, Reprendre blanc, Abandonner gris texte rouge (avec confirmation). Même constructeur qu'avant (`padding`), rien à changer dans `lib/app/shell.dart`.
- 04 Saisie des séries (`pages/seance_page.dart`, `widgets/exercice_carte.dart`, `widgets/serie_ligne.dart`) : barre du haut (réduire, pilule bleue du minuteur qui se vide, Terminer), trois tuiles, exercices à plat (image qui ouvre la fiche, nom, menu, « Ajouter une note… », ligne bleue du repos, tableau pleine largeur sans cases, numéro bleu, coche en pilule, ligne validée sur fond vert sombre), « + Ajouter une série », « Plus » et « Ajouter des exercices ». La fourchette de la routine (« 12-15 ») tient lieu de valeur tant que la série n'est ni saisie ni validée. Valider une série lance le repos.
- 05 Menu « Plus » : partager, pause (le chrono se fige, la durée ne compte pas la pause), photo, notes, réglages de la séance (renommer, réordonner, disques, colonne RPE, cocher les séries remplies, historique), abandonner.
- 06 Type de série : douze types sur deux colonnes, « ? » qui explique, « Supprimer la série ».
- 07 et 08 Repos : `/seance/repos` (`pages/repos_page.dart`), anneau bleu, −10 / +10, Arrêter, roues minutes et secondes, durées toutes prêtes, Démarrer, onglets Compte à rebours / Chronomètre.
- 09 Remplacer un exercice (`pages/remplacer_page.dart`, `logic/alternatives.dart`) : alternative conseillée calculée sur le catalogue (mêmes muscles principaux, même mécanique, autre matériel), autres exercices proches, recherche dans la bibliothèque.
- 10 à 12 Terminer (`pages/terminer_page.dart`) : nom, note, photos et vidéos (`image_picker`, copiées dans `<documents>/medias_seances/`, enregistrées dans `WorkoutSession.medias`), date, durée (trois roues), type d'activité, envoi Health Connect, Abandonner, Enregistrer.
- 13 Bilan (`pages/resume_page.dart`, route inchangée `/seance/resume/:id`) : volume, écart avec la dernière séance de la même routine, corps face et dos, un record par exercice ; plus bas « La prochaine fois » et la mise à jour de la routine. Partager / Fermer.
- 14 à 23 Équivalent : `/seance/equivalent/:id`, affiché juste après Enregistrer (sans volume, on passe au bilan). La croix mène au bilan.
- 24 à 28 Partager : `/seance/partager/:id?carte=N` (`SeancePaths.partager(id, carte:)`), cinq cartes, export PNG par `share_plus`.

**Supprimé ou changé** : `widgets/repos_panneau.dart` (remplacé par la page de repos) ; `ExerciceCarte` n'a plus `replie`, `onBasculer`, `filetHaut` ; le ressenti (5 niveaux) n'est plus saisi (la maquette ne l'a pas), les anciennes valeurs restent lues. `partagerSeance` ouvre le carrousel.

**Tests** : `test/seance/` (`seance_rendu_test.dart`, `seance_logique_test.dart`, `partage_test.dart`, `partage_rendu_test.dart`, `partage_cartes_rendu_test.dart`, banc commun `banc.dart`) et `test/core/equivalents_test.dart`.

**Non fait, à savoir**
- La pause vit en mémoire : appli fermée pendant une pause, le temps est compté.
- Détail, historique, modifier, disques, réordonner et l'écran « Démarrer une séance » (`/seance` sans séance en cours) ne sont pas dans la maquette : ils marchent mais gardent l'ancien habillage.
- Rien n'a été essayé sur un appareil : appareil photo, galerie, vidéo, feuille de partage, Health Connect, notification de fin de repos.

**Demandes**
- FONDATION (`android/app/src/main/AndroidManifest.xml`) : ajouter `<uses-permission android:name="android.permission.health.WRITE_EXERCISE" />`. Sans elle, « Envoyer vers Health Connect » échoue en silence (`logic/envoi_sante.dart`).
- FONDATION (`SessionRepo.finishActive`) : accepter `debut`, `type` et `medias` ; en attendant, je les pose par `updateActive` juste avant de terminer.
- ENTRAÎNER : ouvrir `SeancePaths.apercu(routine.id, programId: ...)` au toucher d'une routine (écran 02) plutôt que `SeancePaths.routine` directement.
- ACCUEIL, PROGRÈS : les cartes de séance peuvent lire `WorkoutSession.medias` (photos, vidéos avec `dureeSec`) ; pour partager une séance, `context.push(SeancePaths.partager(id))`.
- PROGRÈS (bilan du mois) : `equivalentPour(volume, graine: n, mois: true)`.

### PROGRÈS, design du 2 octobre (livré, écrans 41 à 65)

Onglet refait d'après `refs/modeles` (échelle 1,25 comme la fondation), branché sur les dépôts. Remplace la section PROGRÈS plus haut pour tout ce qui touche la page d'entrée, le calendrier et le bilan.

**Livré** (`lib/features/progres/`, récupération dans `lib/features/sante/recuperation/`)
- 41 Progrès (`ui/progres_page.dart`) : sélecteur Semaine / Mois / Année ; grande carte volume, écart, deux étiquettes de groupes, corps face et dos allumé selon le volume ; séances, temps, records ; « Volume par semaine » (huit barres, la semaine en cours en blanc ; douze mois en vue Année) ; « Ton corps » (Récupération avec l'anneau vert, Mensurations avec le poids et son écart sur trente jours) ; « Calendrier » (`ui/calendrier_mois.dart` : le mois en grand avec `GrilleMois`, flèches et glissement vers les mois précédents, trois points, lien « Détail ») ; « Tes repères » (Records, Photos) ; carte bleue du mois précédent, présente tout le mois dès qu'il compte une séance. Sans aucune séance : une carte « Commencer une séance ».
- 42 Bilan de la semaine (`ui/semaine_page.dart`), 43 Statistiques du mois (`ui/mois_page.dart`), 44 Calendrier (`ui/calendrier_page.dart` : série de semaines, séances du mois, grille, détail du jour touché, glisser sur la grille change de mois).
- 45 Récupération (`sante/recuperation/recuperation_page.dart`) et 46 Tous les muscles (`tous_muscles_page.dart`) : anneau global, vignettes par muscle (vert à partir de 90 %, ambre en dessous), filtre Tous / En récupération / Prêts, carte « Conseillé aujourd'hui ». `RecuperationPage` garde son nom : `/sante/recuperation` montre le nouvel écran.
- 47 à 65 Bilan du mois (`ui/bilan/`) : dix pages plein écran (ouverture, séances, régularité, volume, équivalent, série, muscles, records, favoris, résumé), barre de segments, croix, « Partager » (image de la page en PNG par `share_plus`, sans la barre ni les boutons). Toucher le tiers gauche revient, le reste avance. Couleurs des pages dans `ui/bilan/couleurs.dart` (`CouleursBilan`), celles de l'équivalent viennent de `equivalentPour(kg, graine: année * 12 + mois, mois: true)`.
- Calculs purs : `logic/tableau.dart` (`Calculs` : périodes, volumes par semaine et par mois, groupes, records en un passage, série de semaines, numéro de semaine ISO), `logic/bilan_mois.dart` (`BilanMois.calculer`), `sante/recuperation/recup_calcul.dart` (`Recup`).
- Supprimé : l'ancien tableau de bord, l'ancien calendrier en grille de contributions, l'ancien bilan en liste (`ui/bilan_page.dart`). Aucun rang, XP ni classement dans le module.

**Routes** (`progresRoutes()`, chemins dans `lib/features/progres/progres_paths.dart`, classe `ProgresPaths`, sans dépendance aux pages)
- `/progres` ; `/progres/semaine` (`?jour=2026-10-02` facultatif) ; `/progres/mois` (`?mois=2026-09`) ; `/progres/calendrier` (`?mois=2026-09` ou `?jour=2026-10-02`) ; `/progres/recuperation` ; `/progres/recuperation/muscles` ; `/progres/records` : dans l'onglet, barre visible.
- `/progres/bilan` : **plein écran** (`parentNavigatorKey: rootNavigatorKey`). `?mois=2026-09` (ou `2026-9`), le mois précédent par défaut ; `?page=serie` ouvre directement une page (`ouverture, seances, regularite, volume, equivalent, serie, muscles, records, favoris, resume`). `ProgresPaths.bilan(mois, 'serie')`.
- Gardées, ancien habillage, plus liées depuis les écrans validés sauf Records : `/progres/records`, `/progres/exercices`, `/progres/exercices/:id`, `/progres/seance/:id`, `/progres/muscles`, `/progres/muscles/:muscle`, `/progres/comparer`.
- Liens sortants : `/profil/mensurations` et `/profil/photos` (`push`), `/entrainer/muscles?muscle=<nom>` (`go`, bascule sur l'onglet Entraîner), `/entrainer` (bouton « Voir » du conseil), `SeancePaths.detail(id)` (séance du jour touché).

**Choix à connaître**
- L'écart de la carte Progrès compare la période en cours à la précédente arrêtée au même point (lundi à vendredi contre lundi à vendredi). Le bilan de la semaine et les statistiques du mois comparent des périodes entières. Un écart nul ou sans base n'affiche rien.
- Un record = la meilleure série d'un exercice (1RM estimé, ou répétitions sans charge) dépasse tout l'historique ; la première fois ne compte pas. « Records 18 » = exercices avec un record.
- Bilan de la semaine : le pourcentage d'un groupe est son volume rapporté à sa meilleure semaine des douze dernières.
- Corps : quatre muscles en plein et quatre en retrait au plus, selon le volume.
- Récupération : dix-huit groupes (ni cou ni abducteurs) ; la vignette « Épaules » prend le faisceau le moins récupéré.
- Série de semaines du bilan : comptée au dernier jour du mois.

**Tests** (`test/progres/`, 37 tests)
- `progres_calculs_test.dart` : périodes, écarts, volumes par semaine et par mois, numéro de semaine, records, série de semaines, bilan du mois (régularité, toile, comparaison au mois d'avant, mois vide), récupération, chemins.
- `progres_rendu_test.dart` : rendu de chaque écran avec la démo, images dans `build/rendus/progres/` (380 de large), parcours des tuiles, calendrier vers les mois précédents, filtre des muscles, dix pages du bilan, Fold ouvert (900) et petit écran (320), état sans séance.
- `progres_navigation_test.dart` : l'appli entière avec le vrai routeur (bilan plein écran depuis Progrès et depuis l'accueil, mensurations, photos, explorateur de muscles). Il dépend des autres modules.
- `progres_stats_test.dart` : inchangé (calculs des pages gardées).

**Non fait, à savoir**
- Les écrans 42 et 45 n'ont pas de bouton de retour, comme la maquette : retour par le geste ou le bouton du téléphone.
- Les volumes sont affichés en kilos, sans conversion en livres.
- L'ambre des muscles est l'accent Ambre du thème (#FFA928), plus jaune que l'orange de la maquette.
- Les pages gardées (records, courbes par exercice, muscles, comparer, résumé de séance) ont encore l'ancien habillage.
- Pas de minuteur de rafraîchissement sur la récupération : elle se recalcule à chaque ouverture.
- Partage de l'image et écran réel non vérifiés sur appareil.

**Demandes**
- ACCUEIL : ouvrir le bilan par `context.push('/progres/bilan?mois=...')` plutôt que `go` : la croix rend alors la main à l'accueil (vérifié dans `progres_navigation_test.dart`). Flamme : `/progres/bilan?mois=<mois en cours>&page=serie`. « Voir plus » : `/progres/semaine`. Sans `mois`, le bilan montre maintenant le mois précédent.
- PROFIL : `/progres/records` et `/progres/calendrier` sont gardés. Avec la police de test, la page Mensurations déborde de 29 px à droite en 412 de large (vu dans mon test de navigation, peut-être seulement dû à la police de test).
- ENTRAÎNER : merci de garder `/entrainer/muscles?muscle=<nom de l'enum>`.
- FONDATION : `DemoData` sans photo ni cardio (la tuile Photos affiche 0, aucun cœur dans le calendrier). Un jeton pour l'orange des muscles en récupération serait bienvenu. `BodyImageRepository` garde en cache un chargement resté en attente quand un test s'arrête en cours de route : dans les tests de rendu, charger le personnage dans `runAsync` avant le premier écran (voir `progres_rendu_test.dart`).


### ENTRAÎNER, design du 2 octobre (écrans 29 à 40)

Onglet refait sur la maquette `refs/modeles/` (29 à 40), branché sur les vraies données. Remplace les sections « ENTRAÎNER, BIBLIOTHÈQUE » et « ENTRAÎNER, ROUTINES ET PROGRAMMES » pour tout ce qui touche aux écrans ; la logique (index de recherche, statistiques, progression, modèles) est gardée.

**Routes** (`entrainerRoutes()`, toutes sous `/entrainer`)
- `/entrainer?onglet=programmes|routines|exercices` : la racine à trois volets (`SelecteurSegmente`). `seances` (ancien nom) ouvre Routines.
- `/entrainer/programmes/idees` : idées de programmes (dans l'onglet, barre visible). `/entrainer/programmes/modele/:modeleId` : détail d'une idée et « Ajouter à ma bibliothèque » (plein écran).
- `/entrainer/programmes/:id` : page d'un programme (plein écran). `/entrainer/programmes/nouveau`, `/:id/modifier` : éditeur, inchangé.
- `/entrainer/routines/favoris` : routines en favori. `/entrainer/routines/nouvelle?retour=1`, `/entrainer/routines/:id/modifier` : éditeur, inchangé.
- `/entrainer/muscles?muscle=biceps` : explorateur de muscles (dans l'onglet).
- `/entrainer/exercices` (bibliothèque en page pleine, `?onglet=favoris|perso|recents&muscle=...&q=...`), `/entrainer/exercices/nouveau`, `/entrainer/exercices/:id/modifier`.
- **Fiche d'exercice, route stable : `/entrainer/exercices/:id?onglet=apropos|historique|progres|records`** (plein écran), et `/entrainer/exercices/:id/records` (historique des records). Les anciens noms d'onglet (`graphiques`, `muscles`, `comment`) restent compris.
- Redirections gardées pour les liens des autres modules : `/entrainer/routines` et `/entrainer/dossiers/:id` vers le volet Routines, `/entrainer/programmes` vers le volet Programmes, **`/entrainer/routines/:id` vers `SeancePaths.apercu(id)`** (« Lancer la séance »), `/entrainer/historique[/:id]` vers `/seance/historique`.

**Depuis la séance en cours** (`import '.../entrainer/bibliotheque/bibliotheque.dart';`)
- `ouvrirFicheExercice(context, exerciseId, {FicheTab tab = FicheTab.apropos, VoidCallback? onRemplacer})` : ouvre la fiche par-dessus tout, sans toucher à la pile de la séance. Passer `onRemplacer` pour brancher le raccourci « Remplacer » de la fiche sur l'écran « Remplacer un exercice » (09). Sans lui, la fiche remplace elle-même : dans la séance en cours si l'exercice y est, sinon dans les routines qui le contiennent.
- `pickExercises`, `pickExercise`, `choisirExercices`, `ExerciseThumb` : inchangés (le sélecteur a pris le nouveau design).

**Lancer une routine** : partout (ligne, bouton rond, suggestion « Commencer ») on fait `context.push(SeancePaths.apercu(id, programId: ...))` ; « Nouvel entraînement » fait `context.push(SeancePaths.vide)`. Le module n'ouvre plus `/seance` lui-même et n'a plus de page d'aperçu de routine.

**Écrans**
- 29 Programmes : toujours la bibliothèque. « Créer un programme », « Favoris · N routine(s) », les programmes (celui en cours d'abord, pastille verte « En cours »), bouton gris « Voir des idées de programmes ».
- 30 Idées : recherche, « Les classiques » (Full body, PPL, Haut / Bas), « Recommandé pour toi » (classé par le profil et le programme en cours, raison écrite). Couvertures au personnage ou à la pose (`CouvertureIdee`). Huit modèles, dont deux nouveaux : « Split 5 jours » et « À la maison » (poids du corps).
- 31 Programme : fond flou, couverture, boutons ronds retour / partage / menu, « Voir plus » (description, rythme, avancement, progression), nom en grand, « Ajouter une routine au programme » puis les routines.
- 32 Actions sur une routine et 33 Vignette : `showPanneauBas`. Sept cartes de jour (`CarteJour`) et une case photo (galerie, image recopiée dans le dossier de l'appli).
- 34, 35 Routines : suggestion seulement si l'appli est sûre, « Nouvel entraînement », « Tes routines ».
- 36 Exercices : recherche en pilule, Favoris et raccourcis par muscle sur le buste, puces Récents / Mes exercices / Muscles (puis Matériel, Catégorie), « Tous les exercices · N » avec trier / liste / créer, cartes avec signet et « ? ».
- 37 à 39 Fiche : À propos, Historique, Progrès, Records, et « Voir l'historique des records ». Ni onglet Classement ni bouton vidéo externe.
- 40 Explorateur de muscles.

**Règle de la suggestion** (`routines/logic/suggestion.dart`, pure et testée) : `suggererRoutine({maintenant, seances, routinesConnues, semaines = 8, seuil = 6})`. Une routine n'est proposée que si elle a été faite ce jour de la semaine au moins 6 fois sur les 8 dernières semaines (aujourd'hui ne compte pas, deux séances le même jour comptent une fois). Rien si elle est déjà faite aujourd'hui, supprimée, ou si aucune n'atteint le seuil ; à égalité, la plus récente. `raisonSuggestion` écrit la phrase. « Une autre » écarte la suggestion jusqu'au lendemain.

**Données ajoutées** (store, sans toucher aux modèles du noyau ; `RoutinePrefs.of(store)`)
- `routines_vignettes` : `[{id, jour}]` ou `[{id, photo}]`. Sans choix, la carte suit le rang de la routine (Lun, Mar, Mer...).
- `routines_favoris` : liste d'identifiants. `routines_suggestion` : `{ecartee: 'a-m-j'}`.
- Les idées ajoutées ne créent plus de dossier : le programme range ses routines. Les dossiers existants ne sont plus affichés (les routines restent, le champ `folderId` aussi).

**Réutilisable**
- `entrainer/commun/` : `CarteJour(jour:, taille:, fond:, choisie:)`, `PaletteEntrainer` (dégradés des jours, bleu des muscles secondaires, fonds des couvertures : seules couleurs en dur du module), `IconeTrait(Trait.xxx)` (icônes au trait de la maquette), `CorpsColore` / `CorpsFaceDos` (le personnage avec une teinte par muscle, `Teinte.principal` rouge et `Teinte.secondaire` bleu), `TexteNet`, `RecherchePilule`, `PuceAction`, `BoutonRond`, `Medaille`.
- `routines/routines.dart` : `LigneRoutine`, `VignetteRoutineVue`, `lancerRoutine`, `montrerActionsRoutine`, `suggererRoutine`, `RoutinePrefs`, `routinePrevue` (routine du jour avec la progression du programme appliquée).

**Écarts voulus avec la maquette**
- Panneau des actions (32) : une ligne en plus, « Ajouter aux favoris », sans quoi « Favoris » ne peut pas se remplir.
- Volet Routines : une ligne « Créer une routine » à la fin de la liste (la maquette ne montre aucun moyen d'en créer hors d'un programme).
- Les raccourcis par muscle de la bibliothèque filtrent la grille sur place ; c'est la puce « Muscles » qui ouvre l'explorateur.
- Fiche : après « Exercices alternatifs », les sections « Conseils » et « À éviter » du catalogue sont gardées.
- Muscles ciblés : dans le pack, les calques des deltoïdes antérieurs et latéraux de face sont identiques. Le muscle principal est peint par-dessus ; le secondaire reste dans la légende.

**Tests** : `test/entrainer/` (56 tests). `entrainer_rendu_test.dart` rend chaque écran avec les données de la maquette dans `build/rendus/routines/` et `build/rendus/bibliotheque/` (fichiers `29-...` à `40-...`) ; `entrainer_logique_test.dart` (suggestion, favoris, vignettes, idées, ajout d'un programme, déplacement) ; `bibliotheque_test.dart` (filtres, records, chiffres d'un muscle, sélecteur) ; `routines_test.dart`. `test/entrainer/outils.dart` : coquille de test avec la vraie barre du bas, et `prechargerCorps()` (à appeler dans `runAsync` avant de monter un écran qui montre le personnage, sinon un chargement resté en suspens dans un test précédent bloque les suivants).

**À savoir**
- Le thème Material hérite d'un espacement de lettres (0,25) sur le texte courant ; la maquette n'en a pas. Mes écrans sont enveloppés dans `TexteNet` (`DefaultTextStyle.merge(letterSpacing: 0)`). Les textes en 11,5 px de la maquette sont rendus en 13,8 (et non 14,4) : c'est la largeur mesurée sur les captures.
- La lueur des cartes de jour ne se voit pas dans les rendus de test (`debugDisableShadows`) : à regarder sur l'appareil.

**Demandes**
- SÉANCE : (1) ouvrir la fiche depuis la séance avec `ouvrirFicheExercice(context, id, onRemplacer: ...)` ; (2) `Lancement.routine` démarre la routine telle quelle : pour garder la progression des programmes, passer par `routinePrevue(context, routine, programId: ...)` avant `startFromRoutine`, et appeler `ProgramRepo.advance(programId)` à la fin ; (3) ne pas renommer `SeancePaths.apercu`, `SeancePaths.vide`, `SeancePaths.detail`, `SeancePaths.historique` sans prévenir.
- FONDATION : (1) un jeton pour le bleu des muscles secondaires (`#5AA2FF`, aujourd'hui dans `PaletteEntrainer.secondaire`) ; (2) régler l'espacement de lettres du thème à 0 (`TexteNet` deviendrait inutile, et les composants du noyau auraient la largeur de la maquette) ; (3) `BodyMap` ne sait teindre qu'une couleur à la fois et multiplie la teinte : `CorpsColore` pourrait remonter dans `core/ui/body` ; (4) la démo n'a aucune routine faite le même jour six semaines sur huit : aucune suggestion en démo. Poser les séances « Push » sur un jour fixe la ferait apparaître ; (5) `DemoData` range ses routines dans un dossier, qui n'a plus d'écran.
- ACCUEIL, COACH : `/entrainer/routines/:id` mène maintenant à « Lancer la séance » ; `/entrainer/programmes` et `/entrainer/routines` ouvrent les volets.


### ASSEMBLAGE, 2 octobre

Raccord des six modules du design du 2 octobre. Aucun écran redessiné : seulement les liens entre modules, les demandes croisées et les données de la démo.

**Raccords faits**
- ACCUEIL (`features/aujourdhui`) : la carte bleue et la ligne « résumé prêt » de la cloche ouvrent le bilan par `context.push('/progres/bilan?mois=AAAA-M')` (la croix rend la main à l'accueil) ; la flamme ouvre `/progres/bilan?mois=<mois en cours>&page=serie` (`AujourdhuiPaths.bilanSerie`) ; « Voir plus » et la ligne « objectif atteint » de la cloche font `context.go('/progres/semaine')` (la page vit dans l'onglet Progrès, sans bouton de retour). Plus aucun lien vers `/sante/corps/...` hors du module santé. Une carte de séance sans exercice ni média (cardio) n'a plus de filet en bas.
- SÉANCE : toucher l'image d'un exercice pendant la saisie (ou « Voir la fiche » du menu) appelle `ouvrirFicheExercice(context, id, onRemplacer: ...)` ; « Remplacer » referme la fiche et ouvre « Remplacer un exercice » (09). `/seance/routine/:id?programme=` et l'écran « Démarrer une séance » passent par `routinePrevue(...)` avant `startFromRoutine` : la progression du programme s'applique. `ProgramRepo.advance` était déjà appelé à l'enregistrement (`terminer_page.dart`).
- FONDATION :
  - `SessionRepo.finishActive({nom, notes, ressenti, debut, fin, type, medias})` ; `terminer_page.dart` ne passe plus par `updateActive`.
  - Jetons `AppTokens.orange` / `context.colors.orange` (#FFA928 : flamme, muscles en récupération) et `AppTokens.muscleSecondaire` / `context.colors.muscleSecondaire` (#5AA2FF). Utilisés par la flamme de l'accueil (à la place de `warning`), `CouleursPartage.flamme`, `VignetteMuscle.ambre` et `PaletteEntrainer.secondaire`.
  - `CarteResumeMensuel` : titre dans un `FittedBox`, jamais coupé.
  - Espacement de lettres du thème à 0 sur les styles headline, title, body et label (Material en ajoutait 0,25 sur le texte courant). Vérifié avant et après sur les rendus (`build/rendus/`) : le texte se resserre de quelques points, aucune mise en page ne bouge ; avec la police de test, le débordement signalé sur Mensurations passe de 29 à 22 px. `TexteNet` (ENTRAÎNER) n'a plus d'effet, il peut être retiré.
  - `nutrition/pages/goals_page.dart` : `context.go('/profil')`. Il ne reste aucun `push('/profil')`.
  - `android.permission.health.WRITE_EXERCISE` était déjà dans le manifeste.
- PROGRÈS : « 1 séance ce mois » et « 1 semaine de série » au singulier dans le calendrier.
- `DemoData` (`lib/core/demo/`) :
  - chaque routine tombe un jour fixe (Push, Pull, Legs, Push sur lundi, mardi, jeudi, samedi ; le jour où l'on ouvre la démo remplace le jour d'avant s'il n'en fait pas partie) et la séance de ce jour n'est jamais manquée sur neuf semaines : l'onglet Routines propose toujours la routine du jour ;
  - une sortie de cardio par semaine sur trois mois (course, vélo, rameur, fractionné ; les deux dernières sont des courses, donc un cœur dans la semaine et le calendrier) ;
  - les trois dernières séances portent des médias (deux photos et une vidéo de 24 s, une photo, deux photos) ;
  - les huit zones de mensurations toutes les deux semaines, au demi-centimètre, gauche et droite égales ;
  - neuf photos de progression (cinq de face, deux de profil, deux de dos) avec le poids du jour.
  - Les images sont dessinées par `demo_images.dart` (silhouette neutre, haltère) et écrites en PNG dans `<stockage>/medias/` : rien n'est copié de `refs/` ni du pack. La vidéo n'a pas de fichier (sa tuile ne montre que sa durée).

**Test de bout en bout** : `test/parcours/parcours_test.dart` monte l'appli entière (vrai routeur, démo, Figtree et Montserrat) en 412 puis en 360 de large et parcourt : les quatre onglets ; carte bleue, quatre pages du bilan, croix ; flamme ; « Voir plus » ; une séance passée ; Entraîner, suggestion du jour, programme, routine, « Lancer la séance », Commencer, fiche puis Remplacer, deux séries validées, repos, Terminer, Enregistrer, carte « équivalent », bilan ; bibliothèque, explorateur de muscles, fiche et ses quatre onglets ; Progrès, calendrier, récupération, « Tout afficher », un muscle ; Profil, Mensurations, une mesure, modifier une saisie, Enregistrer ; Photos ; Réglages. Chaque étape relève les exceptions (débordement, route inconnue) et le test échoue en listant les étapes fautives. Images de contrôle dans `build/rendus/parcours/`. Un troisième test vérifie que la démo montre tout, quel que soit le jour de la semaine. Passé le 3 du mois, l'accueil n'a plus de carte bleue : le test ouvre alors la même route à la main.

**Vérifié sans rien changer**
- Mensurations en 412 et en 360 avec Figtree : aucun débordement. Les 29 px vus par PROGRÈS viennent de la police de test, bien plus large.
- Aucun rang, XP, badge ni classement dans l'interface ; aucun tiret long ou moyen dans `lib` et `test` ; aucun nom d'une autre appli de suivi.

**Non fait, à savoir**
- Réglages > Apparence > Taille du texte enregistre un choix (`TailleTexte.facteur`) qu'aucun écran n'applique : il n'y a pas de `textScaler` dans l'appli. À brancher par PROFIL et FONDATION, avec une passe de débordements.
- `CorpsColore` n'est pas remonté dans `core/ui/body` ; `TexteNet` et les contournements de `SubPageScaffold` sont laissés en place ; la démo range toujours ses routines dans un dossier (sans écran, sans effet).
- `/aujourdhui/semaine` et les autres anciennes sous-pages de l'accueil existent encore, plus rien n'y mène.
- Rien n'a été essayé sur un appareil : appareil photo, galerie, partage, Health Connect, notification de fin de repos, lueur des cartes de jour.


### ENTRAÎNER, éditeurs de programme et de routine (retour de Tristan, 2 octobre)

- `routines/pages/program_editor_page.dart` refait : couverture en tête et « Ajouter / Changer la photo », champs au cadre fin, Niveau en trois cartes à barres, Séances par semaine (1 à 7) et Durée (4, 6, 8, 12, 16, Autre) en pastilles, Jours en disques blancs, Objectif en grille de six cartes, Progression en cartes cochées, « Routines du programme » avec carte de jour, bouton blanc fixe. `routine_editor_page.dart` : mêmes champs et boutons, numéros de série et minuteur en bleu minuteur.
- Briques réutilisables dans `routines/widgets/` : `formulaire.dart` (`TitreSection`, `ChampBord`, `CadreChoix`, `CarteChoix`, `LigneChoix`, `CadreReglage`, `RangeePastilles`, `CocheChoix`, `LienBlanc`), `icones_editeur.dart` (`IconePicto(Picto.xxx)`, `IconeNiveau`), `photo_programme.dart` (`CouvertureDuProgramme`, `TuileDuProgramme`, `choisirPhotoProgramme`).
- Données, additif : `ProgramPlan.photo` (clé `photo` de `programmes_plans`, absente sans photo) ; `Program.objectif` reçoit le libellé d'un `ObjectifProgramme` (`routines/logic/objectif.dart`), un ancien texte libre est gardé tant qu'on ne touche pas à l'objectif.
- La page d'un programme et la liste des programmes montrent la photo quand il y en a une.
- Tests : `test/entrainer/editeurs_rendu_test.dart` (images `build/rendus/routines/editeur-*.png`).
- Non vérifié sur appareil : la galerie. À savoir : le message « retirée du programme » recouvre le bouton Enregistrer pendant trois secondes (comme les autres messages de l'appli).


### SÉANCE, 2 octobre au soir : écran de la séance en cours refait en liste

- `pages/seance_page.dart` : sous la barre du haut, tout défile ensemble (`SingleChildScrollView`, clé `defile-seance`) : encadré Durée / Volume / Séries (`EncadreChiffres` dans `widgets/habillage.dart`, durée au bleu du minuteur), liste des exercices, puis « Ajouter des exercices » (blanc) et « Plus » (gris) en fin de page.
- `widgets/exercice_carte.dart` : `ExerciceCarte(ouvert:, onBascule:, onAnnulable:)`. Replié : vignette, nom, « 1/3 effectués » (vert forêt quand tout est fait), trois points. Un seul exercice ouvert à la fois ; le premier non terminé à l'ouverture ; un exercice terminé se replie et le suivant à faire s'ouvre (en superset, on passe au membre suivant). Sans `onBascule` (page « Modifier la séance »), l'exercice reste ouvert comme avant.
- « Série supprimée / Annuler » n'est plus un SnackBar sur cet écran : une bande dans la mise en page, sous la liste et au-dessus du clavier, quatre secondes.
- Tests : `test/seance/seance_liste_test.dart` (logique et rendus `build/rendus/seance/liste-<largeur>-*.png`) ; `toucherPlus(t)` dans `test/seance/banc.dart` (le bouton « Plus » est en fin de page).

### IMPORT, rapprochement des noms revu sur un vrai historique (2 octobre)

- `lib/features/import/logic/exercise_synonyms.dart` : table de synonymes de noms d'exercices en anglais, vérifiée à la main contre le catalogue, consultée avant tout calcul. Trois issues par nom : correspondance sûre, voisins à confirmer, ou exercice personnel déjà rempli (nom français, muscles, matériel) quand le catalogue n'a pas l'exercice. Un test vérifie que chaque identifiant existe dans `assets/data/exercises.json` : après une régénération du catalogue, lancer `flutter test test/import/exercise_synonyms_test.dart`.
- `exercise_matcher.dart` : familles de mouvement (un rowing n'est plus jamais proposé pour un pec deck), matériel du champ `equipement`, mots de position presque sans poids, rien de proposé sous 0,60 (« à choisir »).
- « Tout accepter » ne prend que les suggestions sûres (`Rapprochement.suggestionSure`, score ≥ 0,85) ; `accepterSuggestions(toutes: true)` existe pour les tests. `test/inscription/test_donnees_premier_lancement_test.dart` a reçu trois lignes pour confirmer les suggestions incertaines.
- Séances importées : durée invraisemblable remplacée par une estimation, séance de cardio seule typée `TypeSeance.cardio`, superset d'un seul exercice défait.
- Catalogue, à savoir (non corrigé, fichier généré) : `curl-a-l-elastique` porte le nom anglais et les muscles d'un leg curl ; `decline-bench-press` est noté haltères mais décrit une barre et fait doublon avec `developpe-decline` ; il manque un rowing assis machine, un oiseau machine, un dips assis machine, une extension triceps au-dessus de la tête à la poulie, un curl pupitre haltère, des mollets à la presse.
