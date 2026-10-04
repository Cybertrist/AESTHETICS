#!/bin/bash
# L'image d'aperçu du dépôt, celle que GitHub montre quand le lien est
# partagé : 1280 x 640, la taille que GitHub recommande,
# rendue en 2560 x 1280 pour rester nette. Le logo et le nom
# à gauche, deux écrans de l'application à droite. Comme SmartBudget.
#
# À déposer dans Settings > General > Social preview : GitHub ne la lit
# pas depuis le dépôt.
#
#   bash docs/tools/social.sh
source "$(dirname "${BASH_SOURCE[0]}")/rendu.sh"
# Les écrans viennent des captures brutes de l'émulateur (1080 px de large),
# plus nettes que les JPEG réduits : la barre d'état et la barre de
# navigation sont masquées par le cadre du téléphone.
SRC="file:///$B/src-captures/brut"

cat > "$D/html/social.html" <<HTML
<!doctype html><html lang="fr"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Syne:wght@800&family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@600&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1280px;height:640px;overflow:hidden;background:#060607}
.w{position:relative;width:1280px;height:640px;overflow:hidden;
   background:radial-gradient(circle at 12% 30%,#26262A 0,transparent 42%),
              radial-gradient(circle at 88% 90%,#1A1A1E 0,transparent 45%),#060607}
.w::after{content:"";position:absolute;left:0;right:0;bottom:0;height:6px;background:linear-gradient(90deg,#FFFFFF,#8A8A92)}
.g{position:absolute;left:84px;top:0;bottom:0;width:600px;display:flex;flex-direction:column;justify-content:center}
.logo{width:132px;height:132px;border-radius:30px;box-shadow:0 0 0 1px #FFFFFF24,0 0 50px #FFFFFF30}
h1{margin-top:36px;white-space:nowrap;font-family:Syne,sans-serif;font-weight:800;font-size:52px;line-height:1;letter-spacing:1px;color:#FFFFFF}

p{margin-top:22px;font-family:'Space Grotesk',sans-serif;font-size:25px;line-height:1.45;color:#A7B0BD}
p b{font-weight:500;color:#E6EDF3}
.c{margin-top:30px;display:flex;gap:12px}
.c span{font-family:'JetBrains Mono',monospace;font-weight:600;font-size:15px;letter-spacing:1.5px;
  color:#E6E6EA;padding:10px 16px;border-radius:9px;border:1.5px solid #FFFFFF3A;background:#FFFFFF10}
.e{position:absolute;width:250px;padding:7px;border-radius:36px;
   background:linear-gradient(160deg,#3A3B41,#0E0F12 45%,#26272C);
   box-shadow:0 0 0 1px #4A4A52,0 40px 80px -20px rgba(0,0,0,.85),0 0 70px -10px rgba(255,255,255,.16)}
.e .v{position:relative;width:236px;height:481px;border-radius:29px;overflow:hidden;background:#000}
.e img{position:absolute;left:0;top:-29.7px;width:236px;display:block}
.e1{left:738px;transform:rotate(-4deg);top:66px}
.e2{left:1006px;transform:rotate(4deg);top:92px}
</style></head><body><div class="w">
  <div class="g">
    <img class="logo" src="file:///$DOCS/logo.png">
    <h1>AESTHETICS</h1>
    <p><b>Chaque série. Chaque record. Chaque progrès.</b><br>Pour devenir la meilleure version de moi-même.</p>
    <div class="c"><span>ANDROID</span><span>MUSCULATION</span><span>FLUTTER</span></div>
  </div>
  <div class="e e1"><div class="v"><img src="$SRC/05-seance.png"></div></div>
  <div class="e e2"><div class="v"><img src="$SRC/14-recuperation.png"></div></div>
</div></body></html>
HTML

"$CH" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=15000 \
  --force-device-scale-factor=2 --window-size=1280,640 --screenshot="$D/html/social.png" "file:///$B/html/social.html" >/dev/null 2>&1
# Rendu deux fois plus dense, puis en JPEG : un PNG de cette taille dépasse
# le mégaoctet que GitHub accepte.
node "$B/jpeg.js" "$D/html/social.png" "$DOCS/social-preview.jpg" 0.97
echo "  social-preview.jpg  $(( $(stat -c %s "$DOCS/social-preview.jpg") / 1024 )) Ko"
