// La musique de la vidéo de présentation : un morceau de hardstyle à
// 150 battements par minute, entièrement synthétisé ici (un pied, une basse
// à contretemps, un thème en dents de scie, des charlestons). Aucun
// échantillon, aucun morceau existant : rien à créditer.
//
//   node docs/tools/video/musique.js <sortie.wav>
const fs = require('fs');
const SR = 44100, BPM = 150, T = 60 / BPM, TEMPS = 64, DUREE = TEMPS * T;
const N = Math.ceil(DUREE * SR);
const g = new Float32Array(N), d = new Float32Array(N);

// Quatre mesures : la mineur, fa, do, sol. Une fondamentale par mesure.
const FONDAMENTALES = [55, 43.65, 65.41, 49];
const note = (demi) => 440 * Math.pow(2, demi / 12);
// Le thème, en croches, sur la gamme de la mineur (demi-tons depuis le la 4).
const THEME = [0, 0, 3, 0, 7, 5, 3, 2, -4, -4, 0, -4, 5, 3, 0, -2, 3, 3, 7, 3, 12, 10, 7, 5, -2, -2, 2, -2, 7, 5, 2, 3];

let graine = 7;
const bruit = () => { graine = (graine * 16807) % 2147483647; return graine / 1073741823.5 - 1; };
const scie = (phase) => 2 * (phase - Math.floor(phase + 0.5));

// Où joue quoi, en temps : 0 à 8 l'entrée, 8 à 16 la respiration, 16 à 56 le plein, 56 à 64 la fin.
const plein = (b) => b >= 16 && b < 56;
const entree = (b) => b < 8;

let bas = 0, haut = 0; // deux filtres passe-bas à un pôle
for (let i = 0; i < N; i++) {
  const t = i / SR, b = t / T, bi = Math.floor(b), f = b - bi, tb = f * T;
  const mesure = Math.floor(bi / 4) % 4, fond = FONDAMENTALES[mesure];
  let s = 0, l = 0, r = 0;

  // Le pied : une sinusoïde qui tombe de 220 à 48 Hz, saturée.
  if (entree(bi) || plein(bi) || bi === 56) {
    const freq = 48 + 172 * Math.exp(-tb * 38);
    const env = Math.exp(-tb * (bi === 56 ? 2.2 : 7.5));
    const phase = 2 * Math.PI * (48 * tb + (172 / 38) * (1 - Math.exp(-tb * 38)));
    s += Math.tanh(3.2 * Math.sin(phase)) * env * (entree(bi) ? 0.6 : 0.95);
    s += bruit() * Math.exp(-tb * 220) * 0.25; // le clic d'attaque
  }
  // La basse à contretemps : elle enfle entre deux pieds.
  if (plein(bi)) {
    const env = Math.max(0, Math.sin(Math.PI * Math.min(1, Math.max(0, (f - 0.28) / 0.72))));
    const brut = scie(t * fond) + 0.6 * scie(t * fond * 2.005);
    bas += (brut - bas) * (0.03 + 0.10 * env);
    s += Math.tanh(bas * 2.4) * env * 0.5;
  }
  // Le thème : trois dents de scie désaccordées, une note par croche.
  if (plein(bi) || (bi >= 12 && bi < 16)) {
    const croche = Math.floor(b * 2), fc = b * 2 - croche;
    const hz = note(THEME[croche % THEME.length]);
    const env = Math.exp(-fc * 2.6) * Math.min(1, fc * 40);
    const vol = plein(bi) ? 0.20 : 0.20 * (b - 12) / 4;
    const a = scie(t * hz) + scie(t * hz * 1.007) + scie(t * hz * 0.993);
    const o = scie(t * hz * 2.003) * 0.5;
    haut += ((a + o) - haut) * 0.42;
    const duck = Math.min(1, 0.25 + f * 2.2); // la pompe : le thème s'efface sous le pied
    l += haut * env * vol * duck * 1.05; r += haut * env * vol * duck * 0.95;
  }
  // La nappe de la respiration, puis l'accord final qui s'éteint.
  if ((bi >= 8 && bi < 16) || bi >= 56) {
    const k = bi >= 56 ? Math.exp(-(b - 56) * 0.55) : Math.min(1, (b - 8) / 2) * 0.9;
    const acc = [0, 3, 7, 12].reduce((x, n) => x + Math.sin(2 * Math.PI * note(n - 12) * t) + 0.5 * scie(t * note(n - 12) * 1.004), 0);
    l += acc * 0.045 * k; r += acc * 0.045 * k;
  }
  // La montée de bruit avant le plein, et le roulement de caisse claire.
  if (bi >= 12 && bi < 16) {
    const k = (b - 12) / 4;
    s += bruit() * 0.10 * k * k;
    const pas = k < 0.5 ? 0.5 : k < 0.75 ? 0.25 : 0.125; // de plus en plus serré
    const fr = (b / pas) % 1;
    s += bruit() * Math.exp(-fr * pas * T * 60) * 0.32 * (0.4 + 0.6 * k);
  }
  // Les charlestons, à contretemps, et la caisse claire sur les temps 2 et 4.
  if (plein(bi)) {
    const fh = (b * 2) % 1;
    if (Math.floor(b * 2) % 2 === 1) { const h = bruit() * Math.exp(-fh * T * 45) * 0.11; l += h; r -= h * 0.6; }
    if (bi % 2 === 1) s += bruit() * Math.exp(-tb * 28) * 0.20;
  }
  const fin = Math.min(1, (DUREE - t) / 1.2), debut = Math.min(1, t / 0.02);
  g[i] = (s + l) * fin * debut; d[i] = (s + r) * fin * debut;
}
// Le plafond : une saturation douce, puis le niveau ramené à 0,9.
let max = 0;
for (let i = 0; i < N; i++) { g[i] = Math.tanh(g[i] * 1.15); d[i] = Math.tanh(d[i] * 1.15); max = Math.max(max, Math.abs(g[i]), Math.abs(d[i])); }
const pcm = Buffer.alloc(44 + N * 4);
pcm.write('RIFF', 0); pcm.writeUInt32LE(36 + N * 4, 4); pcm.write('WAVEfmt ', 8); pcm.writeUInt32LE(16, 16);
pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(2, 22); pcm.writeUInt32LE(SR, 24); pcm.writeUInt32LE(SR * 4, 28);
pcm.writeUInt16LE(4, 32); pcm.writeUInt16LE(16, 34); pcm.write('data', 36); pcm.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  pcm.writeInt16LE(Math.round(g[i] / max * 0.9 * 32767), 44 + i * 4);
  pcm.writeInt16LE(Math.round(d[i] / max * 0.9 * 32767), 46 + i * 4);
}
fs.writeFileSync(process.argv[2] || 'musique.wav', pcm);
console.log(`  musique : ${DUREE.toFixed(1)} s, ${BPM} BPM, crête ${max.toFixed(2)} avant mise à niveau`);
