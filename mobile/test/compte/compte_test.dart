import 'dart:convert';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/compte/logic/compte_repo.dart';
import 'package:aesthetic/features/compte/logic/copie_serveur.dart';
import 'package:aesthetic/features/compte/logic/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FausseConnexion implements ServiceConnexion {
  @override
  Utilisateur? actuel;

  @override
  Future<Utilisateur?> connecterGoogle() async => actuel = const Utilisateur(uid: 'u1', nom: 'Tristan');

  @override
  Future<void> deconnecter() async => actuel = null;
}

/// Un serveur en mémoire, qui peut tomber en panne.
class _FauxServeur implements ServiceCopies {
  final resumes = <String, ResumeCopie>{};
  final copies = <String, List<String>>{};
  bool enPanne = false;
  int envois = 0;

  @override
  Future<ResumeCopie?> resume(String uid) async {
    if (enPanne) throw StateError('hors ligne');
    return resumes[uid];
  }

  @override
  Future<void> envoyer(String uid, ResumeCopie resume, List<String> morceaux) async {
    if (enPanne) throw StateError('hors ligne');
    envois++;
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

Future<AppData> _telephone({int seances = 0}) async {
  final d = AppData(Store.memory());
  await d.sessions.load();
  for (var i = 0; i < seances; i++) {
    await d.sessions.save(_seance('s$i', DateTime(2026, 9, 1 + i, 18)));
  }
  return d;
}

void main() {
  group('la copie', () {
    test('découpée puis recollée, elle revient à l’identique, accents compris', () {
      final json = jsonEncode({
        'application': 'aesthetic',
        'date': '2026-10-06T20:00:00.000',
        'donnees': {
          'profil': {'prenom': 'Zoé'},
          'seances': [for (var i = 0; i < 400; i++) {'id': 's$i', 'nom': 'Séance n° $i, épaules'}],
          'routines': [1, 2, 3],
        },
      });
      final morceaux = CopieServeur.decouper(json, taille: 500);
      expect(morceaux.length, greaterThan(1));
      expect(morceaux.every((m) => m.length <= 500), isTrue);
      expect(CopieServeur.recoller(morceaux), json);
      final r = CopieServeur.resumer(json, morceaux: morceaux.length);
      expect((r.seances, r.routines, r.prenom, r.morceaux), (400, 3, 'Zoé', morceaux.length));
      expect(ResumeCopie.fromJson(r.toJson())!.seances, 400);
    });

    test('un morceau manquant ou abîmé se dit, sans rien inventer', () {
      final morceaux = CopieServeur.decouper(jsonEncode({'donnees': {'seances': List.filled(300, 'x' * 40)}}), taille: 200);
      expect(() => CopieServeur.recoller(morceaux.sublist(1)), throwsFormatException);
      expect(() => CopieServeur.recoller(['pas du base64 !']), throwsFormatException);
    });
  });

  group('le compte', () {
    test('sans serveur dans la construction, rien ne se passe', () async {
      final repo = CompteRepo(await _telephone(seances: 1));
      await repo.charger();
      expect(repo.disponible, isFalse);
      expect(await repo.connecter(), isFalse);
      repo.noterChangement();
      expect(repo.etat, EtatCopie.aucune);
    });

    test('première connexion, rien sur le serveur : le téléphone y est envoyé', () async {
      final serveur = _FauxServeur();
      final repo = CompteRepo(await _telephone(seances: 3), connexion: _FausseConnexion(), copies: serveur);
      await repo.charger();
      expect(await repo.connecter(), isTrue);
      expect(repo.etat, EtatCopie.aJour);
      expect(serveur.resumes['u1']!.seances, 3);
      expect(repo.choix, isNull);
    });

    test('téléphone neuf : la copie du compte est reprise', () async {
      final serveur = _FauxServeur();
      final ancien = CompteRepo(await _telephone(seances: 5), connexion: _FausseConnexion(), copies: serveur);
      await ancien.charger();
      await ancien.connecter();

      final neuf = await _telephone();
      final repo = CompteRepo(neuf, connexion: _FausseConnexion(), copies: serveur);
      await repo.charger();
      await repo.connecter();
      expect(neuf.sessions.sessions.length, 5);
      expect(repo.etat, EtatCopie.aJour);
      expect(serveur.envois, 1, reason: 'reprendre la copie ne la renvoie pas');
    });

    test('des données des deux côtés : rien n’est écrasé sans un choix', () async {
      final serveur = _FauxServeur();
      final autre = CompteRepo(await _telephone(seances: 5), connexion: _FausseConnexion(), copies: serveur);
      await autre.charger();
      await autre.connecter();

      final ici = await _telephone(seances: 2);
      final repo = CompteRepo(ici, connexion: _FausseConnexion(), copies: serveur);
      await repo.charger();
      await repo.connecter();
      expect(repo.choix, isNotNull);
      expect((repo.choix!.telephone.seances, repo.choix!.serveur.seances), (2, 5));
      expect(ici.sessions.sessions.length, 2, reason: 'le téléphone est intact');
      expect(serveur.resumes['u1']!.seances, 5, reason: 'le serveur aussi');

      await repo.reprendreServeur();
      expect(ici.sessions.sessions.length, 5);
      expect(repo.choix, isNull);
    });

    test('garder le téléphone remplace la copie du serveur', () async {
      final serveur = _FauxServeur();
      final autre = CompteRepo(await _telephone(seances: 5), connexion: _FausseConnexion(), copies: serveur);
      await autre.charger();
      await autre.connecter();
      final repo = CompteRepo(await _telephone(seances: 2), connexion: _FausseConnexion(), copies: serveur);
      await repo.charger();
      await repo.connecter();
      await repo.garderTelephone();
      expect(serveur.resumes['u1']!.seances, 2);
      expect(repo.etat, EtatCopie.aJour);
    });

    test('sans réseau, l’envoi attend et les données restent ; il repart au retour du réseau', () async {
      final serveur = _FauxServeur();
      final data = await _telephone(seances: 1);
      final repo = CompteRepo(data, connexion: _FausseConnexion(), copies: serveur, delai: const Duration(milliseconds: 20));
      await repo.charger();
      await repo.connecter();
      serveur.enPanne = true;
      await data.sessions.save(_seance('nouvelle', DateTime(2026, 10, 1, 18)));
      await repo.envoyer();
      expect(repo.etat, EtatCopie.enAttente);
      expect(repo.envoiEnAttente, isTrue);
      expect(data.sessions.sessions.length, 2);
      expect(serveur.resumes['u1']!.seances, 1);
      serveur.enPanne = false;
      await repo.envoyer();
      expect(repo.etat, EtatCopie.aJour);
      expect(serveur.resumes['u1']!.seances, 2);
    });

    test('un changement part tout seul après le délai, et plusieurs rapprochés ne font qu’un envoi', () async {
      final serveur = _FauxServeur();
      final data = await _telephone(seances: 1);
      final repo = CompteRepo(data, connexion: _FausseConnexion(), copies: serveur, delai: const Duration(milliseconds: 40));
      await repo.charger();
      await repo.connecter();
      final avant = serveur.envois;
      for (var i = 0; i < 3; i++) {
        await data.sessions.save(_seance('n$i', DateTime(2026, 10, 2 + i, 18)));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(serveur.envois, avant + 1);
      expect(serveur.resumes['u1']!.seances, 4);
      repo.dispose();
    });

    test('se déconnecter laisse les données sur le téléphone et la copie sur le serveur', () async {
      final serveur = _FauxServeur();
      final data = await _telephone(seances: 2);
      final repo = CompteRepo(data, connexion: _FausseConnexion(), copies: serveur);
      await repo.charger();
      await repo.connecter();
      await repo.deconnecter();
      expect(repo.connecte, isFalse);
      expect(data.sessions.sessions.length, 2);
      expect(serveur.resumes['u1']!.seances, 2);
    });
  });
}
