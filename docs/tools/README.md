# Les outils qui dessinent ce README

Aucune image de ce dépôt n'est un export d'un logiciel de dessin. Chacune
est une page HTML que Chrome capture en mode headless, au double de la
taille d'affichage pour rester nette sur un écran dense. Un texte de figure
se corrige donc en modifiant une ligne de script.

## Refaire toutes les images

    bash docs/tools/tout.sh

Cela rend les deux langues. Les scripts écrivent dans `docs/tools/png/`,
`sec/` et `langues/`, suffixés `-en` pour l'anglais, qui ne sont pas
versionnés. `installer.sh` recopie ensuite les fichiers retenus dans
`docs/` et `docs/en/`.

## Ce que fait chaque script

- `figures.sh` : la bannière et les sept bandeaux de section.
- `cartes.sh` : le gabarit des bannières 1280x320.
- `bandeaux.sh` : le gabarit des bandeaux de section numérotés.
- `pastilles.sh` : les deux pastilles du sélecteur de langue.
- `langue.sh` : la bascule `LANGUE` et la fonction `t <français> <anglais>`.
- `installer.sh` : repose les images rendues dans `docs/` ou `docs/en/`.
- `tout.sh` : enchaîne tout ce qui précède, dans les deux langues.

## Le logo

`docs/logo.png` porte son propre badge sombre, qui n'occupe que 80 % du
fichier. Sur la bannière, il est agrandi à 184 px dans une plaque de 142
pour que la plaque coupe à l'intérieur du badge : sans cela, on voit une
marge morte et un double contour. La valeur a été choisie en comparant
172, 184 et 196 px côte à côte.

## Ce dont ils dépendent

Chrome est cherché dans `C:\Program Files\Google\Chrome\Application`. La
variable d'environnement `CHROME` prend le dessus s'il est ailleurs.

Les polices, Syne, Space Grotesk et JetBrains Mono, sont chargées depuis
Google Fonts au moment du rendu : il faut une connexion.
