# Défauts relevés sur l'émulateur (2 octobre au soir)

`Fmt` (écriture commune, disponible dans `lib/core/logic/format.dart`) : `Fmt.charge(kg, reps, [unite])` « 70 kg × 6 » (« × 12 » sans charge, « 70 kg » sans répétitions), `Fmt.fois` « × », `Fmt.minSec(secondes)` « 2:30 », `Fmt.decimal(valeur, {decimals})` « 72,5 » pour un champ de saisie, `Fmt.lireDecimal(texte)` relit « 72,5 » ou « 72.5 », `Fmt.joursEntre(de, a)` écart en jours de calendrier ; déjà là et inchangées : `Fmt.poids` « 70 kg », `Fmt.volume` « 1 690 kg », `Fmt.n`, `Fmt.repos`.

Captures dans `build/chasse/NNN-*.png` (les ouvrir avec Read). Règles de design : `BRIEF.md`, dernière section. Consignes générales : `TESTS_CONSIGNES.md` (méthode et contraintes), sauf que plusieurs agents corrigent en même temps, chacun sa zone ci-dessous.

## Écriture commune (à appliquer par chaque zone sur ses écrans)
- Charge et répétitions : « 70 kg × 6 » (espace avant kg, signe ×, pas la lettre x). Volume : « 1 690 kg ». Jamais « 70kg ».
- Décimales : virgule partout, y compris dans les champs de saisie (« 72,5 »).
- Repos et durées courtes : « 2:30 » (minutes:secondes), « 1 min » accepté dans une phrase.
- Baisse : en rouge (`context.colors.error`). Hausse : en vert (`success`). Écart nul : rien.
- Les fonctions de mise en forme sont dans `lib/core/logic/format.dart` (`Fmt`) : s'il manque une fonction, l'agent ACCUEIL ET SOCLE l'ajoute ; les autres utilisent ce qui existe ou formatent localement dans le même esprit.
- En-tête de toute page : bouton retour rond gris, titre en gras, comme les écrans de la maquette (`refs/modeles/captures/67-mensurations.png`). Pas d'icône Material bleue ni de pastille colorée : icônes blanches au trait dans un rond ou un carré gris. Bouton principal blanc. Aucun bleu hors minuteur de repos, aucun corail hors muscles.
- Le bas des pages respecte la zone système (barre de gestes) : `SafeArea` ou `MediaQuery.padding.bottom`.

## Zone PROGRÈS (`lib/features/progres`, `lib/features/sante/recuperation`)
1. Records et progression d'un exercice restés à l'ancien habillage (`223-records.png`, `226-record-detail.png`) : flèche nue, titre maigre, icônes Material bleues, courbe bleue, gains en corail, « 26,9kg ». À refaire au design validé ; gains en vert.
7b. Statistiques du mois : pastille « -80 % vs sept. » en gris, à passer en rouge (`211-volume-semaine.png`, `207-tuile-volume.png`).
23. Résumé mensuel : les séances de cardio affichent « 0 kg » dans la liste (afficher la durée seule) ; toucher à droite sur la dernière page ne fait rien (fermer la story).
24. Progrès : les tuiles séances / temps / records sous la carte du volume ne réagissent pas ; les rendre cliquables (séances vers le calendrier, temps vers le bilan de la période, records vers Records) ou retirer l'effet de bouton.
14b. Récupération : « Voir » de la carte « Conseillé aujourd'hui » ouvre Entraîner > Programmes, sans rapport ; ouvrir l'explorateur de muscles sur le muscle conseillé.
Pages gardées à l'ancien habillage à reprendre aussi : muscles, comparer, exercices (`ui/`).

## Zone SÉANCE (`lib/features/seance`)
2. « Modifier la séance » à l'ancien habillage (`021-...png`, `031-...png`, `pages/modifier_page.dart`).
5. Nombre de séries contradictoire : l'encadré de la séance dit 4, « Terminer la séance » dit 5 (échauffement compté d'un seul côté). Une seule règle partout dans l'appli : les échauffements ne comptent pas dans « séries » ni dans le volume ; vérifier aussi la carte de partage et le bilan.
7a. Bilan de séance : « -76 % vs dernier Push » en gris, à passer en rouge (`189-bilan.png`).
15. Séance en paysage : les personnages débordent de la carte « Muscles travaillés » (`172-seance-paysage.png`).
18a. Champ de saisie « 72.5 » avec un point ; « 2m30 » pour le repos ; « 70kg x 6 » dans la colonne Précédent : appliquer l'écriture commune.
20. Bilan de séance : « Tirage verti… » coupé dans le tableau de la routine (`010-bilan-seance-fin.png`).
Supprimer une série : le geste n'est pas trouvable (glisser ne marche pas depuis un champ) ; ajouter « Supprimer la série » bien visible dans le panneau « Type de série » si ce n'est pas déjà le cas, et faire marcher le glissé depuis toute la ligne.
Pages gardées à l'ancien habillage à reprendre : historique, détail, disques, réordonner, « Démarrer une séance » (ronds de lecture corail).
Supprimer les fichiers de médias quand une séance est abandonnée ou supprimée.

## Zone PROFIL (`lib/features/profil`)
3. Toutes les sous-pages des Réglages à l'ancien habillage (`281` à `2810-reglage.png`, `284-reglage.png`, `pages/reglages/*_section.dart`).
4. Textes de modules cachés visibles en musculation seule (`Env.muscuSeule`) : À propos (« Muscu, nutrition, sommeil et coach... »), Mes données (« ... sommeil, repas ... »), Rappels (blocs Compléments et Eau).
17. « Dernière saisie : 19 septembre » alors que l'historique va jusqu'au 30 septembre (`254-mensurations.png`, `265-mens-historique.png`).
22. Titres de page différents de la ligne qui y mène (« Séance et charges » ouvre « Entraînement », « Taille du texte » ouvre « Apparence », « Importer mes séances » ouvre « Importer et exporter ») ; « Repos par défaut » en double.
Réglages sans effet à retirer de l'interface : taille du texte, unité de longueur, unité d'énergie, séries d'échauffement automatiques (garder les données, masquer les lignes).
Photos de progression : `cacheWidth` sur les vignettes de la grille (`photos/photos_page.dart`) pour ne pas décoder en pleine résolution.
Retour depuis Records et Calendrier ouverts par le Profil : ouvrir par `push` une page au-dessus pour revenir au Profil.

## Zone ENTRAÎNER (`lib/features/entrainer`)
6. Fiche > Historique : médaille « Poids » sur des séries qui ne sont pas des records (`108-fiche-historique.png` contre `111-fiche-records.png`).
8. Éditeurs de programme et de routine : le bouton du bas passe sous la barre de gestes (`048`, `052`, `057`).
11. Idée « Haut du corps / Bas du corps » : seule la moitié basse du corps est allumée sur la couverture (`072-idee-ouverte.png`).
12. Sigle absurde après ajout d'une idée : « HAUT/BAS 4 / HBJ » (`076`, `079`).
13. « Une autre » fait disparaître la suggestion : proposer la routine suivante la plus plausible ; s'il n'y en a pas, le dire en une ligne au lieu de retirer le bloc sans explication.
16. Fenêtre de série de l'éditeur de routine mal composée (`058-routine-serie-edit.png`).
18b. Fiche d'exercice : « 70kg x 6 réps », « 85kg », « 1 690kg » : appliquer l'écriture commune.
19. Historique des records : « Record en cours 85 kg » au-dessus de « Ancien record 85 kg » : un record égal n'est pas un nouveau record.
21. Suggestion du jour : la ligne finit par un point médian orphelin (`080-routines.png`).
25. Recherche « dos » : « Shrug à la barre derrière le dos » avant Tractions et Rowing ; faire passer d'abord les exercices dont le muscle principal correspond.
Tri par défaut de la grille : les plus faits d'abord, puis alphabétique.
Éditeur d'exercice personnel resté à l'ancien habillage.

## Zone ACCUEIL ET SOCLE (`lib/features/aujourdhui`, `lib/app`, `lib/core`)
9. Accueil : le contenu défile sous la barre d'état (`002`, `003`) : garder une zone haute opaque.
10. Version démo : les photos de séance sont de grands blocs gris avec un haltère ; rendre ce remplacement plus soigné (dégradé sombre, pictogramme discret) dans la démo et quand un fichier manque.
14a. Retour Android depuis « Voir plus » (bilan hebdo) : on atterrit sur Progrès au lieu de l'Accueil.
18c. `Fmt` : fournir les fonctions de l'écriture commune (charge × répétitions, repos mm:ss, décimale à virgule) et corriger `Fmt.relatif` au changement d'heure.
Verrouiller l'orientation en portrait quand la largeur la plus courte de l'écran est sous 600 (téléphone, Fold fermé) ; laisser libre au-delà (Fold ouvert, tablette).
Barre « Entraînement en cours » : la montrer aussi par-dessus les pages plein écran (réglages, mensurations, fiche), sauf les écrans de la séance elle-même.
Fichier de données abîmé (`store.abimes`, `AppData.erreursChargement`) : afficher un message sur l'accueil qui le dit et indique où est la copie de secours.
Texte tertiaire trop sombre (#5C5C61) : l'éclaircir pour atteindre un contraste de 4,5 sur le fond des cartes.
Retirer du `pubspec.yaml` les polices jamais utilisées (Inter, Roboto, SpaceGrotesk) si aucun code ne les référence.
Inscription et import : finir de retirer le corail des commandes et les icônes à halo coloré.
