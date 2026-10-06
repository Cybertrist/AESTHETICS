# Consignes communes aux agents de test (2 octobre)

Appli Flutter ÆSTHETIC (musculation), dossier `C:\Users\trist\Documents\Github\Aesthetic\mobile`. Flutter : `/c/src/flutter/bin/flutter.bat`.
Une maquette validée par l'utilisateur vient d'être portée. État de départ : `flutter analyze lib test` propre, 286 tests verts.

Dix agents testent EN MÊME TEMPS, chacun une zone. L'utilisateur veut un résultat très soigné : cherche de vrais défauts, ne te contente pas de confirmer que ça marche.

## À lire
- `BRIEF.md`, dernière section « Design validé le 2 octobre » (elle prime).
- `COORDINATION.md`, les sections datées « design du 2 octobre » et « ASSEMBLAGE » qui concernent ta zone.
- La maquette : `refs/modeles/captures/NN-*.png` (liste dans `LISTE.txt`), source `refs/modeles/index.html`, liens `refs/modeles/proto.html`.

## Méthode
1. Lis le code de ta zone en cherchant les bugs : états limites (aucune donnée, une seule donnée, valeurs énormes, textes très longs, dates en bord de mois ou d'année, changement d'heure), calculs faux, données perdues ou écrasées, erreurs asynchrones (setState après dispose, contexte utilisé après un await), fuites (timers, contrôleurs non libérés), navigation (retour, double appui, route inconnue), accessibilité (cibles trop petites, libellés manquants).
2. Écris des tests qui reproduisent chaque défaut suspecté (unitaires ou de widgets, dans `test/<ta zone>/`, nouveaux fichiers au nom explicite). Un défaut n'est confirmé que s'il est reproduit par un test ou par un rendu.
3. Rends les écrans de ta zone (tests de rendu existants, drapeau `RENDUS=1` si le module l'utilise ; regarde comment font les tests en place), ouvre les images avec Read et compare-les une à une aux captures de la maquette : alignements, tailles, couleurs, textes coupés, éléments manquants ou en trop. Fais-le aussi en 360 de large et en large (Fold ouvert, 700 et plus).
4. Corrige ce que tu confirmes, DANS TA ZONE seulement, sans changer le design validé. Un défaut hors de ta zone ou dans `lib/core` : ne le corrige que s'il est petit, sûr et clairement à toi ; sinon décris-le précisément dans ton rapport.
5. Avant de finir : `flutter analyze` propre sur ta zone et ses tests, et `flutter test test/<ta zone>` vert. D'autres agents modifient d'autres modules au même moment : si un test échoue à cause d'eux, relance-le plus tard et signale-le, ne corrige pas leur code.

## Contraintes
Pas de couleur en dur hors thème, pas de tiret long ni moyen, ne jamais nommer une autre appli de suivi, rien écrire dans `refs/`, aucun commit git, ne rien installer, ne pas construire d'APK, ne pas toucher à `COORDINATION.md` (ton rapport suffit).

## Rapport final (pour l'agent principal, pas pour l'utilisateur)
- Défauts confirmés, du plus grave au moins grave : ce qui se passe, comment le reproduire, corrigé ou non, fichier.
- Défauts suspectés non confirmés.
- Écarts visuels avec la maquette, écran par écran, corrigés ou non.
- Tests ajoutés, résultat exact de l'analyse et des tests.
- Ce que tu n'as pas pu vérifier (notamment ce qui demande un vrai appareil).
