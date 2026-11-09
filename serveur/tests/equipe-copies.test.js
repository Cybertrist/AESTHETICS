// La copie des données vue par un testeur : propriétaire seul, tailles
// limites, autres comptes, effacement, et les écritures exactes de
// `CopiesFirebase` (mobile/lib/features/compte/data/copies_firebase.dart) :
// morceaux par lots de 8, puis le résumé et l'effacement des morceaux en trop
// dans un dernier lot.
import {
  getDoc, getDocs, deleteDoc, updateDoc, writeBatch, query, where, collectionGroup, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, peupler, base, anonyme, permis, refuse, doc, collection, setDoc } from './monde.js';

// Ce que `ResumeCopie.toJson()` écrit : la date en texte ISO, sans fuseau.
const resume = (autres = {}) => ({
  date: '2026-11-09T18:30:00.000', seances: 130, routines: 5, morceaux: 2, octets: 61000, prenom: 'Alice', ...autres,
});

// Un morceau de la taille que l'appli découpe (`CopieServeur.tailleMorceau`).
const TAILLE = 700000;
const morceau = (lettre = 'A', taille = TAILLE) => ({ texte: lettre.repeat(taille) });

/** L'envoi de l'appli, rejoué tel quel : lots de 8 morceaux, puis le résumé. */
async function envoyer(db, uid, morceaux, ancien = 0, autres = {}) {
  for (let i = 0; i < morceaux.length; i += 8) {
    const lot = writeBatch(db);
    for (let n = i; n < morceaux.length && n < i + 8; n++) lot.set(doc(db, `copies/${uid}/morceaux/${n}`), { texte: morceaux[n] });
    await lot.commit();
  }
  const fin = writeBatch(db);
  fin.set(doc(db, `copies/${uid}`), resume({ morceaux: morceaux.length, ...autres }));
  for (let n = morceaux.length; n < ancien; n++) fin.delete(doc(db, `copies/${uid}/morceaux/${n}`));
  await fin.commit();
}

describe('équipe : copies, le propriétaire seul', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('le compte crée puis remplace son résumé', async () => {
    await permis(setDoc(doc(base('karim'), 'copies/karim'), resume()));
    await permis(setDoc(doc(base('karim'), 'copies/karim'), resume({ seances: 131 })));
  });
  it('un compte sans profil a quand même sa copie', () =>
    permis(setDoc(doc(base('karim'), 'copies/karim'), { date: '2026-11-09T18:30:00.000', seances: 0, routines: 0, morceaux: 1, octets: 10 })));
  it('une date en Timestamp passe aussi', () => permis(setDoc(doc(base('alice'), 'copies/alice'), resume({ date: Timestamp.now() }))));
  it('mise à jour partielle par le propriétaire', () => permis(updateDoc(doc(base('alice'), 'copies/alice'), { seances: 121 })));

  for (const qui of ['david', 'bruno', 'karim', 'hugo', 'ines']) {
    it(`${qui} ne lit ni le résumé ni un morceau d'alice`, async () => {
      await refuse(getDoc(doc(base(qui), 'copies/alice')));
      await refuse(getDoc(doc(base(qui), 'copies/alice/morceaux/0')));
    });
    it(`${qui} n'écrit, ne modifie ni n'efface la copie d'alice`, async () => {
      await refuse(setDoc(doc(base(qui), 'copies/alice'), resume()));
      await refuse(updateDoc(doc(base(qui), 'copies/alice'), { seances: 0 }));
      await refuse(setDoc(doc(base(qui), 'copies/alice/morceaux/0'), morceau('Z', 10)));
      await refuse(setDoc(doc(base(qui), 'copies/alice/morceaux/7'), morceau('Z', 10)));
      await refuse(deleteDoc(doc(base(qui), 'copies/alice/morceaux/0')));
      await refuse(deleteDoc(doc(base(qui), 'copies/alice')));
    });
  }

  it('sans connexion : ni lecture, ni écriture, ni effacement', async () => {
    await refuse(getDoc(doc(anonyme(), 'copies/alice/morceaux/0')));
    await refuse(getDocs(collection(anonyme(), 'copies/alice/morceaux')));
    await refuse(setDoc(doc(anonyme(), 'copies/alice'), resume()));
    await refuse(setDoc(doc(anonyme(), 'copies/alice/morceaux/0'), morceau('Z', 10)));
    await refuse(deleteDoc(doc(anonyme(), 'copies/alice')));
  });

  it('lister toutes les copies, refusé, même pour un connecté', async () => {
    await refuse(getDocs(collection(base('alice'), 'copies')));
    await refuse(getDocs(query(collection(base('david'), 'copies'), where('seances', '>', 0))));
  });
  it('les morceaux de tout le monde par un collectionGroup, refusé', () =>
    refuse(getDocs(collectionGroup(base('alice'), 'morceaux'))));

  it('un lot qui mêle sa copie et celle d’un autre est refusé en entier', async () => {
    const db = base('david');
    const lot = writeBatch(db);
    lot.set(doc(db, 'copies/david'), resume());
    lot.set(doc(db, 'copies/alice/morceaux/0'), morceau('Z', 10));
    await refuse(lot.commit());
    const d = await getDoc(doc(base('david'), 'copies/david'));
    if (d.exists()) throw new Error('la moitié du lot a été écrite');
  });

  it('une sous-collection inventée sous la copie, refusée', async () => {
    await refuse(setDoc(doc(base('alice'), 'copies/alice/autres/0'), { texte: 'x' }));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/0/plus/0'), { texte: 'x' }));
  });
});

describe('équipe : copies, les limites', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  const ecrire = (autres) => setDoc(doc(base('alice'), 'copies/alice'), resume(autres));

  it('clés obligatoires : chacune manquante est refusée', async () => {
    for (const k of ['date', 'seances', 'routines', 'morceaux', 'octets']) {
      const r = resume();
      delete r[k];
      await refuse(setDoc(doc(base('alice'), 'copies/alice'), r));
    }
  });
  it('types faux refusés : compteur décimal, texte, date en nombre', async () => {
    await refuse(ecrire({ seances: 1.5 }));
    await refuse(ecrire({ morceaux: '2' }));
    await refuse(ecrire({ date: 1731170000000 }));
    await refuse(ecrire({ prenom: 42 }));
  });
  // 20 morceaux de 900 Ko au plus : un compte ne remplit pas l'offre gratuite.
  it('bornes du nombre de morceaux : 20 passe, 21 non', async () => {
    await permis(ecrire({ morceaux: 20 }));
    await refuse(ecrire({ morceaux: 21 }));
  });
  it('bornes des compteurs', async () => {
    await permis(ecrire({ seances: 1000000, routines: 100000, octets: 1000000000 }));
    await refuse(ecrire({ seances: 1000001 }));
    await refuse(ecrire({ routines: 100001 }));
    await refuse(ecrire({ octets: 1000000001 }));
    await refuse(ecrire({ octets: -1 }));
  });
  it('majLe posée par le téléphone, refusée ; heure du serveur, permise', async () => {
    await refuse(ecrire({ majLe: Timestamp.fromDate(new Date('2030-01-01')) }));
    await permis(ecrire({ majLe: serverTimestamp() }));
  });
  it('prénom : 40 lettres accentuées passent', () => permis(ecrire({ prenom: 'é'.repeat(40) })));
  // Le champ « Prénom » de l'appli (LengthLimitingTextInputFormatter(40))
  // compte les caractères visibles ; la règle compte autrement. Un prénom
  // refusé bloque toute la copie, qui reste « en attente » pour toujours.
  it('sonde : 20 emojis (40 unités UTF-16) passent', () => permis(ecrire({ prenom: '💪'.repeat(20) })));
  it('sonde : 101 emojis (202 unités UTF-16) refusés', () => refuse(ecrire({ prenom: '💪'.repeat(101) })));
  it('prénom de 17 caractères visibles (« Tristan » et 9 emojis teintés) que l’appli laisse saisir, accepté', () =>
    permis(ecrire({ prenom: 'Tristan ' + '💪🏽'.repeat(9) })));
  it('prénom de 40 caractères visibles avec des emojis, accepté', () => permis(ecrire({ prenom: '💪'.repeat(40) })));
  it('prénom vide passe (le champ peut être vidé)', () => permis(ecrire({ prenom: '' })));

  it('morceau : 900 000 caractères pile passent', () =>
    permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/3'), morceau('B', 900000))));
  it('morceau : texte vide passe, texte en nombre refusé, texte absent refusé', async () => {
    await permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/3'), { texte: '' }));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/3'), { texte: 12 }));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/3'), { n: 3 }));
  });
  it('morceau : numéros 0 et 19 passent, 20, 9999, -1 et 1.5 non', async () => {
    await permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/0'), morceau('C', 5)));
    await permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/19'), morceau('C', 5)));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/20'), morceau('C', 5)));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/9999'), morceau('C', 5)));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/-1'), morceau('C', 5)));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/1.5'), morceau('C', 5)));
  });
  it('morceau : majLe du téléphone refusée, n négatif refusé', async () => {
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/0'), { texte: 'x', majLe: Timestamp.now() }));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/0'), { texte: 'x', n: -1 }));
    await permis(setDoc(doc(base('alice'), 'copies/alice/morceaux/0'), { texte: 'x', n: 0, majLe: serverTimestamp() }));
  });
});

describe('équipe : copies, l’envoi de l’appli rejoué', () => {
  before(demarrer);
  after(arreter);
  beforeEach(peupler);

  it('un lot de 8 morceaux pleins (5,6 Mo) passe en une requête', async () => {
    const morceaux = Array.from({ length: 8 }, (_, i) => String.fromCharCode(65 + i).repeat(TAILLE));
    await permis(envoyer(base('alice'), 'alice', morceaux, 1));
    const lus = await getDocs(collection(base('alice'), 'copies/alice/morceaux'));
    if (lus.size !== 8) throw new Error(`8 morceaux attendus, ${lus.size} lus`);
  });

  it('11 morceaux : deux lots, puis le résumé ; tout se relit dans l’ordre', async () => {
    const morceaux = Array.from({ length: 11 }, (_, i) => `${i}:`.padEnd(1000, 'x'));
    await permis(envoyer(base('karim'), 'karim', morceaux));
    const r = (await getDoc(doc(base('karim'), 'copies/karim'))).data();
    const lus = await Promise.all(Array.from({ length: r.morceaux }, (_, n) => getDoc(doc(base('karim'), `copies/karim/morceaux/${n}`))));
    if (lus.map((d) => d.data().texte).join('|') !== morceaux.join('|')) throw new Error('copie relue différente');
  });

  it('une copie plus petite efface les morceaux en trop dans le dernier lot', async () => {
    await permis(envoyer(base('karim'), 'karim', ['a', 'b', 'c', 'd']));
    await permis(envoyer(base('karim'), 'karim', ['e'], 4));
    const lus = await getDocs(collection(base('karim'), 'copies/karim/morceaux'));
    if (lus.size !== 1 || lus.docs[0].data().texte !== 'e') throw new Error(`reste ${lus.size} morceaux`);
  });

  it('effacer un morceau qui n’existe plus est permis (ancien résumé trop grand)', () =>
    permis(envoyer(base('alice'), 'alice', ['x'], 5)));

  it('le résumé ne peut pas usurper un autre compte dans le lot final', async () => {
    const db = base('david');
    const lot = writeBatch(db);
    lot.set(doc(db, 'copies/david'), resume());
    lot.delete(doc(db, 'copies/alice/morceaux/0'));
    await refuse(lot.commit());
    const reste = await getDoc(doc(base('alice'), 'copies/alice/morceaux/0'));
    if (!reste.exists()) throw new Error('le morceau d’alice a disparu');
  });

  it('le compte efface toute sa copie, morceaux compris, puis la relit vide', async () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'copies/alice'));
    lot.delete(doc(db, 'copies/alice/morceaux/0'));
    await permis(lot.commit());
    const r = await getDoc(doc(db, 'copies/alice'));
    const m = await getDocs(collection(db, 'copies/alice/morceaux'));
    if (r.exists() || m.size) throw new Error('copie encore là');
  });
});
