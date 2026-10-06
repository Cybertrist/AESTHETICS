// Réglages du rendu : groupes de l'enum Muscle, exclusions, proportions, lumière.

// Muscle de l'enum Dart -> maillages (noms anatomiques anglais du modèle).
export const GROUPES = [
  ['pectoraux', /pectoralis major/],
  ['deltoidesAnterieurs', /clavicular part of .*deltoid/],
  ['deltoidesLateraux', /acromial part of .*deltoid/],
  ['deltoidesPosterieurs', /spinal part of .*deltoid/],
  ['biceps', /biceps brachii/],
  ['triceps', /triceps brachii/],
  ['avantBras', /brachioradialis|extensor carpi|flexor carpi|palmaris longus|pronator teres|flexor digitorum superficialis|(left|right) extensor digitorum( \(\d\))?$|extensor digiti minimi|abductor pollicis longus|extensor pollicis|anconeus|flexor pollicis longus|flexor digitorum profundus/],
  ['trapezes', /trapezius/],
  ['grandDorsal', /latissimus dorsi/],
  ['rhomboides', /rhomboid/],
  ['lombaires', /iliocostalis lumborum|iliocostalis thoracis|longissimus thoracis|spinalis thoracis|^spinalis$|multifidus lumborum/],
  ['abdominaux', /rectus abdominis/],
  ['obliques', /external oblique/],
  ['fessiers', /gluteus maximus/],
  ['quadriceps', /rectus femoris|vastus lateralis|vastus medialis/],
  ['ischios', /biceps femoris|semitendinosus|semimembranosus/],
  ['adducteurs', /adductor longus|adductor brevis|adductor magnus|gracilis|pectineus/],
  ['abducteurs', /gluteus medius|tensor fasciae latae/],
  ['mollets', /gastrocnemius|soleus/],
  ['cou', /sternocleidomastoid|splenius capitis|levator scapulae|scalenus|semispinalis capitis/],
];

// Jamais dessinés : muscles profonds, fascias, tête (remplacée par la peau lissée), mains et pieds (peau).
export const EXCLUS = [
  /platysma|fascia|omohyoid|sternohyoid|supraspinatus|^spinalis$|multifidus lumborum|intercostal|diaphragm|transversus|internal oblique|pectoralis minor|subclavius|subscapularis|serratus posterior|quadratus lumborum|psoas|iliacus|obturator|gemellus|piriformis|quadratus femoris|popliteus|tibialis posterior|flexor digitorum longus|flexor hallucis longus|vastus intermedius|adductor minimus|gluteus minimus|coracobrachialis|brachialis$|supinator|pronator quadratus|flexor digitorum profundus|flexor pollicis longus|extensor indicis|interosseous membrane/,
  /multifidus cervicis|multifidus thoracis|rotatores|levatores|intertransvers|interspinal|semispinalis cervicis|semispinalis thoracis|longissimus capitis|longissimus cervicis|iliocostalis cervicis|splenius cervicis|rectus capitis|longus colli|longus capitis|scalenus/,
  /orbicularis|frontalis|temporalis|masseter|pterygoid|zygomaticus|levator labii|depressor|risorius|mentalis|procerus|nasalis|corrugator|levator palpebrae|(superior|inferior|medial|lateral) rectus$|(superior|inferior) oblique$|veli palatini|arytenoid|crico|thyro|cricothyroid|geniohyoid|stylohyoid|mylohyoid|digastric|sternothyroid|thyrohyoid/,
  /anal sphincter|coccygeus|iliococcygeus|pubococcygeus|puborectalis|levator ani/,
  /lumbrical|interosse|abductor digiti minimi|flexor digiti minimi|opponens|abductor pollicis brevis|flexor pollicis brevis|adductor pollicis|adductor hallucis|flexor hallucis brevis|abductor hallucis|extensor hallucis brevis|flexor digitorum brevis|flexor accessorius|retinaculum|long plantar ligament|extensor digitorum brevis/,
];

// Parties d'un même muscle dessinées d'un seul tenant (sans couture entre elles).
export const FUSIONS = [
  [/^(clavicular|sternocostal|abdominal) part of (left|right) pectoralis major$/, 'pectoralis major $2'],
  [/^(descending|transverse|ascending) part of (left|right) trapezius$/, 'trapezius $2'],
  [/^(humeral|ulnar) head of (left|right) (flexor carpi ulnaris|pronator teres)$/, '$3 $2'],
  [/^(long|short) head of (left|right) biceps brachii$/, 'biceps $2'],
  [/^(left|right) flexor digitorum superficialis$/, 'fds $1'],
  [/^(left|right) extensor carpi ulnaris$/, 'ecu $1'],
];

// Muscles en éventail : direction du point où convergent les fibres.
export const EVENTAILS = [
  [/pectoralis major/, 'lateral'],
  [/deltoid/, 'bas'],
  [/latissimus dorsi/, 'hautLateral'],
  [/trapezius/, 'lateral'],
];

export const REGLAGES = {
  // maillages qui suivent le bras quand on l écarte
  bras: /deltoid|biceps brachii|triceps brachii|brachialis|brachioradialis|extensor carpi|flexor carpi|palmaris|pronator teres|flexor digitorum superficialis|(left|right) extensor digitorum( (d))?$|extensor digiti minimi|abductor pollicis longus|extensor pollicis|anconeus|coracobrachialis/,
  surech: 2,
  abdos: [0.2, 0.37, 0.54], // intersections tendineuses (fraction de la hauteur du grand droit, depuis le haut)
  obliqueX: 78,
  // grand dorsal : aponévrose lombaire retirée (laisse voir les lombaires) et tendon du bras retiré
  dorsalMedial: (z) => Math.max(0, Math.min(95, (1230 - z) * 0.34)),
  dorsalLateralX: 168, // partie aponévrotique de l oblique externe retirée (laisse voir les abdominaux)
  lissageMuscles: 30,
  forme: {
    abduction: 20, // degrés ajoutés à l'écartement des bras
    epauleX: 172, epauleZ: 1372, brasDebutX: 186,
    couZ: 1440, couY: -60, cou: 0.18,
    jambeZ: 820, jambeY: -60, jambes: 0.2,
    brasEpais: 0.22, brasY: -45,
    epaules: 0.14, // élargissement du haut du tronc
    tailleZ: 1020, taille: 0.07, // affinement de la taille
  },
  // Gonflement (mm, le long des normales) : physique musclé et sec.
  gonflement: [
    [/deltoid/, 11],
    [/pectoralis major/, 7],
    [/biceps brachii|triceps brachii/, 10],
    [/latissimus dorsi/, 7],
    [/trapezius/, 4],
    [/rectus abdominis/, 5],
    [/external oblique/, 8],
    [/serratus anterior/, 4],
    [/brachioradialis|extensor carpi|flexor carpi|palmaris|pronator teres|flexor digitorum superficialis|extensor digitorum|anconeus/, 4],
    [/gluteus maximus/, 13],
    [/gluteus medius/, 6],
    [/rectus femoris|vastus|sartorius|tensor fasciae/, 11],
    [/biceps femoris|semitendinosus|semimembranosus|adductor|gracilis|pectineus/, 8],
    [/gastrocnemius|soleus|tibialis anterior|fibularis|extensor digitorum longus/, 8],
    [/teres|infraspinatus/, 13],
    [/sternocleidomastoid|splenius|levator scapulae/, 7],
  ],
  gonflementDefaut: 2,
  peau: {
    teteZ: 1445, teteY0: -120, tetePente: 0.35, lissageTete: 400, teteGonfle: 0, teteOeuf: 1, teteEchelle: 1.0, teteLargeur: 0.97, teteMachoire: 0.22, teteMenton: 0.05, teteZDecal: -6,
    mainZ: 840, mainX: 205,
    piedZ: 15,
    retraitMax: 90, toleranceTrou: 7, sousMuscle: 2.5, retraitOs: 6, lissageRetrait: 6,
    aine: { x: 80, z0: 690, z1: 880, y1: -150, pente: 0.5 },
  },
  cadres: {
    corps: { cx: 0, cz: 781, hauteurMm: 1790, largeur: 760, hauteur: 1200, trait: 0.7, fibre: 0.7 },
    genou: { cx: -120, cz: 450, hauteurMm: 700, largeur: 500, hauteur: 700 },
    tete: { cx: 0, cz: 1450, hauteurMm: 450, largeur: 600, hauteur: 600 },
    bassin: { cx: 0, cz: 850, hauteurMm: 450, largeur: 600, hauteur: 450 },
    buste: { cx: 0, cz: 1135, hauteurMm: 600, largeur: 1100, hauteur: 900, trait: 0.95 },
  },
};
