#!/bin/bash
# La bannière du README et ses bandeaux de section.
#
# Chaque texte porte ses deux langues, t <français> <anglais>. L'anglais
# n'est pas un calque : une tournure qui claque en français tombe à plat
# traduite mot à mot, alors elle est réécrite.
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/cartes.sh"   >/dev/null 2>&1
source "$D/bandeaux.sh" >/dev/null 2>&1

# Le rouge est celui de la lueur du logo, relevé dans le fichier (#FD0002),
# à peine éclairci pour rester lisible sur le fond sombre.
A="#FF2B2B"

# Le logo porte son propre badge sombre, qui n'occupe que 80 % du fichier
# (bord mesuré à 128 px sur 1254). Posé tel quel, il laisserait une marge
# morte et un double contour : il est agrandi à ${TAILLE:-184} px dans la
# fenêtre de 142, pour que la plaque coupe à l'intérieur du badge.
T="${TAILLE:-184}"
ban aesthetic "$A" "#8A0A12" "#0A0506" \
"<div class='crop'><img src='file:///$B/../logo.png' style='width:${T}px;height:${T}px'></div>" \
'<em>Æ</em>STHETIC' \
"$(t "Le suivi de musculation de Lyfta, refait pour moi, sans abonnement." 'Lyfta-style workout tracking, rebuilt for myself, with no subscription.')" \
"$(t 'Séances, records, streak et analyses, avec tout mon historique importé.' 'Workouts, records, streaks and insights, with my whole history imported.')" \
"$(P 'FLUTTER' "$(t 'HORS LIGNE' 'OFFLINE')" "$(t 'IMPORT CSV' 'CSV IMPORT')")" \
"$(C 'MOBILE' "$(t 'MUSCULATION' 'STRENGTH TRAINING')")" "<i>$(t 'EN COURS' 'IN PROGRESS')</i>"

# ------------------------------------------------ les bandeaux de section
rep aesthetic "$A" \
"$(t "L'idée" 'The idea')" \
"$(t "Ce que fait l'application" 'What the app does')" \
"$(t 'Reprendre ses données' 'Bringing your data along')" \
"$(t 'Où en est le projet' 'Where things stand')"
