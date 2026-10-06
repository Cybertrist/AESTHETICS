import 'dart:io';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/routines/logic/idees.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_templates.dart';
import 'package:flutter_test/flutter_test.dart';

/// Empreinte d'une séance : ses exercices et leur dosage.
String _empreinte(ModeleRoutine r) =>
    [for (final e in r.exercices) '${e.ids.first}:${e.series}x${e.reps}-${e.repsMax}:${e.repos}:${e.dureeSec}'].join('|');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalogue : pas de doublon, des séances de taille raisonnable', () async {
    final data = AppData(Store.memory());
    await data.loadAll();
    final vus = <String, String>{};
    for (final m in modelesProgrammes) {
      // Deux programmes ne proposent jamais exactement les mêmes séances au même dosage.
      final cle = '${m.joursParSemaine}/${[for (final i in m.cycle) _empreinte(m.routines[i])].join('//')}';
      expect(vus[cle], isNull, reason: '${m.nom} est identique à ${vus[cle]}');
      vus[cle] = m.nom;
      expect(m.cycle, isNotEmpty, reason: m.nom);
      expect(m.joursParSemaine, inInclusiveRange(1, 7), reason: m.nom);
      for (final r in m.routines) {
        for (final e in r.exercices) {
          final ex = data.exercises.byId(e.ids.first);
          expect(ex, isNotNull, reason: '${m.nom} / ${r.nom} : ${e.ids.first} inconnu');
          // Un programme débutant ne contient aucun exercice classé avancé.
          if (m.niveau == Niveau.debutant) {
            expect(ex!.niveau, isNot('avance'), reason: '${m.nom} / ${r.nom} : ${ex.nom}');
          }
          // Le soulevé de terre classique ne se fait jamais en séries longues.
          if (e.ids.first == 'souleve-de-terre') {
            expect(e.repsMax ?? e.reps, lessThanOrEqualTo(8), reason: '${m.nom} / ${r.nom}');
            expect(e.repos, greaterThanOrEqualTo(150), reason: '${m.nom} / ${r.nom}');
          }
          // Pas de série d'échauffement chargée sur une traction ou une pompe.
          if (e.ids.first.startsWith('pompes') || (e.ids.first.startsWith('tractions') && e.ids.first != 'tractions-lestees')) {
            expect(e.echauffements, 0, reason: '${m.nom} / ${r.nom} : ${e.ids.first}');
          }
        }
        expect(r.exercices.length, inInclusiveRange(1, 9), reason: '${m.nom} / ${r.nom}');
        final ids = [for (final e in r.exercices) e.ids.first];
        expect(ids.toSet().length, ids.length, reason: '${m.nom} / ${r.nom} : un exercice en double');
      }
    }
  });

  test('catalogue : la liste lisible des programmes', () async {
    final data = AppData(Store.memory());
    await data.loadAll();
    final b = StringBuffer();
    for (final r in Rayon.values) {
      b.writeln('\n# Rayon : ${r.label}\n');
      for (final i in ideesProgrammes.where((i) => i.rayon == r)) {
        final m = i.modele;
        b
          ..writeln('## ${m.nom}  [id ${m.id}]')
          ..writeln('${m.joursParSemaine} jours par semaine, ${m.semaines} semaines, ${m.niveau.label}, objectif : ${m.objectif}, progression : ${m.progression.label}'
              '${m.decharge > 0 ? ', décharge toutes les ${m.decharge} semaines' : ''}')
          ..writeln('Couverture : « ${i.gros} » / « ${i.bandeau ?? ''} »')
          ..writeln('Résumé : ${m.resume}')
          ..writeln('Description : ${m.description}');
        for (final c in m.conseils) {
          b.writeln('Conseil : $c');
        }
        b.writeln('Ordre des séances sur le cycle : ${[for (final x in m.cycle) m.routines[x].nom].join(' > ')}');
        for (final ro in m.routines) {
          b.writeln('- Séance « ${ro.nom} »');
          for (final e in ro.exercices) {
            final ex = data.exercises.byId(e.ids.first);
            final duree = ex != null && ex.suivi.usesDuration && !ex.suivi.usesReps;
            final dose = duree ? '${e.series} × ${e.dureeSec ?? 45} s' : '${e.series} × ${e.reps}${e.repsMax == null ? '' : '-${e.repsMax}'}';
            b.writeln('    - ${ex?.nom ?? e.ids.first} (${ex?.equipement ?? '?'}) : $dose, repos ${e.repos} s'
                '${e.echauffements > 0 ? ', ${e.echauffements} échauffement(s)' : ''}${e.superset == null ? '' : ', superset ${e.superset}'}');
          }
        }
        b.writeln();
      }
    }
    final f = File('build/programmes.md')..createSync(recursive: true);
    f.writeAsStringSync(b.toString());
    expect(modelesProgrammes.length, ideesProgrammes.length);
  });
}
