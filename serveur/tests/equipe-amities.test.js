// L'équipe de test, angle « amitiés » : demandes, demandes croisées,
// doublons, accepter, refuser, annuler, retirer d'un côté ou de l'autre, et
// les tentatives de se fabriquer un ami. Le monde est celui de monde.js :
// jules a demandé alice, alice est amie de david, emma et farid, alice a
// bloqué hugo, ines a bloqué alice, karim n'a pas de profil.
import {
  getDoc, getDocs, deleteDoc, updateDoc, writeBatch, query, where, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, permis, refuse, doc, collection, setDoc } from './monde.js';

const demande = (de, vers, autres = {}) => ({ de, vers, date: serverTimestamp(), ...autres });
const envoyer = (qui, de, vers, autres = {}, id = `${de}_${vers}`) =>
  setDoc(doc(base(qui), 'demandes', id), demande(de, vers, autres));
const existe = async (qui, chemin) => (await getDoc(doc(base(qui), chemin))).exists();

/**
 * Accepter : `qui` écrit les deux sens entre `de` et `vers`, et supprime les
 * demandes de `supprimer` (par défaut celle `{de}_{vers}`, comme l'appli).
 */
function accepter(qui, de, vers, { supprimer = [`${de}_${vers}`], sens = [[vers, de], [de, vers]] } = {}) {
  const db = base(qui);
  const lot = writeBatch(db);
  for (const [a, b] of sens) lot.set(doc(db, 'amis', a, 'liste', b), { depuis: serverTimestamp() });
  for (const id of supprimer) lot.delete(doc(db, 'demandes', id));
  return lot.commit();
}

/** Retirer comme l'appli : les deux sens, en un lot. */
function retirer(qui, a, b) {
  const db = base(qui);
  return writeBatch(db).delete(doc(db, 'amis', a, 'liste', b)).delete(doc(db, 'amis', b, 'liste', a)).commit();
}

describe('équipe : les demandes d’ami', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('à soi-même, refusé, même sous un identifiant bricolé', async () => {
    await refuse(envoyer('gael', 'gael', 'gael'));
    await refuse(envoyer('gael', 'gael', 'gael', {}, 'gael_gael'));
    await refuse(envoyer('gael', 'gael', 'gael', {}, 'gael'));
  });
  it('vers qui m’a bloqué, refusé ; vers qui j’ai bloqué, refusé', async () => {
    await refuse(envoyer('alice', 'alice', 'ines'));
    await refuse(envoyer('hugo', 'hugo', 'alice'));
    await refuse(envoyer('alice', 'alice', 'hugo'));
  });
  it('après déblocage, la demande repart', async () => {
    await permis(deleteDoc(doc(base('alice'), 'blocages/alice/liste/hugo')));
    await permis(envoyer('hugo', 'hugo', 'alice'));
  });
  it('doublon : la même demande deux fois, la seconde refusée (pas de modification)', async () => {
    await permis(envoyer('gael', 'gael', 'manon'));
    await refuse(envoyer('gael', 'gael', 'manon'));
  });
  it('doublon sous un autre identifiant, refusé', async () => {
    await refuse(envoyer('jules', 'jules', 'alice', {}, 'jules_alice_2'));
    await refuse(envoyer('jules', 'jules', 'alice', {}, 'alice_jules'));
  });
  it('demandes croisées : A→B puis B→A, les deux existent', async () => {
    await permis(envoyer('gael', 'gael', 'manon'));
    await permis(envoyer('manon', 'manon', 'gael'));
  });
  it('« vers » au nom de qui n’a pas de profil ou chemin glissé dans « vers », refusé', async () => {
    await refuse(envoyer('gael', 'gael', 'karim'));
    await refuse(envoyer('gael', 'gael', 'manon/details/public', {}, 'gael_manon'));
  });
  it('un tiers ne lit, n’annule ni ne refuse une demande des autres', async () => {
    await refuse(getDoc(doc(base('manon'), 'demandes/jules_alice')));
    await refuse(deleteDoc(doc(base('manon'), 'demandes/jules_alice')));
    await refuse(getDocs(query(collection(base('manon'), 'demandes'), where('de', '==', 'jules'))));
  });
  it('déjà amis (dans un sens ou dans l’autre), refusé', async () => {
    await refuse(envoyer('alice', 'alice', 'emma'));
    await refuse(envoyer('emma', 'emma', 'alice'));
  });
  it('refuser puis redemander : permis', async () => {
    await permis(deleteDoc(doc(base('alice'), 'demandes/jules_alice')));
    await permis(envoyer('jules', 'jules', 'alice'));
  });
  it('annuler une demande puis la renvoyer : permis', async () => {
    await permis(deleteDoc(doc(base('jules'), 'demandes/jules_alice')));
    await permis(envoyer('jules', 'jules', 'alice'));
  });
  it('« vers » ne transforme pas la demande (de ou vers changés), refusé', async () => {
    await refuse(updateDoc(doc(base('alice'), 'demandes/jules_alice'), { de: 'alice', vers: 'jules' }));
  });
});

describe('équipe : accepter et se fabriquer un ami', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('accepter une demande qui n’existe pas, refusé', () => refuse(accepter('manon', 'gael', 'manon')));
  it('accepter une demande refusée entre-temps, refusé', async () => {
    await permis(deleteDoc(doc(base('jules'), 'demandes/jules_alice')));
    await refuse(accepter('alice', 'jules', 'alice'));
  });
  it('l’envoyeur ne s’accepte pas lui-même', () => refuse(accepter('jules', 'jules', 'alice')));
  it('se fabriquer un ami sans demande : les deux sens d’un coup, refusé', () =>
    refuse(accepter('gael', 'manon', 'gael', { supprimer: [] })));
  it('se fabriquer un ami avec sa propre demande envoyée, refusé', async () => {
    await permis(envoyer('gael', 'gael', 'manon'));
    await refuse(accepter('gael', 'manon', 'gael', { supprimer: [] }));
    await refuse(accepter('gael', 'gael', 'manon', { supprimer: [] }));
  });
  it('un tiers ne marie pas deux autres avec leur demande', () =>
    refuse(accepter('manon', 'jules', 'alice')));
  it('se servir de la demande reçue pour s’ajouter un autre ami, refusé', () =>
    refuse(accepter('alice', 'jules', 'alice', { sens: [['alice', 'gael'], ['gael', 'alice']], supprimer: [] })));
  it('demande créée et acceptée dans le même lot, refusé', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'demandes/gael_manon'), demande('gael', 'manon'));
    lot.set(doc(db, 'amis/gael/liste/manon'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/manon/liste/gael'), { depuis: serverTimestamp() });
    await refuse(lot.commit());
  });
  it('accepter une demande d’un compte que j’ai bloqué depuis, refusé', async () => {
    await permis(setDoc(doc(base('alice'), 'blocages/alice/liste/jules'), { date: serverTimestamp() }));
    await refuse(accepter('alice', 'jules', 'alice'));
  });
  it('accepter deux fois (deux téléphones), la seconde refusée sans rien casser', async () => {
    await permis(accepter('alice', 'jules', 'alice'));
    await refuse(accepter('alice', 'jules', 'alice'));
    if (!(await existe('alice', 'amis/alice/liste/jules'))) throw new Error('amitié perdue');
  });
  it('clé en trop dans l’amitié, refusée', async () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/jules'), { depuis: serverTimestamp(), proche: true });
    lot.set(doc(db, 'amis/jules/liste/alice'), { depuis: serverTimestamp() });
    lot.delete(doc(db, 'demandes/jules_alice'));
    await refuse(lot.commit());
  });

  it('demandes croisées : accepter efface les deux demandes, puis plus rien ne traîne', async () => {
    await permis(envoyer('alice', 'alice', 'jules'));
    await permis(accepter('alice', 'jules', 'alice', { supprimer: ['jules_alice', 'alice_jules'] }));
    if (await existe('alice', 'demandes/alice_jules')) throw new Error('demande croisée restée');
    if (await existe('alice', 'demandes/jules_alice')) throw new Error('demande restée');
  });
  it('demandes croisées : l’autre ne peut pas « accepter » une seconde fois après coup', async () => {
    await permis(envoyer('alice', 'alice', 'jules'));
    await permis(accepter('alice', 'jules', 'alice', { supprimer: ['jules_alice', 'alice_jules'] }));
    await refuse(accepter('jules', 'alice', 'jules', { supprimer: [] }));
  });

  // Le contrat : accepter « crée les deux sens, puis supprime la demande », en
  // un lot. Si la demande survit au lot, elle reste une clé d'amitié valable.
  it('accepter sans supprimer la demande, refusé', () =>
    refuse(accepter('alice', 'jules', 'alice', { supprimer: [] })));
  it('demandes croisées : accepter en laissant la demande croisée, refusé', async () => {
    await permis(envoyer('alice', 'alice', 'jules'));
    await refuse(accepter('alice', 'jules', 'alice'));
  });
  it('retiré, on ne se rajoute pas tout seul avec une demande gardée', async () => {
    // alice accepte jules en gardant la demande (lot permis aujourd'hui) ;
    // jules la retire ; alice ne doit pas pouvoir se remettre dans sa liste.
    await accepter('alice', 'jules', 'alice', { supprimer: [] }).catch(() => {});
    await permis(retirer('jules', 'jules', 'alice'));
    await refuse(accepter('alice', 'jules', 'alice', { supprimer: [] }));
  });
  it('demandes croisées laissées par l’appli : après un retrait, l’autre ne revient pas seul', async () => {
    // Le lot de l'appli quand `_envoyees` ne connaît pas encore la demande
    // croisée : seule `jules_alice` est effacée, `alice_jules` reste.
    await permis(envoyer('alice', 'alice', 'jules'));
    await accepter('alice', 'jules', 'alice').catch(() => {});
    await permis(retirer('alice', 'alice', 'jules'));
    // jules se rajoute dans la liste d'alice sans qu'elle le veuille.
    await refuse(accepter('jules', 'alice', 'jules', { supprimer: [] }));
  });
});

describe('équipe : retirer d’un côté ou de l’autre', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('chacun des deux retire, puis une nouvelle demande repart', async () => {
    await permis(retirer('alice', 'alice', 'david'));
    await permis(envoyer('david', 'david', 'alice'));
    await permis(retirer('emma', 'emma', 'alice'));
    await permis(envoyer('alice', 'alice', 'emma'));
  });
  it('retiré, l’ancien ami ne lit plus les détails « amis » ni la liste', async () => {
    await permis(retirer('alice', 'alice', 'emma'));
    await refuse(getDoc(doc(base('alice'), 'profils/emma/details/public')));
    await refuse(getDocs(collection(base('alice'), 'amis/emma/liste')));
  });
  it('retirer une amitié qui n’existe pas, sans effet sur les autres', async () => {
    await permis(retirer('gael', 'gael', 'manon'));
    await refuse(retirer('gael', 'alice', 'david'));
  });
  it('retiré puis redemandé puis accepté : l’amitié revient', async () => {
    await permis(retirer('david', 'david', 'alice'));
    await permis(envoyer('david', 'david', 'alice'));
    await permis(accepter('alice', 'david', 'alice'));
  });

  // Le contrat : « chacun des deux peut supprimer les deux documents ». Un
  // seul sens supprimé laisse une amitié boiteuse.
  it('retirer un seul sens, refusé', () =>
    refuse(deleteDoc(doc(base('emma'), 'amis/emma/liste/alice'))));
  it('après un retrait d’un seul sens, l’amitié se refait par demande et acceptation', async () => {
    // Retirer un seul sens est refusé : l'amitié reste entière, rien à refaire.
    if (!(await deleteDoc(doc(base('emma'), 'amis/emma/liste/alice')).then(() => true, () => false))) return;
    // emma n'a plus alice, elle redemande ; alice accepte comme l'appli.
    await permis(envoyer('emma', 'emma', 'alice'));
    await permis(accepter('alice', 'emma', 'alice'));
  });
  it('après un retrait d’un seul sens, celui qui a retiré ne lit plus les détails « amis »', async () => {
    // emma (« amis ») garde alice ; alice retire seulement amis/alice/liste/emma
    // et lit encore les détails d'emma, qui la croit toujours amie.
    // Refusé : l'amitié reste entière et la lecture permise est juste.
    if (!(await deleteDoc(doc(base('alice'), 'amis/alice/liste/emma')).then(() => true, () => false))) return;
    await refuse(getDoc(doc(base('alice'), 'profils/emma/details/public')));
  });
});
