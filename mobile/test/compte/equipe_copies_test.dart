// Le testeur de la copie serveur : ce que CompteRepo fait du choix entre le
// téléphone et le serveur quand l'appli est relancée ou que le réseau lâche
// pendant la connexion. Le compte Firebase, lui, survit à la relance : au
// lancement suivant, `connexion.actuel` rend déjà la personne.
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/compte/logic/compte_repo.dart';
import 'package:aesthetic/features/compte/logic/copie_serveur.dart';
import 'package:aesthetic/features/compte/logic/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _tristan = Utilisateur(uid: 'u1', nom: 'Tristan');

class _FausseConnexion implements ServiceConnexion {
  _FausseConnexion([this.actuel]);

  @override
  Utilisateur? actuel;

  @override
  Future<Utilisateur?> connecterGoogle() async => actuel = _tristan;

  @override
  Future<void> deconnecter() async => actuel = null;
}

/// Un serveur en mémoire, qui peut tomber en panne.
class _FauxServeur implements ServiceCopies {
  final resumes = <String, ResumeCopie>{};
  final copies = <String, List<String>>{};
  bool enPanne = false;

  @override
  Future<ResumeCopie?> resume(String uid) async {
    if (enPanne) throw StateError('hors ligne');
    return resumes[uid];
  }

  @override
  Future<void> envoyer(String uid, ResumeCopie resume, List<String> morceaux) async {
    if (enPanne) throw StateError('hors ligne');
    resumes[uid] = resume;
    copies[uid] = morceaux;
  }

  @override
  Future<List<String>> lire(String uid, ResumeCopie resume) async {
    if (enPanne) throw StateError('hors ligne');
    return copies[uid] ?? const [];
  }
}

WorkoutSession _seance(String id, DateTime debut) => WorkoutSession(
      id: id,
      nom: 'Push',
      debut: debut,
      fin: debut.add(const Duration(hours: 1)),
      exercices: const [
        SessionExercise(id: 'e', exerciseId: 'developpe-couche', series: [WorkoutSet(id: 'w', poids: 80, reps: 8, fait: true)]),
      ],
    );

Future<AppData> _telephone({int seances = 0, Store? store}) async {
  final d = AppData(store ?? Store.memory());
  await d.sessions.load();
  for (var i = 0; i < seances; i++) {
    await d.sessions.save(_seance('s$i', DateTime(2026, 9, 1 + i, 18)));
  }
  return d;
}

/// Un compte qui a déjà 50 séances sur le serveur, envoyées d'un autre téléphone.
Future<_FauxServeur> _serveurPlein() async {
  final serveur = _FauxServeur();
  final autre = CompteRepo(await _telephone(seances: 50), connexion: _FausseConnexion(), copies: serveur);
  await autre.charger();
  await autre.connecter();
  expect(serveur.resumes['u1']!.seances, 50);
  return serveur;
}

const _delai = Duration(milliseconds: 20);
Future<void> _attendre() => Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  test('choix en attente, appli fermée puis rouverte : la copie du serveur n’est pas écrasée sans choix', () async {
    final serveur = await _serveurPlein();
    // Ce téléphone a 2 séances : la connexion demande de choisir.
    final store = Store.memory();
    final premier = CompteRepo(await _telephone(seances: 2, store: store), connexion: _FausseConnexion(), copies: serveur, delai: _delai);
    await premier.charger();
    await premier.connecter();
    expect(premier.choix, isNotNull);

    // La personne ferme l'appli sans choisir. Au lancement suivant, Firebase
    // rend le même compte, et app.dart appelle noterChangement().
    final data = AppData(store);
    await data.sessions.load();
    final relance = CompteRepo(data, connexion: _FausseConnexion(_tristan), copies: serveur, delai: _delai);
    await relance.charger();
    relance.noterChangement();
    await _attendre();

    expect(serveur.resumes['u1']!.seances, 50, reason: 'les 50 séances du serveur ont été remplacées par les 2 du téléphone, sans que personne ait choisi');
  });

  test('le réseau lâche pendant la connexion : le compte ne reste pas branché sans avoir comparé les copies', () async {
    final serveur = await _serveurPlein();
    final data = await _telephone(seances: 2);
    final repo = CompteRepo(data, connexion: _FausseConnexion(), copies: serveur, delai: _delai);
    await repo.charger();
    serveur.enPanne = true;
    final ok = await repo.connecter();
    expect(ok, isFalse);

    // Le réseau revient, la personne note une séance : l'envoi part.
    serveur.enPanne = false;
    await data.sessions.save(_seance('s9', DateTime(2026, 10, 1, 18)));
    await _attendre();

    expect(serveur.resumes['u1']!.seances, 50,
        reason: 'connecter() a rendu false mais le compte est resté connecté (connecte = ${repo.connecte}) '
            'et le téléphone a écrasé la copie du serveur sans proposer le choix');
  });

  test('téléphone neuf, réseau coupé pendant la connexion puis relance : la copie vide n’écrase pas le serveur', () async {
    final serveur = await _serveurPlein();
    final store = Store.memory();
    final neuf = CompteRepo(await _telephone(store: store), connexion: _FausseConnexion(), copies: serveur, delai: _delai);
    await neuf.charger();
    serveur.enPanne = true;
    await neuf.connecter();
    serveur.enPanne = false;

    final data = AppData(store);
    await data.sessions.load();
    final relance = CompteRepo(data, connexion: _FausseConnexion(_tristan), copies: serveur, delai: _delai);
    await relance.charger();
    relance.noterChangement();
    await _attendre();

    expect(serveur.resumes['u1']!.seances, 50, reason: 'un téléphone vide a remplacé 50 séances par 0');
  });
}
