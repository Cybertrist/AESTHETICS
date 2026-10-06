#!/bin/bash
# Les captures brutes, prises sur l'émulateur dans la démo de l'application.
#
# L'application ouvre n'importe quelle page par un lien, celui dont se
# servent ses widgets : `aesthetics://ouvrir?chemin=/progres`. Chaque écran
# se photographie donc en une ligne, sans toucher l'émulateur. Les captures
# vont dans src-captures/brut/ ; rogner.js en retire ensuite les barres.
#
# Avant de lancer :
#   - l'émulateur tourne, avec la démo installée
#     (flutter build apk --debug --target-platform android-x64 --dart-define=DEMO=true)
#   - sa date est celle des figures, pour que la semaine de la démo soit pleine :
#     adb root && adb shell date 100420002026.00   (dimanche 4 octobre 2026, 20 h)
#     puis adb shell pm clear fr.cybertrist.aesthetic, et un premier lancement
#
#   bash docs/tools/emulateur.sh
#
# Restent à prendre à la main, parce qu'il faut y jouer une séance : 05-seance,
# 06-repos, 11-fin-records, 11a-fin-comparaison et 11b-record-en-seance
# (`voir /seance/routine/demo-routine-push`, cocher des séries, « Terminer »).
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRUT="$D/src-captures/brut"
ADB="${ADB:-adb}"
APPLI=fr.cybertrist.aesthetic
export MSYS_NO_PATHCONV=1
mkdir -p "$BRUT"

photo () { "$ADB" exec-out screencap -p > "$BRUT/$1.png"; echo "  $1.png"; }
# voir <chemin> <nom> [secondes d'attente] : le « ? » et le « & » du chemin s'écrivent %3F et %26.
voir () {
  "$ADB" shell "am start -n $APPLI/.MainActivity -a es.antonborri.home_widget.action.LAUNCH -d 'aesthetics://ouvrir?chemin=$1'" >/dev/null 2>&1
  sleep "${3:-4}"
  photo "$2"
}

voir "/" 01-accueil
voir "/entrainer%3Fonglet%3Dprogrammes" 02-programmes
voir "/entrainer%3Fonglet%3Droutines" 03-routines
voir "/entrainer/routines/demo-routine-push" 04-routine
voir "/entrainer/exercices/developpe-couche" 07-fiche-a-propos 5
voir "/entrainer/exercices/developpe-couche/records" 08b-fiche-records
voir "/entrainer/exercices" 09-exercices
voir "/progres" 13a-progres-semaine
voir "/progres/recuperation" 14-recuperation 5
voir "/profil/mensurations" 15-mensurations 5
voir "/progres/bilan%3Fmois%3D2026-09%26page%3Dequivalent" 16e-resume-comparaison 5
voir "/progres/bilan%3Fmois%3D2026-09%26page%3Dmuscles" 16g-resume-muscles 5
voir "/progres/bilan%3Fannee%3D2026%26page%3Dregularite" 16k-resume-annuel 5
voir "/profil" 17-profil
voir "/profil/grades" 18-badges
voir "/aujourdhui/serie" 21-serie
voir "/seance/historique" 22-historique

# La vue Année de Progrès : l'onglet se touche (écran de 1080 points de large).
voir "/progres" 13a-progres-semaine
"$ADB" shell input tap 855 385; sleep 3; photo 13c-progres-annee

# Le partage : la dernière séance « Push » de la démo, dont l'identifiant change à chaque remplissage.
ID=$("$ADB" exec-out cat /data/data/$APPLI/app_flutter/demo/seances.json | node -e "
  const l = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  const push = (Array.isArray(l) ? l : Object.values(l)[0]).filter((s) => s.nom === 'Push' && s.exercices.length > 1);
  console.log(push.sort((a, b) => (a.debut < b.debut ? 1 : -1))[0].id);")
voir "/seance/partager/$ID" 12a-partage 5
