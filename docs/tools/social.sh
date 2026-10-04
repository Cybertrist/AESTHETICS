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
SRC="file:///$B/src-captures/telephone"

cat > "$D/html/social.html" <<HTML
<!doctype html><html lang="fr"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Syne:wght@800&family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@600&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1280px;height:640px;overflow:hidden;background:#060607}
.w{position:relative;width:1280px;height:640px;overflow:hidden;
   background:radial-gradient(circle at 12% 30%,#3A1012 0,transparent 42%),
              radial-gradient(circle at 88% 90%,#1A1A1E 0,transparent 45%),#060607}
.w::after{content:"";position:absolute;left:0;right:0;bottom:0;height:6px;background:linear-gradient(90deg,#E0393E,#F5F5F7)}
.g{position:absolute;left:84px;top:0;bottom:0;width:600px;display:flex;flex-direction:column;justify-content:center}
.logo{width:132px;height:132px;border-radius:30px;box-shadow:0 0 0 1px #FFFFFF24,0 0 50px #E0393E55}
h1{margin-top:36px;white-space:nowrap;font-family:Syne,sans-serif;font-weight:800;font-size:52px;line-height:1;letter-spacing:1px;color:#FFFFFF}

p{margin-top:22px;font-family:'Space Grotesk',sans-serif;font-size:25px;line-height:1.45;color:#A7B0BD}
p b{font-weight:500;color:#E6EDF3}
.c{margin-top:30px;display:flex;gap:12px}
.c span{font-family:'JetBrains Mono',monospace;font-weight:600;font-size:15px;letter-spacing:1.5px;
  color:#F0A3A5;padding:10px 16px;border-radius:9px;border:1.5px solid #E0393E55;background:#E0393E14}
.e{position:absolute;width:220px;border-radius:26px;overflow:hidden;border:1.5px solid #3A3A3F;
   box-shadow:0 40px 80px -20px rgba(0,0,0,.8),0 0 60px -10px rgba(224,57,62,.30)}
.e img{width:100%;display:block}
.e1{left:770px;transform:rotate(-6deg);top:92px}
.e2{left:1010px;transform:rotate(5deg);top:58px}
</style></head><body><div class="w">
  <div class="g">
    <img class="logo" src="file:///$DOCS/logo.png">
    <h1>AESTHETICS</h1>
    <p><b>Chaque série. Chaque record. Chaque progrès.</b><br>Pour devenir la meilleure version de moi-même.</p>
    <div class="c"><span>ANDROID</span><span>MUSCULATION</span><span>FLUTTER</span></div>
  </div>
  <div class="e e1"><img src="$SRC/05-seance.jpg"></div>
  <div class="e e2"><img src="$SRC/14-recuperation.jpg"></div>
</div></body></html>
HTML

"$CH" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=15000 \
  --force-device-scale-factor=2 --window-size=1280,640 --screenshot="$D/html/social.png" "file:///$B/html/social.html" >/dev/null 2>&1
# Rendu deux fois plus dense, puis en JPEG : un PNG de cette taille dépasse
# le mégaoctet que GitHub accepte.
node "$B/jpeg.js" "$D/html/social.png" "$DOCS/social-preview.jpg" 0.92
echo "  social-preview.jpg  $(( $(stat -c %s "$DOCS/social-preview.jpg") / 1024 )) Ko"
