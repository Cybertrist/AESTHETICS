// La copie des données (résumé et morceaux) et le reste de la base, fermé.
import { getDoc, getDocs, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, doc, collection, setDoc } from './monde.js';

const resume = (autres = {}) => ({
  date: new Date().toISOString(), seances: 130, routines: 5, morceaux: 2, octets: 61000, prenom: 'Alice', ...autres,
});

describe('copies/{uid} et morceaux', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('le compte écrit son résumé', () => permis(setDoc(doc(base('alice'), 'copies/alice'), resume({ majLe: serverTimestamp() }))));
  it('le compte lit son résumé', () => permis(getDoc(doc(base('alice'), 'copies/alice'))));
  it('un ami ne lit pas la copie', () => refuse(getDoc(doc(base('david'), 'copies/alice'))));
  it('sans connexion, refusé', () => refuse(getDoc(doc(anonyme(), 'copies/alice'))));
  it('écrire la copie d’un autre, refusé', () => refuse(setDoc(doc(base('david'), 'copies/alice'), resume())));
  it('clé inconnue, refusée', () => refuse(setDoc(doc(base('alice'), 'copies/alice'), resume({ motDePasse: 'x' }))));
  it('compteur négatif, refusé', () => refuse(setDoc(doc(base('alice'), 'copies/alice'), resume({ seances: -1 }))));
  // 200 unités UTF-16 : 40 lettres avec des emojis tiennent.
  it('prénom de 201 caractères, refusé', () => refuse(setDoc(doc(base('alice'), 'copies/alice'), resume({ prenom: 'p'.repeat(201) }))));

  it('le compte écrit un morceau', () => permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/1'), { texte: 'b'.repeat(700000) })));
  it('morceau de plus de 900 000 caractères, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/1'), { texte: 'b'.repeat(900001) })));
  it('morceau au nom qui n’est pas un numéro, refusé', () => refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/x'), { texte: 'b' })));
  it('morceau avec une clé inconnue, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/1'), { texte: 'b', script: 'x' })));
  it('le compte relit ses morceaux', () => permis(getDocs(collection(base('alice'), 'copies/alice/morceaux'))));
  it('un autre ne lit pas les morceaux', () => refuse(getDocs(collection(base('david'), 'copies/alice/morceaux'))));
  it('un autre n’écrit pas de morceau', () => refuse(setDoc(doc(base('david'), 'copies/alice/morceaux/1'), { texte: 'b' })));
  it('le compte efface sa copie, pas un autre', async () => {
    await refuse(deleteDoc(doc(base('david'), 'copies/alice/morceaux/0')));
    await permis(deleteDoc(doc(base('alice'), 'copies/alice/morceaux/0')));
    await refuse(deleteDoc(doc(base('david'), 'copies/alice')));
    await permis(deleteDoc(doc(base('alice'), 'copies/alice')));
  });
});

describe('le reste de la base', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('une collection inconnue ne s’écrit pas', () => refuse(setDoc(doc(base('alice'), 'admins/alice'), { oui: true })));
  it('une collection inconnue ne se lit pas', () => refuse(getDoc(doc(base('alice'), 'admins/alice'))));
  it('une sous-collection inventée sous un profil, refusée', () =>
    refuse(setDoc(doc(base('alice'), 'profils/alice/secrets/x'), { a: 1 })));
});
