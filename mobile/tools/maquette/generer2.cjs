// Génère maquette2.html (proposition « l'image d'abord ») à partir du style de maquette.html.
// Usage : node generer2.cjs (dans ce dossier).
const fs = require('fs');
const path = require('path');
let s = fs.readFileSync(path.join(__dirname, 'maquette.html'), 'utf8');
const P = '../../assets/exercises/poses/', B = '../../assets/body/pack/', A = '../../assets/exercises/anim/';

const nav = (actif) => `<div class="nav">
    <div${actif === 0 ? ' class="actif"' : ''}><svg viewBox="0 0 24 24"><path d="M4 11l8-7 8 7v9H4z"/></svg>Accueil</div>
    <div${actif === 1 ? ' class="actif"' : ''}><svg viewBox="0 0 24 24"><path d="M6 8v8M3 10v4M18 8v8M21 10v4M6 12h12"/></svg>Entraîner</div>
    <div${actif === 2 ? ' class="actif"' : ''}><svg viewBox="0 0 24 24"><path d="M4 19V10M10 19V5M16 19v-7M21 19H3"/></svg>Progrès</div>
  </div>`;
const sil = (base, calque, nom, choisi) =>
  `<div class="sil${choisi ? ' choisi' : ''}"><div class="corps carre"><img src="${B}${base}.webp"><img src="${B}${calque}.webp"></div><span>${nom}</span></div>`;
const exo = (img, nom, mat, fav) =>
  `<div class="exo2"><div class="img"><img src="${P}${img}.webp"><i class="${fav ? 'fav' : ''}"><svg viewBox="0 0 24 24"><path d="M7 4h10v16l-5-4-5 4z"/></svg></i></div><b>${nom}</b><span>${mat}</span></div>`;
const mini = (img) => `<div class="mini"><img src="${P}${img}.webp"></div>`;
const coche = `<span class="coche"><svg viewBox="0 0 24 24"><path d="M5 12l5 5 9-10"/></svg></span>`;
const play = `<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`;

const css = `
  /* Proposition 2 : l'image d'abord, comme la page des exercices. */
  .lumiere { background: radial-gradient(circle at 50% 42%, #2A2A2F 0%, #151517 62%); }
  .sils { display: flex; gap: 12px; margin-bottom: 22px; }
  .sil { display: flex; flex-direction: column; align-items: center; gap: 7px; font-size: 12px; font-weight: 600; color: var(--gris); flex: none; }
  .sil .corps { width: 64px; border-radius: 20px; background: var(--carte); }
  .sil.choisi { color: #fff; }
  .sil.choisi .corps { background: var(--carte2); outline: 2px solid var(--accent); }
  .exo2 b { display: block; font-size: 15px; font-weight: 700; margin-top: 10px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .exo2 span { color: var(--gris); font-size: 13px; }
  .exo2 .img { position: relative; border-radius: 22px; aspect-ratio: 1 / 1.08; padding: 10px; background: radial-gradient(circle at 50% 45%, #2A2A2F 0%, #151517 68%); }
  .exo2 .img img { width: 100%; height: 100%; object-fit: contain; }
  .exo2 .img i { position: absolute; top: 10px; right: 10px; width: 30px; height: 30px; border-radius: 50%; background: rgba(0,0,0,.45); display: grid; place-items: center; color: var(--gris); }
  .exo2 .img i svg { width: 15px; height: 15px; }
  .exo2 .img i.fav { color: var(--accent); }
  .exo2 .img i.fav svg { fill: currentColor; }
  .pastilles { display: flex; gap: 8px; margin-bottom: 18px; }
  .pastilles span { padding: 7px 13px; border-radius: 17px; background: var(--carte); color: var(--gris); font-size: 13px; font-weight: 600; }
  .pastilles span.actif { background: #fff; color: #000; }
  .heros2 { border-radius: 28px; padding: 20px; }
  .heros2 .haut { display: flex; justify-content: space-between; align-items: flex-start; }
  .heros2 .nom { font-size: 38px; font-weight: 800; letter-spacing: -.02em; line-height: 1; margin-top: 8px; }
  .heros2 .duo { display: flex; justify-content: center; gap: 22px; margin: 6px 0 14px; }
  .heros2 .duo .corps { height: 230px; }
  .minis { display: flex; gap: 8px; }
  .mini { width: 46px; height: 46px; border-radius: 13px; background: var(--carte2); padding: 3px; flex: none; }
  .mini img { width: 100%; height: 100%; object-fit: contain; }
  .mini.plus { display: grid; place-items: center; color: var(--gris); font-size: 13px; font-weight: 700; }
  .routine { background: var(--carte); border-radius: 24px; padding: 16px 16px 16px 18px; display: flex; align-items: center; gap: 12px; margin-bottom: 10px; }
  .routine .t { flex: 1; min-width: 0; }
  .routine .t b { font-size: 18px; font-weight: 800; display: block; }
  .routine .t span { color: var(--gris); font-size: 13px; }
  .routine .minis { margin-top: 10px; }
  .routine .mini { width: 40px; height: 40px; border-radius: 12px; }
  .banniere { border-radius: 26px; height: 250px; padding: 8px; position: relative; margin-bottom: 4px; }
  .banniere img { width: 100%; height: 100%; object-fit: contain; }
  .banniere .titre2 { position: absolute; left: 18px; bottom: 14px; }
  .banniere .titre2 b { font-size: 22px; font-weight: 800; display: block; }
  .banniere .titre2 span { color: var(--accent); font-weight: 700; font-size: 14px; }
  .banniere .pts { position: absolute; right: 16px; top: 14px; color: var(--gris); letter-spacing: 2px; font-weight: 800; }
  .suite { display: flex; align-items: center; gap: 10px; margin-top: 6px; }
  .suite .etiquette { flex: none; }
  .corps-heros { display: flex; justify-content: center; gap: 26px; border-radius: 28px; padding: 16px 0 12px; margin-bottom: 20px; }
  .corps-heros .corps { height: 230px; }
`;

const ecrans = `
<figure>
<figcaption>Exercices (amélioré)</figcaption>
<div class="tel">
  <div class="ecran">
    <div class="tete"><div><div class="titre">Exercices</div><div class="sur">608 mouvements animés</div></div>
      <svg width="24" height="24" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg></div>
    <div class="sils">
      ${sil('face_buste_base', 'face_buste_pectoraux', 'Pectoraux', true)}
      ${sil('face_buste_base', 'face_buste_deltoidesAnterieurs', 'Épaules')}
      ${sil('face_buste_base', 'face_buste_biceps', 'Bras')}
      ${sil('dos_buste_base', 'dos_buste_grandDorsal', 'Dos')}
      ${sil('face_jambes_base', 'face_jambes_quadriceps', 'Jambes')}
    </div>
    <div class="pastilles"><span class="actif">Tout</span><span>Barre</span><span>Haltères</span><span>Machine</span><span>Poulie</span></div>
    <div class="grille">
      ${exo('bench-press-start', 'Développé couché', 'Barre', true)}
      ${exo('incline-db-press-start', 'Développé incliné', 'Haltères')}
      ${exo('lateral-raise-peak', 'Élévations latérales', 'Haltères')}
      ${exo('pull-up-peak', 'Tractions', 'Poids du corps', true)}
    </div>
  </div>
  ${nav(1)}
</div>
</figure>

<figure>
<figcaption>Accueil</figcaption>
<div class="tel">
  <div class="ecran">
    <div class="tete"><div><div class="sur">Jeudi 1 octobre</div><div class="titre">Bonjour Tristan</div></div><div class="avatar">T</div></div>
    <div class="heros2 lumiere">
      <div class="haut">
        <div><div class="etiquette">Séance du jour</div><div class="nom">Legs</div></div>
        <div class="sur" style="text-align:right">6 exercices<br>56 min</div>
      </div>
      <div class="duo">
        <div class="corps"><img src="${B}face_base.webp"><img src="${B}face_quadriceps.webp"><img src="${B}face_mollets.webp"><img src="${B}face_adducteurs.webp"></div>
        <div class="corps"><img src="${B}dos_base.webp"><img src="${B}dos_fessiers.webp"><img src="${B}dos_ischios.webp"><img src="${B}dos_mollets.webp"></div>
      </div>
      <div class="minis" style="justify-content:center;margin-bottom:16px">
        ${mini('squat-start')}${mini('romanian-deadlift-start')}${mini('leg-press-start')}${mini('leg-curl-start')}${mini('leg-extension-start')}${mini('standing-calf-raise-start')}
      </div>
      <div class="bouton"><svg width="16" height="16" viewBox="0 0 24 24" style="fill:currentColor;stroke:none"><path d="M7 4v16l13-8z"/></svg>Démarrer</div>
    </div>
    <div class="section" style="margin-top:22px"><b>Cette semaine</b><span>1 séance sur 4</span></div>
    <div class="semaine">
      <div class="jour fait">L<i>✓</i></div><div class="jour">M<i>29</i></div><div class="jour">M<i>30</i></div>
      <div class="jour auj">J<i>1</i></div><div class="jour">V<i>2</i></div><div class="jour">S<i>3</i></div><div class="jour">D<i>4</i></div>
    </div>
  </div>
  ${nav(0)}
</div>
</figure>

<figure>
<figcaption>Entraîner</figcaption>
<div class="tel">
  <div class="ecran">
    <div class="tete"><div class="titre">Entraîner</div><div class="avatar">T</div></div>
    <div class="onglets"><span class="actif">Séances</span><span>Programmes</span><span>Exercices</span></div>
    <div class="section" style="margin-top:0"><b>Push Pull Legs</b><span>Semaine 7 sur 12</span></div>
    <div class="barre" style="margin:-4px 0 22px"><i style="width:52%"></i></div>

    <div class="routine"><div class="t"><b>Push</b><span>6 exercices · 56 min</span>
      <div class="minis">${mini('bench-press-start')}${mini('incline-db-press-start')}${mini('lateral-raise-peak')}<div class="mini plus">+3</div></div></div>
      <div class="rond">${play}</div></div>
    <div class="routine"><div class="t"><b>Pull</b><span>6 exercices · 56 min</span>
      <div class="minis">${mini('pull-up-peak')}${mini('lat-pulldown-peak')}${mini('hammer-curl-peak')}<div class="mini plus">+3</div></div></div>
      <div class="rond">${play}</div></div>
    <div class="routine"><div class="t"><b>Legs</b><span>6 exercices · 56 min · aujourd'hui</span>
      <div class="minis">${mini('squat-start')}${mini('romanian-deadlift-start')}${mini('leg-press-start')}<div class="mini plus">+3</div></div></div>
      <div class="rond" style="background:var(--accent)">${play}</div></div>

    <div class="tuiles" style="margin-top:14px">
      <div class="bouton gris" style="font-size:15px">Séance vide</div>
      <div class="bouton gris" style="font-size:15px">Nouvelle routine</div>
    </div>
  </div>
  ${nav(1)}
</div>
</figure>

<figure>
<figcaption>Séance en cours</figcaption>
<div class="tel">
  <div class="ecran">
    <div class="seance-tete" style="margin-bottom:16px">
      <svg width="24" height="24" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg>
      <div class="t"><b>Legs</b><span>20:31 <em>· 2 séries sur 21</em></span></div>
      <div class="bouton petit">Terminer</div>
    </div>
    <div class="banniere lumiere">
      <img src="${A}squat.webp">
      <div class="pts">•••</div>
      <div class="titre2"><b>Squat</b><span>Repos 2:30</span></div>
    </div>
    <div class="entete" style="margin-top:12px"><span>SÉRIE</span><span>PRÉCÉDENT</span><span>KG</span><span>RÉPS</span><span></span></div>
    <div class="serie faite"><span>1</span><span class="avant">90 × 6</span><span class="champ">90</span><span class="champ">6</span>${coche}</div>
    <div class="serie faite"><span>2</span><span class="avant">90 × 5</span><span class="champ">90</span><span class="champ">5</span>${coche}</div>
    <div class="serie"><span>3</span><span class="avant">90 × 4</span><span class="champ">90</span><span class="champ">5</span>${coche}</div>
    <div class="serie"><span>4</span><span class="avant">90 × 4</span><span class="champ">90</span><span class="champ">5</span>${coche}</div>
    <div class="ajout" style="margin-bottom:14px">+ Ajouter une série</div>
    <div class="suite"><div class="etiquette">Ensuite</div>
      <div class="minis">${mini('romanian-deadlift-start')}${mini('leg-press-start')}${mini('leg-curl-start')}${mini('leg-extension-start')}${mini('standing-calf-raise-start')}</div>
    </div>
  </div>
</div>
</figure>

<figure>
<figcaption>Progrès</figcaption>
<div class="tel">
  <div class="ecran">
    <div class="tete" style="margin-bottom:18px"><div class="titre">Progrès</div><div class="avatar">T</div></div>
    <div class="periodes" style="margin-bottom:18px"><span class="actif">4 sem.</span><span>3 mois</span><span>6 mois</span><span>1 an</span></div>
    <div class="corps-heros lumiere">
      <div class="corps"><img src="${B}face_base.webp"><img src="${B}face_pectoraux.webp"><img src="${B}face_quadriceps.webp" style="opacity:.55"></div>
      <div class="corps"><img src="${B}dos_base.webp"><img src="${B}dos_grandDorsal.webp"><img src="${B}dos_fessiers.webp" style="opacity:.55"></div>
    </div>
    <div class="tuiles">
      <div class="carte"><div class="etiquette">Volume</div><div class="chiffre">100,4 <small>t</small></div><div class="hausse" style="margin-top:4px">+18 %</div></div>
      <div class="carte"><div class="etiquette">Séances</div><div class="chiffre">12</div><div class="sur" style="margin-top:4px">3,4 par semaine</div></div>
    </div>
    <div style="margin-top:18px">
      <div class="muscle">Pectoraux<div class="barre"><i style="width:92%"></i></div><em>42 séries</em></div>
      <div class="muscle">Grand dorsal<div class="barre"><i style="width:80%"></i></div><em>36 séries</em></div>
      <div class="muscle">Quadriceps<div class="barre"><i style="width:58%"></i></div><em>27 séries</em></div>
    </div>
  </div>
  ${nav(2)}
</div>
</figure>
`;

s = s.replace('</style>', css + '</style>');
s = s.replace(/<title>.*<\/title>/, '<title>ÆSTHETIC, proposition 2</title>');
s = s.replace(/<h1>.*<\/h1>/, "<h1>ÆSTHETIC, proposition 2 : l'image d'abord</h1>");
s = s.replace(/<p class="intro">[\s\S]*?<\/p>/, "<p class=\"intro\">Ce qui marche sur la page des exercices, c'est le bonhomme en grand. Je l'applique partout : chaque écran s'ouvre sur une grande image (le corps, l'animation, les vignettes des exercices) posée sur une lumière douce, et le texte se fait discret.</p>");
const d = s.indexOf('<div class="planche">');
s = s.slice(0, d) + '<div class="planche">\n' + ecrans + '\n</div>\n</body>\n</html>\n';
fs.writeFileSync(path.join(__dirname, 'maquette2.html'), s);
console.log('maquette2.html écrit');
