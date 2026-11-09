// L'équipe de test, côté profils et pseudos : l'unicité sous concurrence,
// les vols de pseudo, les changements de pseudo, l'accès tous/amis/privé aux
// détails, ce que `montre` cache, les champs en trop, la photo trop grosse
// et la lecture sans connexion.
//
// Les tests marqués « TROU » attendent ce que le contrat demande : les trous
// sont bouchés, ils gardent qu'ils ne se rouvrent pas.
import {
  getDoc, getDocs, updateDoc, deleteDoc, writeBatch, query, where, orderBy, limit,
  collectionGroup, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import assert from 'node:assert/strict';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, carte, doc, collection, setDoc } from './monde.js';

/** Crée (ou remplace) la carte et réserve le pseudo dans le même lot. */
function inscrire(uid, pseudo, autres = {}, pseudoMin = pseudo.toLowerCase()) {
  const db = base(uid);
  const lot = writeBatch(db);
  lot.set(doc(db, 'pseudos', pseudoMin), { uid });
  lot.set(doc(db, 'profils', uid), carte(pseudo, autres));
  return lot.commit();
}

/** Change de pseudo comme l'appli : réserve le nouveau, rend l'ancien. */
function changer(uid, ancien, nouveau, { rendre = true } = {}) {
  const db = base(uid);
  const lot = writeBatch(db);
  lot.set(doc(db, 'pseudos', nouveau.toLowerCase()), { uid });
  lot.update(doc(db, 'profils', uid), { pseudo: nouveau, pseudoMin: nouveau.toLowerCase(), majLe: serverTimestamp() });
  if (rendre && ancien) lot.delete(doc(db, 'pseudos', ancien));
  return lot.commit();
}

/** À qui appartient un pseudo (lu par un tiers connecté). */
async function proprio(pseudoMin) {
  const d = await getDoc(doc(base('manon'), 'pseudos', pseudoMin));
  return d.exists() ? d.data().uid : null;
}

/** La carte d'un compte, lue par un tiers connecté. */
async function carteDe(uid) {
  const d = await getDoc(doc(base('manon'), 'profils', uid));
  return d.exists() ? d.data() : null;
}

const lireDetails = (qui, de) => getDoc(doc(base(qui), 'profils', de, 'details', 'public'));
const ecrireDetails = (qui, champs) =>
  setDoc(doc(base(qui), 'profils', qui, 'details', 'public'), { ...champs, majLe: serverTimestamp() });

describe('équipe profils : unicité du pseudo sous concurrence', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('dix comptes neufs veulent le même pseudo en même temps : un seul l’obtient', async () => {
    const comptes = Array.from({ length: 10 }, (_, i) => `neuf${i}`);
    const res = await Promise.allSettled(comptes.map((u) => inscrire(u, 'convoite')));
    const gagnants = comptes.filter((_, i) => res[i].status === 'fulfilled');
    assert.equal(gagnants.length, 1, `gagnants : ${gagnants.join(', ')}`);
    assert.equal(await proprio('convoite'), gagnants[0]);
    for (const u of comptes) {
      const c = await carteDe(u);
      if (u === gagnants[0]) assert.equal(c.pseudoMin, 'convoite');
      else assert.equal(c, null, `${u} a une carte sans pseudo`);
    }
  });

  it('les variantes de casse se disputent le même pseudo : un seul gagnant', async () => {
    const essais = [['neuf0', 'Convoite'], ['neuf1', 'CONVOITE'], ['neuf2', 'convoite'], ['neuf3', 'cOnVoItE']];
    const res = await Promise.allSettled(essais.map(([u, p]) => inscrire(u, p)));
    assert.equal(res.filter((r) => r.status === 'fulfilled').length, 1);
  });

  it('un pseudo rendu pendant qu’un autre le guette : jamais deux cartes pour un pseudo', async () => {
    const guet = Array.from({ length: 5 }, (_, i) => inscrire(`neuf${i}`, 'alice'));
    await Promise.allSettled([changer('alice', 'alice', 'alice.b'), ...guet]);
    const p = await proprio('alice');
    const porteurs = [];
    for (const u of ['alice', 'neuf0', 'neuf1', 'neuf2', 'neuf3', 'neuf4']) {
      if ((await carteDe(u))?.pseudoMin === 'alice') porteurs.push(u);
    }
    assert.ok(porteurs.length <= 1, `porteurs : ${porteurs.join(', ')}`);
    if (porteurs.length === 1) assert.equal(p, porteurs[0]);
  });

  it('deux comptes qui échangent leurs pseudos en même temps n’y arrivent pas', async () => {
    await Promise.allSettled([changer('alice', 'alice', 'david'), changer('david', 'david', 'alice')]);
    assert.equal(await proprio('alice'), 'alice');
    assert.equal(await proprio('david'), 'david');
    assert.equal((await carteDe('alice')).pseudoMin, 'alice');
    assert.equal((await carteDe('david')).pseudoMin, 'david');
  });

  it('un même compte sur deux téléphones change de pseudo en même temps : la carte garde un pseudo à elle', async () => {
    await Promise.allSettled([changer('alice', 'alice', 'alice.un'), changer('alice', 'alice', 'alice.deux')]);
    const c = await carteDe('alice');
    assert.equal(await proprio(c.pseudoMin), 'alice');
  });
});

describe('équipe profils : voler un pseudo', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('réécrire le document du pseudo d’un autre est refusé', () =>
    refuse(setDoc(doc(base('gael'), 'pseudos/alice'), { uid: 'gael' })));
  it('le rendre à sa place puis le prendre, en un lot, est refusé', () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'pseudos', 'alice'));
    lot.update(doc(db, 'profils', 'gael'), { pseudo: 'alice', pseudoMin: 'alice', majLe: serverTimestamp() });
    return refuse(lot.commit());
  });
  it('porter le pseudo d’un autre avec une autre casse est refusé', () =>
    refuse(updateDoc(doc(base('gael'), 'profils/gael'), { pseudo: 'ALICE', pseudoMin: 'alice', majLe: serverTimestamp() })));
  it('écraser la carte d’un autre pour lui prendre son pseudo est refusé', () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'profils', 'alice'), carte('gael.vrai'));
    lot.set(doc(db, 'pseudos', 'gael.vrai'), { uid: 'gael' });
    return refuse(lot.commit());
  });
  it('supprimer la carte d’un autre pour libérer son pseudo est refusé', () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'profils', 'alice'));
    lot.delete(doc(db, 'pseudos', 'alice'));
    return refuse(lot.commit());
  });
  it('un pseudo réservé avec un champ en trop est refusé', () => {
    const db = base('karim');
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'karim'), { uid: 'karim', verifie: true });
    lot.set(doc(db, 'profils', 'karim'), carte('karim'));
    return refuse(lot.commit());
  });
  it('un pseudo rendu est libre pour un autre, et son ancien porteur ne le reprend plus', async () => {
    await permis(changer('alice', 'alice', 'alice.b'));
    await permis(inscrire('karim', 'Alice'));
    assert.equal(await proprio('alice'), 'karim');
    await refuse(changer('alice', 'alice.b', 'alice'));
  });
  it('chercher un pseudo par son propriétaire (requête sur uid) est refusé', () =>
    refuse(getDocs(query(collection(base('gael'), 'pseudos'), where('uid', '==', 'alice')))));

  it('TROU : changer de pseudo sans rendre l’ancien est refusé (sinon un compte en accapare cent)', () =>
    refuse(changer('alice', 'alice', 'alice.b', { rendre: false })));

  it('TROU : un compte ne garde pas cinq pseudos en changeant cinq fois sans rien rendre', async () => {
    let ancien = 'alice';
    for (const p of ['a.un', 'a.deux', 'a.trois', 'a.quatre', 'a.cinq']) {
      try { await changer('alice', ancien, p, { rendre: false }); } catch { /* refusé : c'est ce qu'on veut */ }
      ancien = p;
    }
    const gardes = [];
    for (const p of ['alice', 'a.un', 'a.deux', 'a.trois', 'a.quatre', 'a.cinq']) {
      if ((await proprio(p)) === 'alice') gardes.push(p);
    }
    assert.equal(gardes.length, 1, `alice tient ${gardes.length} pseudos : ${gardes.join(', ')}`);
  });

  it('TROU : supprimer sa carte sans rendre son pseudo est refusé (sinon le pseudo est perdu pour tous)', () =>
    refuse(deleteDoc(doc(base('gael'), 'profils/gael'))));
});

describe('équipe profils : changer de pseudo', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('changer seulement la casse du pseudo affiché est permis', () =>
    permis(updateDoc(doc(base('alice'), 'profils/alice'), { pseudo: 'ALICE', majLe: serverTimestamp() })));
  it('aller et revenir : alice → alice.b → alice', async () => {
    await permis(changer('alice', 'alice', 'alice.b'));
    await permis(changer('alice', 'alice.b', 'alice'));
    assert.equal(await proprio('alice'), 'alice');
    assert.equal(await proprio('alice.b'), null);
  });
  it('vers un pseudo pris par un autre : refusé, et rien ne bouge', async () => {
    await refuse(changer('alice', 'alice', 'david'));
    assert.equal(await proprio('alice'), 'alice');
    assert.equal((await carteDe('alice')).pseudoMin, 'alice');
  });
  it('vers un pseudo invalide : refusé', async () => {
    await refuse(changer('alice', 'alice', 'Al'));
    await refuse(changer('alice', 'alice', 'alice!'));
    await refuse(changer('alice', 'alice', 'a'.repeat(25)));
  });
  it('rendre l’ancien plus tard, une fois la carte changée, est permis', async () => {
    await changer('alice', 'alice', 'alice.b', { rendre: false }).catch(() => {});
    if ((await carteDe('alice')).pseudoMin !== 'alice.b') return; // le trou est bouché : rien à rendre
    await permis(deleteDoc(doc(base('alice'), 'pseudos/alice')));
  });
  it('deuxième téléphone : rendre un pseudo déjà rendu ne fait pas échouer le lot', async () => {
    // Le téléphone A rend « alice » ; le téléphone B croit encore la porter.
    await permis(changer('alice', 'alice', 'alice.un'));
    const db = base('alice');
    await permis(deleteDoc(doc(db, 'pseudos', 'alice')));
    // Mais le lot de B doit rendre celui que la carte porte vraiment : l'appli
    // relit sa carte avant chaque lot (publierProfil), sinon alice.un resterait.
    await refuse(changer('alice', 'alice', 'alice.deux'));
    const porte = (await carteDe('alice')).pseudoMin;
    await permis(writeBatch(db).set(doc(db, 'pseudos', 'alice.deux'), { uid: 'alice' })
      .update(doc(db, 'profils', 'alice'), { pseudo: 'alice.deux', pseudoMin: 'alice.deux', majLe: serverTimestamp() })
      .delete(doc(db, 'pseudos', porte)).delete(doc(db, 'pseudos', 'alice')).commit());
    assert.equal(await proprio('alice.un'), null);
  });
  it('une carte qui pointe sur un pseudo réservé par un autre est refusée même avec majuscules', () =>
    refuse(inscrire('karim', 'David', {}, 'david')));
});

describe('équipe profils : accès tous, amis, privé aux détails', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('amis : l’ami d’un ami ne lit pas', () => refuse(lireDetails('david', 'emma')));
  it('amis : celui qui a bloqué son ami ne lui montre plus ses détails', async () => {
    // emma (accès amis) bloque alice sans retirer l'amitié (un téléphone qui ne fait qu'une partie du lot).
    await permis(setDoc(doc(base('emma'), 'blocages/emma/liste/alice'), { date: serverTimestamp() }));
    await refuse(lireDetails('alice', 'emma'));
  });
  it('amis : un ami retiré ne lit plus', async () => {
    const db = base('emma');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'amis/emma/liste/alice'));
    lot.delete(doc(db, 'amis/alice/liste/emma'));
    await permis(lot.commit());
    await refuse(lireDetails('alice', 'emma'));
  });
  it('amis : on ne se fabrique pas une amitié pour lire (demande envoyée puis « acceptée » soi-même)', async () => {
    await permis(setDoc(doc(base('gael'), 'demandes/gael_emma'), { de: 'gael', vers: 'emma', date: serverTimestamp() }));
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/emma/liste/gael'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/gael/liste/emma'), { depuis: serverTimestamp() });
    await refuse(lot.commit());
    await refuse(lireDetails('gael', 'emma'));
  });
  it('amis : passer à tous ouvre aux inconnus, revenir à amis referme', async () => {
    await refuse(lireDetails('gael', 'emma'));
    await permis(updateDoc(doc(base('emma'), 'profils/emma'), { acces: 'tous', majLe: serverTimestamp() }));
    await permis(lireDetails('gael', 'emma'));
    await permis(updateDoc(doc(base('emma'), 'profils/emma'), { acces: 'amis', majLe: serverTimestamp() }));
    await refuse(lireDetails('gael', 'emma'));
    await permis(lireDetails('alice', 'emma'));
  });
  it('privé : celui qui a bloqué le propriétaire ne lit pas non plus', () => refuse(lireDetails('ines', 'chloe')));
  it('carte supprimée : les détails restés ne se lisent plus par les autres, le propriétaire les lit', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'profils', 'gael'));
    lot.delete(doc(db, 'pseudos', 'gael'));
    await permis(lot.commit());
    await refuse(lireDetails('manon', 'gael'));
    await permis(lireDetails('gael', 'gael'));
  });
  it('lister les détails d’un profil amis par un inconnu est refusé', () =>
    refuse(getDocs(collection(base('gael'), 'profils/emma/details'))));
  it('la requête sur tous les détails de tous (collectionGroup) est refusée', () =>
    refuse(getDocs(collectionGroup(base('gael'), 'details'))));
  it('la liste d’amis d’un profil tous ne se lit pas par un inconnu', () =>
    refuse(getDocs(collection(base('gael'), 'amis/alice/liste'))));
  it('la liste d’amis d’un profil privé ne se lit pas par son ami', () =>
    refuse(getDocs(collection(base('alice'), 'amis/farid/liste'))));
  it('écrire les détails d’un autre profil, même en étant son ami, est refusé', () =>
    refuse(setDoc(doc(base('alice'), 'profils/emma/details/public'), { phrase: 'Piraté', majLe: serverTimestamp() })));
});

describe('équipe profils : ce que montre cache', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('passer en privé comme l’appli (montre vide) efface les champs déjà publiés', async () => {
    await permis(ecrireDetails('alice', { phrase: 'Visible', ville: 'Brest', seances: 300, records: [{ exercice: 'squat', kg: 140, reps: 3 }] }));
    await permis(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'prive', majLe: serverTimestamp() }));
    await permis(ecrireDetails('alice', { montre: [] }));
    const d = (await lireDetails('alice', 'alice')).data();
    assert.deepEqual(Object.keys(d).sort(), ['majLe', 'montre']);
    await refuse(lireDetails('david', 'alice'));
  });
  it('cacher le lieu : un inconnu ne lit plus la ville une fois les détails réécrits', async () => {
    await permis(ecrireDetails('alice', { montre: ['lieu'], ville: 'Brest', salle: 'Basic-Fit' }));
    await permis(ecrireDetails('alice', { montre: [] }));
    const d = (await lireDetails('gael', 'alice')).data();
    assert.equal(d.ville, undefined);
    assert.equal(d.salle, undefined);
  });
  it('les détails d’un profil privé ne se lisent pas, même s’ils contiennent encore tout', async () => {
    await permis(ecrireDetails('chloe', { phrase: 'Secret', ville: 'Brest', seances: 3 }));
    for (const qui of ['alice', 'gael', 'manon']) await refuse(lireDetails(qui, 'chloe'));
  });
});

describe('équipe profils : champs en trop, types et tailles', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('modifier sa carte avec une clé en trop est refusé', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { admin: true, majLe: serverTimestamp() })));
  it('modifier sa carte sans majLe du serveur est refusé', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { prenom: 'Al' })));
  it('pseudo affiché qui n’est pas un texte refusé', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { pseudo: 42, majLe: serverTimestamp() })));
  it('couleur décimale refusée', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { couleur: 1.5, majLe: serverTimestamp() })));
  it('détails : majLe absente refusée', () =>
    refuse(setDoc(doc(base('alice'), 'profils/alice/details/public'), { phrase: 'x' })));
  it('détails : ville de 61 caractères refusée', () => refuse(ecrireDetails('alice', { ville: 'v'.repeat(61) })));
  it('détails : plus de 30 records refusés', () =>
    refuse(ecrireDetails('alice', { records: Array.from({ length: 31 }, () => ({ exercice: 'squat', kg: 100, reps: 5 })) })));
  it('détails : nbAmis qui n’est pas un entier refusé', () => refuse(ecrireDetails('alice', { nbAmis: '12' })));

  it('TROU : un record qui n’est pas {exercice, kg, reps} est refusé', async () => {
    await refuse(ecrireDetails('alice', { records: ['n’importe quoi'] }));
    await refuse(ecrireDetails('alice', { records: [{ exercice: 'squat', kg: 'lourd', reps: 5, admin: true }] }));
  });
  it('TROU : des détails de près de 1 Mo (textes cachés dans les listes) sont refusés', () =>
    refuse(ecrireDetails('alice', {
      montre: ['m'.repeat(30000)],
      records: Array.from({ length: 30 }, () => 'r'.repeat(30000)),
      fetiches: Array.from({ length: 30 }, () => 'f'.repeat(1000)),
    })));
  it('TROU : badges avec des valeurs qui ne sont pas des nombres refusés', () =>
    refuse(ecrireDetails('alice', { badges: { or: 'x'.repeat(5000) } })));
  it('TROU : heures infinies refusées (l’appli plante en les convertissant)', () =>
    refuse(ecrireDetails('alice', { heures: Infinity })));
});

describe('équipe profils : la photo', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('une vignette de 40 000 caractères base64 passe sur une modification', () =>
    permis(updateDoc(doc(base('alice'), 'profils/alice'), { photo: 'A'.repeat(40000), majLe: serverTimestamp() })));
  it('40 001 caractères refusés sur une modification', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { photo: 'A'.repeat(40001), majLe: serverTimestamp() })));
  it('une photo qui n’est pas un texte refusée', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { photo: ['A'], majLe: serverTimestamp() })));
  it('TROU : 40 000 caractères de 4 octets (160 Ko) refusés : la limite est de 40 Ko', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { photo: '😀'.repeat(20000), majLe: serverTimestamp() })));
});

describe('équipe profils : sans connexion, et l’annuaire', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('sans connexion : ni carte, ni détails, ni pseudo, ni liste ne se lisent', async () => {
    const db = anonyme();
    await refuse(getDocs(collection(db, 'profils')));
    await refuse(getDoc(doc(db, 'profils/chloe')));
    await refuse(getDocs(collection(db, 'profils/alice/details')));
    await refuse(getDocs(collectionGroup(db, 'details')));
    await refuse(getDoc(doc(db, 'pseudos/libre')));
    await refuse(getDocs(collection(db, 'amis/alice/liste')));
  });
  it('sans connexion : rien ne s’écrit', async () => {
    const db = anonyme();
    await refuse(setDoc(doc(db, 'pseudos/anonyme'), { uid: 'anonyme' }));
    await refuse(deleteDoc(doc(db, 'pseudos/alice')));
    await refuse(deleteDoc(doc(db, 'profils/alice')));
    await refuse(setDoc(doc(db, 'profils/alice/details/public'), { majLe: serverTimestamp() }));
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'anonyme'), { uid: null });
    lot.set(doc(db, 'profils', 'anonyme'), carte('anonyme'));
    await refuse(lot.commit());
  });
  it('la recherche de l’appli (préfixe, 20 au plus) passe', () =>
    permis(getDocs(query(collection(base('gael'), 'profils'), where('pseudoMin', '>=', 'a'), where('pseudoMin', '<', 'a'), orderBy('pseudoMin'), limit(20)))));
  it('TROU : télécharger tout l’annuaire (cartes, pseudos et uid, même privés) d’une seule requête est refusé', async () => {
    // La liste de `pseudos/` est fermée, mais `profils/` donne la même chose, et plus.
    const s = await getDocs(collection(base('gael'), 'profils')).catch(() => null);
    // Comparer des nombres : la différence de deux instantanés ferait exploser mocha.
    const lues = s ? s.size : 0, privees = s ? s.docs.filter((d) => d.data().acces === 'prive').length : 0;
    assert.equal(lues, 0, `annuaire complet lu : ${lues} cartes, dont ${privees} privées`);
  });
});
