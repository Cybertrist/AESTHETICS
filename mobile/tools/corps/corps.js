// Silhouette et régions communes aux deux vues. Coordonnées de la moitié droite de l'image (x >= 200).
// Proportions : 7,7 têtes (tête de 103 unités, du sommet 30 au menton 133), cou court et large.
'use strict';
const { symOutline, P } = require('./lib');

// Tête en œuf, mâchoire à peine marquée.
const tete = [[200, 27], [217, 30], [230, 41.5], [236.5, 58], [238, 77], [235, 95], [230, 108], [223, 119], [214, 127.5], [206, 132], [200, 133]];

// Contour du tronc et des jambes, jusqu'aux pieds (différents de face et de dos).
function tronc(pieds) {
  return [
    [200, 112], [223, 112], [225, 124], [230, 136], [240, 144], [256, 151], [272, 157], [285, 163],
    [296, 178], [298, 200], [293, 218], [291, 240], [287, 262], [279, 288], [269, 312], [261, 334],
    [259, 350], [261, 366], [266, 386], [272, 408], [277, 432], [279.5, 458], [279.5, 486], [276, 520],
    [269, 556], [261, 590], [256, 614], [254.5, 634], [256.5, 652], [262.5, 676], [264, 700], [259, 728],
    [252, 756], [248, 782],
    ...pieds,
    [220, 780], [215.5, 754], [211, 724], [209.5, 698], [211, 674], [215, 654], [216, 636], [212.5, 618],
    [209.5, 598], [208.5, 576], [206, 550], [203.8, 522], [201.8, 490], [200, 458, 'c'],
  ];
}
// De face, le pied en raccourci s'ouvre vers l'extérieur ; les orteils forment une rangée arrondie.
const piedsFace = [[249, 798], [254.5, 813], [258.5, 827], [259, 836], [257, 841.5], [253.5, 843.5], [251.5, 842.6, 'c'], [249, 845.6], [245.5, 846.2], [243.8, 845.2, 'c'], [241.5, 847.4], [237.6, 848], [235.8, 847, 'c'], [233, 849], [227, 849.6], [222.5, 847], [220.5, 840], [220, 828], [221, 812], [220, 798]];
// De dos, le talon arrondi, l'avant du pied dépasse un peu de chaque côté.
const piedsDos = [[249, 796], [251.5, 811], [253, 824], [256.5, 831], [258.5, 837.5], [255.5, 842], [249, 843.5], [242, 846], [235.5, 847], [229, 845.5], [223.5, 840], [221, 828], [221, 812], [220, 796]];

// Bras droit de l'image dans son repère (u le long du bras, v vers l'extérieur), main ouverte paume vers l'avant.
const brasContour = [
  [-16, -26], [-26, -8], [-24, 10], [-14, 24], [2, 30.5], [22, 32.5], [42, 29], [58, 23.5], [72, 24.5], [95, 25.5], [120, 24.5],
  [140, 22], [152, 22], [165, 25], [182, 25.5], [205, 21], [232, 16], [255, 13], [268, 12.5],
  // pouce (éminence charnue à la base, pointe arrondie)
  [277, 16], [289, 21], [300, 25], [309.5, 26.6], [316, 27.6], [319.5, 26.2], [319, 23.2], [313.5, 20.8], [305, 18], [301, 15.6, 'c'],
  // index, majeur, annulaire, auriculaire : doigts légèrement écartés, jointifs vers la paume
  [312, 15.2], [326, 14.6], [339, 13.6], [347.5, 12.8], [351.5, 11], [351.5, 8.6], [348, 7], [338, 6.6], [322, 6.2, 'c'],
  [340, 5.7], [352, 5.1], [358.5, 4], [361, 2], [360, -0.3], [355.5, -1.3], [340, -1.3], [323, -1.2, 'c'],
  [340, -1.9], [350.5, -2.6], [355.5, -4.2], [355, -6.7], [351, -7.9], [338, -8], [320, -7.8, 'c'],
  [333, -8.8], [340, -9.8], [344.5, -11.5], [344, -13.8], [339.5, -14.4], [329, -15], [314, -15.8], [299, -16.4], [284, -15.2],
  [268, -12.5], [250, -13.5], [230, -15.5], [205, -19], [182, -21.5], [164, -21], [150, -19], [135, -21.5], [110, -24.5],
  [85, -25.5], [60, -24.5], [38, -21.5], [18, -24],
];

function silhouette(vue) {
  return [
    { pts: tronc(vue === 'face' ? piedsFace : piedsDos), centre: false },
    { pts: symOutline(tete), centre: true },
    { pts: brasContour.map(([u, v, k]) => { const p = P(u, v); return k ? [p[0], p[1], k] : p; }) },
  ];
}
// Le tronc est symétrique mais décrit en une seule moitié : on l'écrit en entier.
function silhouetteComplete(vue) {
  const s = silhouette(vue);
  s[0] = { pts: symOutline(s[0].pts), centre: true };
  return s;
}

// Axes des membres pour le dégradé cylindrique (bords sombres, reflet un peu à gauche du centre).
const regions = {
  tete: { a: [200, 27], b: [200, 133], r: 40, clair: 0.38 },
  cou: { a: [200, 110], b: [200, 156], r: 34, clair: 0.4 },
  torse: { a: [200, 150], b: [200, 460], r: 96, clair: 0.42 },
  brasH: { a: P(-20, 0), b: P(150, 0), r: 27, clair: 0.4 },
  avantBras: { a: P(150, 0), b: P(270, 0), r: 26, clair: 0.4 },
  main: { a: P(270, 0), b: P(350, 0), r: 26, clair: 0.4 },
  cuisse: { a: [242, 440], b: [234, 625], r: 44, clair: 0.4 },
  genou: { a: [234, 610], b: [234, 660], r: 26, clair: 0.4 },
  jambe: { a: [236, 640], b: [234, 800], r: 32, clair: 0.4 },
  pied: { a: [235, 798], b: [236, 849], r: 29, clair: 0.4 },
  bassin: { a: [200, 380], b: [200, 500], r: 84, clair: 0.42 },
};

// Fonds neutres qui couvrent chaque membre (la découpe de la silhouette les rogne).
const R = (pts) => pts.map(([u, v]) => P(u, v));
const fonds = [
  { m: null, region: 'torse', relief: 0, ombre: 0, pts: [[200.5, 108], [300, 108], [310, 200], [300, 420], [262, 470], [200.5, 470]] },
  { m: null, region: 'cuisse', relief: 0, ombre: 0, pts: [[200.5, 430], [252, 396], [300, 420], [296, 630], [200.5, 630]] },
  { m: null, region: 'jambe', relief: 0, ombre: 0, pts: [[200.5, 624], [300, 624], [300, 806], [200.5, 806]] },
  { m: null, region: 'pied', relief: 0, ombre: 0, pts: [[200.5, 806], [300, 806], [300, 860], [200.5, 860]] },
];
// Fonds du bras, tirés du contour : haut du bras puis avant-bras (dessinés juste avant les muscles du bras).
const tranche = (lo, hi) => R(brasContour.filter(([u]) => u >= lo && u <= hi));
const fondsBras = [
  { m: null, region: 'brasH', relief: 0, ombre: 0, pts: R([...brasContour.filter(([u, v]) => u <= 158 && (v > 0 || u > 50)), [48, -12], [20, -8], [-10, -8]]) },
  { m: null, region: 'avantBras', relief: 0, ombre: 0, pts: tranche(138, 276) },
];
const cou = { m: null, region: 'cou', centre: true, relief: 0, ombre: 0, pts: symOutline([[200, 100], [228, 100], [230, 146], [200, 160, 'c']]) };
const tete0 = { m: null, region: 'tete', centre: true, relief: 0.5, ombre: 0.6, pts: symOutline(tete) };

module.exports = { tete, silhouette: silhouetteComplete, regions, fonds, fondsBras, cou, tete0, R };
