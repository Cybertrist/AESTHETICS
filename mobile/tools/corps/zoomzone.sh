#!/bin/sh
# zoomzone.sh page.html sortie.png x y largeur hauteur echelle : capture une zone agrandie d'une page de zoom
p=$1; o=$2; x=$3; y=$4; w=$5; h=$6; e=$7
cat > _zone.html <<H
<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;background:#2B2D31;overflow:hidden}iframe{border:0;width:$((400*e))px;height:$((860*e))px;transform:translate(-$((x*e))px,-$((y*e))px)}</style></head>
<body><iframe src="$p"></iframe></body></html>
H
./cap.sh _zone.html "$o" $((w*e)) $((h*e))
