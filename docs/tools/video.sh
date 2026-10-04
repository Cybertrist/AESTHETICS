#!/bin/bash
# La vidéo de présentation : la musique, synthétisée, puis les images,
# photographiées une à une dans Chrome et montées par ffmpeg.
# La vidéo sort dans docs/tools/html/video/aesthetics.mp4 (non versionné) :
# GitHub ne joue dans un README qu'une vidéo déposée par son éditeur web.
#
#   bash docs/tools/video.sh            la vidéo entière
#   bash docs/tools/video.sh --apercu   treize images fixes, pour relire
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$D/html/video"
node "$D/video/musique.js" "$D/html/video/musique.wav" && node "$D/video/capture.js" "$@"
