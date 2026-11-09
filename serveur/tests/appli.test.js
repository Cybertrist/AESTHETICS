// Le parcours de l'appli, avec les écritures et les lectures exactes de
// `SourceFirestore` (mobile/lib/features/social/data/source_firestore.dart) :
// si l'une d'elles change d'un côté, ce test le dit avant le téléphone.
import {
  getDoc, getDocs, writeBatch, query, where, orderBy, limit, deleteField, updateDoc, deleteDoc, addDoc,
  serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { demarrer, arreter, base, permis, refuse, doc, collection, setDoc, filDeLAppli } from './monde.js';

const st = serverTimestamp;
const jour = (n) => Math.floor(Date.now() / 86400000) - n;

/** Ma carte et mes détails, comme `publierProfil` : pseudo réservé dans le même lot. */
function publierProfil(uid, pseudo, { acces = 'amis', ancien, pseudoDejaAMoi = false, prive = false } = {}) {
  const db = base(uid);
  const lot = writeBatch(db);
  if (!pseudoDejaAMoi) lot.set(doc(db, 'pseudos', pseudo), { uid });
  lot.set(doc(db, 'profils', uid), {
    pseudo, pseudoMin: pseudo, prenom: uid[0].toUpperCase() + uid.slice(1), couleur: 0xff2c5676,
    // La plus grosse vignette permise : 40 000 signes de base64.
    photo: 'iVBORw0KGgo'.padEnd(40000, 'A'), acces, majLe: st(),
  });
  if (ancien) lot.delete(doc(db, 'pseudos', ancien));
  lot.set(doc(db, 'profils', uid, 'details', 'public'), prive ? { montre: [], majLe: st() } : {
    phrase: 'Un pas après l’autre.', ville: 'Brest', salle: 'Basic-Fit', depuis: 2022,
    montre: ['seances', 'charges', 'serie', 'badges', 'records', 'lieu', 'nbSeances', 'nbAmis', 'heures', 'objectif', 'niveau'],
    seances: 48, heures: 52, serieSemaines: 6, jours: [jour(0), jour(2), jour(4), jour(6), jour(8), jour(10), jour(12)],
    // Les plus longues listes que l'appli envoie : le lot entier tient sous
    // les 1 000 expressions que les règles évaluent par requête.
    objectif: 'Gagner en force', niveau: 'Intermédiaire',
    records: Array.from({ length: 4 }, (_, i) => ({ exercice: `exercice-${i}`, kg: 120.5, reps: 3 })),
    badges: Object.fromEntries(['semaineParfaite', 'leveTot', 'serie', 'weekEnd', 'collectionneur', 'explorateur', 'marathon', 'noctambule', 'records'].map((g, i) => [g, i * 7])),
    fetiches: Array.from({ length: 10 }, (_, i) => `fetiche-${i}`), nbAmis: 1, majLe: st(),
  });
  return lot.commit();
}

const inviter = (de, vers) => setDoc(doc(base(de), 'demandes', `${de}_${vers}`), { de, vers, date: st() });

/** Accepter : les deux sens, et les deux demandes effacées (la mienne, même absente). */
function accepter(moi, de) {
  const db = base(moi);
  return writeBatch(db)
    .set(doc(db, 'amis', moi, 'liste', de), { depuis: st() })
    .set(doc(db, 'amis', de, 'liste', moi), { depuis: st() })
    .delete(doc(db, 'demandes', `${de}_${moi}`))
    .delete(doc(db, 'demandes', `${moi}_${de}`))
    .commit();
}

/** `_balayer` : l'ami parti sort de toutes mes séances, une écriture par séance. */
async function balayer(uid, parti) {
  const db = base(uid);
  const s = await getDocs(query(collection(db, 'publications'), where('auteur', '==', uid), where('visiblePar', 'array-contains', parti)));
  for (const d of s.docs) {
    await updateDoc(d.ref, { visiblePar: d.data().visiblePar.filter((v) => v !== parti), majLe: st() });
  }
  return s.size;
}

/** `retirerSeance` : réactions et commentaires d'abord, puis la séance. */
async function retirerSeance(uid, id) {
  const db = base(uid);
  const lot = writeBatch(db);
  for (const sous of ['reactions', 'commentaires']) {
    for (const d of (await getDocs(collection(db, 'publications', id, sous))).docs) lot.delete(d.ref);
  }
  await lot.commit();
  await deleteDoc(doc(db, 'publications', id));
}

function publierSeance(uid, seanceId, visiblePar, { volume = true } = {}) {
  return setDoc(doc(base(uid), 'publications', `${uid}_${seanceId}`), {
    auteur: uid, seanceId, titre: 'Jambes', date: Timestamp.fromMillis(Date.now() - 3600e3), dureeSec: 3840,
    ...(volume ? { volumeKg: 8420 } : {}), series: 18,
    exercices: ['squat', 'presse-a-cuisses', 'leg-extension', 'leg-curl', 'mollets', 'gainage'], records: 1,
    visiblePar, majLe: st(),
  });
}

/** Les écoutes de la source, lancées à la connexion (le fil : mes séances et celles de mes amis). */
function ecoutes(uid) {
  const db = base(uid);
  return [
    getDocs(collection(db, 'amis', uid, 'liste')),
    getDocs(query(collection(db, 'demandes'), where('vers', '==', uid))),
    getDocs(query(collection(db, 'demandes'), where('de', '==', uid))),
    getDocs(collection(db, 'blocages', uid, 'liste')),
    filDeLAppli(db, uid),
  ];
}

describe('le parcours de l’appli (SourceFirestore)', () => {
  before(async () => {
    const env = await demarrer();
    await env.clearFirestore();
  });
  after(arreter);

  it('publier son profil, changer de pseudo, être privé', async () => {
    await permis(publierProfil('anna', 'anna'));
    await permis(publierProfil('basile', 'basile'));
    await permis(publierProfil('cyril', 'cyril', { acces: 'tous' }));
    await permis(publierProfil('dora', 'dora', { acces: 'prive', prive: true }));
    // Republié sans changer de pseudo : le pseudo n'est pas réécrit.
    await permis(publierProfil('anna', 'anna', { pseudoDejaAMoi: true }));
    // Un pseudo pris : le lot entier est refusé.
    await refuse(publierProfil('basile', 'anna', { ancien: 'basile' }));
    await permis(publierProfil('basile', 'basile.m', { ancien: 'basile' }));
    await permis(getDoc(doc(base('anna'), 'pseudos', 'basile.m')));
    await permis(getDoc(doc(base('anna'), 'profils', 'anna')));
  });

  it('la connexion : chaque écoute est permise', async () => {
    for (const uid of ['anna', 'basile', 'cyril', 'dora']) {
      await Promise.all(ecoutes(uid).map(permis));
    }
  });

  it('chercher par pseudo, lire une carte, et des détails selon l’accès', async () => {
    const db = base('anna');
    await permis(getDocs(query(collection(db, 'profils'), where('pseudoMin', '>=', 'ba'), where('pseudoMin', '<', 'ba'), orderBy('pseudoMin'), limit(20))));
    await permis(getDoc(doc(db, 'profils', 'cyril', 'details', 'public')));
    await refuse(getDoc(doc(db, 'profils', 'basile', 'details', 'public')));
    await refuse(getDoc(doc(db, 'profils', 'dora', 'details', 'public')));
  });

  it('demande, acceptation (avec ma propre demande croisée), fil, réactions, commentaires', async () => {
    await permis(inviter('basile', 'anna'));
    await permis(inviter('anna', 'basile'));
    await permis(accepter('anna', 'basile'));
    await permis(getDoc(doc(base('anna'), 'profils', 'basile', 'details', 'public')));
    // Les amis en commun : la liste d'un ami.
    await permis(getDocs(collection(base('anna'), 'amis', 'basile', 'liste')));
    await permis(publierSeance('basile', 's1', ['basile', 'anna']));
    // Publiée deux fois : la même séance est réécrite.
    await permis(publierSeance('basile', 's1', ['basile', 'anna']));
    await Promise.all(ecoutes('anna').map(permis));
    const fil = await filDeLAppli(base('anna'), 'anna');
    if (!fil.docs.some((d) => d.id === 'basile_s1')) throw new Error('basile_s1 absente du fil d’anna');
    const pub = (uid) => doc(base(uid), 'publications', 'basile_s1');
    await permis(getDocs(collection(pub('anna'), 'reactions')));
    await permis(getDocs(collection(pub('anna'), 'commentaires')));
    await permis(setDoc(doc(pub('anna'), 'reactions', 'anna'), { type: 'feu', date: st() }));
    await permis(deleteDoc(doc(pub('anna'), 'reactions', 'anna')));
    await permis(setDoc(doc(pub('anna'), 'reactions', 'anna'), { type: 'coeur', date: st() }));
    const c = await addDoc(collection(pub('anna'), 'commentaires'), { auteur: 'anna', texte: 'Belle séance !', date: st() });
    // Cyril n'est pas dans visiblePar : rien.
    await refuse(getDoc(pub('cyril')));
    await refuse(setDoc(doc(pub('cyril'), 'reactions', 'cyril'), { type: 'feu', date: st() }));
    // L'auteur de la séance retire le commentaire.
    await permis(deleteDoc(doc(pub('basile'), 'commentaires', c.id)));
  });

  it('réglages : volume retiré, visiblePar réécrit, privé', async () => {
    const pub = doc(base('basile'), 'publications', 'basile_s1');
    await permis(updateDoc(pub, { volumeKg: deleteField(), majLe: st() }));
    await permis(updateDoc(pub, { visiblePar: ['basile'], majLe: st() }));
    await permis(updateDoc(pub, { visiblePar: ['basile', 'anna'], majLe: st() }));
    // Un profil privé ne publie plus rien.
    await refuse(publierSeance('dora', 's1', ['dora']));
  });

  it('retirer, bloquer, débloquer', async () => {
    const db = base('anna');
    await permis(writeBatch(db).delete(doc(db, 'amis', 'anna', 'liste', 'basile')).delete(doc(db, 'amis', 'basile', 'liste', 'anna')).commit());
    // Basile voit anna partir : elle sort de toutes ses séances.
    await permis(balayer('basile', 'anna'));
    await refuse(getDoc(doc(base('anna'), 'publications', 'basile_s1')));
    await permis(inviter('cyril', 'anna'));
    const lot = writeBatch(db)
      .set(doc(db, 'blocages', 'anna', 'liste', 'cyril'), { date: st() })
      .delete(doc(db, 'amis', 'anna', 'liste', 'cyril'))
      .delete(doc(db, 'amis', 'cyril', 'liste', 'anna'))
      .delete(doc(db, 'demandes', 'anna_cyril'))
      .delete(doc(db, 'demandes', 'cyril_anna'));
    await permis(lot.commit());
    await refuse(inviter('cyril', 'anna'));
    await permis(deleteDoc(doc(db, 'blocages', 'anna', 'liste', 'cyril')));
    await permis(inviter('cyril', 'anna'));
    // Refuser, annuler.
    await permis(deleteDoc(doc(db, 'demandes', 'cyril_anna')));
    await permis(inviter('anna', 'cyril'));
    await permis(deleteDoc(doc(db, 'demandes', 'anna_cyril')));
  });

  it('retirer une séance : ses réactions et commentaires partent avant elle', async () => {
    await permis(publierSeance('basile', 's2', ['basile', 'anna']));
    await permis(setDoc(doc(base('basile'), 'publications/basile_s2/reactions/basile'), { type: 'feu', date: st() }));
    await permis(addDoc(collection(base('basile'), 'publications/basile_s2/commentaires'), { auteur: 'basile', texte: 'Top', date: st() }));
    await permis(retirerSeance('basile', 'basile_s2'));
  });

  it('changer de pseudo depuis un deuxième téléphone : la carte relue, l’ancien rendu', async () => {
    // Le premier téléphone est passé à basile.m ; le second relit la carte.
    const porte = (await getDoc(doc(base('basile'), 'profils', 'basile'))).data().pseudoMin;
    await permis(publierProfil('basile', 'basile.deux', { ancien: porte }));
    const reste = await getDoc(doc(base('anna'), 'pseudos', porte));
    if (reste.exists()) throw new Error(`${porte} reste réservé`);
  });
});
