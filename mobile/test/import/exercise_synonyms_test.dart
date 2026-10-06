import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/import/data/conversion.dart';
import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le catalogue complet n'est pas versionné : les tests qui en ont besoin
/// sont sautés quand il manque.
List<CatalogueEntry>? _catalogueReel() {
  final f = File('assets/data/exercises.json');
  if (!f.existsSync()) return null;
  return [
    for (final j in jsonDecode(f.readAsStringSync()) as List)
      CatalogueEntry.fromJson(Map<String, dynamic>.from(j as Map)),
  ];
}

/// Petit catalogue où un rowing, un écarté et un crunch partagent « seated »
/// et « machine » : le piège des mots communs.
final _mini = [
  for (final j in <Map<String, dynamic>>[
    {'id': 'pec-deck', 'nom': 'Pec deck', 'nomEn': 'Pec Deck', 'alias': ['Butterfly', 'lever seated fly'], 'equipement': 'machine'},
    {'id': 'crunch-machine', 'nom': 'Crunch machine', 'nomEn': 'Machine Seated Crunch', 'alias': ['lever seated crunch'], 'equipement': 'machine'},
    {'id': 'tirage-horizontal', 'nom': 'Tirage horizontal', 'nomEn': 'Seated Cable Row', 'alias': ['cable seated row'], 'equipement': 'poulie'},
    {'id': 'rameur', 'nom': 'Rameur', 'nomEn': 'Rowing Machine', 'alias': ['Row'], 'equipement': 'cardio'},
    {'id': 'assisted-dips', 'nom': 'Dips assistés à la machine', 'nomEn': 'Machine Assisted Dips', 'alias': [], 'equipement': 'machine'},
    {'id': 'crab-dips', 'nom': 'Dips crabe', 'nomEn': 'Crab Dips', 'alias': [], 'equipement': 'poids du corps'},
    {'id': 'curl-halteres', 'nom': 'Curl haltères', 'nomEn': 'Dumbbell Bicep Curl', 'alias': ['Dumbbell Curl'], 'equipement': 'halteres'},
    {'id': 'curl-suspension', 'nom': 'Curl biceps TRX', 'nomEn': 'TRX Bicep Curl', 'alias': [], 'equipement': 'poids du corps'},
    {'id': 'leg-curl-assis', 'nom': 'Leg curl assis', 'nomEn': 'Seated Leg Curl', 'alias': ['lever seated leg curl'], 'equipement': 'machine'},
    {'id': 'extension-nuque-haltere', 'nom': 'Extension nuque haltère', 'nomEn': 'Overhead Tricep Extension', 'alias': [], 'equipement': 'halteres'},
    {'id': 'leg-extension', 'nom': 'Leg extension', 'nomEn': 'Leg Extension', 'alias': ['lever leg extension'], 'equipement': 'machine'},
    {'id': 'developpe-incline', 'nom': 'Développé incliné', 'nomEn': 'Incline Barbell Bench Press', 'alias': ['Incline bench'], 'equipement': 'barre'},
    {'id': 'developpe-incline-pause', 'nom': 'Développé incliné avec pause', 'nomEn': 'Paused Incline Bench Press', 'alias': [], 'equipement': 'barre'},
    {'id': 'etirement-chat', 'nom': 'Étirement du chat', 'nomEn': 'Cat Stretch', 'alias': [], 'equipement': 'poids du corps'},
    {'id': 'mollets-assis', 'nom': 'Mollets assis machine', 'nomEn': 'Seated Calf Raise', 'alias': ['lever seated calf raise'], 'equipement': 'machine'},
    {'id': 'developpe-epaules-machine', 'nom': 'Développé épaules machine', 'nomEn': 'Machine Shoulder Press', 'alias': ['lever shoulder press'], 'equipement': 'machine'},
  ])
    CatalogueEntry.fromJson(j),
];

const _enTete = ' Title,Date,Duration,Exercise,"Superset id",Weight,Reps,Distance,Time,"Set Type"';

void main() {
  group('table de synonymes', () {
    final reel = _catalogueReel();
    final sansCatalogue = reel == null ? 'catalogue complet absent de ce poste' : null;

    test('chaque identifiant de la table existe dans le catalogue', skip: sansCatalogue, () {
      final ids = {for (final e in reel!) e.id};
      for (final s in synonymesExercices) {
        for (final id in s.ids) {
          expect(ids, contains(id), reason: '${s.noms.first} pointe vers « $id », absent du catalogue');
        }
      }
    });

    test('entrées bien formées : une issue par nom, pas de doublon, modèles valides', () {
      final vus = <String, String>{};
      for (final s in synonymesExercices) {
        expect(s.noms, isNotEmpty);
        expect(s.sur != null || s.proches.isNotEmpty || s.perso != null, isTrue, reason: s.noms.first);
        expect(s.sur == null || s.proches.isEmpty, isTrue, reason: '${s.noms.first} : sûr ou à confirmer, pas les deux');
        for (final n in s.noms) {
          final cle = (motsCanoniques(n)..sort()).join(' ');
          expect(cle, isNotEmpty, reason: n);
          expect(vus[cle], isNull, reason: '« $n » fait double emploi avec « ${vus[cle]} »');
          vus[cle] = n;
        }
        final p = s.perso;
        if (p == null) continue;
        expect(p.nom.trim(), isNotEmpty);
        expect(p.muscles, isNotEmpty, reason: p.nom);
        for (final m in p.muscles) {
          expect(Muscle.tryParse(m), isNotNull, reason: '${p.nom} : muscle « $m » inconnu');
        }
        if (p.equipement != null) {
          expect(Equipements.labels.keys, contains(p.equipement), reason: p.nom);
        }
      }
    });

    test('la table passe avant le calcul, sans tenir compte de l\'ordre des mots', skip: sansCatalogue, () {
      final m = ExerciseMatcher(reel!);
      final fly = m.rapprocher('Lever Seated Fly');
      expect(fly.statut, StatutRapprochement.automatique);
      expect(fly.exerciceId, 'pec-deck');
      expect(m.rapprocher('Seated Fly (Lever)').exerciceId, 'pec-deck');
      expect(m.rapprocher('Cable Wide-Grip Lat Pulldown').exerciceId, 'tirage-vertical');
      expect(m.rapprocher('Assisted Triceps Dip').exerciceId, 'assisted-dips');
      expect(m.rapprocher('Walking on Treadmill').exerciceId, 'walking');
    });

    test('sans équivalent : exercice personnel déjà rempli, jamais un voisin faux', skip: sansCatalogue, () {
      final m = ExerciseMatcher(reel!);
      for (final n in ['Lever Seated Row', 'Lever Seated Reverse Fly', 'Lever Seated Dip', 'High Pulley Overhead Tricep Extension']) {
        final r = m.rapprocher(n);
        expect(r.statut, StatutRapprochement.nouveau, reason: n);
        expect(r.choisi, isNull);
        expect(r.candidats, isEmpty);
        expect(r.modele, isNotNull);
      }
      final d = PersoDraft.depuisModele(m.rapprocher('Lever Seated Row').modele!, 'Lever Seated Row');
      expect(d.nom, 'Rowing assis à la machine');
      expect(d.equipement, 'machine');
      expect(d.muscles, {Muscle.grandDorsal, Muscle.rhomboides});
    });

    test('matériel non précisé : voisins à confirmer, jamais acceptés en lot', skip: sansCatalogue, () {
      final m = ExerciseMatcher(reel!);
      final r = m.rapprocher('Incline Bench Press');
      expect(r.statut, StatutRapprochement.ambigu);
      expect(r.candidats.first.entree.id, 'developpe-incline');
      expect(r.candidats.every((c) => c.deTable), isTrue);
      expect(r.suggestionSure, isFalse);
      expect(m.rapprocher('Biceps Curl').candidats.map((c) => c.entree.id), isNot(contains('trx-bicep-curl')));
    });

    test('un catalogue qui a l\'exercice garde la main sur « à créer »', () {
      final m = ExerciseMatcher([
        ..._mini,
        const CatalogueEntry(id: 'rowing-assis-machine', nom: 'Rowing assis à la machine', nomEn: 'Lever Seated Row', equipement: 'machine'),
      ]);
      final r = m.rapprocher('Lever Seated Row');
      expect(r.statut, StatutRapprochement.exact);
      expect(r.exerciceId, 'rowing-assis-machine');
    });

    test('un identifiant absent du catalogue ne casse rien', () {
      final m = ExerciseMatcher(_mini);
      // « Lever Chest Press » est sûr dans la table, mais ce catalogue ne l'a pas.
      final r = m.rapprocher('Lever Chest Press');
      expect(r.choisi, isNull);
      expect(r.aConfirmer, isTrue);
    });
  });

  group('ressemblance sans la table : mouvement et matériel d\'abord', () {
    final m = ExerciseMatcher(_mini, synonymes: const []);
    List<String> ids(String n) => [for (final c in m.rapprocher(n).candidats) c.entree.id];

    test('un rowing n\'est jamais proposé comme un pec deck', () {
      for (final n in [
        'Lever Seated Row',
        'Machine Seated Row',
        'Seated Row (Machine)',
        'Lever Narrow Grip Seated Row',
        'Seated Row',
        'Rowing assis à la machine',
      ]) {
        expect(ids(n), isNot(contains('pec-deck')), reason: n);
        expect(ids(n), isNot(contains('crunch-machine')), reason: n);
        expect(ids(n), isNot(contains('leg-curl-assis')), reason: n);
      }
      // Tout l'index : un écarté et un rowing ne se croisent dans aucun sens.
      expect(ids('Lever Seated Fly'), ['pec-deck']);
      expect(m.rechercher('seated').map((c) => c.entree.id), contains('pec-deck'));
    });

    test('ni un dip, ni un oiseau, ni un rameur', () {
      expect(ids('Lever Seated Dip'), isNot(contains('pec-deck')));
      expect(ids('Lever Seated Reverse Fly'), isNot(contains('pec-deck')));
      expect(ids('Lever Seated Row'), isNot(contains('rameur')));
      expect(ids('Assisted Triceps Dip').first, 'assisted-dips');
      expect(ids('Assisted Triceps Dip'), isNot(contains('crab-dips')));
    });

    test('familles de mouvement : leg curl, curl, extension, presse', () {
      expect(ids('Biceps Curl'), isNot(contains('leg-curl-assis')));
      expect(ids('Lever Seated Leg Curl'), ['leg-curl-assis']);
      expect(ids('Incline Triceps Extension'), isNot(contains('leg-extension')));
      expect(ids('Lever Seated Calf Press'), isNot(contains('developpe-epaules-machine')));
    });

    test('matériel différent : jamais accepté seul, jamais sûr', () {
      final r = m.rapprocher('High Pulley Overhead Tricep Extension');
      expect(r.choisi, isNull);
      expect(r.suggestionSure, isFalse);
      final curl = m.rapprocher('Alternate Biceps Curl');
      expect(curl.candidats.map((c) => c.entree.id), isNot(contains('curl-suspension')));
    });

    test('sous le seuil de confiance : rien n\'est proposé, le nom est à choisir', () {
      for (final n in ['Boat Stretch', 'Bicycle Recline Walk', 'Lying Scissors Cross (male)']) {
        final r = m.rapprocher(n);
        expect(r.statut, StatutRapprochement.inconnu, reason: n);
        expect(r.candidats, isEmpty, reason: n);
      }
      for (final c in m.rapprocher('Incline Bench Press').candidats) {
        expect(c.score, greaterThanOrEqualTo(ExerciseMatcher.seuilCandidat));
      }
    });
  });

  group('« Tout accepter »', () {
    String ligne(String exo) => '"Dos","2026-03-02 18:00:00",01:00:00,"$exo",,40.000,10,null,null,NORMAL_SET';
    ImportPreview apercu() => ImportAnalyzer.analyser(
          [
            _enTete,
            ligne('Cable Seated Row with V bar'),
            ligne('Incline Bench Press'),
            ligne('Lever Seated Fly'),
            ligne('Boat Stretch'),
          ].join('\n'),
          catalogue: _mini,
          matcher: ExerciseMatcher(_mini, synonymes: const []),
        );

    test('seules les suggestions sûres sont prises, les autres restent comptées', () {
      final p = apercu();
      final row = p.rapprochements[cleNom('Cable Seated Row with V bar')]!;
      final incline = p.rapprochements[cleNom('Incline Bench Press')]!;
      expect(row.statut, StatutRapprochement.ambigu);
      expect(row.meilleurScore, greaterThanOrEqualTo(ExerciseMatcher.seuilSur));
      expect(row.suggestionSure, isTrue);
      expect(incline.statut, StatutRapprochement.ambigu);
      expect(incline.suggestionSure, isFalse, reason: 'deux développés inclinés au coude à coude');
      expect(p.rapport.aConfirmer, hasLength(3));

      expect(p.accepterSuggestions(), 1);
      expect(p.rapprochements[cleNom('Cable Seated Row with V bar')]!.exerciceId, 'tirage-horizontal');
      expect(p.rapport.aConfirmer.map((r) => r.nomSource), unorderedEquals(['Incline Bench Press', 'Boat Stretch']));
      expect(p.rapport.pret, isFalse);
      // Un second appui ne prend rien de plus.
      expect(p.accepterSuggestions(), 0);
    });

    test('« toutes » prend aussi les incertaines, jamais un nom sans suggestion', () {
      final p = apercu();
      expect(p.accepterSuggestions(toutes: true), 2);
      expect(p.rapport.aConfirmer.single.nomSource, 'Boat Stretch');
    });

    test('un voisin proposé par la table n\'est jamais accepté en lot', () {
      final catalogue = [
        ..._mini,
        const CatalogueEntry(id: 'developpe-incline-halteres', nom: 'Développé incliné haltères', nomEn: 'Incline Dumbbell Press', equipement: 'halteres'),
      ];
      final p = ImportAnalyzer.analyser([_enTete, ligne('Incline Bench Press')].join('\n'), catalogue: catalogue);
      final r = p.rapport.aConfirmer.single;
      expect(r.candidats.map((c) => c.entree.id), ['developpe-incline', 'developpe-incline-halteres']);
      expect(p.accepterSuggestions(), 0);
      expect(p.rapport.aConfirmer, hasLength(1));
    });
  });

  group('séries gardées ou écartées', () {
    String ligne(String titre, String date, String duree, String exo, String poids, String reps, String dist, String temps,
            {String superset = ''}) =>
        '"$titre","$date",$duree,"$exo",$superset,$poids,$reps,$dist,$temps,NORMAL_SET';

    final texte = [
      _enTete,
      // poids du corps, répétitions seules, durée seule, distance et durée
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Crunch', '0.000', '20', 'null', 'null'),
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Jumping Jack', '', '30', '', '1:00'),
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Front Plank', '', '', '', '0:45'),
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Walking', '', '', '2.74', '35:00'),
      // série prévue jamais remplie
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Crunch', 'null', 'null', 'null', 'null'),
      ligne('Abdos', '2026-03-02 18:00:00', '00:40:00', 'Crunch', '0.000', '0', 'null', 'null'),
      // séance dont rien n'a été noté
      ligne('Pousser', '2026-03-03 18:00:00', '01:10:00', 'Bench Press', 'null', 'null', 'null', 'null'),
      ligne('Pousser', '2026-03-03 18:00:00', '01:10:00', 'Lateral Raise', 'null', 'null', 'null', 'null'),
      // marche longue : minutes au-delà de 59
      ligne('Marche', '2026-03-04 21:30:00', '01:26:00', 'Walking', '', '', '5.74', '86:00'),
      // chronomètre oublié
      ligne('Dos', '2026-03-05 18:00:00', '15:06:09', 'Pulldown', '50.000', '10', 'null', 'null'),
      // chronomètre arrêté tout de suite, séries saisies après coup
      ligne('Bras', '2026-03-06 18:00:00', '00:00:49', 'Biceps Curl', '12.000', '10', 'null', 'null', superset: '1'),
      ligne('Bras', '2026-03-06 18:00:00', '00:00:49', 'Biceps Curl', '12.000', '10', 'null', 'null', superset: '1'),
      ligne('Bras', '2026-03-06 18:00:00', '00:00:49', 'Biceps Curl', '12.000', '8', 'null', 'null', superset: '1'),
    ].join('\n');
    final p = ImportAnalyzer.analyser(texte, catalogue: _mini);
    ImportedSession seance(String titre) => p.seances.firstWhere((s) => s.titre == titre);
    ImportedSet serie(String titre, String exo, [int i = 0]) =>
        seance(titre).exercices.firstWhere((e) => e.nomSource == exo).series[i];

    test('poids du corps, répétitions seules, durée seule, distance : gardées', () {
      expect(serie('Abdos', 'Crunch').reps, 20);
      expect(serie('Abdos', 'Crunch').poidsKg, 0);
      expect(serie('Abdos', 'Jumping Jack').reps, 30);
      expect(serie('Abdos', 'Jumping Jack').dureeSec, 60);
      expect(serie('Abdos', 'Front Plank').dureeSec, 45);
      expect(serie('Abdos', 'Front Plank').reps, isNull);
      expect(serie('Abdos', 'Walking').distanceM, closeTo(2740, 0.001));
      expect(serie('Abdos', 'Walking').dureeSec, 35 * 60);
      expect(serie('Marche', 'Walking').dureeSec, 86 * 60);
      expect(seance('Abdos').nombreSeries, 4);
    });

    test('séries sans aucune valeur : écartées, avec le nombre de séances perdues', () {
      expect(p.seances.map((s) => s.titre), isNot(contains('Pousser')));
      final m = p.rapport.messages.firstWhere((m) => m.texte.contains('ignorées'));
      expect(m.texte, '4 séries sans charge, répétitions, durée ni distance ont été ignorées, dont une séance entière.');
      expect(m.gravite, Gravite.info);
    });

    test('option : garder les séries vides garde la séance', () {
      final q = ImportAnalyzer.analyser(texte,
          catalogue: _mini, options: const ImportOptions(ignorerSeriesVides: false));
      expect(q.seances.map((s) => s.titre), contains('Pousser'));
      expect(q.rapport.messages.where((m) => m.texte.contains('ignorées')), isEmpty);
    });

    test('durée invraisemblable : estimée à partir des séries', () {
      expect(seance('Abdos').duree, const Duration(minutes: 40));
      expect(seance('Marche').duree, const Duration(minutes: 86));
      expect(seance('Dos').duree, isNull, reason: 'quinze heures : chronomètre oublié');
      expect(seance('Dos').dureeRetenue, const Duration(minutes: 10));
      expect(seance('Bras').duree, isNull, reason: '49 secondes pour trois séries');
      expect(seance('Bras').dureeRetenue, const Duration(minutes: 10));
      expect(p.rapport.messages.where((m) => m.texte.contains('durée invraisemblable')), hasLength(1));
      expect(p.rapport.dureeTotale, const Duration(minutes: 40 + 86 + 10 + 10));
    });

    test('conversion : séance de marche en cardio, superset d\'un seul exercice défait', () {
      String? id(String nom) => switch (nom) {
            'Walking' => 'walking',
            'Crunch' => 'crunch',
            'Front Plank' => 'gainage',
            'Jumping Jack' => 'jumping-jacks',
            _ => 'curl-halteres',
          };
      bool cardio(String id) => id == 'walking' || id == 'jumping-jacks';
      final marche = convertirSeance(seance('Marche'), idPour: id, estCardio: cardio);
      expect(marche.type, TypeSeance.cardio);
      expect(marche.duree, const Duration(minutes: 86));
      final abdos = convertirSeance(seance('Abdos'), idPour: id, estCardio: cardio);
      expect(abdos.type, TypeSeance.musculation, reason: 'du cardio au milieu d\'une séance de musculation');
      final bras = convertirSeance(seance('Bras'), idPour: id, estCardio: cardio);
      expect(bras.exercices.single.supersetId, isNull);
      expect(bras.fin!.difference(bras.debut), const Duration(minutes: 10));
    });
  });
}
