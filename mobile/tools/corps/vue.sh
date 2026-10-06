#!/bin/sh
# vue.sh fichier.svg sortie.png echelle [x y l h] : rendu d'un SVG (ou d'une zone) à l'échelle voulue.
s=$1; o=$2; e=${3:-1}; x=${4:-0}; y=${5:-0}; l=${6:-400}; h=${7:-860}
d=$(cd "$(dirname "$s")" && pwd -W)
cat > _vue.html <<H
<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#2B2D31;overflow:hidden;width:${l}px;height:${h}px}
img{position:absolute;left:-${x}px;top:-${y}px;width:400px;height:860px}</style></head><body><img src="file:///$d/$(basename "$s")"></body></html>
H
./cap.sh _vue.html "$o" $l $h $e
