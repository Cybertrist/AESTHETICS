// Vue de face. Coordonnées de la moitié droite de l'image (x >= 200), le miroir est automatique.
'use strict';
const { silhouette, regions, fonds, cou, tete0 } = require('./corps');
const { smoothClosed, mx } = require('./lib');
const bras = require('./bras');

const X = (mir) => (x) => Math.round((mir ? 400 - x : x) * 10) / 10;
const T = (pts, w = 1.1, forme = 'deux', s2 = false, centre = false) => ({ pts, w, forme, s2, centre });
const O = (pts, w = 3, op = 0.2, forme = 'deux', centre = false) => ({ pts, w, op, forme, centre });

// Grand droit : une pièce par côté, trois paires de blocs et le bas du ventre rendus par le modelé.
const inter = [262, 298, 336];
const blocs = [[232, 262], [262, 298], [298, 336], [336, 418]];
const grandDroit = {
  m: 'abdominaux', region: 'torse', relief: 0.5, ombre: 0.8,
  pts: [[201, 224], [222, 222], [236, 229], [240.5, 258], [241.5, 296], [240, 336], [236, 372], [228, 398], [217, 416], [206, 425], [201, 426]],
  detail: (mir) => {
    // Chaque bloc : un carré aux angles très arrondis, bombé doucement (pas une bulle).
    const bloc = (x0, x1, y0, y1) => {
      const r = 6;
      const pts = [[x0 + r, y0], [(x0 + x1) / 2, y0 - 0.8], [x1 - r, y0], [x1, y0 + r], [x1 + 0.6, (y0 + y1) / 2], [x1, y1 - r],
        [x1 - r, y1], [(x0 + x1) / 2, y1 + 0.8], [x0 + r, y1], [x0, y1 - r], [x0, (y0 + y1) / 2], [x0, y0 + r]];
      return smoothClosed(mir ? pts.map(mx) : pts, 0.9);
    };
    return blocs.map(([a, b], i) => {
      const d = i === 3 ? bloc(202.5, 230, a + 3, b - 10) : bloc(202.5, 238, a + 1.5, b - 1.5);
      return `<path class="vol m-abdominaux" fill="url(#bloc)" d="${d}"/><path class="vol m-abdominaux" fill="url(#reflet)" d="${d}"/>`;
    }).join('');
  },
};

const pieces = [
  ...fonds,
  cou,
  // Trapèze visible au-dessus de la clavicule, qui monte jusque sous l'oreille
  { m: 'trapezes', region: 'cou', relief: 0.8,
    pts: [[221, 110], [226, 124], [232, 137], [244, 146], [260, 152], [276, 158], [294, 165], [290, 172], [268, 167], [246, 162.5], [230, 156], [220, 144], [216, 128]] },
  // Sterno-cléido-mastoïdien, en V vers le sternum
  { m: 'cou', region: 'cou', relief: 0.9,
    pts: [[212, 108], [223, 112], [222, 126], [216, 140], [208, 152], [201, 157.5], [201, 149], [206, 138], [209.5, 124]] },

  // Flanc : oblique externe sur toute la largeur, du bas des pectoraux à la crête iliaque
  { m: 'obliques', region: 'torse', relief: 0.8,
    pts: [[236, 232], [262, 230], [288, 222], [300, 256], [294, 300], [281, 340], [271, 370], [274, 392], [262, 404], [246, 414], [228, 428], [214, 440], [209, 434], [222, 412], [232, 390], [238, 350], [240, 300], [238, 262]] },
  // Pointe du grand dorsal sous l'aisselle
  { m: 'grandDorsal', region: 'torse', relief: 0.7,
    pts: [[282, 214], [294, 218], [302, 250], [296, 282], [285, 305], [276, 318, 'c'], [277.5, 298], [281.5, 272], [283, 246], [280, 226]] },
  grandDroit,
  // Pectoraux en éventail, bord supérieur courbe le long de la clavicule
  { m: 'pectoraux', region: 'torse', relief: 1.1,
    pts: [[201, 168], [225, 164], [250, 162], [272, 163.5], [288, 170], [297, 186], [293, 200], [284, 210], [270, 221], [252, 230], [234, 234], [218, 233], [206, 229], [201, 222]],
    fibres: [{ a: [[203, 172], [203, 224]], b: [[288, 192], [291, 202]], n: 6, bend: 0.03 }], fop: 0.07,
    detail: (mir) => `<ellipse cx="${X(mir)(257)}" cy="221" rx="2.3" ry="1.9" fill="#1A1C20" fill-opacity="0.07"/>` },

  // Hanche et cuisse
  { m: 'abducteurs', region: 'cuisse', relief: 0.8, pts: [[262, 396], [274, 404], [284, 430], [287, 462], [279, 472], [268, 452], [261, 424]] },
  { m: 'quadriceps', region: 'cuisse', relief: 1,
    pts: [[256, 420], [272, 428], [290, 468], [287, 522], [275, 566], [263, 600], [252, 615], [244, 609], [252, 580], [260, 542], [262, 500], [258, 458]],
    fibres: [{ a: [[262, 436], [278, 448]], b: [[248, 606], [254, 608]], n: 4 }], fop: 0.07 },
  { m: 'quadriceps', region: 'cuisse', relief: 1.1,
    pts: [[248, 414], [258, 434], [264, 476], [263, 522], [255, 564], [244, 596], [235, 608, 'c'], [227, 594], [225, 556], [228, 512], [234, 468], [241, 430]] },
  { m: 'adducteurs', region: 'cuisse', relief: 0.8,
    pts: [[200.5, 452], [212, 446], [230, 432], [246, 418], [254, 406], [257, 416], [245, 450], [233, 488], [223, 524], [215, 556], [209, 582], [203, 582], [200.5, 540]] },
  { m: 'quadriceps', region: 'cuisse', relief: 1.2,
    pts: [[216, 552], [226, 562], [233.5, 583], [235.5, 602], [230.5, 614], [220, 618.5], [211, 610], [207, 594], [209, 572]] },

  // Genou : une rotule ronde, le reste par le modelé
  { m: null, region: 'genou', relief: 0.35, pts: [[232, 613], [241, 617], [245, 629], [242, 641], [233, 646], [225, 641], [222, 628], [225, 617]] },

  // Jambe : tibial antérieur (neutre), jumeau interne, jumeau externe et soléaire
  { m: null, region: 'jambe', relief: 0.5, pts: [[238, 646], [252, 652], [262, 684], [259, 724], [250, 764], [244, 790], [236, 788], [238, 746], [242, 706], [241, 668]] },
  { m: 'mollets', region: 'jambe', relief: 0.8,
    pts: [[205, 650], [216, 653], [222.5, 672], [224.5, 698], [221.5, 724], [214.5, 744], [207, 749], [203.5, 724], [203, 690], [203.5, 666]] },
  { m: 'mollets', region: 'jambe', relief: 0.9, pts: [[255, 660], [268, 668], [270, 704], [262, 734], [254.5, 722], [258, 698], [258, 676]] },
  { m: 'mollets', region: 'jambe', relief: 0.6, pts: [[208, 738], [218, 736], [223, 752], [222, 774], [218, 788], [213, 784], [210, 764]] },

  ...bras.brasFace(),
  tete0,
];

const sillons = [
  // Cou, sternum, clavicule
  O([[186, 131], [200, 136.5], [214, 131]], 4.5, 0.2, 'deux', true),
  O([[195.5, 155], [200, 158.5], [204.5, 155]], 2.5, 0.3, 'deux', true),
  O([[214, 146], [226, 156], [240, 161]], 3, 0.16),
  // Sous les pectoraux (ombre portée), sillon sternal
  O([[203, 230], [228, 237], [252, 234], [272, 226], [288, 213]], 5.5, 0.34),
  O([[200, 172], [200, 200], [200, 228]], 2.5, 0.18, 'deux', true),
  // Grand droit : ligne blanche, intersections, bord externe
  O([[200, 236], [200, 300], [200, 336]], 3, 0.2, 'deux', true),
  O([[200, 348], [200, 380], [200, 420]], 2.2, 0.12, 'deux', true),
  O([[200, 339], [200, 347]], 3.2, 0.5, 'deux', true),
  ...inter.map((y) => O([[201.5, y], [220, y + 1.5], [239, y - 2.5]], 3.2, 0.2)),
  O([[239, 238], [241, 290], [239, 340], [233, 382], [220, 412], [206, 424]], 3.6, 0.2),
  // Dentelures du grand dentelé, discrètes, et bord du grand dorsal
  { ...O([[281, 240], [270, 247]], 2.6, 0.14, 'fin'), s2: true },
  { ...O([[282.5, 257], [271, 264]], 2.6, 0.14, 'fin'), s2: true },
  { ...O([[281, 274], [271, 280]], 2.4, 0.12, 'fin'), s2: true },
  O([[280.5, 226], [282.5, 256], [279, 290], [276, 316]], 3, 0.16),
  // Pli de l'aine et crête iliaque
  O([[272, 390], [252, 410], [230, 426], [212, 442]], 4.5, 0.26),
  // Cuisse : couturier, bord du droit fémoral, larme du vaste interne, genou
  O([[256, 410], [244, 450], [232, 490], [222, 526], [214, 558], [209, 584]], 3, 0.18),
  O([[258, 456], [262, 500], [258, 548], [248, 590], [240, 606]], 2.6, 0.14),
  O([[233, 582], [235.5, 602], [230.5, 614], [220, 619]], 3, 0.16, 'debut'),
  { ...O([[226, 643], [233, 647.5], [241, 643]], 2.6, 0.12), s2: true },
  { ...O([[254, 616], [252, 636], [256, 652]], 2.4, 0.12), s2: true },
  // Jambe : bord du jumeau interne, tibia
  O([[217, 656], [223, 676], [224.5, 700], [221, 726], [213, 746]], 2.8, 0.14),
  O([[258, 674], [258, 700], [255, 724]], 2.4, 0.14),
  // Pied : orteils et malléoles
  ...[[235.8, 847], [243.8, 845.2], [251.5, 842.6]].map(([x, y]) => ({ ...O([[x - 0.4, y - 7], [x, y]], 0.8, 0.3, 'debut'), net: true, s2: true })),
  { ...O([[245, 792], [249, 800], [246, 808]], 2.4, 0.16), s2: true },
  { ...O([[224, 786], [221, 796], [223, 806]], 2.4, 0.16), s2: true },
  ...bras.sillonsFace,
];

const traits = [
  // Clavicule, sternum, bord inférieur des pectoraux
  T([[205, 159.5], [230, 159.5], [252, 160.5], [264, 162]], 1.1, 'fin'),
  T([[200, 170], [200, 200], [200, 226]], 1.3, 'deux', false, true),
  T([[207, 230.5], [230, 233.5], [252, 230.5], [271, 222.5], [286, 210]], 1.35),
  // Cou : bord du sterno-cléido-mastoïdien
  T([[218, 124], [213, 138], [206, 150]], 0.8, 'debut', true),
  // Ligne blanche et intersections des abdominaux
  T([[200, 234], [200, 290], [200, 334]], 1.4, 'deux', false, true),
  T([[200, 350], [200, 390], [200, 422]], 0.9, 'fin', false, true),
  ...inter.map((y) => T([[203, y - 0.4], [220, y + 0.9], [236, y - 2.8]], 0.95)),
  T([[238.5, 240], [240, 290], [238.5, 336], [232, 378], [220, 406]], 0.85, 'fin'),
  // Bord du grand dorsal, pli de l'aine
  T([[280.5, 228], [282.5, 258], [279, 290], [276, 314]], 0.9, 'debut', true),
  T([[270, 391], [250, 409], [230, 424], [212, 440]], 1.2, 'fin'),
  // Cuisse
  T([[255, 414], [244, 450], [232, 490], [222, 526], [214, 560]], 1.1, 'fin'),
  T([[259, 460], [262, 504], [257, 550], [246, 592]], 1, 'deux'),
  T([[227, 564], [233.5, 584], [235.5, 602], [231, 613]], 0.9, 'debut'),
  T([[262, 432], [276, 460], [283, 500]], 0.7, 'fin', true),
  // Rotule, tibia, jumeau interne
  T([[226, 638], [232, 645], [240, 641]], 0.6, 'deux', true),
  T([[241, 664], [240, 700], [237.5, 736]], 0.9, 'fin'),
  T([[217, 658], [222, 676], [224, 694]], 0.7, 'fin', true),
  ...bras.traitsFace,
];

module.exports = { silhouette: silhouette('face'), regions, pieces, sillons, traits };
