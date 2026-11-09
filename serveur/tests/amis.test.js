// Demandes, amitiés dans les deux sens et blocages.
import {
  getDoc, getDocs, updateDoc, deleteDoc, writeBatch, query, where, orderBy, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, doc, collection, setDoc } from './monde.js';

const demande = (de, vers, autres = {}) => ({ de, vers, date: serverTimestamp(), ...autres });
const envoyer = (qui, de, vers, autres = {}, id = `${de}_${vers}`) =>
  setDoc(doc(base(qui), 'demandes', id), demande(de, vers, autres));

/** Accepter comme l'appli : les deux sens et la suppression de la demande, en un lot. */
function accepter(qui, de, vers, { sansAutreSens = false, sansSupprimer = false, depuis } = {}) {
  const db = base(qui);
  const lot = writeBatch(db);
  const d = { depuis: depuis ?? serverTimestamp() };
  lot.set(doc(db, 'amis', vers, 'liste', de), d);
  if (!sansAutreSens) lot.set(doc(db, 'amis', de, 'liste', vers), d);
  if (!sansSupprimer) lot.delete(doc(db, 'demandes', `${de}_${vers}`));
  return lot.commit();
}

describe('demandes/{de}_{vers}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('un inconnu envoie une demande', () => permis(envoyer('gael', 'gael', 'bruno')));
  it('on demande un profil privé', () => permis(envoyer('gael', 'gael', 'chloe')));
  it('sans connexion, refusé', () => refuse(setDoc(doc(anonyme(), 'demandes/gael_bruno'), demande('gael', 'bruno'))));
  it('au nom d’un autre, refusé', () => refuse(envoyer('gael', 'manon', 'bruno')));
  it('à soi-même, refusé', () => refuse(envoyer('gael', 'gael', 'gael')));
  it('identifiant qui ne suit pas de_vers, refusé', () => refuse(envoyer('gael', 'gael', 'bruno', {}, 'bruno_gael')));
  it('vers un compte sans profil, refusé', () => refuse(envoyer('gael', 'gael', 'karim')));
  it('vers qui nous a bloqués, refusé', () => refuse(envoyer('alice', 'alice', 'ines')));
  it('vers qui on a bloqué, refusé', () => refuse(envoyer('alice', 'alice', 'hugo')));
  it('déjà amis, refusé', () => refuse(envoyer('alice', 'alice', 'david')));
  it('date fixée par le téléphone, refusée', () => refuse(envoyer('gael', 'gael', 'bruno', { date: Timestamp.fromMillis(0) })));
  it('clé inconnue, refusée', () => refuse(envoyer('gael', 'gael', 'bruno', { message: 'salut' })));

  it('l’envoyeur et le destinataire la lisent', async () => {
    await permis(getDoc(doc(base('jules'), 'demandes/jules_alice')));
    await permis(getDoc(doc(base('alice'), 'demandes/jules_alice')));
  });
  it('un tiers ne la lit pas', () => refuse(getDoc(doc(base('gael'), 'demandes/jules_alice'))));
  it('on vérifie qu’une demande entre soi et un autre n’existe pas', () => permis(getDoc(doc(base('alice'), 'demandes/alice_gael'))));
  it('demandes reçues : la requête « vers == moi » triée par date', () =>
    permis(getDocs(query(collection(base('alice'), 'demandes'), where('vers', '==', 'alice'), orderBy('date', 'desc')))));
  it('demandes envoyées : la requête « de == moi »', () =>
    permis(getDocs(query(collection(base('jules'), 'demandes'), where('de', '==', 'jules')))));
  it('les demandes reçues par un autre, refusé', () =>
    refuse(getDocs(query(collection(base('gael'), 'demandes'), where('vers', '==', 'alice')))));
  it('toutes les demandes sans filtre, refusé', () => refuse(getDocs(collection(base('alice'), 'demandes'))));

  it('le destinataire refuse (supprime)', () => permis(deleteDoc(doc(base('alice'), 'demandes/jules_alice'))));
  it('l’envoyeur annule (supprime)', () => permis(deleteDoc(doc(base('jules'), 'demandes/jules_alice'))));
  it('un tiers ne supprime pas', () => refuse(deleteDoc(doc(base('gael'), 'demandes/jules_alice'))));
  it('une demande ne se modifie pas', () => refuse(updateDoc(doc(base('jules'), 'demandes/jules_alice'), { vers: 'bruno' })));
});

describe('amis/{uid}/liste/{autre}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('le destinataire accepte : les deux sens et la demande supprimée, en un lot', async () => {
    await permis(accepter('alice', 'jules', 'alice'));
    const a = await getDoc(doc(base('alice'), 'amis/alice/liste/jules'));
    const j = await getDoc(doc(base('jules'), 'amis/jules/liste/alice'));
    if (!a.exists() || !j.exists()) throw new Error('amitié incomplète');
    await permis(getDoc(doc(base('jules'), 'profils/alice/details/public')));
  });
  it('l’envoyeur ne peut pas accepter à la place du destinataire', () => refuse(accepter('jules', 'jules', 'alice')));
  it('un seul sens, refusé', () => refuse(accepter('alice', 'jules', 'alice', { sansAutreSens: true })));
  it('sans demande, refusé', () => refuse(accepter('gael', 'alice', 'gael')));
  it('sans demande, même en écrivant pour soi seul, refusé', () =>
    refuse(setDoc(doc(base('gael'), 'amis/gael/liste/alice'), { depuis: serverTimestamp() })));
  it('date fixée par le téléphone, refusée', () => refuse(accepter('alice', 'jules', 'alice', { depuis: Timestamp.now() })));
  it('accepter alors que l’un a bloqué l’autre entre-temps, refusé', async () => {
    await permis(setDoc(doc(base('jules'), 'blocages/jules/liste/alice'), { date: serverTimestamp() }));
    await refuse(accepter('alice', 'jules', 'alice'));
  });
  it('une amitié ne se modifie pas', () => refuse(updateDoc(doc(base('alice'), 'amis/alice/liste/david'), { depuis: serverTimestamp() })));

  it('on lit sa liste', () => permis(getDocs(collection(base('alice'), 'amis/alice/liste'))));
  it('un ami lit la liste d’un profil ouvert (amis en commun)', () => permis(getDocs(collection(base('david'), 'amis/alice/liste'))));
  it('un ami lit la liste d’un profil « amis »', () => permis(getDocs(collection(base('alice'), 'amis/emma/liste'))));
  it('un ami ne lit pas la liste d’un profil privé', () => refuse(getDocs(collection(base('alice'), 'amis/farid/liste'))));
  it('le profil privé lit sa propre liste', () => permis(getDocs(collection(base('farid'), 'amis/farid/liste'))));
  it('un inconnu ne lit pas la liste', () => refuse(getDocs(collection(base('gael'), 'amis/alice/liste'))));
  it('sans connexion, refusé', () => refuse(getDocs(collection(anonyme(), 'amis/alice/liste'))));

  it('retirer : l’un des deux supprime les deux sens', async () => {
    const db = base('david');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'amis/alice/liste/david'));
    lot.delete(doc(db, 'amis/david/liste/alice'));
    await permis(lot.commit());
    await refuse(getDoc(doc(base('david'), 'profils/emma/details/public')));
  });
  it('un tiers ne retire pas une amitié', () => refuse(deleteDoc(doc(base('gael'), 'amis/alice/liste/david'))));
});

describe('blocages/{uid}/liste/{autre}', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  const bloquer = (qui, uid, autre, autres = {}) =>
    setDoc(doc(base(qui), 'blocages', uid, 'liste', autre), { date: serverTimestamp(), ...autres });

  it('on lit ses blocages', () => permis(getDocs(collection(base('alice'), 'blocages/alice/liste'))));
  it('le bloqué ne lit pas qu’on l’a bloqué', () => refuse(getDoc(doc(base('hugo'), 'blocages/alice/liste/hugo'))));
  it('un tiers ne lit pas les blocages', () => refuse(getDocs(collection(base('gael'), 'blocages/alice/liste'))));
  it('on bloque un inconnu', () => permis(bloquer('alice', 'alice', 'gael')));
  it('on ne bloque pas au nom d’un autre', () => refuse(bloquer('gael', 'alice', 'manon')));
  it('on ne se bloque pas soi-même', () => refuse(bloquer('alice', 'alice', 'alice')));
  it('date fixée par le téléphone, refusée', () => refuse(bloquer('alice', 'alice', 'gael', { date: Timestamp.now() })));
  it('clé inconnue, refusée', () => refuse(bloquer('alice', 'alice', 'gael', { raison: 'spam' })));
  it('bloquer un ami : le blocage, les deux sens et la demande, en un lot', async () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'blocages/alice/liste/david'), { date: serverTimestamp() });
    lot.delete(doc(db, 'amis/alice/liste/david'));
    lot.delete(doc(db, 'amis/david/liste/alice'));
    lot.delete(doc(db, 'demandes/david_alice'));
    await permis(lot.commit());
    await refuse(getDoc(doc(base('david'), 'profils/alice/details/public')));
    await refuse(envoyer('david', 'david', 'alice'));
  });
  it('débloquer', () => permis(deleteDoc(doc(base('alice'), 'blocages/alice/liste/hugo'))));
  it('le bloqué ne se débloque pas', () => refuse(deleteDoc(doc(base('hugo'), 'blocages/alice/liste/hugo'))));
});
