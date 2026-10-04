#!/bin/bash
# La planche des widgets de l'écran d'accueil du téléphone.
#
# Les sources sont dans src-captures/widgets/ : ce sont les widgets tels que
# l'application les dessine (test/ecran_accueil/vues_rendu_test.dart, avec
# les données de la démo), pas des maquettes. Aucune vraie séance n'apparaît
# jamais ici.
#
#   bash docs/tools/widgets.sh
source "$(dirname "${BASH_SOURCE[0]}")/rendu.sh"
mkdir -p "$DOCS/schemas"
SRC="file:///$B/src-captures/widgets"

# widget <fichier> <titre> <légende> [classe]
widget () { printf '<figure class="%s"><div class="fond"><img src="%s/%s.png"></div><figcaption><b>%s</b>%s</figcaption></figure>' "$4" "$SRC" "$1" "$2" "$3"; }

{ entete 1280; cat <<HTML
<style>
.w{padding:26px 48px;display:grid;gap:26px 24px;grid-template-columns:repeat(3,1fr);align-items:start}
.col{display:flex;flex-direction:column;gap:24px}
figure{display:flex;flex-direction:column;gap:11px}
.fond{border-radius:24px;padding:22px 18px;display:grid;place-items:center;
  background:radial-gradient(120% 90% at 20% 10%,#4A3A33 0,#2C2C35 45%,#17181F 100%);
  box-shadow:0 0 0 1px #2A2B31}
.fond img{display:block;width:100%;filter:drop-shadow(0 10px 22px #0008)}
.carre .fond img{width:54%}
figcaption{font-family:'Space Grotesk',sans-serif;font-size:13px;line-height:1.45;color:var(--texte);padding:0 6px}
figcaption b{display:block;font-size:14.5px;color:var(--titre);margin-bottom:2px}
</style></head><body>
<div class="w">
<div class="col">
$(widget lancer 'Lancer ma séance' 'La routine du jour ; un appui la démarre.')
$(widget semaine 'Ma semaine' 'Les séances sur l’objectif, et les sept jours.')
$(widget serie 'Ma série' 'Les semaines d’affilée ; un jour fait devient une braise.')
</div>
<div class="col">
$(widget recup 'Récupération' 'Les muscles prêts en vert, le groupe conseillé.')
$(widget recordl 'Mon dernier record' 'Le personnage refait l’exercice du record, en boucle.')
</div>
<div class="col">
$(widget mois 'Mon mois' 'Le calendrier du mois, les jours d’entraînement, la flamme.')
$(widget record 'Le même, en carré' 'Pour un coin de l’écran.' carre)
</div>
</div>
HTML
pied; } > "$D/html/widgets.html"
rendre widgets.html "$DOCS/schemas/widgets.png"

# Puis la même chose en anglais, dans docs/en/.
if [ -z "$LANGUE" ]; then LANGUE=en bash "${BASH_SOURCE[0]}"; fi
