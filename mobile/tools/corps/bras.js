// Bras, épaules et mains dans le repère du bras (u le long du bras depuis l'épaule, v vers l'extérieur).
// Bras écarté de 14 degrés, paume vers l'avant : le pouce est à l'extérieur sur les deux vues.
'use strict';
const { arm } = require('./lib');
const { fondsBras } = require('./corps');

const A = arm;
const trait = (pts, w = 1.1, forme = 'deux', s2 = false) => ({ pts: A(pts), w, forme, s2 });
const ombre = (pts, w = 3, op = 0.2, forme = 'deux') => ({ pts: A(pts), w, op, forme });
// Deltoïde en calotte ronde : large en haut, il s'arrête à mi-bras (u 66) en pointe douce.
// Partage antérieur / latéral (face) ou postérieur / latéral (dos) le long de la ligne médiane.
function deltoides(vue) {
  const lat = { m: 'deltoidesLateraux', region: 'brasH', relief: 1,
    pts: A([[-26, 2], [-24, 12], [-14, 24], [2, 32], [22, 34.5], [42, 31], [58, 24], [66, 12, 'c'], [42, 11.5], [16, 10], [-10, 7]]),
    fibres: [{ a: A([[-20, 10], [8, 34]]), b: A([[62, 13], [64, 16]]), n: 5, bend: -0.02 }], fop: 0.06 };
  const av = { m: vue === 'face' ? 'deltoidesAnterieurs' : 'deltoidesPosterieurs', region: 'brasH', relief: 1,
    pts: A([[-24, -26], [-28, -10], [-24, 4], [-10, 7], [16, 10], [42, 11.5], [66, 12, 'c'], [54, 2], [38, -9], [20, -17], [2, -22.5], [-12, -26]]),
    fibres: [{ a: A([[-26, -20], [-24, 2]]), b: A([[62, 10], [64, 12]]), n: 5, bend: 0.02 }], fop: 0.06 };
  return [lat, av];
}

// Avant-bras en deux masses qui s'affinent vers le poignet, séparées par un sillon oblique.
function avantBras() {
  return [
    { m: 'avantBras', region: 'avantBras', relief: 0.9,
      pts: A([[142, -8], [156, -3], [184, 3], [214, 6], [238, 7.5], [254, 6], [259, -4], [252, -14], [240, -19], [205, -24], [176, -27], [152, -25]]) },
    { m: 'avantBras', region: 'avantBras', relief: 1,
      pts: A([[140, 4], [152, 6], [166, 12], [168, 32], [200, 30], [232, 22], [250, 16], [257, 10], [244, 8], [214, 6], [184, 3], [158, -1]]) },
  ];
}
const sillonsAvantBras = [
  ombre([[152, -1], [184, 3], [218, 6.4], [256, 8.6]], 3, 0.14),
];
const traitsAvantBras = [
  trait([[156, -1], [186, 3.2], [214, 6]], 1, 'fin'),
];

// Main ouverte, paume vers l'avant.
function main() {
  // Les doigts sont dessinés par la silhouette ; leurs séparations sont des ombres fines (sillonsMain).
  return [{ m: null, region: 'main', relief: 0, pts: A([[262, -18], [372, -18], [372, 32], [262, 32]]) }];
}
const sillonsMain = [
  { ...ombre([[306, 6.6], [322, 6.2]], 0.9, 0.32, 'debut'), net: true, s2: true },
  { ...ombre([[306, -1.1], [323, -1.2]], 0.9, 0.32, 'debut'), net: true, s2: true },
  { ...ombre([[304, -7.4], [320, -7.8]], 0.9, 0.32, 'debut'), net: true, s2: true },
  ombre([[292, 16.5], [301, 15.6]], 1.4, 0.3, 'debut'),
];

function brasFace() {
  const f0 = fondsBras;
  return [
    ...f0,
    // Triceps : la bande interne visible de face (longue portion), assez large pour se lire.
    { m: 'triceps', region: 'brasH', relief: 0.8, pts: A([[44, -13], [60, -15.5], [100, -14], [128, -10], [144, -12], [138, -27], [100, -29], [60, -29], [46, -26]]) },
    // Brachial, sous le biceps côté externe (couche du biceps)
    { m: 'biceps', region: 'brasH', relief: 0.7, pts: A([[52, 12], [80, 13], [110, 14], [134, 11], [152, 10], [158, 26], [120, 30], [80, 30], [56, 26]]) },
    ...avantBras(),
    // Biceps bombé au centre de la face avant
    { m: 'biceps', region: 'brasH', relief: 1.2,
      pts: A([[40, -2], [52, -9.5], [72, -13], [96, -13], [118, -10], [136, -5], [149, 2, 'c'], [138, 9.5], [120, 14], [96, 16.5], [72, 15], [54, 10]]),
      fibres: [{ a: A([[48, -8], [50, 6]]), b: A([[138, -2], [140, 3]]), n: 4 }], fop: 0.08 },
    ...deltoides('face'),
    ...main(),
  ];
}

function brasDos() {
  const f0 = fondsBras;
  return [
    ...f0,
    ...avantBras(),
    // Triceps en fer à cheval : chef long (interne) et chef latéral (externe), tendon plat entre les deux.
    { m: 'triceps', region: 'brasH', relief: 1.1,
      pts: A([[34, -3], [50, -21], [82, -29], [112, -28], [132, -21], [143, -14, 'c'], [128, -9.5], [110, -6], [93, -1.5], [70, -1], [50, -2]]) },
    { m: 'triceps', region: 'brasH', relief: 1.1,
      pts: A([[38, 1], [52, 14], [74, 28], [102, 29], [124, 24], [135, 14, 'c'], [120, 10], [104, 6], [93, 1.5], [70, 0.5], [50, 0]]) },
    // Tendon du triceps et olécrane
    { m: null, region: 'brasH', relief: 0.2, pts: A([[93, 0], [112, -5], [132, -9.5], [146, -9], [156, -3], [157, 5], [148, 12], [134, 14], [116, 8]]) },
    ...deltoides('dos'),
    ...main(),
  ];
}

// Ombres et traits blancs effilés du bras.
const sillonsFace = [
  ombre([[16, -17.5], [38, -9.5], [56, 1.5], [66, 12]], 4, 0.26),
  ombre([[22, 34.5], [44, 30], [60, 21], [66, 12]], 3.5, 0.2, 'debut'),
  ombre([[50, -10], [80, -15.5], [118, -12.5], [140, -4]], 3, 0.16),
  ombre([[62, 10], [96, 14.5], [132, 10]], 2.6, 0.12),
  ombre([[140, -12], [150, -2], [150, 8]], 3.2, 0.16),
  ...sillonsAvantBras,
  ...sillonsMain,
];
const traitsFace = [
  trait([[-8, -25.5], [14, -19.5], [36, -10], [54, 1.5], [66, 12]], 1.3, 'fin'),
  trait([[20, 34.2], [42, 30.5], [58, 23.5], [66, 12]], 1.2, 'debut'),
  trait([[-22, 5], [0, 7.5], [30, 10.8], [56, 12]], 0.7, 'deux', true),
  trait([[56, -12.5], [84, -16], [116, -12.8], [138, -5]], 1, 'deux'),
  trait([[70, 12.8], [100, 14.2], [128, 10.5]], 0.8, 'deux', true),
  ...traitsAvantBras,
];
const sillonsDos = [
  ombre([[16, -17.5], [38, -9.5], [56, 1.5], [66, 12]], 4, 0.26),
  ombre([[22, 34.5], [44, 30], [60, 21], [66, 12]], 3.5, 0.2, 'debut'),
  ombre([[93, 0], [112, -5.5], [132, -9.5], [143, -14]], 3, 0.2, 'debut'),
  ombre([[93, 0.5], [106, 6], [122, 10.5], [135, 14]], 3, 0.2, 'debut'),
  ombre([[52, -1], [76, -0.8], [93, 0]], 2.4, 0.14, 'fin'),
  ...sillonsAvantBras,
  ...sillonsMain,
];
const traitsDos = [
  trait([[-8, -25.5], [14, -19.5], [36, -10], [54, 1.5], [66, 12]], 1.3, 'fin'),
  trait([[20, 34.2], [42, 30.5], [58, 23.5], [66, 12]], 1.2, 'debut'),
  trait([[-22, 5], [0, 7.5], [30, 10.8], [56, 12]], 0.7, 'deux', true),
  trait([[96, -1.5], [114, -6.5], [132, -10], [143, -14]], 1.1, 'debut'),
  trait([[96, 1.5], [108, 6.5], [122, 10.5], [135, 14]], 1.1, 'debut'),
  trait([[56, -1], [80, -0.6], [94, 0]], 0.8, 'deux', true),
  ...traitsAvantBras,
];

module.exports = { brasFace, brasDos, sillonsFace, sillonsDos, traitsFace, traitsDos };
