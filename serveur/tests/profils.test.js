// Profils, détails et pseudos : qui lit quoi, et ce qu'une carte peut contenir.
import {
  getDoc, getDocs, updateDoc, deleteDoc, writeBatch, query, where, limit, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, carte, doc, collection, setDoc } from './monde.js';

/** Crée la carte et réserve le pseudo dans le même lot, comme l'appli. */
function inscrire(uid, pseudo, autres = {}, pseudoMin = pseudo.toLowerCase()) {
  const db = base(uid);
  const lot = writeBatch(db);
  const c = carte(pseudo, autres);
  for (const k of Object.keys(c)) if (c[k] === undefined) delete c[k];
  lot.set(doc(db, 'pseudos', pseudoMin), { uid });
  lot.set(doc(db, 'profils', uid), c);
  return lot.commit();
}

describe('profils/{uid} : la carte publique', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('sans connexion, aucune carte ne se lit', () => refuse(getDoc(doc(anonyme(), 'profils/alice'))));
  it('connecté, toute carte se lit, même privée', async () => {
    await permis(getDoc(doc(base('gael'), 'profils/alice')));
    await permis(getDoc(doc(base('gael'), 'profils/chloe')));
  });
  it('la recherche par début de pseudo marche pour tout connecté', () =>
    // 20 cartes au plus, comme l'appli : l'annuaire entier ne se lit pas.
    permis(getDocs(query(collection(base('manon'), 'profils'), where('pseudoMin', '>=', 'al'), where('pseudoMin', '<', 'am'), limit(20)))));
  it('la recherche sans limite, ou au-delà de 20, refusée', async () => {
    await refuse(getDocs(query(collection(base('manon'), 'profils'), where('pseudoMin', '>=', 'al'), where('pseudoMin', '<', 'am'))));
    await refuse(getDocs(query(collection(base('manon'), 'profils'), limit(21))));
  });
  it('sans connexion, la recherche est refusée', () =>
    refuse(getDocs(query(collection(anonyme(), 'profils'), where('pseudoMin', '>=', 'al')))));

  it('un nouveau compte crée sa carte avec son pseudo', () => permis(inscrire('karim', 'Karim_29.fit')));
  it('pas de carte sans réserver le pseudo', () => refuse(setDoc(doc(base('karim'), 'profils/karim'), carte('karim'))));
  it('pas le pseudo déjà pris par un autre', () => refuse(inscrire('karim', 'Alice')));
  it('pseudo de 3 et de 24 caractères permis', async () => {
    await permis(inscrire('karim', 'k.9'));
    // Changer de pseudo rend l'ancien dans le même lot.
    const db = base('karim');
    await permis(writeBatch(db).set(doc(db, 'pseudos', 'k'.repeat(24)), { uid: 'karim' })
      .set(doc(db, 'profils', 'karim'), carte('k'.repeat(24))).delete(doc(db, 'pseudos', 'k.9')).commit());
  });
  it('pseudo trop court, trop long ou avec un caractère interdit refusé', async () => {
    await refuse(inscrire('karim', 'ka'));
    await refuse(inscrire('karim', 'k'.repeat(25)));
    await refuse(inscrire('karim', 'ka rim'));
    await refuse(inscrire('karim', 'karim-29'));
    await refuse(inscrire('karim', 'kärim'));
  });
  it('pseudoMin doit être le pseudo en minuscules', () => refuse(inscrire('karim', 'Karim', { pseudoMin: 'autre' }, 'autre')));
  it('prénom de 40 caractères permis, 41 refusé', async () => {
    await permis(inscrire('karim', 'karim', { prenom: 'p'.repeat(40) }));
    await refuse(inscrire('karim', 'karim', { prenom: 'p'.repeat(41) }));
  });
  it('photo de 40 000 caractères permise, 40 001 refusée', async () => {
    await permis(inscrire('karim', 'karim', { photo: 'a'.repeat(40000) }));
    await refuse(inscrire('karim', 'karim', { photo: 'a'.repeat(40001) }));
  });
  it('accès inconnu refusé', () => refuse(inscrire('karim', 'karim', { acces: 'public' })));
  it('clé inconnue refusée', () => refuse(inscrire('karim', 'karim', { admin: true })));
  it('clé obligatoire absente refusée', () => refuse(inscrire('karim', 'karim', { couleur: undefined })));
  it('couleur qui n’est pas un entier refusée', () => refuse(inscrire('karim', 'karim', { couleur: '#ff0000' })));
  it('majLe fixée par le téléphone refusée', () => refuse(inscrire('karim', 'karim', { majLe: Timestamp.fromMillis(0) })));

  it('on modifie sa carte', () =>
    permis(updateDoc(doc(base('alice'), 'profils/alice'), { prenom: 'Alice B.', acces: 'amis', majLe: serverTimestamp() })));
  it('on ne modifie pas la carte d’un autre', () =>
    refuse(updateDoc(doc(base('gael'), 'profils/alice'), { prenom: 'Pirate', majLe: serverTimestamp() })));
  it('on ne crée pas de carte au nom d’un autre', () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'faux'), { uid: 'karim' });
    lot.set(doc(db, 'profils', 'karim'), carte('faux'));
    return refuse(lot.commit());
  });
  it('on ne prend pas le pseudo d’un autre en modifiant sa carte', () =>
    refuse(updateDoc(doc(base('gael'), 'profils/gael'), { pseudo: 'alice', pseudoMin: 'alice', majLe: serverTimestamp() })));
  it('on supprime sa carte, pas celle d’un autre', async () => {
    await refuse(deleteDoc(doc(base('gael'), 'profils/alice')));
    // Sa carte part avec son pseudo, dans le même lot.
    await refuse(deleteDoc(doc(base('alice'), 'profils/alice')));
    const db = base('alice');
    await permis(writeBatch(db).delete(doc(db, 'profils/alice')).delete(doc(db, 'pseudos/alice')).commit());
  });
});

describe('pseudos/{pseudoMin} : unicité', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('un connecté vérifie qu’un pseudo est pris', () => permis(getDoc(doc(base('karim'), 'pseudos/alice'))));
  it('un connecté vérifie qu’un pseudo est libre', () => permis(getDoc(doc(base('karim'), 'pseudos/libre'))));
  it('sans connexion, refusé', () => refuse(getDoc(doc(anonyme(), 'pseudos/alice'))));
  it('la liste de tous les pseudos est refusée', () => refuse(getDocs(collection(base('karim'), 'pseudos'))));
  it('réserver un pseudo seul (sans la carte) est refusé', () =>
    refuse(setDoc(doc(base('gael'), 'pseudos/reserve'), { uid: 'gael' })));
  it('réserver pour un autre compte est refusé', () =>
    refuse(setDoc(doc(base('gael'), 'pseudos/reserve'), { uid: 'alice' })));
  it('changer de pseudo : réserver le nouveau, rendre l’ancien, en un lot', () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'alice.b'), { uid: 'alice' });
    lot.delete(doc(db, 'pseudos', 'alice'));
    lot.update(doc(db, 'profils', 'alice'), { pseudo: 'Alice.B', pseudoMin: 'alice.b', majLe: serverTimestamp() });
    return permis(lot.commit());
  });
  it('rendre le pseudo que sa carte porte encore est refusé', () => refuse(deleteDoc(doc(base('alice'), 'pseudos/alice'))));
  it('rendre le pseudo d’un autre est refusé', () => refuse(deleteDoc(doc(base('gael'), 'pseudos/alice'))));
  it('supprimer son compte : carte et pseudo ensemble', () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'profils', 'gael'));
    lot.delete(doc(db, 'pseudos', 'gael'));
    return permis(lot.commit());
  });
  it('un pseudo ne se modifie pas', () => refuse(updateDoc(doc(base('alice'), 'pseudos/alice'), { uid: 'alice' })));
});

describe('profils/{uid}/details/public : selon l’accès', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  const lire = (qui, de) => getDoc(doc(base(qui), 'profils', de, 'details', 'public'));
  const ecrire = (qui, autres = {}, nom = 'public') =>
    setDoc(doc(base(qui), 'profils', 'alice', 'details', nom), { phrase: 'Toujours plus', seances: 10, majLe: serverTimestamp(), ...autres });

  it('accès tous : un inconnu lit', () => permis(lire('gael', 'alice')));
  it('accès tous : sans connexion, refusé', () => refuse(getDoc(doc(anonyme(), 'profils/alice/details/public'))));
  it('accès tous : celui qu’on a bloqué ne lit pas', () => refuse(lire('hugo', 'alice')));
  it('accès tous : on lit celui qu’on a bloqué (c’est lui qui ne voit plus)', () => permis(lire('alice', 'hugo')));
  it('accès amis : un ami lit', () => permis(lire('alice', 'emma')));
  it('accès amis : un inconnu ne lit pas', () => refuse(lire('gael', 'emma')));
  it('accès amis : le propriétaire lit', () => permis(lire('emma', 'emma')));
  it('accès privé : même un ami ne lit pas', () => refuse(lire('alice', 'farid')));
  it('accès privé : le propriétaire lit', () => permis(lire('farid', 'farid')));
  it('accès privé : un inconnu ne lit pas', () => refuse(lire('gael', 'noe')));
  it('passer en privé ferme aussitôt les détails', async () => {
    await permis(lire('gael', 'alice'));
    await permis(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'prive', majLe: serverTimestamp() }));
    await refuse(lire('gael', 'alice'));
    await refuse(lire('david', 'alice'));
  });

  it('on écrit ses détails', () => permis(ecrire('alice')));
  it('on n’écrit pas les détails d’un autre', () => refuse(ecrire('gael')));
  it('seul le document « public » existe', () => refuse(ecrire('alice', {}, 'autre')));
  it('phrase de 160 permise, 161 refusée', async () => {
    await permis(ecrire('alice', { phrase: 'p'.repeat(160) }));
    await refuse(ecrire('alice', { phrase: 'p'.repeat(161) }));
  });
  it('clé inconnue refusée', () => refuse(ecrire('alice', { poidsCorps: 72 })));
  it('plus de 7 jours refusé', () => refuse(ecrire('alice', { jours: [1, 2, 3, 4, 5, 6, 7, 8] })));
  it('séances négatives refusées', () => refuse(ecrire('alice', { seances: -1 })));
  it('majLe fixée par le téléphone refusée', () => refuse(ecrire('alice', { majLe: Timestamp.now() })));
  it('on supprime ses détails, pas ceux d’un autre', async () => {
    await refuse(deleteDoc(doc(base('gael'), 'profils/alice/details/public')));
    await permis(deleteDoc(doc(base('alice'), 'profils/alice/details/public')));
  });
});
