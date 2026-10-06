import 'dart:io';

import 'package:aesthetic/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_transverse_banc.dart';

/// Les écrans que le parcours de bout en bout ne traverse pas (éditeurs,
/// historique, réglages, analyses) : chacun est ouvert par son adresse, au
/// téléphone (360 et 412) et sur le Fold ouvert (840), et ne doit lever
/// aucune erreur (débordement, exception). Images dans
/// `build/rendus/transverse/secondaires/`.
///
/// [_connus] : débordements déjà signalés à leur module ; notés au rapport
/// (`build/rendus/transverse/secondaires/rapport-<largeur>.txt`) sans échouer.
const _connus = <String>[];

List<String> _adresses(Banc b) {
  final seance = b.data.sessions.sessions.first.id;
  final routine = b.data.routines.routines.first.id;
  final programme = b.data.programs.programs.first.id;
  return [
    '/seance',
    '/seance/vide',
    '/seance/historique',
    '/seance/historique/$seance',
    '/seance/historique/$seance/modifier',
    '/seance/resume/$seance',
    '/seance/partager/$seance',
    '/seance/equivalent/$seance',
    '/entrainer/routines/nouvelle',
    '/entrainer/routines/$routine/modifier',
    '/entrainer/routines/favoris',
    '/entrainer/programmes/idees',
    '/entrainer/programmes/nouveau',
    '/entrainer/programmes/$programme/modifier',
    '/entrainer/exercices',
    '/entrainer/exercices/nouveau',
    '/entrainer/exercices/developpe-couche/records',
    '/entrainer/muscles',
    '/progres/semaine',
    '/progres/mois',
    '/progres/records',
    '/progres/exercices',
    '/progres/exercices/developpe-couche',
    '/progres/seance/$seance',
    '/progres/muscles',
    '/progres/muscles/pectoraux',
    '/progres/comparer',
    '/progres/recuperation',
    '/profil/mensurations/historique',
    '/profil/mensurations/saisie',
    '/profil/photos/comparer',
    '/reglages',
    '/reglages/entrainement',
    '/reglages/entrainement/disques',
    '/reglages/unites',
    '/reglages/notifications',
    '/reglages/donnees',
    '/reglages/donnees/sauvegardes',
    '/reglages/donnees/effacer',
    '/reglages/a-propos',
    '/bienvenue/modifier',
    '/import',
  ];
}

Future<void> _jouer(WidgetTester t, Size taille, {bool seanceEnCours = false}) async {
  final b = await Banc.monter(t, taille: taille, corps: true);
  final problemes = <String>[];
  var lieu = 'montage';
  final ancienne = FlutterError.onError;
  FlutterError.onError = (d) {
    final ou = RegExp(r'([A-Za-z_]+):file:///\S*?/(lib/\S+?\.dart:\d+)').firstMatch(d.toString());
    final p = '[$lieu] ${d.exceptionAsString().split('\n').first}${ou == null ? '' : ' (${ou.group(1)} ${ou.group(2)})'}';
    if (!problemes.contains(p)) problemes.add(p);
  };
  addTearDown(() => FlutterError.onError = ancienne);

  final adresses = _adresses(b);
  if (seanceEnCours) {
    await t.runAsync(() => b.data.sessions.startFromRoutine(b.data.routines.routines.first));
    await b.pose();
    adresses
      ..clear()
      ..addAll(['/seance', '/seance/repos', '/seance/reordonner', '/seance/disques?poids=82.5', '/seance/terminer']);
  }
  final l = taille.width.round();
  for (final a in adresses) {
    lieu = a;
    await b.aller('/');
    await b.pousser(a);
    if (find.byType(PageIntrouvable).evaluate().isNotEmpty) problemes.add('[$a] adresse inconnue');
    final nom = a.substring(1).replaceAll(RegExp(r'[/?=.]'), '-').replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f-]{20,}|[a-z]+_\d{6,}\w*'), 'id');
    await b.capture('secondaires/$l${seanceEnCours ? '-seance' : ''}-$nom');
    // Fait défiler une fois : les débordements sous le premier écran.
    final listes = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    if (listes.evaluate().isNotEmpty) {
      await t.drag(listes.first, Offset(0, -taille.height * 0.7), warnIfMissed: false);
      await b.pose(1);
    }
  }
  lieu = 'fin';
  await b.fin();
  FlutterError.onError = ancienne;
  Object? e;
  while ((e = t.takeException()) != null) {
    problemes.add('[?] ${e.toString().split('\n').first}');
  }
  (File('build/rendus/transverse/secondaires/rapport-$l${seanceEnCours ? '-seance' : ''}.txt')..parent.createSync(recursive: true))
      .writeAsStringSync('${problemes.length} erreur(s)\n${problemes.join('\n')}\n');
  final nouveaux = problemes.where((p) => !_connus.any(p.contains)).toList();
  expect(nouveaux, isEmpty, reason: '\n${nouveaux.join('\n')}');
}

void main() {
  testWidgets('écrans secondaires en 412', (t) => _jouer(t, const Size(412, 915)));
  testWidgets('écrans secondaires en 360', (t) => _jouer(t, const Size(360, 780)));
  testWidgets('écrans secondaires sur le Fold ouvert, 840', (t) => _jouer(t, const Size(840, 900)));
  testWidgets('écrans d\'une séance en cours, 360 et 840', (t) async {
    await _jouer(t, const Size(360, 780), seanceEnCours: true);
  });
  testWidgets('écrans d\'une séance en cours sur le Fold ouvert, 840', (t) => _jouer(t, const Size(840, 900), seanceEnCours: true));
}
