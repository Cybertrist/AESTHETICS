# Import d'historique : formats et rapprochement

Ce document décrit ce que l'import sait lire et comment il le transforme. L'interface ne nomme jamais l'application d'origine : elle parle d'« Importer depuis une autre application (CSV) ». Le code désigne les formats par leur forme (`legacy`, `ordreSeries`, `snakeCase`, `generique`).

Le code vit dans `lib/features/import/logic/` (Dart pur, sans Flutter), les exemples anonymisés dans `test/fixtures/`, les tests dans `test/import/`.

## Principe commun

Tous les formats connus écrivent **une ligne par série**. Les colonnes de la séance (titre, date, durée, notes) sont répétées sur chaque ligne. L'import :

1. décode le fichier (UTF-8 avec ou sans BOM, sinon Latin-1) ;
2. détecte le séparateur sur la ligne d'en-tête, hors guillemets (virgule, point-virgule, tabulation, barre verticale) ;
3. lit le CSV selon la RFC 4180 : guillemets doublés, retours à la ligne dans un champ, lignes vides ignorées ;
4. normalise les en-têtes (minuscules, sans accents ni guillemets, espaces simples, espaces de tête retirés) ;
5. reconnaît le format d'après les en-têtes et lit les lignes ;
6. regroupe en séances, puis en blocs d'exercices, puis en séries ;
7. rapproche les noms d'exercices du catalogue ;
8. calcule le rapport (séances, séries, records, noms à confirmer, doublons).

Les valeurs `null`, `NaN`, `none`, `undefined`, `-` et vides valent « rien ».

## Format A : l'export principal

C'est l'export de l'application utilisée jusqu'ici. Schéma relevé sur un vrai export (468 séries, 19 séances), en-tête **avec une espace devant `Title`** :

```
 Title,Date,Duration,Exercise,"Superset id",Weight,Reps,Distance,Time,"Set Type"
"Morning Workout","2026-07-13 07:30:19",01:07:22,"Bench Press",,55.000,10,null,null,NORMAL_SET
```

| Colonne | Contenu | Lecture |
| --- | --- | --- |
| `Title` | nom de la séance, peut contenir des virgules (entre guillemets) | titre |
| `Date` | début, `aaaa-mm-jj hh:mm:ss`, heure locale sans fuseau | début de séance |
| `Duration` | durée de séance `hh:mm:ss` | durée |
| `Exercise` | nom anglais du catalogue d'origine (« Lever Narrow Grip Seated Row », « Barbell Full Squat ») | rapprochement |
| `Superset id` | identifiant de superset, souvent vide | groupe de superset |
| `Weight` | charge avec trois décimales `55.000`, `0.000` au poids du corps, `null` pour un exercice chronométré | kg |
| `Reps` | entier, vide pour un gainage | répétitions |
| `Distance` | `null` le plus souvent | lue en km (non confirmé), convertie en mètres |
| `Time` | durée d'une série chronométrée `m:ss` | secondes |
| `Set Type` | `NORMAL_SET`, `WARMUP_SET`, `DROP_SET`, `NEGATIVE_REPS_SET`, `FAILURE_SET`, `BACK_OFF_SET` | type de série |

Pièges :
- l'espace devant `Title` casse une lecture naïve des en-têtes ;
- pas de colonne d'unité : la charge est en kg par défaut, l'option `uniteParDefaut` permet les livres ;
- pas de numéro de série : l'ordre des lignes fait foi ;
- la séance est identifiée par le couple `Date` + `Title` ;
- pas de colonne de notes ni de RPE dans l'export observé (lues si elles apparaissent : `Notes`, `RPE`, `RIR`) ;
- les types numériques de l'API de la même application (`0` normale, `1` échauffement, `2` et `3` côté droit et gauche, `4` échec, `5` dégressive, `6` négatives, `7` partielles, `8` myo-reps, `9` approche, `10` série lourde, `11` série de retour) sont aussi compris ;
- un type inconnu est lu comme série normale, avec un avertissement.

Détection : `exercise` + `date` + (`set type` ou `superset id`). Confiance 0,9 à 1 avec `title` et `duration`.

## Format B : export à « Set Order »

Deux variantes rencontrées.

Récente, séparée par des points-virgules, décimales parfois à virgule :

```
Workout #;Date;Workout Name;Duration (sec);Exercise Name;Set Order;Weight (kg);Reps;RPE;Distance (meters);Seconds;Notes;Workout Notes
```

Ancienne, séparée par des virgules :

```
Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Weight Unit,Reps,Distance,Distance Unit,Seconds,Notes,Workout Notes,RPE
```

Pièges :
- `Set Order` mélange numéros et marqueurs : `1`, `2`, … (normale), `W` (échauffement), `D` (dégressive), `F` (échec) ;
- des lignes `Rest Timer` décrivent un repos, pas une série : ignorées et comptées dans un message ;
- `Duration (sec)` est en secondes, l'ancienne `Duration` est en texte (`1h 5m`, `45m`) ;
- l'unité de charge est dans l'en-tête (`Weight (kg)`, `Weight (lbs)`) ou dans une colonne `Weight Unit` par ligne ;
- la distance est en mètres (`Distance (meters)`) ou selon `Distance Unit` ;
- les noms d'exercice portent le matériel entre parenthèses : `Bench Press (Barbell)` ;
- la séance est identifiée par `Workout #` s'il existe, sinon `Date` + `Workout Name`.

Détection : `exercise name` + `set order`.

## Format C : export en snake_case

```
"title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
"Push","22 Dec 2025, 08:00","22 Dec 2025, 09:12","","Bench Press (Barbell)",,"",0,"warmup",50,10,,0,
```

Pièges :
- dates au format `22 Dec 2025, 08:00` (mois abrégé en anglais, parfois en français selon la langue du téléphone) ;
- durée de séance = `end_time` moins `start_time` ;
- `set_type` : `normal`, `warmup`, `dropset`, `failure` ;
- `superset_id` est un entier à partir de 0 : `0` est un vrai superset, pas une valeur vide ;
- `duration_seconds` et `distance_km` valent 0 sur les séries de musculation : 0 est lu comme « rien » ;
- `weight_lbs` et `distance_miles` remplacent `weight_kg` et `distance_km` dans les exports en unités impériales ;
- `description` = notes de séance, `exercise_notes` = notes de l'exercice ;
- `set_index` repart de 0 à chaque exercice : l'import renumérote lui-même à partir de 1.

Détection : `exercise_title` + (`start_time` ou `title`).

## Tableau quelconque

Si aucun format n'est reconnu, l'import devine les colonnes à partir de synonymes français et anglais (`ColumnMapping.deviner`) :

| Champ | Exemples d'en-têtes |
| --- | --- |
| Date (obligatoire) | date, jour, start_time, horodatage |
| Exercice (obligatoire) | exercice, exercise, mouvement, nom |
| Nom de la séance | séance, titre, workout, programme |
| Charge | poids, charge, weight, poids (kg), weight (lbs) |
| Unité de charge | unité, unit, weight unit |
| Répétitions | reps, répétitions |
| Type de série | type, type de série, set order, série |
| Durée de séance, durée de série | durée, duration, secondes, temps |
| Distance, RPE, RIR, notes, notes de séance | distance, rpe, rir, notes, description |

Le tableau est utilisable s'il a une date, un exercice et au moins une mesure (charge, répétitions, durée ou distance). Sinon l'écran propose d'associer les colonnes à la main : `ColumnMapping` se construit champ par champ (`ChampImport` a un libellé français et un drapeau obligatoire), avec en option `uniteCharge` et `moisDabord`.

Dates `jj/mm/aaaa` et `mm/jj/aaaa` : l'ordre est déduit des données (une valeur au-dessus de 12 tranche) ; à défaut, jour d'abord. Un numéro dans la colonne de type de série veut dire « série normale ».

## Valeurs

- Nombres : `55.000`, `82,5`, `1 234,5`, `1,234.5`, `60kg`.
- Durées : `01:07:22`, `1:30` (minutes:secondes), `1h 5m`, `45 min`, `90s`, nombre de secondes.
- Dates : `2026-07-13 07:30:19`, ISO 8601 avec fuseau (converti en heure locale), `22 Dec 2025, 08:00`, `22 déc. 2025 08:00`, `Dec 22, 2025 8:05 pm`, `13/07/2026 18:30`, horodatage Unix. Les dates impossibles (31 février) sont refusées.
- Livres converties en kg (× 0,45359237), miles, pieds et yards convertis en mètres.

## Modèle intermédiaire

`ImportedSession` (titre, début local, durée, notes, doublon) contient des `ImportedExercise` (nom du fichier, identifiant du catalogue une fois rapproché, groupe de superset, notes) qui contiennent des `ImportedSet` (rang à partir de 1, `SetKind`, charge en kg, répétitions, durée en secondes, distance en mètres, RPE, RIR, notes, ligne du fichier). Chaque classe a `toJson` et `fromJson`.

Regroupement : une ligne rejoint le dernier bloc de la séance si l'exercice est le même. Dans un superset, les lignes alternent (A, B, A, B) : une ligne rejoint alors le bloc de même nom et même superset. Un exercice refait plus tard dans la séance, hors superset, forme un nouveau bloc, comme dans l'appli d'origine.

Sont écartées : les séries sans charge, répétitions, durée ni distance (ce sont les séries prévues d'une routine jamais remplies ; le message donne leur nombre et celui des séances qui disparaissent avec elles), les séances sans exercice. Une série au poids du corps (`0.000` et des répétitions), aux répétitions seules, à la durée seule ou à la distance est gardée. L'option `ignorerSeriesVides: false` garde tout.

Durée de séance : une durée de plus de six heures (chronomètre oublié), nettement plus courte que le temps des séries chronométrées, ou de moins de cinq minutes pour trois séries et plus, est jugée invraisemblable. Elle est remplacée par une estimation (temps des séries chronométrées, trois minutes par autre série, entre dix minutes et quatre heures) et un message en donne le nombre. Même estimation quand le fichier ne donne pas de durée.

À l'enregistrement, une séance qui ne contient que du cardio (marche, elliptique) devient une activité de type cardio ; un superset réduit à un seul exercice est défait.

`SetKind.echauffement` ne compte ni dans le volume ni dans les records.

## Rapprochement des noms

Le catalogue a un nom français (`nom`), un nom anglais (`nomEn`) et des alias. Tous sont indexés.

### Normalisation (`motsCanoniques`, `cleNom`)

1. minuscules, sans accents ;
2. tout ce qui n'est ni lettre ni chiffre devient une espace (`Bench Press (Barbell)` donne `bench press barbell`) ;
3. expressions ramenées à une forme unique, les plus longues d'abord : `pull up` et `tractions` donnent `pullup`, `souleve de terre` donne `deadlift`, `developpe couche` donne `bench press`, `rdl` donne `romanian deadlift`, `tirage vertical` donne `lat pulldown`, etc. ;
4. mots vides retirés (the, of, with, de, du, la, à, aux, avec…) ;
5. mots isolés ramenés à une forme unique : `db`, `dumbbells`, `haltère` donnent `dumbbell` ; `barre` donne `barbell` ; `lever`, `guidée` donnent `machine` ; `poulie` donne `cable` ; `assis` donne `seated` ; pluriels (`curls`, `raises`, `flyes`) ;
6. « s » final retiré des mots de plus de 4 lettres, sauf exceptions (`biceps`, `triceps`, `press`…).

`Développé couché à la barre` et `Barbell Bench Press` n'ont pas la même clé, mais le premier devient `bench press barbell`, et `Bench Press (Barbell)` aussi : les noms français et les noms à parenthèses se rejoignent.

### Table de synonymes (`exercise_synonyms.dart`)

Avant tout calcul, le nom est cherché dans une table de synonymes de noms d'exercices en anglais, vérifiée à la main contre le catalogue. La comparaison ignore l'ordre des mots (`Seated Row (Lever)` vaut `Lever Seated Row`). Une entrée dit l'une de ces trois choses :

- `sur` : le nom désigne sans ambiguïté un exercice du catalogue (`Lever Seated Fly` donne `pec-deck`) : statut `automatique` ;
- `proches` : un ou plusieurs voisins à confirmer, parce que le nom ne dit pas le matériel (`Incline Bench Press`, `Biceps Curl`) ou que la variante exacte manque : statut `ambigu`, candidats marqués `deTable`, jamais acceptés en lot ;
- `perso` seul : le catalogue n'a pas cet exercice (`Lever Seated Row`, `Lever Seated Reverse Fly`) : statut `nouveau`, avec un exercice personnel déjà rempli (nom français, muscles, matériel). Mieux vaut un exercice personnel qu'une mauvaise correspondance.

Un identifiant de la table absent du catalogue est ignoré, et un catalogue qui contient le nom exact garde la main sur une entrée « à créer ». Un test vérifie que chaque identifiant de la table existe dans le catalogue.

### Score

L'ordre : la mémoire des choix de l'utilisateur, puis la table, puis le calcul. Pour un nom absent de la table :

1. **Mémoire** : si l'utilisateur a déjà choisi pour cette clé, on applique son choix (statut `manuel`, ou `nouveau` pour un exercice personnel).
2. **Exact** : clé identique à un nom ou alias du catalogue (score 1).
3. **Mêmes mots dans un autre ordre** : score 0,97.
4. Sinon, on ne compare qu'aux exercices de la **même famille de mouvement**, puis on note les 60 plus proches :
   `0,8 × Dice pondéré des mots + 0,2 × (1 − Levenshtein / longueur)`.

Familles de mouvement : row, press (jambes, mollets, épaules, pectoraux), curl (biceps, jambes, poignets), extension (triceps, jambes, dos), raise (latéral, frontal, jambes, mollets), fly (avant, arrière), pulldown, pushdown, dip, squat, etc. Deux familles différentes ne sont jamais rapprochées : un rowing n'est pas proposé pour un pec deck, un leg curl pas pour un curl biceps. La famille d'un exercice du catalogue est celle de l'ensemble de ses noms (« Pec deck » est un fly par son alias).

Poids des mots dans le Dice : mouvement 2, matériel 1,5, mot ordinaire 1, partie du corps 0,6, position (`seated`, `standing`, `lying`) 0,4, mots presque vides (`grip`, `bar`, `arm`) 0,3. Une faute de frappe est tolérée dans les mots de 5 lettres et plus (comptée 0,85).

Corrections :
- matériel cité des deux côtés et différent (le champ `equipement` du catalogue compte quand le nom ne dit rien) : × 0,6 ; un exercice de cardio pour un nom de musculation : × 0,6 ; matériel cité d'un seul côté : × 0,93 ;
- `assisted` d'un seul côté : × 0,75 ; `weighted` d'un seul côté : × 0,85 ;
- chaque nom a un mot propre que l'autre n'a pas (`boat` contre `cat`) : × 0,7 sans aucun mot propre commun, × 0,85 sinon ;
- un mot propre sans équivalent en face plafonne le score à 0,84 ; le score approché est plafonné à 0,96.

Chaque exercice du catalogue garde son meilleur score parmi ses noms, les 5 meilleurs sont gardés.

### Décision

- `automatique` : entrée sûre de la table, ou meilleur score ≥ 0,90 **et** écart ≥ 0,05 avec le deuxième ;
- `ambigu` : voisins de la table, ou meilleur score ≥ 0,60 : l'écran montre les candidats, l'utilisateur confirme ;
- `inconnu` : en dessous de 0,60 rien n'est proposé, le nom est « à choisir » (`rechercher` sur tout le catalogue, ou exercice personnel) ;
- `nouveau` : exercice personnel, choisi par l'utilisateur ou prévu par la table.

Une suggestion est **sûre** (`Rapprochement.suggestionSure`) si elle ne vient pas de la table, que son score est ≥ 0,85 et qu'elle devance la suivante d'au moins 0,05. `accepterSuggestions()` (le bouton « Tout accepter ») ne prend que celles-là et renvoie leur nombre ; les autres restent à confirmer une par une, et l'écran en affiche le compte. `accepterSuggestions(toutes: true)` prend aussi les incertaines (tests).

Les choix sont gardés dans `memoire` (clé normalisée vers identifiant, chaîne vide pour un exercice personnel). La réutiliser au prochain import évite de reposer les mêmes questions.

Les noms à confirmer sont triés par nombre de séries : les plus fréquents d'abord.

## Rapport

`ImportReport` donne : format, lignes lues, séances (hors doublons), doublons, séries comptées et d'échauffement, exercices distincts, première et dernière date, volume total, durée totale, séances par mois, noms reconnus, à confirmer et personnels, messages (avec numéro de ligne).

Records par exercice (`RecordExercice`) : charge max (et répétitions à cette charge), 1RM estimé (Epley, séries de 1 à 12 répétitions), répétitions max, plus gros volume en une séance, nombre de séances et de séries, première et dernière fois.

## Doublons

`debutsExistants` : les séances déjà enregistrées. Une séance importée qui commence à la même minute est marquée `doublon`, affichée mais pas enregistrée. Réimporter le même fichier n'ajoute donc rien.

## Utilisation

```dart
final apercu = ImportAnalyzer.analyserOctets(
  octets,
  catalogue: [for (final j in exercices) CatalogueEntry.fromJson(j)],
  memoire: memoireSauvegardee,
  debutsExistants: seancesExistantes.map((s) => s.debut),
);
apercu.rapport.aConfirmer; // noms à faire valider
apercu.confirmer('Incline Bench Press', 'developpe-incline');
apercu.creerPersonnel('Curl maison');
if (apercu.rapport.pret) enregistrer(apercu.aImporter);
```

## Limites connues

- Format A : l'unité de la distance n'a pas été observée (colonne vide dans l'export étudié) ; lue en km.
- Les heures sont locales, sans fuseau : un historique fait à l'étranger garde l'heure du lieu.
- Pas de lecture des classeurs Excel : l'utilisateur exporte en CSV.
