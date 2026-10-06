#!/bin/sh
# Télécharge les maillages sources dans cache/ (environ 70 Mo).
set -e
cd "$(dirname "$0")"
mkdir -p cache
B=https://dbarchive.biosciencedbc.jp/data/bodyparts3d/LATEST
[ -f cache/anatomy.glb ] || curl -sL -o cache/anatomy.glb https://raw.githubusercontent.com/25qi/muscle-3d-site/main/public/anatomy.glb
if [ ! -f cache/peau.obj ]; then
  curl -sL -o cache/partof.zip $B/partof_BP3D_4.0_obj_99.zip
  unzip -o -q -j cache/partof.zip "partof_BP3D_4.0_obj_99/FJ2810.obj" -d cache
  mv cache/FJ2810.obj cache/peau.obj
fi
echo "maillages prêts dans cache/"
