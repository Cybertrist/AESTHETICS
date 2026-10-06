#!/bin/bash
# Le résumé mensuel et le résumé annuel en mouvement.
#
# Les images sont celles de l'application : le test
# mobile/test/progres/bilan_film_test.dart ouvre le résumé de la démo, le
# feuillette page par page et photographie chaque page pendant qu'elle se
# construit, vingt fois par seconde. ffmpeg les assemble ici en WebP animé.
# Aucune vraie séance n'apparaît jamais ici.
#
#   bash docs/tools/bilan.sh           # refait les images, puis les assemble
#   SANS_TEST=1 bash docs/tools/bilan.sh   # assemble seulement
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$(dirname "$D")"
MOBILE="$(dirname "$DOCS")/mobile"
FILM="$MOBILE/build/rendus/bilan/film"
FLUTTER="${FLUTTER:-flutter}"

if [ -z "$SANS_TEST" ]; then
  rm -rf "$FILM"
  (cd "$MOBILE" && FILM=1 "$FLUTTER" test test/progres/bilan_film_test.dart) || exit 1
fi

mkdir -p "$DOCS/schemas"
for nom in mensuel annuel; do
  (cd "$FILM" && ffmpeg -v error -y -f concat -safe 0 -i "$nom.txt" \
    -vf "fps=20,scale=600:-1:flags=lanczos" \
    -c:v libwebp_anim -lossless 0 -q:v 82 -compression_level 6 -loop 0 -an \
    "$DOCS/schemas/resume-$nom.webp") || exit 1
  echo "resume-$nom.webp : $(du -h "$DOCS/schemas/resume-$nom.webp" | cut -f1)"
done
