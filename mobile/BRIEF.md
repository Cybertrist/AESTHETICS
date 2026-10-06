# ÆSTHETIC, cahier des charges commun (lu par tous les agents)

Appli Flutter Android de Tristan : sa propre appli de santé, musculation d'abord, puis nutrition, sommeil, coach IA.
Dossier : `Aesthetic/mobile/` (projet Flutter, id `fr.cybertrist.aesthetic`). Flutter : `/c/src/flutter/bin/flutter.bat` (pas dans le PATH).

## Règles d'écriture (strictes)
- Tout le texte de l'interface en français naturel. Jamais de tiret long ni de tiret moyen (ni dans le code, ni dans les commentaires, ni dans l'UI). Vérifier avec `grep -rn "—\|–" lib/`.
- Ne jamais nommer une autre appli de suivi (pas de « Lyfta », « Hevy », « Strong »…) dans l'interface, le README ou les commentaires visibles. L'import se présente comme « Importer depuis une autre application (CSV) ». Le code peut avoir un parseur `LegacyCsvFormat` qui reconnaît le format, sans le nommer à l'écran.
- Code sobre, commentaires en français, peu nombreux.

## Direction artistique (30/09, version définitive : celle de l appli de référence, remplace tout ce qui précède)
Tristan veut repartir sur la DA de l appli de muscu qu il utilisait. Ses captures officielles sont dans mobile/refs/modele/img_1 à img_7 : les ouvrir avec Read et les copier fidèlement (mise en page, tailles, couleurs, densité). Ne jamais nommer cette appli nulle part.
- Fond noir pur #000000. Cartes et tuiles gris foncé #1C1C1E, surfaces plus claires #2C2C2E, champ de recherche en pilule gris violacé #48454E, séparateurs #2C2C2E, cadres fins #3A3A3C.
- Texte blanc #FFFFFF, secondaire #A1A1A6, discret #6E6E73. Police système type Roboto (utiliser Roboto embarquée), poids 400/500/700, rien d excentrique ; grands chiffres en 700 (« 197 248kg »).
- Accent : bleu #1E9BE9 (numéros de série, liens, « Rest Timer: 2min », barres de graphiques, onglet actif souligné, bouton Terminer bleu). Série validée : ligne vert très sombre #0F2A14 avec coche ronde verte #4CD137. Barres de volume par muscle : rouge rosé #F0294B sur piste #3A3A3C. Toujours réglable dans Réglages > Apparence (Bleu par défaut, puis Ambre #FFA928, Lavande #9D8CFF, Lagon #3CE0FF, Pêche #FF8A65).
- Composants : en-tête simple « ‹ Titre » ; onglets du haut avec icône au-dessus et soulignement blanc ; cartes d exercices en grille 2 colonnes (grande image de l animation sur fond gris #2C2C2E, signet en haut à gauche, « ? » en haut à droite, nom et muscle dessous) ; rangée de filtres par muscle faite de petites silhouettes anatomiques, la sélectionnée dans un carré à bord blanc ; sélection par cercles blancs avec coche dans une pastille blanche (écran « Focus Area » : images anatomiques rondes) ; tableau des séries SET / PREVIOUS / KG / REPS avec coche ; bouton « + Ajouter une série » en pilule grise pleine largeur ; encadré Durée / Volume / Séries aux bords fins ; carrousels de programmes avec grandes images arrondies ; semaine en pastilles bleues avec l icône d haltère ; graphique en barres bleues ; corps face/dos réaliste dessous.
- Personnage et images de muscles : rendu anatomique réaliste (le style Gym visual des captures : gris clair, muscles ciblés en rouge orangé). Aucune lueur, aucun halo, aucun dégradé décoratif : c est plat, noir, net.
- Pas de bottom sheets pour les formulaires : pages plein écran ou dialogues. Fold fermé et ouvert gérés.
- Logo : Aesthetic/docs/logo.png, proportions respectées.

### Mise à jour du 1er octobre (prime sur ce qui précède)
- Police Figtree embarquée (400 à 800), titres en gras. Accent Corail #FF5A5F par défaut, toujours réglable.
- Images d exercices et personnage : ceux du pack sous licence (fond transparent, posés sur le gris #2C2C2E), jamais de fond blanc.
- Séance : cartes arrondies, exercice en cours ouvert, les autres repliés et regroupés ; une lueur discrète de l accent en haut de l écran est admise.
- Les captures de mobile/refs/modele restent la référence de mise en page : en cas de doute, on les reproduit.

### Design validé le 1er octobre au soir (prime sur tout ce qui précède)
- La référence est la maquette mobile/tools/maquette/maquette.html, validée par Tristan : simple et propre, une seule idée par écran, beaucoup d air, un seul accent (corail), vert réservé aux séries validées.
- Fond noir, cartes très discrètes #131315 aux coins de 26, surfaces #1D1D20, filets #222226. Pas de lueur ni de dégradé. Séance à plat, sans cartes.
- Avant d ajouter un bloc à un écran, se demander s il aide à s entraîner ; sinon il va sur une page secondaire.

## Architecture (contrat, ne pas dévier)
- État : `provider` + `ChangeNotifier`. Pas de build_runner (plusieurs agents travaillent en même temps).
- Persistance : `lib/core/data/store.dart`, fichiers JSON dans le dossier documents (path_provider), un fichier par collection, écriture atomique. Modèles dans `lib/core/models/` avec `toJson/fromJson` écrits à la main.
- Navigation : `go_router`, toutes les routes déclarées dans `lib/app/router.dart`. Chaque module expose ses routes dans `lib/features/<module>/routes.dart` (une fonction `List<RouteBase> xxxRoutes()`), le routeur les assemble.
- Thème et composants partagés : `lib/core/theme/` (tokens, ThemeData, accent réglable) et `lib/core/ui/` (boutons pilule, cartes, en-têtes de section, tuiles, graphiques simples, états vides, champs, chips, stepper, etc.). Les modules utilisent ces composants, ils n'en recréent pas.
- Chaque module vit dans `lib/features/<module>/` et ne modifie PAS les fichiers d'un autre module. Pour un besoin partagé, écrire une demande dans `mobile/COORDINATION.md` (section « Demandes ») et la contourner localement proprement.
- Onglets (barre du bas) : Aujourd'hui, Entraîner, Coach (au centre), Nutrition, Progrès. Profil et réglages par l'avatar en haut.
- Variante démo : `--dart-define=DEMO=true` remplit des données inventées (séances sur 6 mois, repas, sommeil). La vraie version démarre vide sur l'inscription.

## Coordination entre agents
`mobile/COORDINATION.md` est le tableau commun. Chaque agent, en commençant, lit ce fichier ; en finissant, il y ajoute sa section : ce qu'il a livré (routes, écrans, sous-pages, fichiers), ce qu'il n'a pas fait, et ses demandes aux autres. Ajouter (append) sans réécrire les sections des autres.

## Références visuelles de Tristan
Dans `mobile/refs/` : cartes musculaires grises avec les muscles travaillés en rouge (style betterme), un personnage dessiné au stylo bleu sur papier quadrillé. Le personnage de l'appli doit être un vrai personnage stylisé, propre, nickel : anatomie grise satinée, muscles sculptés (physique sec et esthétique, V marqué, abdos dessinés), muscles ciblés en rouge. Vue de face et de dos.

## Identifiants des muscles (contrat entre catalogue d'exercices, personnage, récupération, stats)
Enum Dart `Muscle` dans `lib/core/models/muscle.dart`, noms de valeur exacts :
`pectoraux, deltoidesAnterieurs, deltoidesLateraux, deltoidesPosterieurs, biceps, triceps, avantBras, trapezes, grandDorsal, rhomboides, lombaires, abdominaux, obliques, fessiers, quadriceps, ischios, adducteurs, abducteurs, mollets, cou`.
Libellés français : Pectoraux, Deltoïdes antérieurs, Deltoïdes latéraux, Deltoïdes postérieurs, Biceps, Triceps, Avant-bras, Trapèzes, Grand dorsal, Rhomboïdes, Lombaires, Abdominaux, Obliques, Fessiers, Quadriceps, Ischio-jambiers, Adducteurs, Abducteurs, Mollets, Cou.
Dans les SVG du personnage, chaque muscle est un groupe `id="m-<valeur>"` (ex. `m-grandDorsal`), gauche et droite dans le même groupe.

## Widget du personnage (contrat)
`lib/core/ui/body/body_map.dart` : `BodyMap({BodyView view = BodyView.front, Map<Muscle,double> intensities = const {}, Color? highlight, Set<Muscle> selected = const {}, ValueChanged<Muscle>? onTap, double? height})`, plus `BodyMapDual` (face et dos côte à côte). Intensité 0..1 : 0 gris satiné, 1 rouge plein. Assets dans `assets/body/`.

## Catalogue d'exercices (contrat)
`assets/data/exercises.json` : liste d'objets `{id, nom (FR), nomEn, alias[], musclesPrincipaux[], musclesSecondaires[], equipement, categorie, mecanique, niveau, instructions[] (FR), conseils[], media: {gif|mp4|images[] (URL ou asset)}, source}`. Chargé par `lib/core/data/exercise_catalog.dart`.

## Design validé le 2 octobre (prime sur TOUT ce qui précède, direction artistique comprise)

Tristan a validé écran par écran une nouvelle maquette. Elle remplace `tools/maquette/maquette.html` et les captures `refs/modele`.

**Où regarder**
- `mobile/refs/modeles/captures/NN-nom.png` : une image par écran (liste dans `captures/LISTE.txt`). Les ouvrir avec Read avant de coder un écran.
- `mobile/refs/modeles/index.html` : la source (HTML et CSS) de chaque écran : y lire les tailles, couleurs, rayons, espacements exacts. Chaque écran est un bloc `<div class="item">` dont le titre est dans `<div class="cap">`.
- `mobile/refs/modeles/proto.html` : la même maquette, cliquable (qui mène où).
- Ce dossier `refs/` est privé (ignoré par git) : ne rien y écrire, ne rien en copier dans `assets/` sauf `refs/modeles/objets/*.png` (émojis 3D sous licence MIT, à embarquer dans `assets/objets/`).

**Règles validées (ne pas en dévier)**
- Fond noir #000, cartes #131315, surfaces #1D1D20, filets #222226, texte secondaire #8E8E93. Police Figtree. Un seul habillage partout.
- Bouton principal : blanc, texte noir (`context.colors.bouton`, déjà en place dans `PillButton` et le thème). Jamais de bouton rouge ou d'accent plein. Bouton destructif : gris, texte rouge.
- Vert forêt #228B22 (`AppTokens.foret`) pour une série ou un exercice validé ; ligne validée sur fond #12261A.
- Bleu #1E9BF0 réservé au minuteur de repos (pilule du haut, ligne « Minuteur de repos », anneau, numéros de série du tableau).
- Corail (accent) : seulement les muscles allumés, les étiquettes de muscle, le point de notification. Jamais sur un bouton.
- Aujourd'hui dans une semaine ou un calendrier : disque blanc plein, chiffre noir. Jour avec séance : cercle au contour blanc avec l'icône du type de séance (haltère en diagonale pour la musculation, cœur pour le cardio). Autres jours : la date seule.
- Barre de navigation : quatre onglets avec icône, Accueil, Entraîner, Progrès, Profil. (Coach et Nutrition restent derrière `Env.muscuSeule`.)
- Pas de rangs, pas d'XP, pas de classement.
- Aucune mesure inchangée n'affiche « 0 » ou « = » : on n'affiche rien.
- Le bilan du mois et les cartes de fin de séance ont leurs propres couleurs (dégradé de la couleur vers le noir, police Montserrat pour les gros titres) et utilisent les objets 3D de `assets/objets/`.
- Résumé mensuel : carte bleue sur l'accueil seulement du 1er au 3 du mois suivant ; disponible tout le mois dans Progrès.
- Cartes de jour des routines : style contour (cadre en dégradé, « Lun », « Mar »...), couleurs dans index.html (classe `.jk`).
- Les règles d'écriture du haut de ce fichier restent valables (français, pas de tiret long, ne jamais nommer une autre appli).

**Répartition des écrans par module** (numéros de `captures/LISTE.txt`)
- FONDATION : thème, barre de navigation à quatre onglets, composants partagés (pastille de jour, semaine, icône de type de séance, carte de séance, bouton, panneau du bas, roues), `assets/objets/`.
- ACCUEIL (`features/aujourdhui`) : 01.
- SÉANCE (`features/seance`) : 02 à 13, cartes de fin de séance 14 à 23, partage 24 à 28.
- ENTRAÎNER (`features/entrainer`) : 29 à 35 (programmes, idées, programme, actions, vignette, routines avec ou sans suggestion), 36 à 40 (bibliothèque, fiche à onglets, explorateur de muscles).
- PROGRÈS (`features/progres`, récupération comprise) : 41 à 46, bilan du mois 47 à 65.
- PROFIL (`features/profil`, mensurations et photos comprises) : 66 à 73.

**Méthode**
- Garder l'architecture (provider, go_router, store JSON, modèles à la main). Brancher les écrans sur les vraies données des dépôts ; la variante `--dart-define=DEMO=true` doit donner un rendu proche de la maquette.
- Ne toucher qu'à son module. Un besoin partagé : le demander dans COORDINATION.md et le contourner localement.
- Chaque module garde ou crée ses tests de rendu (`test/<module>/..._rendu_test.dart`, images dans `build/rendus/<module>/`), ouvre ses images avec Read et les compare aux captures de la maquette avant de dire que c'est fini.
- Avant de finir : `flutter analyze lib/features/<module> test/<module>` propre et `flutter test test/<module>` vert. Flutter : `/c/src/flutter/bin/flutter.bat`.
- Ajouter sa section en fin de COORDINATION.md (livré, non fait, demandes), sans réécrire celles des autres.
