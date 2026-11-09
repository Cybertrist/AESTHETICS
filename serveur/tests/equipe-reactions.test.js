// L'équipe de test : réactions et commentaires, côté abus. Réagir sans
// pouvoir lire, au nom d'un autre, types et tailles hors limites, modifier ou
// supprimer ce qui n'est pas à soi, lire ce qu'on ne devrait pas voir. Et les
// états que l'appli laisse vraiment derrière elle : un blocage n'efface pas
// les vieilles séances (plus de 30 jours) de `visiblePar`, une publication
// supprimée laisse ses sous-collections.
import {
  getDoc, getDocs, updateDoc, deleteDoc, query, where, orderBy, collectionGroup, writeBatch,
  serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, publication, doc, collection, setDoc } from './monde.js';

let env;

/** Écrit des données en plus du monde, règles coupées. */
const ecrire = (f) => env.withSecurityRulesDisabled((ctx) => f(ctx.firestore()));

const reaction = (qui, uid = qui, autres = {}, pub = 'pub-alice') =>
  setDoc(doc(base(qui), 'publications', pub, 'reactions', uid), { type: 'coeur', date: serverTimestamp(), ...autres });
const commenter = (qui, autres = {}, id = 'z1', pub = 'pub-alice') =>
  setDoc(doc(base(qui), 'publications', pub, 'commentaires', id), { auteur: qui, texte: 'Joli', date: serverTimestamp(), ...autres });

describe('équipe : réactions', () => {
  before(async () => { env = await demarrer(); });
  after(arreter);
  beforeEach(peupler);

  it('sans connexion, ni réagir ni lire', async () => {
    await refuse(setDoc(doc(anonyme(), 'publications/pub-alice/reactions/david'), { type: 'coeur', date: serverTimestamp() }));
    await refuse(getDoc(doc(anonyme(), 'publications/pub-alice/reactions/david')));
  });
  it('un inconnu ne lit pas une réaction précise', () => refuse(getDoc(doc(base('gael'), 'publications/pub-alice/reactions/david'))));
  it('l’ami d’un autre fil ne lit pas les réactions de pub-alice', () =>
    refuse(getDocs(collection(base('lea'), 'publications/pub-alice/reactions'))));
  it('toutes les réactions de toutes les publications (collectionGroup), refusé', () =>
    refuse(getDocs(collectionGroup(base('david'), 'reactions'))));
  it('l’auteur réagit à sa propre séance', () => permis(reaction('alice')));
  it('un lecteur ne change pas la réaction d’un autre', () =>
    refuse(updateDoc(doc(base('emma'), 'publications/pub-alice/reactions/david'), { type: 'coeur', date: serverTimestamp() })));
  it('l’auteur de la publication ne réécrit pas la réaction d’un lecteur', () =>
    refuse(reaction('alice', 'david', { type: 'bravo' })));
  it('type vide, en majuscules, nombre ou liste : refusé', async () => {
    for (const type of ['', 'Coeur', 'coeur ', 3, ['coeur']]) await refuse(reaction('emma', 'emma', { type }));
  });
  it('sans type ou sans date, refusé', async () => {
    await refuse(setDoc(doc(base('emma'), 'publications/pub-alice/reactions/emma'), { date: serverTimestamp() }));
    await refuse(setDoc(doc(base('emma'), 'publications/pub-alice/reactions/emma'), { type: 'feu' }));
  });
  it('changer de type sans remettre la date du serveur, refusé', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice/reactions/david'), { type: 'bravo' })));
  it('un lecteur retiré de visiblePar ne réagit plus', async () => {
    await permis(updateDoc(doc(base('alice'), 'publications/pub-alice'), { visiblePar: ['alice', 'emma', 'farid'], majLe: serverTimestamp() }));
    await refuse(reaction('david', 'david', { type: 'bravo' }));
    await refuse(getDocs(collection(base('david'), 'publications/pub-alice/reactions')));
  });
  it('un lecteur retiré peut encore retirer sa propre réaction', async () => {
    await permis(updateDoc(doc(base('alice'), 'publications/pub-alice'), { visiblePar: ['alice', 'emma', 'farid'], majLe: serverTimestamp() }));
    await permis(deleteDoc(doc(base('david'), 'publications/pub-alice/reactions/david')));
  });
  it('réagir et s’ajouter à visiblePar dans le même lot, refusé', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.update(doc(db, 'publications/pub-alice'), { visiblePar: ['alice', 'david', 'emma', 'farid', 'gael'], majLe: serverTimestamp() });
    lot.set(doc(db, 'publications/pub-alice/reactions/gael'), { type: 'feu', date: serverTimestamp() });
    await refuse(lot.commit());
  });
});

describe('équipe : commentaires', () => {
  before(async () => { env = await demarrer(); });
  after(arreter);
  beforeEach(peupler);

  it('sans connexion, refusé', () =>
    refuse(setDoc(doc(anonyme(), 'publications/pub-alice/commentaires/z2'), { auteur: 'farid', texte: 'x', date: serverTimestamp() })));
  it('un inconnu ne lit pas un commentaire précis', () => refuse(getDoc(doc(base('gael'), 'publications/pub-alice/commentaires/c1'))));
  it('tous les commentaires (collectionGroup), refusé', () =>
    refuse(getDocs(query(collectionGroup(base('david'), 'commentaires'), where('auteur', '==', 'david')))));
  it('texte qui n’est pas du texte, refusé', async () => {
    await refuse(commenter('farid', { texte: 42 }));
    await refuse(commenter('farid', { texte: ['Joli'] }));
    await refuse(commenter('farid', { texte: null }));
  });
  it('clé en trop ou clé manquante, refusé', async () => {
    await refuse(commenter('farid', { reponseA: 'c1' }));
    await refuse(setDoc(doc(base('farid'), 'publications/pub-alice/commentaires/z1'), { auteur: 'farid', texte: 'Joli' }));
  });
  it('écraser le commentaire d’un autre avec le même identifiant, refusé', () =>
    refuse(commenter('farid', {}, 'c1')));
  it('l’auteur ne réécrit pas son commentaire, même avec la date du serveur', () =>
    refuse(setDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1'), { auteur: 'david', texte: 'Changé', date: serverTimestamp() })));
  it('l’auteur ne passe pas son commentaire au nom d’un autre', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1'), { auteur: 'emma' })));
  it('l’auteur de la publication ne modifie pas un commentaire', () =>
    refuse(updateDoc(doc(base('alice'), 'publications/pub-alice/commentaires/c1'), { texte: 'Censuré' })));
  it('commenter une publication qui n’existe pas, refusé', () => refuse(commenter('farid', {}, 'z1', 'absente')));
  it('un ami de bruno ne commente pas chez alice', () => refuse(commenter('lea')));
  it('l’auteur d’un fil ne supprime pas un commentaire d’une autre publication', async () => {
    await ecrire((db) => setDoc(doc(db, 'publications/pub-bruno/commentaires/b1'), { auteur: 'lea', texte: 'Top', date: Timestamp.now() }));
    await refuse(deleteDoc(doc(base('alice'), 'publications/pub-bruno/commentaires/b1')));
  });
  it('un lecteur retiré supprime encore son commentaire mais ne le lit plus', async () => {
    await permis(updateDoc(doc(base('alice'), 'publications/pub-alice'), { visiblePar: ['alice', 'emma', 'farid'], majLe: serverTimestamp() }));
    await refuse(getDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1')));
    await permis(deleteDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1')));
  });
});

// Ce que les règles laissaient passer alors que le contrat ou un blocage
// l'interdisait. Bouchés depuis : ces tests gardent qu'ils ne se rouvrent pas.
describe('équipe : trous (blocage, publication supprimée)', () => {
  before(async () => { env = await demarrer(); });
  after(arreter);
  beforeEach(peupler);

  // L'appli ne réécrit `visiblePar` que pour les séances des 30 derniers
  // jours (`_accorderMesSeances`). Une séance plus vieille garde l'ancien ami.
  const vieillePub = async () => {
    await ecrire(async (db) => {
      const lot = writeBatch(db);
      lot.set(doc(db, 'publications/pub-vieille'), {
        ...publication('alice', ['alice', 'david', 'emma', 'farid'], { date: Timestamp.fromMillis(Date.now() - 60 * 86400e3) }),
        majLe: Timestamp.now(),
      });
      lot.set(doc(db, 'publications/pub-vieille/commentaires/v1'), { auteur: 'emma', texte: 'Vieux souvenir', date: Timestamp.now() });
      await lot.commit();
    });
    // Alice bloque david comme le fait l'appli : blocage, amitiés, demandes.
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'blocages/alice/liste/david'), { date: serverTimestamp() });
    lot.delete(doc(db, 'amis/alice/liste/david'));
    lot.delete(doc(db, 'amis/david/liste/alice'));
    lot.delete(doc(db, 'demandes/alice_david'));
    lot.delete(doc(db, 'demandes/david_alice'));
    await permis(lot.commit());
  };

  it('la personne bloquée ne commente plus une vieille séance de qui l’a bloquée', async () => {
    await vieillePub();
    await refuse(commenter('david', { texte: 'Tu ne peux pas m’échapper' }, 'z1', 'pub-vieille'));
  });
  it('la personne bloquée ne réagit plus à une vieille séance', async () => {
    await vieillePub();
    await refuse(reaction('david', 'david', {}, 'pub-vieille'));
  });
  it('la personne bloquée ne lit plus les commentaires d’une vieille séance', async () => {
    await vieillePub();
    await refuse(getDocs(collection(base('david'), 'publications/pub-vieille/commentaires')));
  });
  it('qui a été bloqué ne commente plus chez celle qu’il a bloquée non plus (ines)', async () => {
    // ines a bloqué alice ; une vieille séance d'alice liste encore ines.
    await ecrire((db) => setDoc(doc(db, 'publications/pub-ines'), {
      ...publication('ines', ['ines', 'alice'], { date: Timestamp.fromMillis(Date.now() - 60 * 86400e3) }),
      majLe: Timestamp.now(),
    }));
    await refuse(commenter('alice', { texte: 'Coucou' }, 'z1', 'pub-ines'));
  });

  // Supprimer une publication laisse ses commentaires et réactions ; un autre
  // compte peut recréer une publication sous le même identifiant (rien ne lie
  // l'identifiant `{auteur}_{seanceId}` à l'auteur) et tout relire.
  it('recréer l’identifiant d’une publication supprimée ne rend pas ses commentaires lisibles à un inconnu', async () => {
    await permis(deleteDoc(doc(base('alice'), 'publications/pub-alice')));
    // Si la recréation est refusée, le trou est fermé : le test passe.
    await setDoc(doc(base('gael'), 'publications/pub-alice'), publication('gael', ['gael'])).catch(() => {});
    await refuse(getDocs(collection(base('gael'), 'publications/pub-alice/commentaires')));
  });
  it('un compte ne prend pas l’identifiant de publication d’un autre ({uid}_{seanceId})', () =>
    refuse(setDoc(doc(base('gael'), 'publications/alice_seance-9'), publication('gael', ['gael'], { seanceId: 'seance-9' }))));
  // L'identifiant de l'appli (`{auteur}_{seanceId}`) dit à qui est la
  // publication, même effacée ; les vieux identifiants du monde de test
  // (`pub-alice`) ne le disent pas.
  it('l’auteur de la publication peut encore effacer les commentaires d’une séance qu’il a supprimée', async () => {
    await ecrire(async (db) => {
      const lot = writeBatch(db);
      lot.set(doc(db, 'publications/alice_s9'), { ...publication('alice', ['alice', 'david'], { seanceId: 's9' }), majLe: Timestamp.now() });
      lot.set(doc(db, 'publications/alice_s9/commentaires/c1'), { auteur: 'david', texte: 'Costaud', date: Timestamp.now() });
      lot.set(doc(db, 'publications/alice_s9/reactions/david'), { type: 'feu', date: Timestamp.now() });
      await lot.commit();
    });
    await permis(deleteDoc(doc(base('alice'), 'publications/alice_s9')));
    await permis(getDocs(collection(base('alice'), 'publications/alice_s9/commentaires')));
    await permis(deleteDoc(doc(base('alice'), 'publications/alice_s9/commentaires/c1')));
    await permis(deleteDoc(doc(base('alice'), 'publications/alice_s9/reactions/david')));
    // Un autre n'y touche pas.
    await refuse(getDocs(collection(base('gael'), 'publications/alice_s9/reactions')));
  });
  it('avant d’effacer sa séance, l’auteur en efface les réactions des autres (l’appli nettoie)', async () => {
    await ecrire(async (db) => {
      const lot = writeBatch(db);
      lot.set(doc(db, 'publications/alice_s8'), { ...publication('alice', ['alice', 'david'], { seanceId: 's8' }), majLe: Timestamp.now() });
      lot.set(doc(db, 'publications/alice_s8/reactions/david'), { type: 'feu', date: Timestamp.now() });
      await lot.commit();
    });
    await permis(deleteDoc(doc(base('alice'), 'publications/alice_s8/reactions/david')));
    await refuse(deleteDoc(doc(base('emma'), 'publications/alice_s8/reactions/alice')));
  });
});
