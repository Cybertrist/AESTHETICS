// Le monde simulé des tests : quatorze comptes, leurs profils, amitiés,
// blocages, demandes, publications et copie, écrits règles coupées avant
// chaque test.
//
//   alice  'tous'  amie de david, emma, farid ; a bloqué hugo ; demande reçue de jules
//   bruno  'amis'  ami de lea
//   chloe  'prive' sans ami
//   david  'tous'  ami d'alice
//   emma   'amis'  amie d'alice
//   farid  'prive' ami d'alice
//   gael   'tous'  inconnu de tous
//   hugo   'tous'  bloqué par alice
//   ines   'tous'  a bloqué alice
//   jules  'tous'  a demandé alice en ami
//   karim  sans profil (compte tout neuf)
//   lea    'amis'  amie de bruno
//   manon  'tous'  inconnue
//   noe    'prive' inconnu
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, collection, writeBatch, setDoc, getDocs, query, where, orderBy, limit, serverTimestamp, Timestamp,
} from 'firebase/firestore';

export const PROJET = 'demo-aesthetics';

export const ACCES = {
  alice: 'tous', bruno: 'amis', chloe: 'prive', david: 'tous', emma: 'amis', farid: 'prive',
  gael: 'tous', hugo: 'tous', ines: 'tous', jules: 'tous', lea: 'amis', manon: 'tous', noe: 'prive',
};

export const AMITIES = [['alice', 'david'], ['alice', 'emma'], ['alice', 'farid'], ['bruno', 'lea']];
export const BLOCAGES = [['alice', 'hugo'], ['ines', 'alice']];

let env;

/** Démarre l'environnement de test sur l'émulateur (FIRESTORE_EMULATOR_HOST). */
export async function demarrer() {
  if (env) return env;
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: PROJET,
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(fileURLToPath(new URL('../firestore.rules', import.meta.url)), 'utf8'),
    },
  });
  return env;
}

export async function arreter() {
  if (env) await env.cleanup();
  env = undefined;
}

/** La base vue par un compte connecté. */
export const base = (uid) => env.authenticatedContext(uid).firestore();

/** La base vue sans connexion. */
export const anonyme = () => env.unauthenticatedContext().firestore();

export const permis = assertSucceeds;
export const refuse = assertFails;

/** Une carte publique valide, à compléter ou casser. */
export function carte(pseudo, autres = {}) {
  return {
    pseudo,
    pseudoMin: pseudo.toLowerCase(),
    prenom: pseudo.slice(0, 1).toUpperCase() + pseudo.slice(1).toLowerCase(),
    couleur: 0xff2266aa,
    acces: 'tous',
    majLe: serverTimestamp(),
    ...autres,
  };
}

/** Une publication valide d'`auteur`, visible par `visiblePar`. */
export function publication(auteur, visiblePar, autres = {}) {
  return {
    auteur,
    seanceId: 'seance-1',
    titre: 'Push A',
    date: Timestamp.fromMillis(Date.now() - 3600 * 1000),
    dureeSec: 3900,
    volumeKg: 8450.5,
    series: 18,
    exercices: ['bench_press', 'incline_db_press', 'dips'],
    records: 2,
    note: 'Bonne séance',
    visiblePar,
    majLe: serverTimestamp(),
    ...autres,
  };
}

/**
 * Le fil tel que l'appli le lit (SourceFirestore._ecouter) : mes séances
 * (`auteur == moi`), puis celles de mes amis par paquets de 30 (`auteur in`,
 * `visiblePar` me contient), sur 30 jours, date décroissante, `n` au plus.
 * Un inconnu qui glisse mon uid dans `visiblePar` n'y entre pas, et ne
 * chasse pas mes amis du fil. `amis` : la liste lue par l'appli, sinon relue.
 */
export async function filDeLAppli(db, moi, { n = 100, amis } = {}) {
  const depuis = Timestamp.fromMillis(Date.now() - 30 * 86400e3);
  const liste = amis ?? (await getDocs(collection(db, 'amis', moi, 'liste'))).docs.map((d) => d.id);
  const pubs = collection(db, 'publications');
  const requetes = [query(pubs, where('auteur', '==', moi), where('date', '>', depuis), orderBy('date', 'desc'), limit(n))];
  for (let i = 0; i < liste.length; i += 30) {
    requetes.push(query(pubs, where('auteur', 'in', liste.slice(i, i + 30)), where('visiblePar', 'array-contains', moi),
      where('date', '>', depuis), orderBy('date', 'desc'), limit(n)));
  }
  const docs = (await Promise.all(requetes.map((r) => getDocs(r)))).flatMap((s) => s.docs)
    .sort((a, b) => b.data().date.toMillis() - a.data().date.toMillis()).slice(0, n);
  return { docs, size: docs.length };
}

/** Efface la base et écrit le monde, règles coupées. */
export async function peupler() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const lot = writeBatch(db);
    const t = Timestamp.now();
    const amis = (u) => AMITIES.filter((p) => p.includes(u)).length;
    for (const [uid, acces] of Object.entries(ACCES)) {
      lot.set(doc(db, 'pseudos', uid), { uid });
      lot.set(doc(db, 'profils', uid), { ...carte(uid, { acces }), majLe: t });
      lot.set(doc(db, 'profils', uid, 'details', 'public'), {
        phrase: `La phrase de ${uid}`, seances: 120, heures: 140.5, montre: ['seances', 'records'],
        jours: [1, 3, 5], nbAmis: amis(uid), majLe: t,
      });
    }
    for (const [a, b] of AMITIES) {
      lot.set(doc(db, 'amis', a, 'liste', b), { depuis: t });
      lot.set(doc(db, 'amis', b, 'liste', a), { depuis: t });
    }
    for (const [a, b] of BLOCAGES) lot.set(doc(db, 'blocages', a, 'liste', b), { date: t });
    lot.set(doc(db, 'demandes', 'jules_alice'), { de: 'jules', vers: 'alice', date: t });
    lot.set(doc(db, 'publications', 'pub-alice'), { ...publication('alice', ['alice', 'david', 'emma', 'farid']), majLe: t });
    lot.set(doc(db, 'publications', 'pub-bruno'), { ...publication('bruno', ['bruno', 'lea']), majLe: t });
    lot.set(doc(db, 'publications', 'pub-alice', 'reactions', 'david'), { type: 'feu', date: t });
    lot.set(doc(db, 'publications', 'pub-alice', 'commentaires', 'c1'), { auteur: 'david', texte: 'Costaud', date: t });
    lot.set(doc(db, 'publications', 'pub-alice', 'commentaires', 'c2'), { auteur: 'emma', texte: 'Bravo', date: t });
    lot.set(doc(db, 'copies', 'alice'), { date: new Date().toISOString(), seances: 120, routines: 4, morceaux: 1, octets: 52000 });
    lot.set(doc(db, 'copies', 'alice', 'morceaux', '0'), { texte: 'AE1:abcd' });
    await lot.commit();
  });
}

export { doc, collection, setDoc };
