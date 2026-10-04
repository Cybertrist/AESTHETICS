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

# Le personnage : ce que montrent la récupération (le corps entier) et la
# toile des muscles du résumé mensuel (le buste ou les jambes).
for f in face_base dos_base face_pectoraux face_deltoidesAnterieurs face_biceps face_quadriceps dos_triceps dos_grandDorsal          face_buste_base dos_buste_base face_jambes_base dos_jambes_base          face_buste_pectoraux face_buste_deltoidesLateraux dos_buste_triceps dos_buste_grandDorsal face_buste_biceps          face_buste_abdominaux face_jambes_quadriceps dos_jambes_ischios dos_buste_trapezes; do
  cp "$APPLI/body/pack/$f.webp" "$SORTIE/corps/" && echo "  corps/$f.webp"
done

# L'objet en 3D de la page « en objets » du résumé (Fluent Emoji, licence MIT).
mkdir -p "$SORTIE/objets"
cp "$APPLI/objets/elephant_3d.png" "$SORTIE/objets/" && echo "  objets/elephant_3d.png"

# Les poses : les exercices montrés dans les téléphones des schémas.
# pose <nom rangé> <nom possible dans l'appli>...
pose () {
  local sortie="$1" trouvee=""; shift
  for n in "$@"; do
    trouvee="$(ls "$APPLI/exercises/poses/$n"-peak.webp "$APPLI/exercises/poses/$n"*.webp 2>/dev/null | head -1)"
    [ -n "$trouvee" ] && break
  done
  [ -z "$trouvee" ] && { echo "  pose introuvable : $sortie" >&2; return; }
  cp "$trouvee" "$SORTIE/vignettes/$sortie.webp" && echo "  vignettes/$sortie.webp  ($(basename "$trouvee"))"
}
pose bench-press bench-press
pose cable-fly cable-fly
pose incline-db-press incline-db-press
pose squat squat
pose lat-pulldown lat-pulldown
pose deadlift deadlift
pose barbell-row barbell-row
