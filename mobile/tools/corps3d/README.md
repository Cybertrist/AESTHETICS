# Personnage anatomique (rendu 3D)

Le personnage de l'appli (`assets/body/`) est rendu à partir de vrais maillages 3D de muscles, découpés par muscle, avec three.js dans Chrome sans fenêtre.

## Sources et licences

- **BodyParts3D**, © The Database Center for Life Science (DBCLS), licence Creative Commons Attribution-Partage dans les mêmes conditions 2.1 Japon (CC BY-SA 2.1 JP). Peau du corps entier (`FJ2810.obj`, concept FMA7163) : tête, mains, pieds et sous-couche qui comble les interstices. https://dbarchive.biosciencedbc.jp/en/bodyparts3d/
- **Z-Anatomy** (dérivé de BodyParts3D), licence CC BY-SA 4.0 : maillages des 467 muscles séparés, réunis dans `anatomy.glb` par le projet BodyExplorer (JohanBellander, code MIT) et compressé en meshopt par le dépôt `25qi/muscle-3d-site` (code MIT, le modèle garde sa licence CC BY-SA).
- Les images produites (`assets/body/*.png`, `assets/body/masques/*.png`) sont une œuvre dérivée : elles restent sous **CC BY-SA 4.0** avec l'attribution ci-dessus (voir `docs/SOURCES_CORPS.md`).

## Refaire le rendu

```sh
cd tools/corps3d
npm install
sh telecharger.sh          # maillages dans cache/ (non versionné)
node rendu.js ../../assets/body
node controle.js assets/body captures/controle-final.png   # planche à côté des références
```

## Chaîne de rendu

1. `scene.js` charge les muscles (`anatomy.glb`) et la peau (BodyParts3D), écarte les muscles profonds et les fascias (`reglages.js`), lisse les maillages, écarte les bras, élargit les épaules, affine la taille, épaissit bras et jambes, gonfle chaque muscle le long de ses normales (physique sec et musclé), découpe le grand droit en tablette, remplace la tête par un œuf de mannequin lisse. La peau restante est plaquée juste sous les muscles (lancer de rayons) : elle ne sert qu'à boucher les trous.
2. Caméra orthographique de face et de dos, deux cadrages (corps entier 760 x 1200, buste 1100 x 900), suréchantillonnage x2. Passes : identifiant de maillage, normale et profondeur, coordonnées de fibres (axe principal ou éventail vers l'insertion).
3. `compo.js` nettoie les régions (îlots, lanières, filtre de majorité), ouvre la silhouette, calcule la distance aux coutures pour bomber chaque muscle en coussin, adoucit normales et profondeur dans chaque région, puis ombre sur le GPU : lumière douce du haut et de face, satin léger, occlusion ambiante par horizon, fibres, coutures claires et liseré de silhouette (`lumiere.js`).
4. Sorties par vue : `<vue>_base.png` (rendu complet, fond transparent), `<vue>_traits.png` (coutures seules, redessinées par-dessus la couleur), `masques/<vue>_<muscle>.png` (blanc, alpha = couverture exacte, alignés au pixel) et `masques/manifeste.json`. Les muscles profonds (rhomboïdes) ont un masque vu à travers le trapèze.

## Outils de mise au point

- `apercu.js "regex" face corps sortie.png` : maillages bruts colorés par région.
- `debugcarte.js dos buste` : carte des régions après nettoyage.
- `comparer.js`, `recadre.js` : planches côte à côte avec `refs/`.
