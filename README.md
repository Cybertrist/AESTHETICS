<div align="center">

<p>
  <img src="docs/langues/fr-on.png" alt="Français, page affichée" width="150" />
  <a href="README.en.md"><img src="docs/langues/en-off.png" alt="Read this page in English" width="150" /></a>
</p>

<img src="docs/banniere.png" alt="ÆSTHETIC, musculation, nutrition et santé, avec un coach IA qui connaît mes séances" width="100%">
<br><br>

</div>

**Mon application de suivi : la salle, l'assiette, le sommeil, et un coach qui relie les trois.**

Je m'entraîne quatre fois par semaine et j'ai plus de 460 séances derrière moi. Pour les suivre, j'avais une application pour la muscu, une autre pour les calories, et ma montre pour le reste. Aucune ne voyait l'ensemble, alors aucune ne pouvait me dire pourquoi je stagne. ÆSTHETIC rassemble tout au même endroit, dans une interface volontairement sobre.

<img src="docs/sections/s01.png" alt="01 L'idée" width="100%">

**Simple.** Noir et blanc, de grands chiffres, rien qui clignote. Le vert n'apparaît que pour valider : une série cochée, un objectif atteint, une progression. Si c'est vert, c'est fait.

**Complet.** Cinq onglets suffisent : Aujourd'hui, Entraîner, Coach, Nutrition, Progrès. L'écran du jour dit tout en un coup d'œil, la séance prévue, les calories restantes, les protéines, les pas, la récupération.

**À moi.** Pas d'abonnement, pas de fonction verrouillée. Les données restent sur le téléphone, avec une sauvegarde automatique chaque nuit.

J'ai longtemps utilisé Lyfta, que j'aime beaucoup et dont je reprends l'historique. ÆSTHETIC n'en est pas une copie : c'est ce que j'aurais voulu y trouver en plus.

<img src="docs/sections/s02.png" alt="02 S'entraîner" width="100%">

**La séance.** On coche ses séries, le minuteur de repos démarre tout seul, et la charge de la dernière fois est rappelée à côté de chaque série. Échauffement, séries dégressives, supersets, RPE et notes sont gérés.

**La progression.** Quand toutes les séries passent, l'application propose d'ajouter du poids la fois suivante. Le calculateur de disques dit quoi charger de chaque côté.

**Les programmes.** Un programme regroupe les routines de la semaine et sait où on en est. On peut partir d'un modèle, 5x5, push pull legs, haut et bas du corps, ou construire le sien.

**Les exercices.** Chaque fiche montre la courbe du 1RM estimé, l'historique des séries, les records personnels et un guide d'exécution.

<img src="docs/sections/s03.png" alt="03 Manger" width="100%">

**Le journal.** Les repas de la journée, les calories restantes en grand, et trois barres pour les protéines, les glucides et les lipides. Les objectifs se calculent à partir du poids, de l'activité et du but : prise de muscle, sèche ou maintien.

**Ajouter vite.** Scanner un code-barres, chercher un aliment, reprendre un repas habituel, ou prendre l'assiette en photo et laisser l'IA estimer ce qu'elle contient. La base alimentaire vient d'Open Food Facts.

**L'eau.** Un bouton, un quart de litre, une barre qui se remplit.

<img src="docs/sections/s04.png" alt="04 La santé" width="100%">

**Ce que la montre sait déjà.** Sommeil, pas, fréquence cardiaque au repos et calories brûlées arrivent par Health Connect, sans rien saisir.

**Le corps.** Poids, masse grasse, mensurations et photos d'évolution, avec leurs courbes.

**La récupération.** Muscle par muscle, calculée à partir des séances récentes, du volume et du sommeil. Elle dit ce qui est prêt à être travaillé aujourd'hui.

**Les compléments.** Créatine ou autre, avec un rappel et une case à cocher.

<img src="docs/sections/s05.png" alt="05 Le coach" width="100%">

Le coach est un onglet à part entière, au centre de la barre. Il lit les séances, les repas, le sommeil et la récupération, et répond avec des chiffres, pas des généralités.

**Il oriente.** Chaque matin, une phrase sur l'écran du jour : ce qu'il faudrait faire, et pourquoi.

**Il débloque.** « Je stagne au développé couché » : il regarde l'historique, repère depuis quand, et propose un plan précis sur deux semaines.

**Il agit.** Ses propositions se valident d'un geste : appliquer un changement au programme, ajouter un repas au dîner, déplacer une séance.

**Il fait le bilan.** Chaque dimanche, la semaine en quelques lignes : volume, records, sommeil, écart aux objectifs, et ce qui a manqué.

On choisit ce qu'il a le droit de lire, et rien ne lui est envoyé sans qu'on l'ait ouvert.

<img src="docs/sections/s06.png" alt="06 Reprendre ses données" width="100%">

Lyfta exporte tout son historique en CSV, depuis Profil, Paramètres, Exporter des données. ÆSTHETIC lit ce fichier et recrée les séances, les séries, les records et les programmes. Les noms d'exercices sont rapprochés automatiquement, et ceux qui restent ambigus sont montrés avant l'import.

Hevy, Strong et FitNotes passent par le même chemin, ainsi qu'un tableau quelconque dont on associe les colonnes à la main. L'export se fait dans l'autre sens aussi, en CSV ou en JSON.

<img src="docs/sections/s07.png" alt="07 Où en est le projet" width="100%">

La maquette est terminée : douze écrans interactifs, de l'écran du jour au coach, dans la direction artistique définitive. L'application Android arrive ensuite, en Flutter, avec une version complète et une démo installables côte à côte.

<br>

<sub>Projet personnel, sans lien avec Lyfta. Sous licence MIT.</sub>
