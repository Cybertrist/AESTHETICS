#!/bin/bash
# Toutes les figures fixes du README : la bannière, les bandeaux de
# section, les tuiles du sommaire, les fonctionnalités et la palette.
# C'est le seul fichier à ouvrir pour changer un texte des figures fixes.
#
#   bash docs/tools/figures.sh
source "$(dirname "${BASH_SOURCE[0]}")/rendu.sh"
mkdir -p "$DOCS/sections" "$DOCS/schemas" "$DOCS/sommaire"
LOGO="file:///$DOCS/logo.png"
ICONES='<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,500,1,0" rel="stylesheet">'

# ------------------------------------------------------------- bannière
# Le nom est tout en blanc, comme dans l'application : la bannière est en noir
# et blanc, sans couleur d'accent.
{ entete 1280; cat <<HTML
<style>
.w{width:1280px;height:340px;position:relative;overflow:hidden;
   background:radial-gradient(52% 140% at 9% 0%,#FFFFFF12 0%,transparent 60%),linear-gradient(135deg,#0B0C0F 0%,#0B0C0F 55%,#040405 100%)}
.grille{position:absolute;inset:0;opacity:.5;
  background-image:linear-gradient(#FFFFFF0B 1px,transparent 1px),linear-gradient(90deg,#FFFFFF0B 1px,transparent 1px);
  background-size:46px 46px;-webkit-mask-image:radial-gradient(70% 100% at 8% 50%,#000 0%,transparent 72%)}
.cat{position:absolute;top:26px;right:30px;display:flex;gap:8px}
.cat b{font-family:'JetBrains Mono',monospace;font-weight:500;font-size:12px;letter-spacing:2.2px;
  color:#E6E6EA;border:1px solid #FFFFFF3A;background:#FFFFFF10;border-radius:5px;padding:7px 13px}
.in{position:absolute;inset:0;display:flex;align-items:center;gap:48px;padding:0 66px}
.logo{width:150px;height:150px;flex-shrink:0;border-radius:34px;
  box-shadow:0 0 0 1px #FFFFFF24,0 0 44px #FFFFFF24,0 16px 34px #000C}
h1{font-family:Syne,sans-serif;font-weight:800;font-size:60px;line-height:1;letter-spacing:1px;color:#FFFFFF}
.sl{font-family:'Space Grotesk',sans-serif;font-size:23px;line-height:1.55;color:#9A9AA2;margin-top:18px}
.sl b{font-weight:500;color:#EDEDF0}
.pl{display:flex;gap:8px;margin-top:18px}
.pl span{font-family:'Space Grotesk',sans-serif;font-size:12.5px;font-weight:500;letter-spacing:.6px;
  color:#D8D8DE;border:1px solid #FFFFFF2A;background:#FFFFFF0C;border-radius:6px;padding:6px 11px}
.ln{position:absolute;left:0;right:0;bottom:0;height:3px;background:linear-gradient(90deg,#FFFFFF 0%,#8A8A92 40%,transparent 90%)}
</style></head><body>
<div class="w"><div class="grille"></div>
<div class="cat"><b>ANDROID</b><b>MUSCULATION</b><b>HORS LIGNE</b></div>
<div class="in"><img class="logo" src="$LOGO">
<div><h1>AESTHETICS</h1>
<p class="sl"><b>Chaque série. Chaque record. Chaque progrès.</b><br>Pour devenir la meilleure version de moi-même.</p>
<div class="pl"><span>Flutter</span><span>608 exercices</span><span>116 programmes</span><span>Aucun compte</span><span>Fold</span></div></div></div>
<div class="ln"></div></div>
HTML
pied; } > "$D/html/banniere.html"
rendre banniere.html "$DOCS/banniere.png"

# -------------------------------------------------------------- bandeaux
bandeau () {
{ entete 1280; cat <<HTML
<style>
.w{height:118px;display:flex;flex-direction:column;justify-content:center;gap:18px;padding:0 60px}
.l{display:flex;align-items:center;gap:20px;height:40px}
.ix{width:52px;height:40px;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-family:'JetBrains Mono',monospace;
  font-size:15px;color:#F5F5F7;border:1.5px solid #FFFFFF66;background:#FFFFFF14;border-radius:6px}
h2{font-family:Syne,sans-serif;font-weight:800;font-size:29px;letter-spacing:5px;text-transform:uppercase;white-space:nowrap}
.r{height:2px;display:flex}.r .a{width:52px;background:#FFFFFF}.r .b{flex:1;background:linear-gradient(90deg,#4A4A52,#26282E 42%,transparent)}
</style></head><body>
<div class="w"><div class="l"><div class="ix">$1</div><h2>$2</h2></div><div class="r"><i class="a"></i><i class="b"></i></div></div>
<script>
// Un titre trop long se resserre jusqu'à tenir dans la marge de droite.
document.fonts.ready.then(()=>{const h=document.querySelector('h2');let s=29;
  while(h.getBoundingClientRect().right>1220&&s>16){s--;h.style.fontSize=s+'px';h.style.letterSpacing=(s/29*5).toFixed(2)+'px';}});
</script>
HTML
pied; } > "$D/html/s$1.html"
rendre "s$1.html" "$DOCS/sections/s$1.png"
}

# --------------------------------------------------------------- sommaire
# Une tuile par section : son icône, son numéro, son titre. Une image
# chacune, pour que chaque tuile du README mène à sa section.
tuile () {
{ entete 250; echo "$ICONES"; cat <<HTML
<style>
.c{height:64px;display:flex;align-items:center;gap:13px;padding:0 14px;background:var(--carte);border:1px solid var(--bord);border-radius:14px}
.ic{font-family:'Material Symbols Rounded';font-size:22px;width:38px;height:38px;flex-shrink:0;border-radius:11px;
  display:flex;align-items:center;justify-content:center;color:#F5F5F7;background:#FFFFFF14;border:1px solid #FFFFFF40;box-shadow:0 0 16px #FFFFFF14}
.n{font-family:'JetBrains Mono',monospace;font-size:11px;color:#B4B4BC;letter-spacing:1px}
h3{font-family:'Space Grotesk',sans-serif;font-size:14.5px;font-weight:600;line-height:1.2;margin-top:2px}
</style></head><body>
<div class="c"><span class="ic">$2</span><div><div class="n">$1</div><h3>$3</h3></div></div>
HTML
pied; } > "$D/html/sommaire-$1.html"
rendre "sommaire-$1.html" "$DOCS/sommaire/$1.png" 250
}

# ------------------------------------------------------------- les grilles
# grille <nom> <colonnes> "icone|titre|texte" ...
grille () {
local nom="$1" cols="$2"; shift 2
local cartes=""
for e in "$@"; do
  IFS='|' read -r ic ti tx <<< "$e"
  cartes+="<div class=\"c\"><span class=\"ic\">$ic</span><div><h3>$ti</h3><p>$tx</p></div></div>"
done
{ entete 1280; echo "$ICONES"; cat <<HTML
<style>
.w{padding:22px 56px;display:grid;grid-template-columns:repeat($cols,1fr);gap:14px}
.c{background:var(--carte);border:1px solid var(--bord);border-radius:14px;padding:18px;display:flex;gap:15px;align-items:flex-start}
.ic{font-family:'Material Symbols Rounded';font-size:24px;width:46px;height:46px;flex-shrink:0;border-radius:13px;
  display:flex;align-items:center;justify-content:center;color:#F5F5F7;background:#FFFFFF14;border:1px solid #FFFFFF40;
  box-shadow:0 0 18px #FFFFFF12}
h3{font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:700;margin:2px 0 5px}
p{font-family:'Space Grotesk',sans-serif;font-size:13.5px;line-height:1.5;color:var(--texte)}
code{font-family:'JetBrains Mono',monospace;font-size:12.5px;color:#C9C9D0}
</style></head><body><div class="w">$cartes</div>
HTML
pied; } > "$D/html/$nom.html"
rendre "$nom.html" "$DOCS/schemas/$nom.png"
}

# ---------------------------------------------------------------- palette
pastille () { printf '<div class="p"><i style="background:%s"></i><b>%s</b><span>%s</span></div>' "$1" "$2" "$1"; }
palette () {
{ entete 1280; cat <<HTML
<style>
.w{padding:22px 56px;display:grid;grid-template-columns:repeat(8,1fr);gap:12px}
.p{background:var(--carte);border:1px solid var(--bord);border-radius:12px;padding:12px;display:flex;flex-direction:column;gap:8px}
.p i{height:54px;border-radius:9px;border:1px solid #FFFFFF24}
.p b{font-family:'Space Grotesk',sans-serif;font-size:13px}
.p span{font-family:'JetBrains Mono',monospace;font-size:11.5px;color:var(--texte)}
</style></head><body><div class="w">$*</div>
HTML
pied; } > "$D/html/palette.html"
rendre palette.html "$DOCS/schemas/palette.png"
}

# ------------------------------------------------------------ les appels
n=1
for titre in "Fonctionnalités" "Les écrans" "La séance" "Le 1RM et les records" "Programmes et progression"              "Les exercices" "La récupération" "La série" "Le résumé mensuel" "Les badges"              "Reprendre son historique" "Mes données" "Architecture" "Les tests" "Construire, licences et auteur"; do
  bandeau "$(printf '%02d' $n)" "$titre"; n=$((n+1))
done
bandeau "00" "Sommaire"

tuile 01 auto_awesome 'Fonctionnalités'
tuile 02 smartphone 'Les écrans'
tuile 03 fitness_center 'La séance'
tuile 04 emoji_events '1RM et records'
tuile 05 trending_up 'Programmes et progression'
tuile 06 menu_book 'Les exercices'
tuile 07 battery_charging_full 'La récupération'
tuile 08 local_fire_department 'La série'
tuile 09 auto_stories 'Le résumé mensuel'
tuile 10 military_tech 'Les badges'
tuile 11 upload_file 'Reprendre son historique'
tuile 12 folder_open 'Mes données'
tuile 13 account_tree 'Architecture'
tuile 14 task_alt 'Les tests'
tuile 15 gavel 'Construire et licences'

grille fonctionnalites 3   "fitness_center|La séance|Un tableau par exercice, la charge de la dernière fois à côté de chaque série, douze types de série. On coche, la ligne passe au vert."   "timer|Le minuteur de repos|Il part tout seul à chaque série validée : 90 secondes par défaut, réglable exercice par exercice, plus ou moins dix secondes d’un toucher."   "emoji_events|Les records|Poids, 1RM estimé, meilleure série, répétitions, volume : un record battu s’annonce pendant la séance, écusson doré « PR »."   "trending_up|Programmes et progression|116 idées de programmes, quatre façons de faire monter les charges, et une routine suggérée quand l’habitude est claire."   "menu_book|608 exercices|496 sont animés. Vingt muscles, une recherche en français ou en anglais, un filtre par matériel, et tes propres exercices."   "album|Disques et échauffement|Quoi charger de chaque côté de la barre avec ton matériel, et les paliers d’échauffement avant la série de travail."   "battery_charging_full|La récupération|Dix-huit muscles suivis, de l’orange au vert, et le groupe conseillé aujourd’hui."   "local_fire_department|La série|Comptée en semaines : une séance suffit pour qu’une semaine compte, et la semaine en cours ne casse rien."   "auto_stories|Le résumé mensuel|Dix pages à faire défiler, et le volume du mois converti en objets, de 0,25 kg à 225 tonnes. Un résumé annuel aussi."   "military_tech|Les badges|Neuf badges à paliers, six secrets, dix-huit étapes. Ni points d’expérience, ni rang."   "straighten|Le corps|Le poids, le taux de gras, huit mensurations et des photos d’évolution sous trois angles."   "ios_share|Le partage|À la fin d’une séance, cinq cartes à faire défiler, et une de plus s’il y a un record."   "upload_file|Reprendre son historique|Un export CSV d’une autre application devient des séances, des séries et des records, exercices rapprochés du catalogue."   "folder_open|À toi|Des fichiers sur le téléphone : aucun compte, aucun serveur. Tout s’exporte, se sauvegarde et se restaure."   "devices_fold|L’écran déplié|Dès 840 points de large, la barre du bas devient un rail, et la séance passe en deux colonnes."

palette "$(pastille '#000000' 'Fond') $(pastille '#131315' 'Cartes') $(pastille '#FFFFFF' 'Bouton') $(pastille '#E0393E' 'Muscles')
$(pastille '#228B22' 'Série validée') $(pastille '#1E9BF0' 'Minuteur') $(pastille '#FFBE0B' 'Record') $(pastille '#FF9A00' 'Flamme')"

# Puis la même chose en anglais, dans docs/en/.
if [ -z "$LANGUE" ]; then LANGUE=en bash "${BASH_SOURCE[0]}"; fi
