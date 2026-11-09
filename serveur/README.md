# Serveur AESTHETICS

Firestore seul (offre gratuite) : les règles de sécurité `firestore.rules`, les index
`firestore.indexes.json`, et leurs tests. Le contrat des collections est dans `CONCEPTION.md`.

## Lancer les tests

Il faut Node, l'outil `firebase` et Java 21 pour l'émulateur.

```sh
cd serveur
npm install
export JAVA_HOME="/c/Program Files/Microsoft/jdk-21.0.13.21-hotspot"
export PATH="$JAVA_HOME/bin:$PATH"
firebase emulators:exec --project demo-aesthetics --only firestore,auth "npm test"
```

`emulators:exec` démarre l'émulateur, renseigne `FIRESTORE_EMULATOR_HOST` et lance `npm test`.
Avec un émulateur déjà lancé (`firebase emulators:start`), `npm test` suffit ; sans la variable,
les tests visent `127.0.0.1:8080`.

Les tests (`tests/*.test.js`, mocha) rejouent quatorze comptes simulés, décrits en tête de
`tests/monde.js` : amis, inconnus, bloqués, profils `tous`, `amis` et `prive`, un compte sans
profil. Le monde est réécrit avant chaque test ; chaque droit y est essayé permis et refusé.

## Ce que l'appli doit savoir

- **Pseudo** : la carte `profils/{uid}` et la réservation `pseudos/{pseudoMin}` s'écrivent dans le
  même lot (ou la même transaction). Changer de pseudo : réserver le nouveau, supprimer l'ancien et
  mettre la carte à jour, en un lot ; un lot qui garde l'ancien est refusé. L'ancien est celui que la
  carte porte sur le serveur (la relire avant le lot) ; supprimer un pseudo déjà rendu est permis.
  Effacer sa carte rend son pseudo dans le même lot.
- **Recherche** : 20 cartes au plus par requête (`limit(20)`), sinon refusée.
- **Dates** : `majLe`, `demandes.date`, `amis.depuis`, `blocages.date`, et la `date` des réactions
  et commentaires valent `FieldValue.serverTimestamp()`. La `date` d'une publication est celle de
  la séance (au plus un jour dans l'avenir).
- **Accepter** une demande : `amis/{vers}/liste/{de}`, `amis/{de}/liste/{vers}` et la suppression de
  `demandes/{de}_{vers}` **et** de `demandes/{vers}_{de}` (même absente) dans un seul lot, écrit par
  `vers`. **Retirer** : les deux sens ensemble.
- **Bloquer** : le blocage, la suppression des deux sens d'amitié et des deux demandes possibles,
  en un lot (supprimer une demande absente est permis).
- **Publier** sous l'identifiant `{auteur}_{seanceId}` (« / » en « _ »), avec une carte dont l'accès
  n'est pas `prive` ; un profil privé peut encore retirer des lecteurs de `visiblePar` (pas en ajouter)
  ou supprimer. Réécrire ses publications une par une : un lot de plusieurs dépasse les 1 000
  expressions que les règles évaluent par requête.
- **Le fil** : mes séances (`auteur == moi`), et celles de mes amis par paquets de 30 (`auteur in`,
  `visiblePar` array-contains moi). Une requête sur `visiblePar` seul est permise mais montre ce
  qu'un inconnu y a glissé.
- **Un ami qui part** : `where auteur == moi, visiblePar array-contains lui`, puis le retirer de chaque
  séance trouvée. Bloquer interdit déjà de réagir, de commenter et de lire les commentaires.
- **Effacer une séance** : ses réactions et commentaires d'abord (lots de 50), puis elle.
- **Détails** : `records` ≤ 4 de la forme `{exercice, kg, reps}`, `depuis` une année (int),
  `fetiches` ≤ 10, `badges` ≤ 20 entiers ; les autres listes bornées en nombre et en longueur totale.
- **Copie** : `copies/{uid}` = `ResumeCopie.toJson()` (plus `majLe` facultatif, `prenom` ≤ 200 unités
  UTF-16, `morceaux` ≤ 20) ; `copies/{uid}/morceaux/{n}` (n = 0 à 19) = `{ texte, n?, majLe? }`,
  `texte` ≤ 900 000 caractères.

## Déployer

Seulement quand les tests passent, et sur le vrai projet (`aesthetics-cybertrist`) :
`firebase deploy --only firestore:rules,firestore:indexes`.
