// L'équipe de test, angle « attaquant » : écrire chez les autres, fausses
// dates, documents énormes, clés et chemins imprévus, énumération, copies
// d'un autre, suppressions, blocages contournés.
//
// Les tests marqués [trou] décrivent des trous trouvés puis bouchés (règles
// et appli) : ils gardent qu'ils ne se rouvrent pas.
import {
  getDoc, getDocs, updateDoc, deleteDoc, writeBatch, query, where, orderBy, limit,
  collectionGroup, serverTimestamp, Timestamp,
} from 'firebase/firestore';
import {
  demarrer, arreter, peupler, base, permis, refuse, carte, publication, doc, collection, setDoc, filDeLAppli,
} from './monde.js';

const passe = Timestamp.fromMillis(Date.now() - 86400e3);
const avenir = Timestamp.fromMillis(Date.now() + 3 * 86400e3);

/** Écrit règles coupées (pour poser un état ancien, ex. une vieille séance). */
async function poser(chemin, donnees) {
  const { env } = globalThis.__abus;
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), chemin), donnees));
}

/** Change la carte de `uid` vers `pseudo` et réserve celui-ci, sans rendre l'ancien. */
function changerSansRendre(uid, pseudo) {
  const db = base(uid);
  const lot = writeBatch(db);
  lot.set(doc(db, 'pseudos', pseudo), { uid });
  lot.set(doc(db, 'profils', uid), carte(pseudo));
  return lot.commit();
}

describe('équipe abus : écrire chez les autres', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('réécrire la carte d’un autre, même avec un pseudo réservé, refusé', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'alice2'), { uid: 'alice' });
    lot.set(doc(db, 'profils', 'alice'), carte('alice2'));
    await refuse(lot.commit());
  });
  it('réécrire les détails d’un autre, refusé', () =>
    refuse(setDoc(doc(base('gael'), 'profils/alice/details/public'), { phrase: 'piraté', majLe: serverTimestamp() })));
  it('supprimer la carte ou les détails d’un autre, refusé', async () => {
    await refuse(deleteDoc(doc(base('gael'), 'profils/alice')));
    await refuse(deleteDoc(doc(base('gael'), 'profils/alice/details/public')));
  });
  it('réserver un pseudo au nom d’un autre, refusé', () =>
    refuse(setDoc(doc(base('gael'), 'pseudos/libre'), { uid: 'alice' })));
  it('se débloquer soi-même chez celle qui nous a bloqués, refusé', () =>
    refuse(deleteDoc(doc(base('hugo'), 'blocages/alice/liste/hugo'))));
  it('écrire un blocage dans la liste d’un autre, refusé', () =>
    refuse(setDoc(doc(base('gael'), 'blocages/alice/liste/david'), { date: serverTimestamp() })));
  it('se faire ami d’office (les deux sens, sans demande), refusé', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/gael'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/gael/liste/alice'), { depuis: serverTimestamp() });
    await refuse(lot.commit());
  });
  it('accepter à la place du destinataire (l’envoyeur écrit les deux sens), refusé', async () => {
    const db = base('jules');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/jules'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/jules/liste/alice'), { depuis: serverTimestamp() });
    lot.delete(doc(db, 'demandes/jules_alice'));
    await refuse(lot.commit());
  });
  it('un tiers se sert de la demande d’un autre pour devenir ami, refusé', async () => {
    const db = base('gael');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/jules'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/jules/liste/alice'), { depuis: serverTimestamp() });
    await refuse(lot.commit());
  });
  it('défaire l’amitié de deux autres, refusé', () => refuse(deleteDoc(doc(base('gael'), 'amis/alice/liste/david'))));
  it('supprimer la demande de deux autres, refusé', () => refuse(deleteDoc(doc(base('gael'), 'demandes/jules_alice'))));
  it('modifier ou supprimer la publication d’un autre, refusé', async () => {
    await refuse(updateDoc(doc(base('david'), 'publications/pub-alice'), { titre: 'Nul' }));
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice'), publication('david', ['david', 'alice'])));
    await refuse(deleteDoc(doc(base('david'), 'publications/pub-alice')));
  });
  it('voler la publication d’un autre en se mettant auteur, refusé', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice'), { auteur: 'david', majLe: serverTimestamp() })));
  it('réagir ou commenter au nom d’un autre, refusé', async () => {
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/reactions/emma'), { type: 'coeur', date: serverTimestamp() }));
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/commentaires/x'),
      { auteur: 'emma', texte: 'faux', date: serverTimestamp() }));
  });
  it('supprimer la réaction ou le commentaire d’un autre (non auteur de la séance), refusé', async () => {
    await refuse(deleteDoc(doc(base('emma'), 'publications/pub-alice/reactions/david')));
    await refuse(deleteDoc(doc(base('emma'), 'publications/pub-alice/commentaires/c1')));
  });
  it('modifier un commentaire, même le sien, refusé', () =>
    refuse(updateDoc(doc(base('david'), 'publications/pub-alice/commentaires/c1'), { texte: 'modifié' })));
  it('écrire ou effacer la copie d’un autre, refusé', async () => {
    await refuse(setDoc(doc(base('david'), 'copies/alice/morceaux/0'), { texte: 'AE1:faux' }));
    await refuse(deleteDoc(doc(base('david'), 'copies/alice/morceaux/0')));
    await refuse(updateDoc(doc(base('david'), 'copies/alice'), { seances: 0 }));
  });
});

describe('équipe abus : fausses dates', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('carte datée par le téléphone, refusée', async () => {
    const db = base('alice');
    await refuse(updateDoc(doc(db, 'profils/alice'), { majLe: avenir }));
  });
  it('détails datés par le téléphone, refusés', () =>
    refuse(setDoc(doc(base('alice'), 'profils/alice/details/public'), { phrase: 'x', majLe: passe })));
  it('amitié antidatée, refusée', async () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/jules'), { depuis: Timestamp.fromMillis(0) });
    lot.set(doc(db, 'amis/jules/liste/alice'), { depuis: Timestamp.fromMillis(0) });
    lot.delete(doc(db, 'demandes/jules_alice'));
    await refuse(lot.commit());
  });
  it('blocage daté par le téléphone, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'blocages/alice/liste/gael'), { date: passe })));
  it('réaction et commentaire datés par le téléphone, refusés', async () => {
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/reactions/david'), { type: 'coeur', date: avenir }));
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/commentaires/x'), { auteur: 'david', texte: 'a', date: passe }));
  });
  it('date de séance au-delà d’un jour dans l’avenir, refusée (pour rester en tête du fil)', () =>
    refuse(setDoc(doc(base('alice'), 'publications/futur'), publication('alice', ['alice', 'david'], { date: avenir }))));
  it('date de séance qui n’est pas une date, refusée', () =>
    refuse(setDoc(doc(base('alice'), 'publications/futur'), publication('alice', ['alice'], { date: '2099-01-01' }))));
  it('majLe d’une publication fixée par le téléphone, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { majLe: avenir }))));
  it('majLe d’une copie fixée par le téléphone, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'copies/alice'),
      { date: 'x', seances: 1, routines: 1, morceaux: 1, octets: 1, majLe: passe })));
});

describe('équipe abus : documents énormes', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('photo de plus de 40 000 caractères, refusée', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { photo: 'A'.repeat(40001), majLe: serverTimestamp() })));
  it('commentaire de 501 caractères, refusé', () =>
    refuse(setDoc(doc(base('david'), 'publications/pub-alice/commentaires/long'),
      { auteur: 'david', texte: 'x'.repeat(501), date: serverTimestamp() })));
  it('titre de 81 et note de 281 caractères, refusés', async () => {
    await refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { titre: 't'.repeat(81) })));
    await refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { note: 'n'.repeat(281) })));
  });
  it('7 exercices, refusés', () =>
    refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { exercices: ['a', 'b', 'c', 'd', 'e', 'f', 'g'] }))));
  it('compteurs énormes ou négatifs, refusés', async () => {
    await refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { dureeSec: 86401 })));
    await refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { series: -1 })));
    await refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', ['alice'], { volumeKg: -5 })));
    await refuse(setDoc(doc(base('alice'), 'profils/alice/details/public'), { seances: -1, majLe: serverTimestamp() }));
  });
  it('[trou] un exercice de 150 000 caractères dans une publication, refusé', () =>
    // `exercices` ne borne que le nombre d'éléments, pas leur type ni leur
    // taille : six textes de 150 Ko font une séance de 900 Ko, téléchargée
    // par chaque ami qui ouvre son fil.
    refuse(setDoc(doc(base('alice'), 'publications/lourde'),
      publication('alice', ['alice', 'david'], { exercices: Array(6).fill('x'.repeat(150000)) }))));
  it('[trou] des records de 30 000 caractères chacun dans les détails, refusés', () =>
    // `records`, `jours`, `montre`, `fetiches`, `badges` : le nombre seul est
    // borné. Des détails de près d'1 Mo, lus par tous si l'accès est `tous`.
    refuse(setDoc(doc(base('alice'), 'profils/alice/details/public'),
      { records: Array(30).fill('r'.repeat(30000)), majLe: serverTimestamp() })));
  it('[trou] un morceau de copie numéroté 9999 quand le résumé en annonce 1, refusé', async () => {
    // Le résumé d'alice dit `morceaux: 1`. Rien ne relie le numéro au résumé :
    // un seul compte peut poser 10 000 morceaux de 900 Ko (9 Go), bien
    // au-delà du Go de l'offre gratuite pour tout le projet.
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/9999'), { texte: 'b'.repeat(900000) }));
  });
});

describe('équipe abus : clés inattendues', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('carte avec un drapeau admin, refusée', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { admin: true, majLe: serverTimestamp() })));
  it('détails avec une clé inconnue, refusés', () =>
    refuse(setDoc(doc(base('alice'), 'profils/alice/details/public'), { certifie: true, majLe: serverTimestamp() })));
  it('pseudo avec une clé en plus, refusé', async () => {
    const db = base('karim');
    const lot = writeBatch(db);
    lot.set(doc(db, 'pseudos', 'karim'), { uid: 'karim', role: 'admin' });
    lot.set(doc(db, 'profils', 'karim'), carte('karim'));
    await refuse(lot.commit());
  });
  it('amitié, blocage, réaction, commentaire, publication avec une clé en plus, refusés', async () => {
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/jules'), { depuis: serverTimestamp(), proche: true });
    lot.set(doc(db, 'amis/jules/liste/alice'), { depuis: serverTimestamp() });
    lot.delete(doc(db, 'demandes/jules_alice'));
    await refuse(lot.commit());
    await refuse(setDoc(doc(db, 'blocages/alice/liste/gael'), { date: serverTimestamp(), raison: 'x' }));
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/reactions/david'), { type: 'feu', date: serverTimestamp(), n: 99 }));
    await refuse(setDoc(doc(base('david'), 'publications/pub-alice/commentaires/x'),
      { auteur: 'david', texte: 'a', date: serverTimestamp(), epingle: true }));
    await refuse(setDoc(doc(db, 'publications/x'), publication('alice', ['alice'], { sponsorise: true })));
  });
  it('type de réaction inventé, refusé', () =>
    refuse(setDoc(doc(base('david'), 'publications/pub-alice/reactions/david'), { type: 'caca', date: serverTimestamp() })));
  it('accès inventé (« admin ») sur la carte, refusé', () =>
    refuse(updateDoc(doc(base('alice'), 'profils/alice'), { acces: 'admin', majLe: serverTimestamp() })));
  it('visiblePar qui n’est pas une liste, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'publications/x'), publication('alice', 'alice'))));
});

describe('équipe abus : chemins inattendus', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  const ecrits = [
    'amis/alice', 'blocages/alice', 'utilisateurs/alice', 'demandes/jules_alice/notes/x',
    'profils/alice/details/prive', 'profils/alice/details/public/x/y', 'publications/pub-alice/vues/alice',
    'publications/pub-alice/reactions/david/x/y', 'copies/alice/autres/x', 'copies/alice/morceaux/0/x/y',
    'pseudos/alice/x/y', 'amis/alice/liste/david/x/y', 'blocages/alice/liste/hugo/x/y',
  ];
  for (const c of ecrits) {
    it(`écrire ${c}, refusé`, () => refuse(setDoc(doc(base('alice'), c), { a: 1 })));
  }
  it('lire un document hors du contrat, refusé', async () => {
    await refuse(getDoc(doc(base('alice'), 'utilisateurs/alice')));
    await refuse(getDoc(doc(base('alice'), 'amis/alice')));
  });
  it('morceau au numéro de 5 chiffres ou négatif, refusé', async () => {
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/10000'), { texte: 'b' }));
    await refuse(setDoc(doc(base('alice'), 'copies/alice/morceaux/-1'), { texte: 'b' }));
  });
});

describe('équipe abus : énumérer', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('tous les détails d’un coup (requête de groupe), refusé', () =>
    refuse(getDocs(collectionGroup(base('gael'), 'details'))));
  it('toutes les amitiés, tous les blocages (requêtes de groupe), refusés', async () => {
    await refuse(getDocs(collectionGroup(base('gael'), 'liste')));
    await refuse(getDocs(query(collectionGroup(base('gael'), 'liste'), where('depuis', '>', Timestamp.fromMillis(0)))));
  });
  it('tous les commentaires, réactions et morceaux (requêtes de groupe), refusés', async () => {
    await refuse(getDocs(collectionGroup(base('gael'), 'commentaires')));
    await refuse(getDocs(collectionGroup(base('gael'), 'reactions')));
    await refuse(getDocs(collectionGroup(base('gael'), 'morceaux')));
  });
  it('la liste des copies, refusée', () => refuse(getDocs(collection(base('alice'), 'copies'))));
  it('toutes les demandes, refusées', () => refuse(getDocs(collection(base('gael'), 'demandes'))));
  it('les demandes reçues par un autre, même triées, refusées', () =>
    refuse(getDocs(query(collection(base('gael'), 'demandes'), where('vers', '==', 'alice'), orderBy('date', 'desc')))));
  it('les détails d’un profil « amis » par un inconnu, refusés', () =>
    refuse(getDocs(collection(base('gael'), 'profils/bruno/details'))));
  it('les détails d’un profil privé par un ami, refusés', () =>
    refuse(getDoc(doc(base('alice'), 'profils/farid/details/public'))));
  it('la liste d’amis d’un inconnu ou d’un ami privé, refusée', async () => {
    await refuse(getDocs(collection(base('gael'), 'amis/alice/liste')));
    await refuse(getDocs(collection(base('alice'), 'amis/farid/liste')));
  });
  it('les blocages d’un autre (savoir qui l’a bloqué), refusés', async () => {
    await refuse(getDocs(collection(base('hugo'), 'blocages/alice/liste')));
    await refuse(getDoc(doc(base('hugo'), 'blocages/alice/liste/hugo')));
  });
  it('les publications d’un auteur dont on n’est pas, refusées', () =>
    refuse(getDocs(query(collection(base('gael'), 'publications'), where('auteur', '==', 'alice'), orderBy('date', 'desc')))));
  it('la recherche limitée à 20 reste permise', () =>
    permis(getDocs(query(collection(base('gael'), 'profils'), where('pseudoMin', '>=', 'a'), where('pseudoMin', '<', 'b'), orderBy('pseudoMin'), limit(20)))));
  it('[trou] toutes les cartes d’un coup, privées comprises, refusé', () =>
    // La recherche de l'appli demande 20 cartes au plus ; les règles ne
    // bornent rien (`request.query.limit`), et n'importe quel compte vide la
    // collection : prénom, photo et uid de tous, profils privés compris.
    refuse(getDocs(collection(base('gael'), 'profils'))));
});

describe('équipe abus : blocages et amitiés contournés', () => {
  before(async () => { globalThis.__abus = { env: await demarrer() }; });
  after(arreter);
  beforeEach(peupler);

  it('la personne bloquée ne lit pas les détails, même en accès « tous »', () =>
    refuse(getDoc(doc(base('hugo'), 'profils/alice/details/public'))));
  it('la personne bloquée ne redemande pas, dans aucun sens', async () => {
    await refuse(setDoc(doc(base('hugo'), 'demandes/hugo_alice'), { de: 'hugo', vers: 'alice', date: serverTimestamp() }));
    await refuse(setDoc(doc(base('alice'), 'demandes/alice_ines'), { de: 'alice', vers: 'ines', date: serverTimestamp() }));
  });
  it('accepter une demande restée là après un blocage, refusé', async () => {
    // Une demande de hugo encore présente (lot de blocage raté) ne rouvre rien.
    await poser('demandes/hugo_alice', { de: 'hugo', vers: 'alice', date: Timestamp.now() });
    const db = base('alice');
    const lot = writeBatch(db);
    lot.set(doc(db, 'amis/alice/liste/hugo'), { depuis: serverTimestamp() });
    lot.set(doc(db, 'amis/hugo/liste/alice'), { depuis: serverTimestamp() });
    await refuse(lot.commit());
  });
  it('se bloquer soi-même, refusé', () =>
    refuse(setDoc(doc(base('alice'), 'blocages/alice/liste/alice'), { date: serverTimestamp() })));

  // Les règles ne peuvent pas relire 500 amitiés : l'écriture d'un inconnu
  // qui met alice dans `visiblePar` passe. Le fil de l'appli ne prend que
  // les séances de ses amis (`auteur in`), elle ne la voit donc jamais.
  it('un inconnu glisse sa séance dans visiblePar de quelqu’un : absente du fil de l’appli', async () => {
    await setDoc(doc(base('gael'), 'publications/gael_seance-1'), publication('gael', ['gael', 'alice'])).catch(() => {});
    const r = await filDeLAppli(base('alice'), 'alice');
    const vues = r.docs.filter((d) => d.data().auteur === 'gael').length;
    if (vues) throw new Error(`le fil d'alice montre ${vues} séance(s) de gael, un inconnu`);
  });
  it('la personne bloquée glisse sa séance dans visiblePar de celle qui l’a bloquée : absente du fil', async () => {
    await setDoc(doc(base('hugo'), 'publications/hugo_seance-1'), publication('hugo', ['hugo', 'alice'])).catch(() => {});
    const r = await filDeLAppli(base('alice'), 'alice');
    const vues = r.docs.filter((d) => d.data().auteur === 'hugo').length;
    if (vues) throw new Error(`le fil d'alice montre ${vues} séance(s) de hugo, qu'elle a bloqué`);
    // Et alice ne peut ni y réagir ni la commenter : le blocage coupe tout.
    await refuse(setDoc(doc(base('alice'), 'publications/hugo_seance-1/reactions/alice'), { type: 'feu', date: serverTimestamp() }));
  });
  it('[trou] la personne bloquée commente et réagit sur une vieille séance où elle figure encore', async () => {
    // Une séance d'alice de 60 jours, d'avant le blocage : l'appli ne
    // réécrit `visiblePar` que sur 30 jours, hugo y reste. Les règles ne
    // relisent pas le blocage.
    await poser('publications/vieille', {
      ...publication('alice', ['alice', 'hugo'], { date: Timestamp.fromMillis(Date.now() - 60 * 86400e3) }),
      majLe: Timestamp.now(),
    });
    await refuse(setDoc(doc(base('hugo'), 'publications/vieille/commentaires/insulte'),
      { auteur: 'hugo', texte: 'je suis toujours là', date: serverTimestamp() }));
    await refuse(setDoc(doc(base('hugo'), 'publications/vieille/reactions/hugo'), { type: 'feu', date: serverTimestamp() }));
  });
  it('[trou] garder la demande en acceptant, puis se réimposer en ami après avoir été retiré', async () => {
    // gael demande bruno. bruno accepte sans supprimer la demande : permis.
    await permis(setDoc(doc(base('gael'), 'demandes/gael_bruno'), { de: 'gael', vers: 'bruno', date: serverTimestamp() }));
    const accepter = () => {
      const db = base('bruno');
      const lot = writeBatch(db);
      lot.set(doc(db, 'amis/bruno/liste/gael'), { depuis: serverTimestamp() });
      lot.set(doc(db, 'amis/gael/liste/bruno'), { depuis: serverTimestamp() });
      return lot.commit();
    };
    // Refusé maintenant : le lot doit effacer la demande. On continue comme
    // si un ancien lot l'avait laissée passer (règles coupées).
    if (!(await accepter().then(() => true, () => false))) {
      await globalThis.__abus.env.withSecurityRulesDisabled(async (ctx) => {
        const d = ctx.firestore();
        await writeBatch(d).set(doc(d, 'amis/bruno/liste/gael'), { depuis: Timestamp.now() })
          .set(doc(d, 'amis/gael/liste/bruno'), { depuis: Timestamp.now() }).commit();
      });
    }
    // gael retire bruno comme le fait l'appli (les deux sens, pas la demande).
    const db = base('gael');
    const lot = writeBatch(db);
    lot.delete(doc(db, 'amis/gael/liste/bruno'));
    lot.delete(doc(db, 'amis/bruno/liste/gael'));
    await permis(lot.commit());
    // bruno se réinstalle seul dans les amis de gael : il ne devrait pas pouvoir.
    await refuse(accepter());
  });
  it('[trou] retirer un seul sens de l’amitié : on garde l’accès à l’autre sans lui laisser le sien', async () => {
    // lea efface seulement amis/lea/liste/bruno. bruno (accès « amis ») la
    // croit toujours amie : lea lit ses détails et ses amis, lui ne lit plus
    // rien d'elle, et ses séances continuent de partir chez elle.
    await refuse(deleteDoc(doc(base('lea'), 'amis/lea/liste/bruno')));
  });
  it('[trou] accumuler des pseudos en changeant de carte sans rendre l’ancien, refusé', async () => {
    // Les règles promettent qu'un compte ne réserve pas des dizaines de
    // pseudos. gael change de carte cinq fois sans rien rendre : les cinq
    // restent à lui, et personne d'autre ne peut les prendre.
    for (const p of ['coach', 'admin', 'support', 'aesthetics']) await changerSansRendre('gael', p).catch(() => {});
    const garde = [];
    for (const p of ['coach', 'admin', 'support']) {
      const s = await getDoc(doc(base('manon'), 'pseudos', p));
      if (s.exists() && s.data().uid === 'gael') garde.push(p);
    }
    if (garde.length) throw new Error(`gael garde ${garde.join(', ')} alors que sa carte porte « aesthetics »`);
  });
});
