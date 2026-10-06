// Vue de dos. Même silhouette que la face, coordonnées de la moitié droite de l'image (x >= 200).
'use strict';
const { silhouette, regions, fonds, cou, tete0 } = require('./corps');
const bras = require('./bras');

const X = (mir) => (x) => Math.round((mir ? 400 - x : x) * 10) / 10;
const T = (pts, w = 1.1, forme = 'deux', s2 = false, centre = false) => ({ pts, w, forme, s2, centre });
const O = (pts, w = 3, op = 0.2, forme = 'deux', centre = false) => ({ pts, w, op, forme, centre });

const pieces = [
  ...fonds,
  cou,
  { m: null, region: 'bassin', relief: 0, pts: [[200.5, 392], [250, 386], [276, 400], [283, 430], [281, 462], [271, 484], [250, 492], [200.5, 492]] },
  // Omoplate : sous-épineux et grand rond (neutres), sous le trapèze et le deltoïde
  { m: null, region: 'torse', relief: 0.9,
    pts: [[240, 202], [262, 196], [284, 198], [298, 212], [296, 234], [284, 248], [266, 256], [250, 258], [240, 246], [236, 222]] },
  // Rhomboïdes, visibles entre le trapèze inférieur et le bord de l'omoplate
  { m: 'rhomboides', region: 'torse', relief: 0.9,
    pts: [[208, 196], [226, 198], [240, 204], [244, 230], [243, 256], [232, 266], [220, 262], [210, 244], [206, 220]] },
  // Érecteurs du rachis, deux colonnes le long de la colonne, jusqu'au losange lombaire
  { m: 'lombaires', region: 'torse', relief: 1,
    pts: [[201, 288], [211, 290], [221, 312], [227, 344], [228, 374], [225, 400], [217, 420], [206, 430], [201, 430]] },
  // Flanc au-dessus de la hanche
  { m: 'obliques', region: 'torse', relief: 0.6, pts: [[248, 372], [258, 344], [272, 322], [290, 316], [296, 350], [290, 392], [278, 414], [262, 416], [250, 402]] },
  // Grand dorsal en aile : bord supérieur sous l'omoplate, bord externe convexe, pointe basse sur le flanc
  { m: 'grandDorsal', region: 'torse', relief: 1,
    pts: [[220, 282], [230, 275], [244, 269], [258, 264], [273, 257], [287, 247], [297, 234], [301, 256], [297, 282], [286, 304], [273, 326], [262, 348],
      [251, 371, 'c'], [243, 356], [233, 334], [224, 312], [217, 292]] },
  // Trapèze en losange : du crâne aux épaules, pointe basse vers T12, bords courbes
  { m: 'trapezes', region: 'torse', relief: 1,
    pts: [[201, 110], [214, 112], [223, 124], [230, 140], [250, 151], [272, 158], [290, 165], [296, 174], [284, 182], [266, 188],
      [250, 196], [240, 206], [234, 226], [226, 254], [216, 282], [206, 304], [201, 312, 'c']],
    // Trapèze supérieur bombé vers l'épaule, trapèze moyen plus plat
    detail: (mir) => { const x = X(mir); return `<ellipse class="vol m-trapezes" fill="url(#reflet)" cx="${x(246)}" cy="160" rx="30" ry="13" transform="rotate(${mir ? -17 : 17} ${x(246)} 160)"/>` + `<ellipse class="vol m-trapezes" fill="url(#reflet)" cx="${x(222)}" cy="222" rx="12" ry="30"/>`; } },
  // Moyen fessier fondu dans la hanche, puis grand fessier en carré arrondi
  { m: 'abducteurs', region: 'bassin', relief: 0.3, pts: [[236, 402], [256, 390], [272, 394], [284, 412], [284, 438], [270, 432], [254, 420], [242, 414]] },
  { m: 'fessiers', region: 'bassin', relief: 1.1,
    pts: [[201, 416], [212, 409], [234, 406], [254, 409], [265, 418], [270, 436], [270, 460], [265, 478], [252, 487], [232, 490], [213, 489], [201, 486]], tension: 0.85 },
  // Ischio-jambiers en deux masses (biceps fémoral dehors, semi-tendineux et semi-membraneux dedans)
  { m: 'ischios', region: 'cuisse', relief: 1,
    pts: [[238, 484], [262, 480], [280, 492], [284, 524], [277, 562], [266, 594], [256, 620], [247, 624], [243, 600], [243, 560], [240, 520]] },
  { m: 'ischios', region: 'cuisse', relief: 1,
    pts: [[204, 488], [224, 490], [243, 486], [244, 528], [241, 568], [234, 600], [225, 624], [216, 620], [210, 598], [206, 560], [204, 524]] },
  // Grand adducteur, coin interne du haut de la cuisse
  { m: 'adducteurs', region: 'cuisse', relief: 0.8, pts: [[200.5, 488], [210, 490], [217, 510], [215, 540], [208, 566], [200.5, 572]] },
  // Mollet en cœur : soléaire dessous, jumeau interne plus bas que l'externe
  { m: 'mollets', region: 'jambe', relief: 0.8,
    pts: [[206, 700], [214, 736], [230, 752], [246, 742], [262, 712], [266, 740], [258, 772], [246, 790], [226, 792], [214, 780], [207, 750]] },
  { m: 'mollets', region: 'jambe', relief: 1.2,
    pts: [[205, 648], [216, 640], [230, 644], [236.5, 664], [236.8, 700], [236.5, 737, 'c'], [224, 734], [212, 725], [205, 707], [203.5, 680]] },
  { m: 'mollets', region: 'jambe', relief: 1.2,
    pts: [[237.5, 648], [250, 641], [262, 652], [266.5, 676], [262.5, 702], [250.5, 722], [237.5, 737, 'c'], [237.2, 700], [237, 664]] },
  // Talon
  { m: null, region: 'pied', relief: 0.6, pts: [[226, 816], [236, 813], [246, 818], [249, 832], [243, 844], [231, 845.5], [223, 838], [222, 826]] },

  ...bras.brasDos(),
  tete0,
];

const sillons = [
  // Nuque sous le crâne, colonne
  O([[188, 127], [200, 131], [212, 127]], 4, 0.1, 'deux', true),
  O([[200, 150], [200, 230], [200, 300], [200, 420]], 3, 0.18, 'deux', true),
  // Épine de l'omoplate : arête claire, ombre dessous
  O([[240, 210], [258, 202], [278, 196], [296, 192]], 3.6, 0.24),
  // Bords du trapèze, du rhomboïde, de l'omoplate
  O([[236, 214], [232, 236], [225, 260], [216, 284], [206, 304]], 3.2, 0.22),
  O([[242, 208], [245, 232], [244, 256], [236, 266]], 3, 0.2),
  O([[232, 273], [250, 266], [268, 259], [286, 249], [297, 236]], 3.4, 0.22),
  // Grand dorsal : bord interne et pointe
  O([[218, 294], [226, 314], [235, 336], [244, 356], [251, 371]], 3.4, 0.22),
  O([[297, 262], [288, 300], [274, 326], [260, 352], [251, 371]], 3.2, 0.2),
  // Érecteurs et losange lombaire
  O([[210, 300], [220, 330], [226, 368], [222, 404], [208, 428]], 3, 0.16),
  O([[226, 372], [214, 404], [202, 432]], 3, 0.18),
  // Crête iliaque, sillon des fessiers, pli fessier net
  O([[250, 396], [262, 406], [276, 416]], 3, 0.16),
  O([[200, 420], [200, 488]], 3, 0.4, 'deux', true),
  O([[204, 491], [222, 495], [244, 494], [262, 486]], 4.2, 0.36),
  O([[260, 412], [272, 430], [276, 456]], 3, 0.16),
  // Ischios : séparation, creux du genou
  O([[243, 492], [244, 540], [240, 580], [232, 612]], 3, 0.2),
  { ...O([[224, 636], [236, 640], [249, 636]], 2.4, 0.12), s2: true },
  // Mollets : fente entre les jumeaux, bas du cœur, tendon
  O([[237, 652], [237, 690], [236.8, 734]], 2.6, 0.2),
  O([[206, 710], [214, 728], [226, 736], [236.5, 739]], 3.4, 0.22),
  O([[263, 704], [252, 724], [237, 739]], 3.4, 0.22),
  O([[232, 770], [233, 800]], 2.6, 0.12),
  { ...O([[224, 800], [236, 806], [247, 800]], 2.6, 0.14), s2: true },
  { ...O([[224, 844], [236, 846.5], [245, 843]], 2.4, 0.2), s2: true },
  ...bras.sillonsDos,
];

const traits = [
  // Colonne (fine, interrompue), épine de l'omoplate en arête claire
  T([[200, 150], [200, 200], [200, 250]], 1.3, 'debut', false, true),
  T([[200, 262], [200, 300], [200, 330]], 1, 'deux', false, true),
  T([[240, 206], [258, 198.5], [278, 192.5], [296, 188.5]], 1.4, 'fin'),
  // Trapèze : bord inférieur courbe, bord du rhomboïde
  T([[240, 208], [235, 226], [228, 252], [218, 280], [207, 302]], 1.2, 'fin'),
  T([[214, 150], [240, 162], [270, 172]], 0.7, 'deux', true),
  T([[243, 210], [245.5, 234], [243, 256]], 0.9, 'deux'),
  // Bord supérieur et bord interne du grand dorsal
  T([[230, 275], [244, 269], [258, 264], [273, 257], [288, 246]], 1.1, 'deux'),
  T([[219, 296], [227, 316], [236, 338], [245, 358], [251, 371]], 1.2, 'debut'),
  T([[296, 270], [288, 300], [274, 326], [261, 350], [251, 371]], 1.1, 'debut'),
  // Losange lombaire
  T([[224, 372], [214, 402], [202, 430]], 1, 'fin'),
  T([[212, 302], [222, 334], [226, 366]], 0.7, 'deux', true),
  // Fessiers : sillon et pli
  T([[200, 424], [200, 486]], 1, 'deux', false, true),
  T([[206, 488], [224, 490.5], [246, 489], [261, 483]], 1.2, 'deux'),
  T([[244, 406], [262, 414], [272, 432]], 0.8, 'deux', true),
  // Ischios, mollets
  T([[243, 496], [244, 540], [240, 580], [233, 606]], 1, 'deux'),
  T([[237, 654], [237, 690], [236.8, 728]], 1, 'fin'),
  T([[208, 712], [216, 728], [228, 735]], 0.9, 'deux'),
  T([[262, 706], [252, 723], [241, 734]], 0.9, 'deux'),
  ...bras.traitsDos,
];

module.exports = { silhouette: silhouette('dos'), regions, pieces, sillons, traits };
