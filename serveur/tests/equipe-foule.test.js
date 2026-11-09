// La foule : quarante comptes simulés vivent quelques centaines de gestes
// tirés au hasard (graine fixe), chacun écrit comme le fait `SourceFirestore`
// (mobile/lib/features/social/data/source_firestore.dart). Un modèle en
// mémoire dit, avant chaque geste, si les règles doivent le permettre ; à la
// fin, la base est relue et des invariants sont vérifiés :
//   - l'amitié est toujours symétrique, et la base suit le modèle ;
//   - aucune demande entre amis ni entre comptes bloqués ;
//   - personne ne lit ce qu'il ne devrait pas (détails, liste d'amis,
//     publications), et chacun lit ce qu'il doit ;
//   - le fil de chacun = ses publications et celles de ses amis non privés ;
//   - chaque pseudo appartient à la carte qui le porte.
// Une partie des comptes est « hors ligne » au moment où ses amitiés
// changent : son appli n'accorde `visiblePar` qu'au geste suivant, comme un
// téléphone qu'on rouvre.
import {
  getDoc, getDocs, writeBatch, query, where, orderBy, limit, deleteDoc, addDoc, collectionGroup,
  serverTimestamp, Timestamp, setLogLevel,
} from 'firebase/firestore';
import { demarrer, arreter, base as baseNeuve, permis, refuse, doc, collection, setDoc, filDeLAppli } from './monde.js';

// Une seule instance Firestore par compte : en créer une par geste
// épuiserait la mémoire de Node sur des milliers de lectures.
const bases = new Map();
const base = (uid) => {
  if (!bases.has(uid)) bases.set(uid, baseNeuve(uid));
  return bases.get(uid);
};

// Les refus attendus ne remplissent pas la sortie.
setLogLevel('silent');

const st = serverTimestamp;
const N = 40;
const GESTES = 600;
const GRAINE = 20261109;

// --- Hasard reproductible ---------------------------------------------------

function mulberry32(a) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

let hasard = mulberry32(GRAINE);
const un = (l) => l[Math.floor(hasard() * l.length)];

/** Permis (true) ou refusé (false) ; toute autre erreur remonte. */
async function essai(p) {
  try {
    await p;
    return true;
  } catch (e) {
    if (e?.code === 'permission-denied' || /PERMISSION_DENIED/.test(String(e?.message))) return false;
    throw e;
  }
}

// --- Les gestes de l'appli (comme SourceFirestore) ---------------------------

const jour = (n) => Math.floor(Date.now() / 86400000) - n;

/** `publierProfil` : carte, pseudo réservé dans le même lot, ancien rendu, détails selon l'accès. */
function publierProfil(uid, pseudo, { acces, ancien, reserver = true }) {
  const db = base(uid);
  const lot = writeBatch(db);
  if (reserver) lot.set(doc(db, 'pseudos', pseudo), { uid });
  lot.set(doc(db, 'profils', uid), {
    pseudo, pseudoMin: pseudo, prenom: uid.toUpperCase(), couleur: 0xff2c5676, acces, majLe: st(),
  });
  if (ancien && ancien !== pseudo) lot.delete(doc(db, 'pseudos', ancien));
  lot.set(doc(db, 'profils', uid, 'details', 'public'), acces === 'prive' ? { montre: [], majLe: st() } : {
    phrase: `Je suis ${uid}`, montre: ['seances', 'records', 'nbAmis'], seances: 12, heures: 14.5,
    jours: [jour(0), jour(2)], nbAmis: 0, majLe: st(),
  });
  return lot.commit();
}

const demande = (db, de, vers) => doc(db, 'demandes', `${de}_${vers}`);
const ami = (db, a, b) => doc(db, 'amis', a, 'liste', b);

const inviter = (de, vers) => setDoc(demande(base(de), de, vers), { de, vers, date: st() });

/** `accepter` : les deux sens, la demande reçue effacée, et la mienne si l'appli la connaît. */
function accepter(moi, de, { aussiLaMienne }) {
  const db = base(moi);
  const lot = writeBatch(db)
    .set(ami(db, moi, de), { depuis: st() })
    .set(ami(db, de, moi), { depuis: st() })
    .delete(demande(db, de, moi));
  if (aussiLaMienne) lot.delete(demande(db, moi, de));
  return lot.commit();
}

const refuser = (moi, de) => deleteDoc(demande(base(moi), de, moi));
const annuler = (moi, vers) => deleteDoc(demande(base(moi), moi, vers));

function retirer(moi, autre) {
  const db = base(moi);
  return writeBatch(db).delete(ami(db, moi, autre)).delete(ami(db, autre, moi)).commit();
}

function bloquer(moi, autre) {
  const db = base(moi);
  return writeBatch(db)
    .set(doc(db, 'blocages', moi, 'liste', autre), { date: st() })
    .delete(ami(db, moi, autre))
    .delete(ami(db, autre, moi))
    .delete(demande(db, moi, autre))
    .delete(demande(db, autre, moi))
    .commit();
}

const debloquer = (moi, autre) => deleteDoc(doc(base(moi), 'blocages', moi, 'liste', autre));

function publierSeance(uid, seanceId, visiblePar) {
  return setDoc(doc(base(uid), 'publications', `${uid}_${seanceId}`), {
    auteur: uid, seanceId, titre: 'Push', date: Timestamp.fromMillis(Date.now() - 3600e3), dureeSec: 3600,
    volumeKg: 5000, series: 16, exercices: ['bench_press', 'dips'], records: 0, visiblePar, majLe: st(),
  });
}

/** L'écoute de mes séances (30 jours), comme la source. */
const requeteMiennes = (uid) => query(collection(base(uid), 'publications'), where('auteur', '==', uid),
  where('date', '>', Timestamp.fromMillis(Date.now() - 30 * 86400e3)), orderBy('date', 'desc'), limit(100));

/** Le fil, exactement comme la source : mes séances et celles de mes amis. */
const lireFil = (uid) => filDeLAppli(base(uid), uid);

// --- Le modèle ---------------------------------------------------------------

const uids = Array.from({ length: N }, (_, i) => `f${String(i).padStart(2, '0')}`);
const M = {
  acces: {}, pseudo: {}, amis: new Set(), demandes: new Set(), blocs: new Set(),
  pubs: new Map(), horsLigne: new Set(), libres: [], seq: 0,
};
const paire = (a, b) => (a < b ? `${a}|${b}` : `${b}|${a}`);
const sontAmis = (a, b) => M.amis.has(paire(a, b));
const aBloque = (a, b) => M.blocs.has(`${a}>${b}`);
const bloques = (a, b) => aBloque(a, b) || aBloque(b, a);
const amisDe = (u) => uids.filter((v) => v !== u && sontAmis(u, v));
/** `_visiblePar` de l'appli : moi seul si privé, sinon moi et mes amis triés. */
const voulu = (u) => (M.acces[u] === 'prive' ? [u] : [u, ...amisDe(u).sort()].slice(0, 500));

const ecarts = [];
let compte = 0;

async function geste(nom, attendu, p) {
  compte++;
  let obtenu;
  try {
    obtenu = await essai(p);
  } catch (e) {
    ecarts.push(`#${compte} ${nom} : erreur ${e.code ?? ''} ${e.message}`);
    return false;
  }
  if (obtenu !== attendu) ecarts.push(`#${compte} ${nom} : attendu ${attendu ? 'permis' : 'refusé'}, obtenu ${obtenu ? 'permis' : 'refusé'}`);
  return obtenu;
}

/** `_accorderMesSeances` : relit son fil et réécrit `visiblePar` de ses séances. */
async function accorder(u) {
  M.horsLigne.delete(u);
  const s = await getDocs(requeteMiennes(u));
  const v = voulu(u);
  const db = base(u);
  const lot = writeBatch(db);
  let n = 0;
  for (const d of s.docs) {
    if (d.data().auteur !== u) continue;
    const vp = d.data().visiblePar;
    if (vp.length === v.length && v.every((x) => vp.includes(x))) continue;
    lot.update(doc(db, d.ref.path), { visiblePar: v, majLe: st() });
    n++;
  }
  if (!n) return;
  if (await geste(`accorder ${u}`, true, lot.commit())) {
    for (const [id, p] of M.pubs) if (p.auteur === u) p.visiblePar = [...v];
  }
}

/** Les deux téléphones voient l'amitié changer ; l'un d'eux est parfois éteint. */
async function apresAmitie(a, b) {
  for (const x of [a, b]) {
    if (hasard() < 0.25) M.horsLigne.add(x);
    else await accorder(x);
  }
}

/** Ouvrir l'appli : un téléphone éteint rattrape son retard. */
async function ouvrir(u) {
  if (M.horsLigne.has(u)) await accorder(u);
}

// Chaque geste : il choisit ses acteurs, ou rend false s'il n'a rien à faire.
const GESTES_POIDS = [
  [25, async () => {
    const de = un(uids), vers = un(uids);
    if (de === vers || sontAmis(de, vers) || aBloque(de, vers) || M.demandes.has(`${de}_${vers}`)) return false;
    await ouvrir(de);
    // Refusé si l'autre m'a bloqué : l'appli le découvre à l'envoi.
    const attendu = !bloques(de, vers);
    if (await geste(`inviter ${de}→${vers}`, attendu, inviter(de, vers))) M.demandes.add(`${de}_${vers}`);
    return true;
  }],
  [18, async () => {
    if (!M.demandes.size) return false;
    const [de, moi] = un([...M.demandes]).split('_');
    await ouvrir(moi);
    const mienne = M.demandes.has(`${moi}_${de}`);
    if (await geste(`accepter ${moi}←${de}`, true, accepter(moi, de, { aussiLaMienne: mienne }))) {
      M.amis.add(paire(de, moi));
      M.demandes.delete(`${de}_${moi}`);
      M.demandes.delete(`${moi}_${de}`);
      await apresAmitie(moi, de);
    }
    return true;
  }],
  [4, async () => {
    if (!M.demandes.size) return false;
    const [de, moi] = un([...M.demandes]).split('_');
    await ouvrir(moi);
    if (await geste(`refuser ${moi}←${de}`, true, refuser(moi, de))) M.demandes.delete(`${de}_${moi}`);
    return true;
  }],
  [3, async () => {
    if (!M.demandes.size) return false;
    const [moi, vers] = un([...M.demandes]).split('_');
    await ouvrir(moi);
    if (await geste(`annuler ${moi}→${vers}`, true, annuler(moi, vers))) M.demandes.delete(`${moi}_${vers}`);
    return true;
  }],
  [5, async () => {
    if (!M.amis.size) return false;
    const [a, b] = un([...M.amis]).split('|');
    const [moi, autre] = hasard() < 0.5 ? [a, b] : [b, a];
    await ouvrir(moi);
    if (await geste(`retirer ${moi}✕${autre}`, true, retirer(moi, autre))) {
      M.amis.delete(paire(a, b));
      await apresAmitie(moi, autre);
    }
    return true;
  }],
  [4, async () => {
    // Bloquer surtout un ami ou quelqu'un qui m'a demandé : c'est là que ça compte.
    const pool = [...M.amis].map((p) => p.split('|')).concat([...M.demandes].map((d) => d.split('_')));
    const [x, y] = pool.length && hasard() < 0.7 ? un(pool) : [un(uids), un(uids)];
    const [moi, autre] = hasard() < 0.5 ? [x, y] : [y, x];
    if (moi === autre || aBloque(moi, autre)) return false;
    await ouvrir(moi);
    if (await geste(`bloquer ${moi}⊘${autre}`, true, bloquer(moi, autre))) {
      M.blocs.add(`${moi}>${autre}`);
      const etaitAmi = sontAmis(moi, autre);
      M.amis.delete(paire(moi, autre));
      M.demandes.delete(`${moi}_${autre}`);
      M.demandes.delete(`${autre}_${moi}`);
      if (etaitAmi) await apresAmitie(moi, autre);
    }
    return true;
  }],
  [2, async () => {
    if (!M.blocs.size) return false;
    const [moi, autre] = un([...M.blocs]).split('>');
    await ouvrir(moi);
    if (await geste(`débloquer ${moi}⊘${autre}`, true, debloquer(moi, autre))) M.blocs.delete(`${moi}>${autre}`);
    return true;
  }],
  [15, async () => {
    const u = un(uids);
    await ouvrir(u);
    const id = `s${++M.seq}`;
    // L'appli ne publie rien d'un profil privé ; on essaie quand même de temps en temps (abus).
    if (M.acces[u] === 'prive' && hasard() < 0.7) return false;
    const vp = voulu(u);
    if (await geste(`publier ${u}/${id}`, M.acces[u] !== 'prive', publierSeance(u, id, vp))) {
      M.pubs.set(`${u}_${id}`, { auteur: u, visiblePar: vp });
    }
    return true;
  }],
  [2, async () => {
    if (!M.pubs.size) return false;
    const id = un([...M.pubs.keys()]);
    const u = M.pubs.get(id).auteur;
    await ouvrir(u);
    if (await geste(`retirer séance ${id}`, true, deleteDoc(doc(base(u), 'publications', id)))) M.pubs.delete(id);
    return true;
  }],
  [10, async () => {
    if (!M.pubs.size) return false;
    const u = un(uids), id = un([...M.pubs.keys()]);
    await ouvrir(u);
    // Figurer dans visiblePar, sans blocage entre l'auteur et moi.
    const peut = M.pubs.get(id).visiblePar.includes(u) && !bloques(M.pubs.get(id).auteur, u);
    await geste(`réagir ${u}→${id}`, peut, setDoc(doc(base(u), 'publications', id, 'reactions', u), { type: un(['coeur', 'feu', 'biceps', 'bravo', 'etoiles']), date: st() }));
    return true;
  }],
  [8, async () => {
    if (!M.pubs.size) return false;
    const u = un(uids), id = un([...M.pubs.keys()]);
    await ouvrir(u);
    // Figurer dans visiblePar, sans blocage entre l'auteur et moi.
    const peut = M.pubs.get(id).visiblePar.includes(u) && !bloques(M.pubs.get(id).auteur, u);
    await geste(`commenter ${u}→${id}`, peut, addDoc(collection(base(u), 'publications', id, 'commentaires'), { auteur: u, texte: 'Costaud !', date: st() }));
    return true;
  }],
  [4, async () => {
    const u = un(uids);
    const acces = un(['tous', 'amis', 'prive'].filter((a) => a !== M.acces[u]));
    await ouvrir(u);
    if (await geste(`accès ${u}=${acces}`, true, publierProfil(u, M.pseudo[u], { acces, reserver: false }))) {
      M.acces[u] = acces;
      await accorder(u);
    }
    return true;
  }],
  [3, async () => {
    const u = un(uids);
    const r = hasard();
    // Un pseudo neuf, un pseudo rendu par un autre, ou un pseudo pris.
    let nouveau, attendu = true;
    if (r < 0.4 && M.libres.length) nouveau = M.libres.pop();
    else if (r < 0.7) { nouveau = un(uids.filter((v) => v !== u).map((v) => M.pseudo[v])); attendu = false; }
    else nouveau = `neo.${u}.${M.seq++}`;
    await ouvrir(u);
    const ancien = M.pseudo[u];
    if (await geste(`pseudo ${u}=${nouveau}`, attendu, publierProfil(u, nouveau, { acces: M.acces[u], ancien }))) {
      M.pseudo[u] = nouveau;
      M.libres.push(ancien);
    } else if (attendu === true && !M.libres.includes(nouveau)) {
      // Un libre refusé à tort : remis dans la pile pour la suite.
      M.libres.push(nouveau);
    }
    return true;
  }],
];
const totalPoids = GESTES_POIDS.reduce((s, [p]) => s + p, 0);

function tirerGeste() {
  let r = hasard() * totalPoids;
  for (const [p, f] of GESTES_POIDS) {
    if ((r -= p) < 0) return f;
  }
  return GESTES_POIDS[0][1];
}

// --- La base relue, règles coupées ------------------------------------------

let env;

async function relire() {
  const etat = { amis: new Set(), asym: [], demandes: new Set(), blocs: new Set(), pubs: new Map(), pseudos: new Map(), cartes: new Map() };
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const listes = await getDocs(collectionGroup(db, 'liste'));
    const sens = new Set();
    for (const d of listes.docs) {
      const [col, a, , b] = d.ref.path.split('/');
      if (col === 'amis') sens.add(`${a}>${b}`);
      if (col === 'blocages') etat.blocs.add(`${a}>${b}`);
    }
    for (const s of sens) {
      const [a, b] = s.split('>');
      if (!sens.has(`${b}>${a}`)) etat.asym.push(s);
      etat.amis.add(paire(a, b));
    }
    for (const d of (await getDocs(collection(db, 'demandes'))).docs) etat.demandes.add(d.id);
    for (const d of (await getDocs(collection(db, 'publications'))).docs) etat.pubs.set(d.id, d.data());
    for (const d of (await getDocs(collection(db, 'pseudos'))).docs) etat.pseudos.set(d.id, d.data().uid);
    for (const d of (await getDocs(collection(db, 'profils'))).docs) etat.cartes.set(d.id, d.data());
  });
  return etat;
}

const trie = (s) => [...s].sort().join(', ');

// --- Les tests ----------------------------------------------------------------

describe('la foule : 40 comptes et 600 gestes au hasard', function () {
  this.timeout(600000);
  let etat;

  before(async () => {
    bases.clear();
    env = await demarrer();
    await env.clearFirestore();
    hasard = mulberry32(GRAINE);
    for (const u of uids) {
      const r = hasard();
      M.acces[u] = r < 0.5 ? 'tous' : r < 0.85 ? 'amis' : 'prive';
      M.pseudo[u] = `foule${u.slice(1)}`;
      await permis(publierProfil(u, M.pseudo[u], { acces: M.acces[u] }));
    }
    for (let i = 0; i < GESTES;) {
      if (await tirerGeste()()) i++;
    }
    // Tout le monde rouvre l'appli : les retards sont rattrapés.
    for (const u of uids) await ouvrir(u);
    etat = await relire();
  });
  after(arreter);

  it('chaque geste de l’appli est permis ou refusé comme prévu', () => {
    if (ecarts.length) throw new Error(`${ecarts.length} écart(s) sur ${compte} gestes :\n${ecarts.slice(0, 40).join('\n')}`);
    if (compte < GESTES) throw new Error(`seulement ${compte} gestes`);
  });

  it('la foule a vraiment vécu (amitiés, demandes, blocages, séances)', () => {
    const resume = `${M.amis.size} amitiés, ${M.demandes.size} demandes, ${M.blocs.size} blocages, ${M.pubs.size} séances`;
    if (M.amis.size < 20 || M.pubs.size < 20 || M.blocs.size < 3) throw new Error(`foule trop calme : ${resume}`);
    console.log(`      (${resume}, ${compte} écritures)`);
  });

  it('l’amitié est toujours symétrique', () => {
    if (etat.asym.length) throw new Error(`un seul sens : ${etat.asym.join(', ')}`);
  });

  it('la base suit le modèle : amitiés, demandes, blocages, séances', () => {
    const e = [];
    if (trie(etat.amis) !== trie(M.amis)) e.push(`amis : base [${trie(etat.amis)}] / modèle [${trie(M.amis)}]`);
    if (trie(etat.demandes) !== trie(M.demandes)) e.push(`demandes : base [${trie(etat.demandes)}] / modèle [${trie(M.demandes)}]`);
    if (trie(etat.blocs) !== trie(M.blocs)) e.push(`blocages : base [${trie(etat.blocs)}] / modèle [${trie(M.blocs)}]`);
    if (trie(etat.pubs.keys()) !== trie(M.pubs.keys())) e.push('séances différentes');
    if (e.length) throw new Error(e.join('\n'));
  });

  it('aucune demande entre amis, ni entre comptes bloqués', () => {
    const e = [];
    for (const id of etat.demandes) {
      const [de, vers] = id.split('_');
      if (etat.amis.has(paire(de, vers))) e.push(`${id} entre amis`);
      if (etat.blocs.has(`${de}>${vers}`) || etat.blocs.has(`${vers}>${de}`)) e.push(`${id} entre bloqués`);
    }
    for (const p of etat.amis) {
      const [a, b] = p.split('|');
      if (etat.blocs.has(`${a}>${b}`) || etat.blocs.has(`${b}>${a}`)) e.push(`${p} amis et bloqués`);
    }
    if (e.length) throw new Error(e.join('\n'));
  });

  it('chaque pseudo appartient à la carte qui le porte, et inversement', () => {
    const e = [];
    for (const [uid, c] of etat.cartes) {
      if (etat.pseudos.get(c.pseudoMin) !== uid) e.push(`${uid} porte ${c.pseudoMin} réservé par ${etat.pseudos.get(c.pseudoMin)}`);
    }
    for (const [p, uid] of etat.pseudos) {
      if (etat.cartes.get(uid)?.pseudoMin !== p) e.push(`${p} réservé par ${uid} sans carte qui le porte`);
    }
    if (e.length) throw new Error(e.join('\n'));
  });

  it('le fil de chacun = ses séances et celles de ses amis non privés', async () => {
    const e = [];
    await Promise.all(uids.map(async (u) => {
      const s = await lireFil(u);
      const vu = new Set(s.docs.map((d) => d.id));
      const attendu = new Set([...etat.pubs].filter(([, p]) => p.auteur === u
        || (etat.amis.has(paire(u, p.auteur)) && M.acces[p.auteur] !== 'prive')).map(([id]) => id));
      if (trie(vu) !== trie(attendu)) {
        e.push(`${u} : en trop [${trie([...vu].filter((x) => !attendu.has(x)))}], manquant [${trie([...attendu].filter((x) => !vu.has(x)))}]`);
      }
    }));
    if (e.length) throw new Error(e.join('\n'));
  });

  it('chaque séance : lue par ceux de visiblePar, refusée aux autres (avec ses réactions et commentaires)', async () => {
    const e = [];
    const essais = [];
    for (const [id, p] of etat.pubs) {
      for (const u of uids) {
        const doit = p.visiblePar.includes(u);
        const db = base(u);
        essais.push(essai(getDoc(doc(db, 'publications', id))).then((ok) => ok !== doit && e.push(`${u} lit ${id} : ${ok}`)));
        if (hasard() < 0.15) {
          const doitCom = doit && !(etat.blocs.has(`${p.auteur}>${u}`) || etat.blocs.has(`${u}>${p.auteur}`));
          essais.push(essai(getDocs(collection(db, 'publications', id, 'commentaires'))).then((ok) => ok !== doitCom && e.push(`${u} lit les commentaires de ${id} : ${ok}`)));
        }
      }
    }
    await Promise.all(essais);
    if (e.length) throw new Error(`${e.length} lecture(s) fausse(s) :\n${e.slice(0, 30).join('\n')}`);
  });

  it('les détails : le propriétaire, tous si « tous », les amis si « amis », jamais celui qu’on a bloqué', async () => {
    const e = [];
    await Promise.all(uids.flatMap((lecteur) => uids.map(async (proprio) => {
      const a = M.acces[proprio];
      const doit = lecteur === proprio || (!etat.blocs.has(`${proprio}>${lecteur}`)
        && (a === 'tous' || (a === 'amis' && etat.amis.has(paire(lecteur, proprio)))));
      const ok = await essai(getDoc(doc(base(lecteur), 'profils', proprio, 'details', 'public')));
      if (ok !== doit) e.push(`${lecteur} lit les détails de ${proprio} (${a}) : ${ok}`);
    })));
    if (e.length) throw new Error(`${e.length} lecture(s) fausse(s) :\n${e.slice(0, 30).join('\n')}`);
  });

  it('la liste d’amis : soi, et ses amis sauf profil privé', async () => {
    const e = [];
    await Promise.all(uids.flatMap((lecteur) => uids.map(async (proprio) => {
      const doit = lecteur === proprio || (etat.amis.has(paire(lecteur, proprio)) && M.acces[proprio] !== 'prive');
      const ok = await essai(getDocs(collection(base(lecteur), 'amis', proprio, 'liste')));
      if (ok !== doit) e.push(`${lecteur} lit les amis de ${proprio} : ${ok}`);
    })));
    if (e.length) throw new Error(e.join('\n'));
  });

  it('les demandes et les blocages : seulement les siens', async () => {
    const e = [];
    await Promise.all(uids.map(async (u) => {
      const autre = un(uids.filter((v) => v !== u));
      const db = base(u);
      if (!await essai(getDocs(query(collection(db, 'demandes'), where('vers', '==', u))))) e.push(`${u} : reçues refusées`);
      if (await essai(getDocs(query(collection(db, 'demandes'), where('vers', '==', autre))))) e.push(`${u} lit les demandes reçues par ${autre}`);
      if (await essai(getDocs(collection(db, 'blocages', autre, 'liste')))) e.push(`${u} lit les blocages de ${autre}`);
    }));
    if (e.length) throw new Error(e.join('\n'));
  });
});

// Des trous qu'une foule honnête ne trouve pas : un téléphone modifié, ou
// l'appli dans un ordre de gestes rare.
describe('la foule : les trous entre les gestes', function () {
  this.timeout(60000);

  before(async () => {
    bases.clear();
    env = await demarrer();
    await env.clearFirestore();
    for (const u of ['xa', 'xb', 'xc', 'xd', 'xe']) await permis(publierProfil(u, `trou.${u}`, { acces: 'tous' }));
  });
  after(arreter);

  it('accepter sans effacer la demande est refusé (sinon la demande survit entre amis)', async () => {
    // xa demande xb ; xb accepte mais garde la demande. Après un retrait par
    // xa, xb peut redevenir son ami seul, sans nouvel accord de xa.
    await permis(inviter('xa', 'xb'));
    const db = base('xb');
    const garde = writeBatch(db).set(ami(db, 'xb', 'xa'), { depuis: st() }).set(ami(db, 'xa', 'xb'), { depuis: st() });
    await refuse(garde.commit());
  });

  it('l’appli qui ne connaît pas encore sa propre demande croisée : la demande survit entre amis', async () => {
    // xc et xd se demandent en même temps ; xc accepte avant que l'écoute
    // de ses demandes envoyées ait vu `xc_xd` (`_envoyees` vide) : `accepter`
    // n'efface que `xd_xc`.
    await permis(inviter('xc', 'xd'));
    await permis(inviter('xd', 'xc'));
    // Ce lot-là (la croisée gardée) est refusé ; l'appli efface toujours les
    // deux demandes, sans regarder `_envoyees`.
    await refuse(accepter('xc', 'xd', { aussiLaMienne: false }));
    await permis(accepter('xc', 'xd', { aussiLaMienne: true }));
    // Invariant : aucune demande entre amis.
    let survit = false;
    await env.withSecurityRulesDisabled(async (ctx) => {
      survit = (await getDoc(doc(ctx.firestore(), 'demandes', 'xc_xd'))).exists();
    });
    if (survit) {
      // La conséquence : xc retire xd, puis xd, toujours destinataire de la
      // vieille demande, redevient ami de xc tout seul.
      await permis(retirer('xc', 'xd'));
      const db = base('xd');
      const reamitie = await essai(writeBatch(db).set(ami(db, 'xd', 'xc'), { depuis: st() })
        .set(ami(db, 'xc', 'xd'), { depuis: st() }).delete(demande(db, 'xc', 'xd')).commit());
      throw new Error(`la demande xc_xd survit entre amis ; après le retrait, xd redevient ami de xc seul : ${reamitie ? 'permis' : 'refusé'}`);
    }
  });

  it('le fil vu par l’appli ne montre que mes amis et moi (pas un inconnu, pas celui que j’ai bloqué)', async () => {
    // xe bloque xa. xa, et l'inconnu xb, publient en mettant xe dans visiblePar :
    // les règles ne peuvent pas vérifier une liste entière, c'est donc à
    // l'appli de filtrer son fil : elle ne demande que les séances de ses
    // amis (`auteur in`, source_firestore.dart, `_ecouterFil`).
    await permis(bloquer('xe', 'xa'));
    await permis(publierSeance('xa', 'spam1', ['xa', 'xe']));
    await permis(publierSeance('xb', 'spam2', ['xb', 'xe']));
    const s = await lireFil('xe');
    const filAppli = s.docs.map((d) => d.data()).filter((p) => p.auteur !== 'xe');
    const amisXe = new Set((await getDocs(collection(base('xe'), 'amis', 'xe', 'liste'))).docs.map((d) => d.id));
    const intrus = filAppli.filter((p) => !amisXe.has(p.auteur)).map((p) => p.auteur);
    if (intrus.length) throw new Error(`le fil de xe montre des séances de non-amis : ${intrus.join(', ')} (xa est bloqué par xe)`);
  });
});
