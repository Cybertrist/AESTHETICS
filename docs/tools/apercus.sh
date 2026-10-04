#!/bin/bash
# Des images fixes de chaque schéma animé, pour les relire d'un coup :
# quatre instants par schéma, et une image par page pour le résumé mensuel.
# Elles vont dans docs/tools/html/apercus/, qui n'est pas versionné.
#
#   bash docs/tools/apercus.sh [nom du schéma...]
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$D/../schemas"; A="$D/html/apercus"; mkdir -p "$A"
noms=("$@"); [ ${#noms[@]} -eq 0 ] && noms=($(ls "$S"/*.svg | xargs -n1 basename | sed 's/\.svg$//'))
for n in "${noms[@]}"; do
  cycle="$(grep -o 'dur="[0-9.]*s" repeatCount="indefinite"' "$S/$n.svg" | grep -o '[0-9.]*' | sort -n | tail -1)"
  if [ "$n" = resume ]; then parts="0.03 0.12 0.20 0.29 0.42 0.56 0.64 0.73 0.81 0.90"; else parts="0.22 0.47 0.72 0.96"; fi
  i=1
  for p in $parts; do
    t="$(awk "BEGIN{printf \"%.1f\", $cycle*$p}")"
    node "$D/image.js" "$S/$n.svg" "$A/$n-$i.png" "$t" >/dev/null && echo "  $n-$i.png  à ${t}s"
    i=$((i+1))
  done
done
