import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/compte/logic/compte_repo.dart';
import 'package:aesthetic/features/compte/logic/copie_serveur.dart';
import 'package:aesthetic/features/compte/logic/services.dart';
import 'package:aesthetic/features/profil/pages/reglages/compte_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../profil/test_profil_banc.dart' show cleBanc, ecran, photo, polices;

class _Connexion implements ServiceConnexion {
  @override
  Utilisateur? actuel;

  @override
  Future<Utilisateur?> connecterGoogle() async => actuel = const Utilisateur(uid: 'u1', nom: 'Tristan', email: 'tristan@exemple.fr');

  @override
  Future<void> deconnecter() async => actuel = null;
}

class _Serveur implements ServiceCopies {
  final resumes = <String, ResumeCopie>{};
  final copies = <String, List<String>>{};

  @override
  Future<ResumeCopie?> resume(String uid) async => resumes[uid];

  @override
  Future<void> envoyer(String uid, ResumeCopie resume, List<String> morceaux) async {
    resumes[uid] = resume;
    copies[uid] = morceaux;
  }

  @override
  Future<List<String>> lire(String uid, ResumeCopie resume) async => copies[uid] ?? const [];
}

Widget _page(CompteRepo? repo) => ChangeNotifierProvider<CompteRepo?>.value(
      value: repo,
      child: MaterialApp(
        theme: AccentController().theme,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: RepaintBoundary(key: cleBanc, child: const Scaffold(body: SafeArea(child: SingleChildScrollView(child: CompteSection())))),
      ),
    );

Future<AppData> _donnees({int seances = 0}) async {
  final d = AppData(Store.memory());
  await d.sessions.load();
  for (var i = 0; i < seances; i++) {
    final debut = DateTime(2026, 9, 1 + i, 18);
    await d.sessions.save(WorkoutSession(id: 's$i', nom: 'Push', debut: debut, fin: debut.add(const Duration(hours: 1)), exercices: const []));
  }
  return d;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('sans serveur, la section le dit et ne propose rien', (t) async {
    await t.pumpWidget(_page(null));
    expect(find.textContaining('pas disponible'), findsOneWidget);
    expect(find.text('Se connecter avec Google'), findsNothing);
  });

  testWidgets('se connecter, voir la copie à jour, se déconnecter', (t) async {
    final serveur = _Serveur();
    final repo = (await t.runAsync(() async {
      final r = CompteRepo(await _donnees(seances: 2), connexion: _Connexion(), copies: serveur, delai: const Duration(hours: 1));
      await r.charger();
      return r;
    }))!;
    addTearDown(repo.dispose);
    await polices(t);
    ecran(t);
    await t.pumpWidget(_page(repo));
    expect(CompteSection.valeur(repo), 'Non connecté');

    await t.tap(find.text('Se connecter avec Google'));
    // L'export des données et l'envoi se font en vraie asynchronie.
    for (var i = 0; i < 50 && repo.etat != EtatCopie.aJour; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await t.pumpAndSettle();
    expect(find.text('Tristan'), findsOneWidget);
    expect(find.text('tristan@exemple.fr'), findsOneWidget);
    expect(find.text('À jour'), findsOneWidget);
    expect(serveur.resumes['u1']!.seances, 2);
    await t.runAsync(() => photo(t, 'compte-connecte'));

    await t.tap(find.text('Se déconnecter'));
    await t.pumpAndSettle();
    // La confirmation : deux « Se déconnecter », le titre de la ligne et le bouton.
    await t.tap(find.text('Se déconnecter').last);
    for (var i = 0; i < 50 && repo.connecte; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await t.pumpAndSettle();
    expect(find.text('Se connecter avec Google'), findsOneWidget);
    expect(serveur.resumes['u1'], isNotNull, reason: 'la copie reste sur le serveur');
  });

  testWidgets('deux copies différentes : le choix est proposé, rien n\'est envoyé avant', (t) async {
    final serveur = _Serveur()..resumes['u1'] = ResumeCopie(date: DateTime(2026, 10, 1), seances: 9, routines: 1, morceaux: 1, octets: 10);
    final repo = (await t.runAsync(() async {
      final r = CompteRepo(await _donnees(seances: 1), connexion: _Connexion(), copies: serveur, delai: const Duration(hours: 1));
      await r.charger();
      await r.connecter();
      return r;
    }))!;
    addTearDown(repo.dispose);
    await t.pumpWidget(_page(repo));
    expect(CompteSection.valeur(repo), 'Choix à faire');
    expect(find.text('Garder ce téléphone'), findsOneWidget);
    expect(find.text('Reprendre la copie du serveur'), findsOneWidget);
    expect(find.text('Envoyer maintenant'), findsNothing);
    expect(serveur.resumes['u1']!.seances, 9);
  });
}
