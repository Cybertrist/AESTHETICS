#!/bin/sh
# Capture une page HTML en PNG : cap.sh page.html sortie.png largeur hauteur
d=$(cd "$(dirname "$1")" && pwd -W)
"C:/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=${5:-1} --window-size=$3,$4 --screenshot="$(cygpath -aw "$2")" "file:///$d/$(basename "$1")" >/dev/null 2>&1
