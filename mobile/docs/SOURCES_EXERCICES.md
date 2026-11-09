# Catalogue d'exercices : source, licence, limites

Le catalogue, les animations et le personnage viennent d'un pack d'exercices acheté (RepDB, licence commerciale Standard, au nom de Tristan) : **701 exercices** en français, dont **544 animés** (pack v1.53 du 8 novembre 2026). Tout est embarqué, rien ne dépend du réseau.

## Ce que l'appli embarque

- `assets/data/exercises.json` : le catalogue, au format `{id, nom, nomEn, alias[], musclesPrincipaux[], musclesSecondaires[], equipement, categorie, mecanique, niveau, suivi, instructions[], conseils[], media: {gif, imagesLocales[]}, source}`.
- `assets/exercises/anim/<id du pack>.webp` : animation en boucle, fond transparent, 720 px, cadence d'origine (20 images par seconde).
- `assets/exercises/poses/<id du pack>-start|peak|main.webp` : poses de départ et de fin (ou pose unique d'un maintien), 720 px. Elles servent de vignettes.
- `assets/body/pack/` : le personnage face et dos (corps entier et buste) et un calque coloré par muscle. C'est le même bonhomme que dans les animations.

## Identifiants

Les exercices historiques de l'appli gardent leur identifiant français, leur nom court et leurs alias (`developpe-couche`, `squat`, `tractions`…) : la table est dans `tools/repdb/identifiants.json`, et les programmes, le programme conseillé et la démo pointent dessus. Les autres exercices prennent l'identifiant du pack, en anglais.

## Régénérer

Depuis `mobile/`, avec le pack décompressé hors du dépôt (`npm install` une fois dans `tools/repdb/`) :

```
node tools/repdb/medias.mjs    --source=<dossier du pack>   # poses et animations (se relance sans tout refaire)
node tools/repdb/corps.mjs     --source=<dossier du pack>   # personnage et calques de muscles
node tools/repdb/catalogue.mjs --source=<dossier du pack>   # exercises.json, vérifie que chaque média existe
```

## Licence, à respecter

Le pack peut être embarqué dans l'appli et modifié (taille, compression). Il ne doit **jamais être publié en vrac** : ni le zip, ni le JSON, ni les dossiers d'images dans un dépôt public. Ces fichiers sont dans le `.gitignore` du dépôt. Interdit aussi : s'en servir pour entraîner ou conditionner un modèle génératif.

## Limites

- Les animations pèsent lourd : c'est le prix de la netteté en grand.
- Les maintiens et étirements (157 exercices) n'ont pas d'animation, seulement leur pose : c'est voulu par le pack.
- Le pack n'a qu'un personnage masculin.
- Le tibial antérieur (pack v1.46) est un muscle à part (`Muscle.tibialAnterieur`), avec son calque de face, sa tuile et sa catégorie « Tibial antérieur » ; un seul exercice le cible, il n'entre donc ni dans la récupération ni dans les muscles oubliés.
