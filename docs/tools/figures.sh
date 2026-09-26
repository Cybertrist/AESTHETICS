#!/bin/bash
# La bannière du README et ses bandeaux de section.
#
# Chaque texte porte ses deux langues, t <français> <anglais>. L'anglais
# n'est pas un calque : une tournure qui claque en français tombe à plat
# traduite mot à mot, alors elle est réécrite.
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/cartes.sh"   >/dev/null 2>&1
source "$D/bandeaux.sh" >/dev/null 2>&1

# L'application est en noir et blanc, le vert n'y sert qu'à valider. La
# bannière suit : un gris clair pour l'accent, aucune couleur vive. Seul le
# logo garde sa lueur.
A="${ACCENT:-#D4D4D4}"

# Le logo porte son propre badge sombre, qui n'occupe que 80 % du fichier
# (bord mesuré à 128 px sur 1254). Posé tel quel, il laisserait une marge
# morte et un double contour : il est agrandi à 184 px dans la fenêtre de
# 142, pour que la plaque coupe à l'intérieur du badge. Valeur choisie en
# comparant 172, 184 et 196 px côte à côte.
ban aesthetic "$A" "#737373" "#0A0A0A" \
"<div class='crop'><img src='file:///$B/../logo.png' style='width:184px;height:184px'></div>" \
'<em>Æ</em>STHETIC' \
"$(t 'Musculation, nutrition et santé, avec un coach IA qui connaît mes séances.' 'Training, nutrition and health, with an AI coach that knows my workouts.')" \
"$(t 'Simple, en noir et blanc, et tout mon historique Lyfta repris.' 'Simple, black and white, with my whole Lyfta history brought over.')" \
"$(P 'FLUTTER' "$(t 'COACH IA' 'AI COACH')" 'HEALTH CONNECT' "$(t 'HORS LIGNE' 'OFFLINE')")" \
"$(C 'MOBILE' "$(t 'MUSCULATION' 'STRENGTH')" 'NUTRITION')" "<i>$(t 'EN COURS' 'IN PROGRESS')</i>"

# ------------------------------------------------ les bandeaux de section
rep aesthetic "$A" \
"$(t "L'idée" 'The idea')" \
"$(t "S'entraîner" 'Training')" \
"$(t 'Manger' 'Eating')" \
"$(t 'La santé' 'Health')" \
"$(t 'Le coach' 'The coach')" \
"$(t 'Reprendre ses données' 'Bringing your data along')" \
"$(t 'Où en est le projet' 'Where things stand')"
