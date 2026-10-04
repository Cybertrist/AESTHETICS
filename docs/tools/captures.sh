#!/bin/bash
# La planche de captures du téléphone.
#
# Les sources sont dans src-captures/telephone/, déjà rognées de leurs
# barres par rogner.js. Elles viennent de l'émulateur, dans la démo de
# l'application (--dart-define=DEMO=true) : aucune vraie séance n'apparaît
# jamais ici.
#
#   bash docs/tools/captures.sh
source "$(dirname "${BASH_SOURCE[0]}")/rendu.sh"
mkdir -p "$DOCS/schemas"
SRC="file:///$B/src-captures/telephone"

# ecran <fichier> <titre> <légende>
ecran () { printf '<figure><div class="cadre"><img src="%s/%s.jpg"></div><figcaption><b>%s</b>%s</figcaption></figure>' "$SRC" "$1" "$2" "$3"; }

{ entete 1280; cat <<HTML
<style>
.w{padding:26px 48px;display:grid;gap:26px 22px;grid-template-columns:repeat(4,1fr)}
figure{display:flex;flex-direction:column;gap:12px}
.cadre{border-radius:26px;padding:7px;background:linear-gradient(160deg,#34353B,#101114 45%,#222327);
  box-shadow:0 20px 40px #0009,0 0 0 1px #3A3A3F,inset 0 0 0 1px #FFFFFF10}
.cadre img{display:block;width:100%;border-radius:20px}
figcaption{font-family:'Space Grotesk',sans-serif;font-size:13px;line-height:1.45;color:var(--texte);padding:0 6px}
figcaption b{display:block;font-size:14.5px;color:var(--titre);margin-bottom:2px}
</style></head><body>
<div class="w">
$(ecran 01-accueil 'L’accueil' 'La série en semaines, la semaine en cours, les dernières séances.')
$(ecran 03-routines 'Les routines' 'La routine suggérée du jour, puis les tiennes, en cartes de jour.')
$(ecran 04-routine 'Une routine' 'Les muscles visés, les exercices, les séries prévues.')
$(ecran 05-seance 'La séance' 'On coche, la ligne passe au vert ; un record se dore.')
$(ecran 06-repos 'Le repos' 'L’anneau bleu, dix secondes de plus ou de moins.')
$(ecran 11-fin-records 'La fin de séance' 'Le volume, l’écart avec la dernière fois, les records battus.')
$(ecran 12a-partage 'Le partage' 'Des cartes à faire défiler, prêtes à envoyer.')
$(ecran 09-exercices 'Les exercices' 'Les muscles en tuiles, 608 exercices, la recherche.')
$(ecran 07-fiche-a-propos 'Une fiche' 'L’animation, les muscles ciblés, comment faire.')
$(ecran 08b-fiche-records 'Ses records' 'Cinq records par exercice, écusson « PR ».')
$(ecran 13b-progres-mois 'Les progrès' 'Le volume du mois, semaine par semaine.')
$(ecran 14-recuperation 'La récupération' 'Muscle par muscle, et le groupe conseillé.')
$(ecran 15-mensurations 'Les mensurations' 'Chaque zone reliée au corps, le poids, le taux de gras.')
$(ecran 16e-resume-comparaison 'Le résumé mensuel' 'Le volume du mois, converti en objets.')
$(ecran 17-profil 'Le profil' 'L’objectif, le calendrier du mois, les badges.')
$(ecran 18-badges 'Les badges' 'Neuf à paliers, et des secrets.')
</div>
HTML
pied; } > "$D/html/captures-telephone.html"
rendre captures-telephone.html "$DOCS/schemas/captures-telephone.png"

# Puis la même chose en anglais, dans docs/en/.
if [ -z "$LANGUE" ]; then LANGUE=en bash "${BASH_SOURCE[0]}"; fi
