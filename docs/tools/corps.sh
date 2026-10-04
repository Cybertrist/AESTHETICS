#!/bin/bash
# Recopie depuis l'application les images dont les schémas animés ont
# besoin : le vrai personnage (le corps de face et de dos, un calque par
# muscle montré) et la pose des exercices cités. Les schémas les intègrent
# ensuite au SVG ; sans elles, ils gardent leurs dessins de secours.
#
# Ces images viennent du pack d'exercices, utilisé sous licence Enterprise.
#
#   bash docs/tools/corps.sh && node docs/tools/anime.js
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLI="$D/../../mobile/assets"
SORTIE="$D/../exercices"
mkdir -p "$SORTIE/corps" "$SORTIE/vignettes"

# Le personnage : ce que montre le schéma de la récupération.
for f in face_base dos_base face_pectoraux face_deltoidesAnterieurs face_biceps face_quadriceps dos_triceps dos_grandDorsal; do
  cp "$APPLI/body/pack/$f.webp" "$SORTIE/corps/" && echo "  corps/$f.webp"
done

# Les poses : les exercices des téléphones de « La séance » et « Les couches ».
for n in bench-press cable-fly incline-db-press; do
  pose="$(ls "$APPLI/exercises/poses/$n"*.webp 2>/dev/null | head -1)"
  [ -z "$pose" ] && { echo "  pose introuvable : $n" >&2; continue; }
  cp "$pose" "$SORTIE/vignettes/$n.webp" && echo "  vignettes/$n.webp  ($(basename "$pose"))"
done
