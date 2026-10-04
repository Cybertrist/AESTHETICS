# Les outils qui dessinent ce README

Aucune image de ce dépôt ne sort d'un logiciel de dessin. Les figures fixes
sont des pages HTML que Chrome capture sans affichage, deux fois plus
denses que leur taille à l'écran ; les schémas animés sont des SVG écrits
par un script. Changer un texte, c'est changer une ligne. Le moteur vient
de SmartBudget.

## Refaire les images

    bash docs/tools/figures.sh     # bannière, bandeaux, sommaire, fonctionnalités, palette
    bash docs/tools/captures.sh    # la planche de captures
    node docs/tools/anime.js       # les schémas animés
    bash docs/tools/pastilles.sh   # les pastilles FRANÇAIS et ENGLISH, dans docs/langues
    bash docs/tools/social.sh      # l'aperçu social (JPEG), à déposer dans Settings > Social preview

Chaque commande fait la version française, puis l'anglaise dans `docs/en/`.

## Ce que fait chaque fichier

- `rendu.sh` : le moteur commun. La page écrit sa hauteur réelle dans son
  `<title>` une fois les polices chargées, `--dump-dom` la lit, la capture
  suit à cette hauteur. `--virtual-time-budget` est indispensable, sinon
  Chrome capture avant l'arrivée des polices.
- `figures.sh` : tout le texte des figures fixes. C'est le seul fichier à
  ouvrir pour corriger une phrase.
- `captures.sh` : la planche du téléphone, à partir de `src-captures/`.
- `rogner.js` : prépare les captures brutes de l'émulateur. Il retire la
  barre d'état et la barre de navigation d'après un `barres.txt` posé à
  côté, réduit et écrit en JPEG, par un canvas de Chrome.
- `anglais.json` : la traduction de chaque texte des figures. Un texte
  absent du dictionnaire arrête le rendu anglais et s'affiche : aucune
  figure anglaise ne garde une phrase française par oubli.
- `traduire.js` : applique `anglais.json` à une page, appelé par `rendu.sh`
  quand `LANGUE=en`.
- `anime.js` : les outils communs des SVG animés. Chaque schéma a son
  fichier dans `schemas/`, avec sa traduction à côté (`<nom>.en.json`).
  Les animations sont en SMIL, que GitHub joue dans une balise `<img>`.
  Pas de police externe : un SVG en `<img>` n'a pas le droit d'aller la
  chercher. `SEUL=seance,tests node docs/tools/anime.js` ne rend que ces
  schémas-là.
- `corps.sh` : recopie depuis l'application le vrai personnage (le corps
  de face et de dos, un calque par muscle) et la pose des exercices cités,
  dans `docs/exercices/`. Les schémas les intègrent au SVG ; sans elles,
  ils gardent leurs dessins de secours. À lancer avant `anime.js`.
- `image.js` : une image fixe d'un schéma animé à un instant donné, pour
  le vérifier sans attendre qu'il tourne.
- `jpeg.js` : convertit l'aperçu social en JPEG, sous le mégaoctet de GitHub.

## Les captures

Elles viennent de l'émulateur, dans la démo de l'application
(`--dart-define=DEMO=true`), qui se remplit d'un jeu d'essai au premier
lancement. Aucune vraie séance ne doit jamais entrer dans `src-captures/`.

## Ce dont ils dépendent

Chrome, cherché dans `C:\Program Files\Google\Chrome\Application` ; la
variable `CHROME` prend le dessus. Les polices, Syne, Space Grotesk,
JetBrains Mono et Material Symbols, viennent de Google Fonts au moment du
rendu : il faut une connexion.
