// L'équipe de test : le fil et la visibilité des publications.
//
// La requête du fil telle que l'appli l'écrit (SourceFirestore._ecouter),
// son ordre et sa pagination, puis ceux qui ne doivent rien lire : inconnu,
// ex-ami, personne bloquée, profil privé. Et ceux qui ne doivent rien
// écrire : publier au nom d'un autre, glisser des inconnus dans
// `visiblePar`, prendre l'identifiant d'une séance d'un autre.
//
// Les tests du bloc « trous » décrivent des trous trouvés puis bouchés
// (règles et appli) : ils gardent qu'ils ne se rouvrent pas.
import {
  getDoc, getDocs, updateDoc, deleteDoc, addDoc, query, where, orderBy, limit, startAfter,
  serverTimestamp, Timestamp, writeBatch, arrayRemove,
} from 'firebase/firestore';
import {
  demarrer, arreter, peupler, base, anonyme, permis, refuse, publication, doc, collection, setDoc, filDeLAppli,
} from './monde.js';

const JOUR = 86400e3;
const FIL_ALICE = ['alice', 'david', 'emma', 'farid'];
const il_y_a = (jours) => Timestamp.fromMillis(Date.now() - jours * JOUR);

let env;

/** Écrit des documents règles coupées : `[chemin, données]`. */
async function ecrireSansRegles(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const lot = writeBatch(db);
    for (const [chemin, d] of docs) lot.set(doc(db, chemin), d);
    await lot.commit();
  });
}

async function effacerSansRegles(chemins) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const lot = writeBatch(db);
    for (const c of chemins) lot.delete(doc(db, c));
    await lot.commit();
  });
}

/** Une publication déjà en base (majLe figée, les règles coupées l'écrivent). */
const enBase = (auteur, visiblePar, autres = {}) => ({ ...publication(auteur, visiblePar, autres), majLe: Timestamp.now() });

/** Le fil exactement comme l'appli : mes séances et celles de mes amis, 30 jours, date décroissante, 100 au plus. */
const filAppli = (qui, pour = qui, n = 100) => filDeLAppli(base(qui), pour, { n });

/** Le fil sans borne de date : ce qu'un téléphone modifié peut demander. */
const filComplet = (qui) =>
  query(collection(base(qui), 'publications'), where('visiblePar', 'array-contains', qui), orderBy('date', 'desc'));

const ids = (s) => s.docs.map((d) => d.id);

describe('équipe : le fil', () => {
  before(async () => {
    env = await demarrer();
  });
  after(arreter);
  beforeEach(async () => {
    await peupler();
    // Cinq séances d'alice étalées sur dix jours, une de 45 jours, une de david.
    await ecrireSansRegles([
      ...[1, 2, 4, 7, 10].map((j) => [`publications/alice_s${j}`, enBase('alice', FIL_ALICE, { seanceId: `s${j}`, date: il_y_a(j) })]),
      ['publications/alice_vieille', enBase('alice', FIL_ALICE, { seanceId: 'vieille', date: il_y_a(45) })],
      ['publications/david_s1', enBase('david', ['david', 'alice'], { seanceId: 's1', date: il_y_a(3) })],
    ]);
  });

  describe('la requête de l’appli', () => {
    it('le fil d’un ami, tel que l’appli le demande, est permis', async () => {
      const s = await permis((filAppli('david')));
      // pub-alice (1 h), alice_s1..s10, david_s1 ; pas la vieille.
      const attendus = ['pub-alice', 'alice_s1', 'alice_s2', 'david_s1', 'alice_s4', 'alice_s7', 'alice_s10'];
      if (ids(s).join() !== attendus.join()) throw new Error(`fil de david : ${ids(s).join()}`);
    });
    it('l’ordre est par date décroissante', async () => {
      const s = await (filAppli('alice'));
      const dates = s.docs.map((d) => d.data().date.toMillis());
      for (let i = 1; i < dates.length; i++) {
        if (dates[i] > dates[i - 1]) throw new Error(`désordre à ${i} : ${ids(s).join()}`);
      }
    });
    it('la pagination par startAfter est permise et ne perd ni ne répète rien', async () => {
      const premiere = await permis((filAppli('emma', 'emma', 3)));
      const suite = await permis(getDocs(query(
        collection(base('emma'), 'publications'),
        where('visiblePar', 'array-contains', 'emma'),
        where('date', '>', Timestamp.fromMillis(Date.now() - 30 * JOUR)),
        orderBy('date', 'desc'),
        startAfter(premiere.docs.at(-1)),
        limit(3),
      )));
      const vus = [...ids(premiere), ...ids(suite)];
      const attendus = ['pub-alice', 'alice_s1', 'alice_s2', 'alice_s4', 'alice_s7', 'alice_s10'];
      if (vus.join() !== attendus.join()) throw new Error(`pages : ${vus.join()}`);
    });
    it('la limite de l’appli tient (limit 2)', async () => {
      const s = await (filAppli('david', 'david', 2));
      if (s.size !== 2) throw new Error(`${s.size} publications`);
    });
    it('un inconnu a un fil vide, permis', async () => {
      const s = await permis((filAppli('gael')));
      if (s.size !== 0) throw new Error(`gael voit ${ids(s).join()}`);
    });
    it('le fil d’un autre, refusé', () => refuse((filAppli('gael', 'alice'))));
    it('le fil sans connexion, refusé', () =>
      refuse(getDocs(query(collection(anonyme(), 'publications'), where('visiblePar', 'array-contains', 'alice')))));
    it('les publications d’un auteur sans filtre visiblePar, refusé', () =>
      refuse(getDocs(query(collection(base('gael'), 'publications'), where('auteur', '==', 'alice'), orderBy('date', 'desc')))));
    it('les publications d’un auteur pour un ami (avec visiblePar), permis', async () => {
      const s = await permis(getDocs(query(
        collection(base('david'), 'publications'),
        where('visiblePar', 'array-contains', 'david'),
        where('auteur', '==', 'alice'),
        orderBy('date', 'desc'),
      )));
      if (s.size !== 7) throw new Error(`${s.size} publications d’alice`);
    });
    it('une requête par date seule, refusée', () =>
      refuse(getDocs(query(collection(base('david'), 'publications'), orderBy('date', 'desc'), limit(5)))));
  });

  describe('qui lit', () => {
    it('un inconnu ne lit pas une publication par son identifiant', () =>
      refuse(getDoc(doc(base('manon'), 'publications/alice_s1'))));
    it('un compte sans profil ne lit rien', () => refuse(getDoc(doc(base('karim'), 'publications/alice_s1'))));
    it('lire une publication qui n’existe pas, refusé (on ne sonde pas les identifiants)', () =>
      refuse(getDoc(doc(base('gael'), 'publications/alice_inexistante'))));
    it('un inconnu ne lit ni réactions ni commentaires', async () => {
      await refuse(getDocs(collection(base('gael'), 'publications/pub-alice/reactions')));
      await refuse(getDocs(collection(base('gael'), 'publications/pub-alice/commentaires')));
    });
    it('un ex-ami retiré de visiblePar ne lit plus la publication', async () => {
      await permis(updateDoc(doc(base('alice'), 'publications/alice_s1'), { visiblePar: ['alice', 'emma', 'farid'], majLe: serverTimestamp() }));
      await refuse(getDoc(doc(base('david'), 'publications/alice_s1')));
      const s = await (filAppli('david'));
      if (ids(s).includes('alice_s1')) throw new Error('alice_s1 reste dans le fil de david');
    });
    it('un ex-ami retiré ne réagit ni ne commente plus', async () => {
      await permis(updateDoc(doc(base('alice'), 'publications/alice_s1'), { visiblePar: ['alice'], majLe: serverTimestamp() }));
      await refuse(setDoc(doc(base('david'), 'publications/alice_s1/reactions/david'), { type: 'feu', date: serverTimestamp() }));
      await refuse(addDoc(collection(base('david'), 'publications/alice_s1/commentaires'), { auteur: 'david', texte: 'Yo', date: serverTimestamp() }));
    });
    it('un profil passé privé (visiblePar réduit à lui) ne se lit plus', async () => {
      await permis(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'prive', majLe: serverTimestamp() }));
      await permis(updateDoc(doc(base('alice'), 'publications/alice_s1'), { visiblePar: ['alice'], majLe: serverTimestamp() }));
      await refuse(getDoc(doc(base('emma'), 'publications/alice_s1')));
    });
  });

  describe('qui écrit', () => {
    it('publier au nom d’un autre, refusé (même avec son uid dans visiblePar)', () =>
      refuse(setDoc(doc(base('gael'), 'publications/alice_x'), publication('alice', ['alice', 'gael']))));
    it('l’identifiant de l’appli ({uid}_{seanceId}) est permis', () =>
      permis(setDoc(doc(base('alice'), 'publications/alice_nouvelle'), publication('alice', FIL_ALICE, { seanceId: 'nouvelle' }))));
    it('un ami ne réécrit pas visiblePar pour s’y ajouter un inconnu', () =>
      refuse(updateDoc(doc(base('david'), 'publications/alice_s1'), { visiblePar: [...FIL_ALICE, 'gael'], majLe: serverTimestamp() })));
    it('un ami ne s’approprie pas la publication par un set complet', () =>
      refuse(setDoc(doc(base('david'), 'publications/alice_s1'), publication('david', ['david']))));
    it('un ami ne supprime pas la publication', () => refuse(deleteDoc(doc(base('david'), 'publications/alice_s1'))));
    it('visiblePar qui n’est pas une liste, refusé', () =>
      refuse(setDoc(doc(base('alice'), 'publications/alice_n'), publication('alice', 'alice'))));
    it('une date en texte, refusée', () =>
      refuse(setDoc(doc(base('alice'), 'publications/alice_n'), publication('alice', FIL_ALICE, { date: '2026-11-09' }))));
    it('repousser la date dans l’avenir par une modification, refusé', () =>
      refuse(updateDoc(doc(base('alice'), 'publications/alice_s1'), { date: Timestamp.fromMillis(Date.now() + 5 * JOUR), majLe: serverTimestamp() })));
  });

  // Ce qui devrait être refusé et ne l'est pas. Chaque test dit le trou.
  describe('trous', () => {
    it('TROU : un inconnu glisse ma personne dans visiblePar et entre dans mon fil', async () => {
      // gael n'est ami de personne. Il publie « pour » alice.
      const tentative = setDoc(doc(base('gael'), 'publications/gael_spam'), publication('gael', ['gael', 'alice'], { seanceId: 'spam', titre: 'Achetez mes protéines' }));
      let passe = true;
      try {
        await tentative;
      } catch {
        passe = false;
      }
      const s = await (filAppli('alice'));
      if (passe && ids(s).includes('gael_spam')) {
        throw new Error('gael (inconnu) a écrit dans le fil d’alice : la publication gael_spam y figure');
      }
    });
    it('TROU : une personne bloquée écrit encore dans le fil de celle qui l’a bloquée', async () => {
      // alice a bloqué hugo.
      let passe = true;
      try {
        await setDoc(doc(base('hugo'), 'publications/hugo_x'), publication('hugo', ['hugo', 'alice'], { seanceId: 'x' }));
      } catch {
        passe = false;
      }
      const s = await (filAppli('alice'));
      if (passe && ids(s).includes('hugo_x')) throw new Error('hugo, bloqué par alice, apparaît dans son fil');
    });
    it('TROU : un inconnu noie le fil (100 publications datées de demain) et en chasse les amis', async () => {
      const db = base('gael');
      const lot = writeBatch(db);
      for (let i = 0; i < 100; i++) {
        lot.set(doc(db, `publications/gael_flot${i}`),
          publication('gael', ['gael', 'david'], { seanceId: `flot${i}`, date: Timestamp.fromMillis(Date.now() + 20 * 3600e3) }));
      }
      let passe = true;
      try {
        await lot.commit();
      } catch {
        passe = false;
      }
      const s = await (filAppli('david'));
      const amis = ids(s).filter((id) => !id.startsWith('gael_'));
      if (passe && amis.length === 0) throw new Error(`les ${s.size} places du fil de david sont prises par gael, plus aucune séance d’alice`);
    });
    it('contrôle : hors de visiblePar, un inconnu ne commente pas', async () => {
      await refuse(addDoc(collection(base('gael'), 'publications/alice_s1/commentaires'), { auteur: 'gael', texte: 'Yo', date: serverTimestamp() }));
    });
    it('TROU : une vieille séance (plus de 30 jours) reste lisible par l’ex-ami', async () => {
      // alice et david ne sont plus amis. L'appli d'alice n'accorde que les
      // séances de son fil (30 jours, 100 au plus) : alice_vieille garde
      // david dans visiblePar.
      await effacerSansRegles(['amis/alice/liste/david', 'amis/david/liste/alice']);
      // L'appli d'alice voit david partir : elle cherche toutes ses séances
      // qui le portent encore, vieilles comprises, et l'en retire.
      const db = base('alice');
      const portent = await permis(getDocs(query(collection(db, 'publications'), where('auteur', '==', 'alice'),
        where('visiblePar', 'array-contains', 'david'))));
      for (const d of portent.docs) {
        await permis(updateDoc(d.ref, { visiblePar: arrayRemove('david'), majLe: serverTimestamp() }));
      }
      const s = await getDocs(filComplet('david'));
      const vues = ids(s).filter((id) => id.startsWith('alice'));
      if (vues.length) throw new Error(`david, plus ami d’alice, lit encore : ${vues.join()}`);
    });
    it('TROU : l’ex-ami bloqué commente encore une vieille séance', async () => {
      // alice bloque david (le lot de l'appli : blocage, amitiés, demandes).
      const db = base('alice');
      const lot = writeBatch(db);
      lot.set(doc(db, 'blocages/alice/liste/david'), { date: serverTimestamp() });
      lot.delete(doc(db, 'amis/alice/liste/david'));
      lot.delete(doc(db, 'amis/david/liste/alice'));
      lot.delete(doc(db, 'demandes/alice_david'));
      lot.delete(doc(db, 'demandes/david_alice'));
      await permis(lot.commit());
      let passe = true;
      try {
        await addDoc(collection(base('david'), 'publications/alice_vieille/commentaires'), { auteur: 'david', texte: 'Je suis toujours là', date: serverTimestamp() });
      } catch {
        passe = false;
      }
      if (passe) throw new Error('david, bloqué par alice, a commenté alice_vieille');
    });
    it('TROU : prendre l’identifiant {autre}_{seanceId} bloque la publication de l’autre', async () => {
      // L'appli d'alice publie sa séance sous `alice_<seanceId>` par un set.
      let passe = true;
      try {
        await setDoc(doc(base('gael'), 'publications/alice_prise'), publication('gael', ['gael'], { seanceId: 'prise' }));
      } catch {
        passe = false;
      }
      if (!passe) return;
      let alicePublie = true;
      try {
        await setDoc(doc(base('alice'), 'publications/alice_prise'), publication('alice', FIL_ALICE, { seanceId: 'prise' }));
      } catch {
        alicePublie = false;
      }
      throw new Error(`gael a créé publications/alice_prise ; alice ${alicePublie ? 'l’écrase' : 'ne peut plus publier sa séance'}`);
    });
    it('TROU : un profil privé ouvre encore ses séances à de nouveaux lecteurs', async () => {
      // CONCEPTION : un profil privé ne publie rien. La règle ne relit l'accès qu'à la création.
      await permis(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'prive', majLe: serverTimestamp() }));
      let passe = true;
      try {
        await updateDoc(doc(base('alice'), 'publications/alice_s1'), { visiblePar: [...FIL_ALICE, 'gael', 'manon'], majLe: serverTimestamp() });
      } catch {
        passe = false;
      }
      if (passe) throw new Error('alice, privée, a ajouté gael et manon à visiblePar');
    });
  });
});
