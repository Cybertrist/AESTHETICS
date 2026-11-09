// Le fil : publications, réactions et commentaires.
import {
  getDoc, getDocs, updateDoc, deleteDoc, query, where, orderBy, limit, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, publication, doc, collection, setDoc } from './monde.js';

const FIL_ALICE = ['alice', 'david', 'emma', 'farid'];
// L'identifiant est celui de l'appli, `{auteur}_{seanceId}` ; `seance` change la séance.
const publier = (qui, donnees, seance = donnees.seanceId) =>
  setDoc(doc(base(qui), 'publications', `${qui}_${seance}`), { ...donnees, seanceId: seance });
const fil = (qui, pour = qui) =>
  getDocs(query(collection(base(qui), 'publications'), where('visiblePar', 'array-contains', pour), orderBy('date', 'desc'), limit(30)));

describe('publications/{id}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('le fil d’un ami (visiblePar contient moi, par date)', async () => {
    const r = await permis(fil('david'));
    if (r.size !== 1) throw new Error(`fil de david : ${r.size} publication(s)`);
  });
  it('le fil d’un inconnu est vide mais permis', async () => {
    const r = await permis(fil('gael'));
    if (r.size !== 0) throw new Error('un inconnu voit des publications');
  });
  it('lire le fil d’un autre, refusé', () => refuse(fil('gael', 'alice')));
  it('toutes les publications sans filtre, refusé', () => refuse(getDocs(collection(base('alice'), 'publications'))));
  it('un ami lit la publication', () => permis(getDoc(doc(base('emma'), 'publications/pub-alice'))));
  it('un inconnu ne la lit pas', () => refuse(getDoc(doc(base('gael'), 'publications/pub-alice'))));
  it('sans connexion, refusé', () => refuse(getDoc(doc(anonyme(), 'publications/pub-alice'))));

  it('l’auteur publie', () => permis(publier('alice', publication('alice', FIL_ALICE))));
  it('sans volume (charges cachées) ni note, permis', () => {
    const p = publication('alice', FIL_ALICE);
    delete p.volumeKg;
    delete p.note;
    return permis(publier('alice', p));
  });
  it('au nom d’un autre, refusé', () => refuse(publier('gael', publication('alice', ['alice', 'gael']))));
  it('sans l’auteur dans visiblePar, refusé', () => refuse(publier('alice', publication('alice', ['david', 'emma']))));
  it('visiblePar de 500 permis, 501 refusé', async () => {
    const amis = (n) => ['alice', ...Array.from({ length: n - 1 }, (_, i) => `ami${i}`)];
    await permis(publier('alice', publication('alice', amis(500))));
    await refuse(publier('alice', publication('alice', amis(501)), 'autre'));
  });
  it('6 exercices permis, 7 refusés', async () => {
    await permis(publier('alice', publication('alice', FIL_ALICE, { exercices: ['a', 'b', 'c', 'd', 'e', 'f'] })));
    await refuse(publier('alice', publication('alice', FIL_ALICE, { exercices: ['a', 'b', 'c', 'd', 'e', 'f', 'g'] }), 'autre'));
  });
  it('note de 280 permise, 281 refusée', async () => {
    await permis(publier('alice', publication('alice', FIL_ALICE, { note: 'n'.repeat(280) })));
    await refuse(publier('alice', publication('alice', FIL_ALICE, { note: 'n'.repeat(281) }), 'autre'));
  });
  it('clé inconnue, refusée', () => refuse(publier('alice', publication('alice', FIL_ALICE, { pub: 'achetez' }))));
  it('séance datée dans l’avenir, refusée', () =>
    refuse(publier('alice', publication('alice', FIL_ALICE, { date: Timestamp.fromMillis(Date.now() + 3 * 86400e3) }))));
  it('majLe fixée par le téléphone, refusée', () => refuse(publier('alice', publication('alice', FIL_ALICE, { majLe: Timestamp.now() }))));
  it('durée négative, refusée', () => refuse(publier('alice', publication('alice', FIL_ALICE, { dureeSec: -5 }))));
  it('un profil privé ne publie pas', () => refuse(publier('chloe', publication('chloe', ['chloe']))));
  it('un compte sans profil ne publie pas', () => refuse(publier('karim', publication('karim', ['karim']))));

  it('l’auteur réécrit visiblePar quand ses amis changent', () =>
    permis(updateDoc(doc(base('alice'), 'publications/pub-alice'), { visiblePar: ['alice', 'david'], majLe: serverTimestamp() })));
  it('un profil passé privé peut encore réduire visiblePar', async () => {
    await permis(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'prive', majLe: serverTimestamp() }));
    await permis(updateDoc(doc(base('alice'), 'publications/pub-alice'), { visiblePar: ['alice'], majLe: serverTimestamp() }));
  });
  it('un lecteur ne modifie pas la publication', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice'), { visiblePar: [...FIL_ALICE, 'gael'], majLe: serverTimestamp() })));
  it('l’auteur ne la passe pas au nom d’un autre', () =>
    refuse(updateDoc(doc(base('alice'), 'publications/pub-alice'), { auteur: 'david', majLe: serverTimestamp() })));
  it('l’auteur la supprime', () => permis(deleteDoc(doc(base('alice'), 'publications/pub-alice'))));
  it('un lecteur ne la supprime pas', () => refuse(deleteDoc(doc(base('david'), 'publications/pub-alice'))));
});

describe('publications/{id}/reactions/{uid}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  const reagir = (qui, pour = qui, autres = {}, pub = 'pub-alice') =>
    setDoc(doc(base(qui), 'publications', pub, 'reactions', pour), { type: 'coeur', date: serverTimestamp(), ...autres });

  it('un lecteur réagit', () => permis(reagir('emma')));
  it('chaque type permis', async () => {
    for (const type of ['coeur', 'feu', 'biceps', 'bravo', 'etoiles']) await permis(reagir('emma', 'emma', { type }));
  });
  it('il change sa réaction', () => permis(reagir('david', 'david', { type: 'bravo' })));
  it('type inconnu, refusé', () => refuse(reagir('emma', 'emma', { type: 'caca' })));
  it('au nom d’un autre, refusé', () => refuse(reagir('emma', 'david')));
  it('qui ne lit pas la publication ne réagit pas', () => refuse(reagir('gael')));
  it('sur une publication qui n’existe pas, refusé', () => refuse(reagir('emma', 'emma', {}, 'absente')));
  it('date fixée par le téléphone, refusée', () => refuse(reagir('emma', 'emma', { date: Timestamp.now() })));
  it('clé inconnue, refusée', () => refuse(reagir('emma', 'emma', { emoji: 'x' })));
  it('les lecteurs voient les réactions', () => permis(getDocs(collection(base('farid'), 'publications/pub-alice/reactions'))));
  it('un inconnu ne les voit pas', () => refuse(getDocs(collection(base('gael'), 'publications/pub-alice/reactions'))));
  it('on retire sa réaction', () => permis(deleteDoc(doc(base('david'), 'publications/pub-alice/reactions/david'))));
  it('on ne retire pas celle d’un autre', () => refuse(deleteDoc(doc(base('emma'), 'publications/pub-alice/reactions/david'))));
});

describe('publications/{id}/commentaires/{cid}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  const commenter = (qui, autres = {}, id = 'c9') =>
    setDoc(doc(base(qui), 'publications', 'pub-alice', 'commentaires', id), { auteur: qui, texte: 'Joli', date: serverTimestamp(), ...autres });

  it('un lecteur commente', () => permis(commenter('farid')));
  it('l’auteur de la publication commente', () => permis(commenter('alice')));
  it('1 et 500 caractères permis', async () => {
    await permis(commenter('farid', { texte: 'x' }));
    await permis(commenter('farid', { texte: 'x'.repeat(500) }, 'c10'));
  });
  it('vide ou 501 caractères refusé', async () => {
    await refuse(commenter('farid', { texte: '' }));
    await refuse(commenter('farid', { texte: 'x'.repeat(501) }));
  });
  it('au nom d’un autre, refusé', () => refuse(commenter('farid', { auteur: 'david' })));
  it('qui ne lit pas la publication ne commente pas', () => refuse(commenter('gael')));
  it('date fixée par le téléphone, refusée', () => refuse(commenter('farid', { date: Timestamp.now() })));
  it('les lecteurs lisent les commentaires', () =>
    permis(getDocs(query(collection(base('emma'), 'publications/pub-alice/commentaires'), orderBy('date')))));
  it('un inconnu ne les lit pas', () => refuse(getDocs(collection(base('gael'), 'publications/pub-alice/commentaires'))));
  it('pas de modification, même par l’auteur', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1'), { texte: 'Modifié' })));
  it('l’auteur du commentaire le supprime', () => permis(deleteDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1'))));
  it('l’auteur de la publication le supprime', () => permis(deleteDoc(doc(base('alice'), 'publications/pub-alice/commentaires/c1'))));
  it('un autre lecteur ne le supprime pas', () => refuse(deleteDoc(doc(base('emma'), 'publications/pub-alice/commentaires/c1'))));
});
