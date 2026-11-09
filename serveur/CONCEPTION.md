# Serveur AESTHETICS : conception

Projet Firebase `aesthetics-cybertrist` (console : https://console.firebase.google.com/project/aesthetics-cybertrist).
Firestore en `europe-west1`. Application Android `fr.cybertrist.aesthetic`.

## Contraintes

- **Offre gratuite (Spark) seulement.** Pas de Cloud Functions, pas de Cloud Storage. Tout est dans
  Firestore, et la sécurité tient entière dans `firestore.rules`. Ce qui serait fait par une fonction
  (notifications, compteurs) se calcule dans l'appli.
- **Connexion : Google seulement** (Firebase Auth). Sans compte, l'appli marche comme avant, tout en
  local ; la communauté et la copie serveur demandent un compte.
- **La communauté reste coupée par défaut** (`AppSettings.communaute`). Le mode démo (`Env.demo`) garde
  ses profils d'exemple en mémoire, sans serveur.
- Les règles valident chaque écriture : propriétaire, clés autorisées (`keys().hasOnly`), types,
  longueurs. Rien n'est lisible sans être connecté.
- Les règles évaluent au plus 1 000 expressions par requête, lot compris, et n'ont pas de boucle :
  les listes sont bornées en nombre et en longueur totale (`join`), seuls les records sont vérifiés
  un à un. L'appli réécrit ses publications une par une, jamais en lot.
- Les photos de profil : une vignette de 96 px (PNG, seul format que Flutter sait écrire), en base64
  dans le document (≤ 40 000 signes de l'alphabet base64), faute de Cloud Storage.

## Collections

### `profils/{uid}` : la carte publique
Lisible par toute personne connectée, une à la fois ou par une recherche de 20 cartes au plus
(pas l'annuaire entier d'une requête). Écrite par `uid` seulement. Changer de pseudo rend l'ancien
dans le même lot ; effacer sa carte rend son pseudo dans le même lot.
`{ pseudo, pseudoMin, prenom, couleur (int ARGB), photo? (base64), acces: 'tous'|'amis'|'prive', majLe }`

### `profils/{uid}/details/public` : le reste du profil
Lisible par le propriétaire ; par toute personne connectée si `acces == 'tous'` ; par ses amis si
`acces == 'amis'` ; par personne d'autre si `'prive'`. L'accès est relu dans la carte `profils/{uid}`.
`{ phrase?, ville?, salle?, depuis? (année, int), montre: [noms de Visible ≤ 20], seances, heures
(≤ 1 000 000), serieSemaines, objectif?, niveau?, jours: [int ≤ 7], records: [{exercice, kg, reps} ≤ 4],
badges: {grade: int ≤ 20}, fetiches: [ids ≤ 10], nbAmis, majLe }`
L'appli relit ces champs sans se fier à leur type : une valeur inattendue ne rend pas le profil
illisible.
L'appli n'écrit que ce que `montre` autorise (le serveur ne reçoit pas ce qui est caché).

### `pseudos/{pseudoMin}` : unicité des pseudos
`{ uid }`. Création si absent et `uid == auth.uid` ; suppression par son `uid` (supprimer un pseudo
déjà rendu est permis). La carte `profils/{uid}.pseudoMin` doit correspondre à un document `pseudos/`
qui lui appartient, et un compte n'en garde jamais qu'un. L'appli relit sa carte avant chaque lot :
un autre téléphone a pu changer de pseudo.

### `demandes/{de}_{vers}` : demandes d'ami
`{ de, vers, date }`. Créée par `de` (pas vers soi-même, pas si `vers` a bloqué `de`, pas si déjà amis).
Lisible par `de` et `vers`. Supprimée par `de` (annuler) ou `vers` (refuser ou accepter).

### `amis/{uid}/liste/{autre}` : amitiés, dans les deux sens
`{ depuis }`. Lisible par `uid` ; et par ses amis (pour « amis en commun ») seulement si l'accès du
profil n'est pas `'prive'`.
- Accepter (par `vers`, en un lot) : crée `amis/{vers}/liste/{de}` et `amis/{de}/liste/{vers}` (permis
  parce que `demandes/{de}_{vers}` existe), et supprime les deux demandes, `{de}_{vers}` et la croisée
  `{vers}_{de}` (même absente). Les règles refusent un lot qui en laisse une : elle resterait une clé
  pour se refaire ami seul après un retrait.
- Retirer : chacun des deux supprime les deux documents, ensemble (un seul sens est refusé).

### `blocages/{uid}/liste/{autre}`
`{ date }`. Lu et écrit par `uid` seulement. Bloquer retire aussi l'amitié et les demandes.

### `publications/{id}` : séances partagées dans le fil
`{ auteur, seanceId, titre, date, dureeSec, volumeKg? (absent si les charges sont cachées), series,
exercices: [ids ≤ 6], records (int), note? (≤ 280), visiblePar: [uids], majLe }`
- L'identifiant est `{auteur}_{seanceId}` (les « / » remplacés par « _ ») : les règles l'exigent,
  personne ne prend celui d'un autre ni ne recrée une publication effacée.
- `visiblePar` = l'auteur et ses amis au moment de l'envoi (≤ 500). Les règles ne peuvent pas vérifier
  que ce sont des amis (500 lectures) : n'importe qui peut y glisser mon uid. Le fil ne se fie donc
  pas à `visiblePar` seul. Le fil d'une personne, c'est ses séances
  (`where('auteur', isEqualTo: moi).orderBy('date', descending)`), plus celles de ses amis par paquets
  de 30 (`where('auteur', whereIn: amis).where('visiblePar', arrayContains: moi).orderBy('date',
  descending)`), sur 30 jours. Un inconnu n'y entre pas et n'en chasse pas les amis.
- Lisible si `auth.uid in visiblePar`, et toujours par son auteur. Créée, modifiée, supprimée par
  `auteur` seulement. Un profil `'prive'` ne publie rien et ne peut que retirer des lecteurs.
- L'auteur réécrit `visiblePar` de ses publications des 30 derniers jours quand ses amis changent.
  Un ami qui part (retiré, bloqué, d'un côté ou de l'autre, même pendant que l'appli dormait) sort
  de toutes ses publications, les vieilles comprises : `where('auteur', isEqualTo: moi)
  .where('visiblePar', arrayContains: lui)`. Rien n'est publié si le profil est `'prive'` ou si `montre`
  ne contient pas `seances` ; fermer ses séances les retire toutes à ses amis.
- Effacer une publication efface d'abord ses réactions et commentaires (Firestore ne le fait pas).

### `publications/{id}/reactions/{uid}`
`{ type: 'coeur'|'feu'|'biceps'|'bravo'|'etoiles', date }`. Écrite par `uid` seulement, s'il peut lire
la publication et qu'aucun blocage ne le sépare de l'auteur. Lisible par les mêmes. L'auteur de la
publication (lu dans l'identifiant) les lit et les supprime, même la publication effacée.

### `publications/{id}/commentaires/{cid}`
`{ auteur, texte (1 à 500), date }`. Créé par `auteur == auth.uid` s'il peut lire la publication et
qu'aucun blocage ne le sépare de l'auteur (une vieille séance peut encore porter celui qu'on a bloqué).
Supprimé par son auteur ou par l'auteur de la publication, même la publication effacée. Pas de
modification.

### `copies/{uid}` et `copies/{uid}/morceaux/{n}` : la copie des données
Résumé (`ResumeCopie` de `lib/features/compte/logic/copie_serveur.dart`, prénom ≤ 200 unités UTF-16)
et morceaux (texte base64 d'un JSON compressé, ≤ 900 Ko chacun, 20 au plus : un compte ne remplit
pas le Go de l'offre gratuite). Lus et écrits par `uid` seulement.
Rien ne part tant que le téléphone et le serveur n'ont pas été comparés pour ce compte (le fichier
`compte` le retient) : un choix laissé en plan ou un réseau coupé pendant la connexion fait comparer
de nouveau, jamais écraser.

## Notifications (calculées dans l'appli)
- Demandes reçues : `demandes where vers == moi`.
- Acceptées : `amis/{moi}/liste` triés par `depuis`, pour ceux à qui j'avais demandé (pas si c'est moi
  qui ai accepté, ni pour une amitié défaite).
- Réactions et commentaires : écoute des sous-collections de mes publications récentes (30 jours).

## Dans l'appli
- `ServiceConnexion` et `ServiceCopies` (`lib/features/compte/logic/services.dart`) reçoivent leur
  version Firebase ; `CompteRepo` est branché, et une section « Compte » dans les Réglages connecte,
  déconnecte et montre l'état de la copie.
- `SocialRepo` garde ses méthodes et change de source : une source Firestore pour la vraie
  communauté, la source d'exemple actuelle pour la démo. La communauté allumée sans compte affiche
  « Connecte-toi avec Google pour retrouver tes amis ».
- L'espace coach reste un aperçu, hors de ce chantier.

## Tests
- `serveur/tests/` : tests des règles en Node (`@firebase/rules-unit-testing`) sur l'émulateur, avec
  des dizaines d'utilisateurs simulés et des tentatives d'abus.
- `mobile/test/social/` : la source Firestore testée avec `fake_cloud_firestore`, plusieurs
  utilisateurs sur une même base.
- Émulateurs : `firebase emulators:start` dans `serveur/` (Java 21 :
  `C:\Program Files\Microsoft\jdk-21.0.13.21-hotspot`).
