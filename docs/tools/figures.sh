#!/bin/bash
# La bannière du README et ses bandeaux de section.
#
# Chaque texte porte ses deux langues, t <français> <anglais>. L'anglais
# n'est pas un calque : une tournure qui claque en français tombe à plat
# traduite mot à mot, alors elle est réécrite.
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/cartes.sh"   >/dev/null 2>&1
source "$D/bandeaux.sh" >/dev/null 2>&1

# Le reste de la bannière reste sobre, gris clair. Seul le Æ reprend le
# rouge du logo (#F5070C mesuré sur docs/logo.png), un cran plus doux pour
# ne pas vibrer sur le fond noir, avec une lueur très faible.
A="${ACCENT:-#D4D4D4}"
EM="#EE1C25"
EMS="text-shadow:0 0 22px #EE1C2540"
export EM EMS

# Le logo porte son propre badge sombre, qui n'occupe que 80 % du fichier
# (bord mesuré à 128 px sur 1254). Posé tel quel, il laisserait une marge
# morte et un double contour : il est agrandi à 184 px dans la fenêtre de
# 142, pour que la plaque coupe à l'intérieur du badge. Valeur choisie en
# comparant 172, 184 et 196 px côte à côte.
ban aesthetic "$A" "#737373" "#0A0A0A" \
"<div class='crop'><img src='file:///$B/../logo.png' style='width:184px;height:184px'></div>" \
'<em>Æ</em>STHETIC' \
"$(t "Ma propre application de santé : musculation, nutrition, sommeil et un coach IA." "My own health app: training, nutrition, sleep and an AI coach.")" \
"$(t "Tout au même endroit, pour devenir la meilleure version de moi-même." "All in one place, to become the best version of myself.")" \
"$(P 'NUTRITION' "$(t 'SOMMEIL' 'SLEEP')" "$(t 'COACH IA' 'AI COACH')" 'FLUTTER')" \
"$(C "MOBILE" "$(t "SANTÉ" "HEALTH")" "$(t "MUSCULATION" "STRENGTH")")" "<i>$(t "EN COURS" "IN PROGRESS")</i>"

# ------------------------------------------------ les bandeaux de section
rep aesthetic "$A" \
"$(t "L'idée" 'The idea')" \
"$(t "S'entraîner" 'Training')" \
"$(t 'Manger' 'Eating')" \
"$(t 'La santé' 'Health')" \
"$(t 'Le coach' 'The coach')" \
"$(t 'Reprendre ses données' 'Bringing your data along')" \
"$(t 'Où en est le projet' 'Where things stand')"
