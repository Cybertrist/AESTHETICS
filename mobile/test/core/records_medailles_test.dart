import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

WorkoutSet _serie(double poids, int reps, {bool fait = true, SetType type = SetType.normale}) =>
    WorkoutSet(id: 's${_n++}', type: type, poids: poids, reps: reps, fait: fait);

/// Une séance du [jour] d'octobre 2026 : une liste de séries par exercice.
WorkoutSession _seance(int jour, Map<String, List<WorkoutSet>> exercices) => WorkoutSession(
      id: 'j$jour',
      nom: 'Séance $jour',
      debut: DateTime(2026, 10, jour, 18),
      fin: DateTime(2026, 10, jour, 19),
      exercices: [
        for (final e in exercices.entries) SessionExercise(id: '${e.key}-$jour', exerciseId: e.key, series: e.value),
      ],
    );

/// « or dc 52.5x7 » : une ligne lisible par record.
List<String> _lire(List<PersonalRecord> records) => [
      for (final r in records) '${r.type.medaille.name} ${r.exerciseId} ${r.poids ?? 0}x${r.reps}',
    ];

void main() {
  group('records : une règle, trois médailles', () {
    final avant = [
      _seance(1, {
        'rowing': [_serie(50, 8), _serie(50, 8)],
        'dc': [_serie(30, 5), _serie(28, 11)],
        'laterales': [_serie(6, 12)],
      }),
    ];

    test('une charge jamais soulevée : l’or, une seule fois même battue trois fois', () {
      final s = _seance(5, {
        'rowing': [_serie(52.5, 5), _serie(52.5, 7), _serie(52.5, 6)],
      });
      expect(_lire(Strength.newRecords(s, avant)), ['or rowing 52.5x7']);
    });

    test('plus de répétitions à une charge déjà faite : le bronze', () {
      // 30 kg × 5 avant, 30 kg × 6 aujourd'hui ; le 1RM estimé reste celui de 28 kg × 11.
      final s = _seance(5, {
        'dc': [_serie(30, 6), _serie(30, 5), _serie(30, 4)],
      });
      final r = Strength.newRecords(s, avant);
      expect(_lire(r), ['bronze dc 30.0x6']);
      expect(r.single.type, RecordType.repsMax);
      expect(r.single.valeur, 6);
      expect(Strength.repsA('dc', avant, 30), 5);
    });

    test('un meilleur 1RM estimé sans charge record : l’argent, et pas de bronze en double', () {
      final s = _seance(5, {
        'laterales': [_serie(6, 15), _serie(6, 13)],
      });
      expect(_lire(Strength.newRecords(s, avant)), ['argent laterales 6.0x15']);
    });

    test('une séance entière : tous les records, dans l’ordre des exercices', () {
      final s = _seance(5, {
        'dc': [_serie(30, 6)],
        'rowing': [_serie(52.5, 7)],
        'laterales': [_serie(6, 15)],
        'nouveau': [_serie(40, 10)],
      });
      expect(_lire(Strength.newRecords(s, avant)), ['bronze dc 30.0x6', 'or rowing 52.5x7', 'argent laterales 6.0x15']);
    });

    test('un bronze par charge, la plus lourde d’abord', () {
      final s = _seance(5, {
        'dc': [_serie(30, 6), _serie(25, 12), _serie(25, 14)],
      });
      expect(_lire(Strength.newRecords(s, avant)), ['bronze dc 30.0x6', 'bronze dc 25.0x14']);
    });

    test('l’argent s’ajoute à l’or seulement s’il le dépasse', () {
      // 52,5 × 2 : charge record. 50 × 12 : un 1RM estimé plus haut encore.
      final s = _seance(5, {
        'rowing': [_serie(52.5, 2), _serie(50, 12)],
      });
      expect(_lire(Strength.newRecords(s, avant)), ['or rowing 52.5x2', 'argent rowing 50.0x12']);
      // 52,5 × 7 dépasse déjà le 1RM de 50 × 7 : un seul record.
      final t = _seance(5, {
        'rowing': [_serie(52.5, 7), _serie(50, 7)],
      });
      expect(_lire(Strength.newRecords(t, avant)), ['or rowing 52.5x7']);
    });

    test('rien sans historique, ni pour une série non validée ou d’échauffement', () {
      expect(Strength.newRecords(_seance(5, {'nouveau': [_serie(100, 5)]}), avant), isEmpty);
      final s = _seance(5, {
        'rowing': [_serie(60, 5, fait: false), _serie(60, 5, type: SetType.echauffement)],
      });
      expect(Strength.newRecords(s, avant), isEmpty);
    });

    test('poids du corps : seules les répétitions comptent', () {
      final hist = [
        _seance(1, {'tractions': [_serie(0, 8)]}),
      ];
      expect(_lire(Strength.newRecords(_seance(5, {'tractions': [_serie(0, 10), _serie(0, 9)]}), hist)), ['bronze tractions 0.0x10']);
      expect(Strength.newRecords(_seance(5, {'tractions': [_serie(0, 8)]}), hist), isEmpty);
    });

    test('au fil de l’historique : le même résultat que séance par séance', () {
      final chrono = [
        ...avant,
        _seance(3, {'dc': [_serie(30, 6)], 'rowing': [_serie(52.5, 7)]}),
        _seance(5, {'dc': [_serie(30, 6), _serie(32.5, 3)], 'rowing': [_serie(52.5, 8)]}),
      ];
      final fil = Strength.recordsAuFil(chrono);
      final unParUn = [
        for (var i = 0; i < chrono.length; i++)
          for (final r in Strength.newRecords(chrono[i], chrono.sublist(0, i))) '${chrono[i].id} ${_lire([r]).single}',
      ];
      expect([for (final r in fil) '${r.session.id} ${_lire([r.record]).single}'], unParUn);
      expect(unParUn, ['j3 bronze dc 30.0x6', 'j3 or rowing 52.5x7', 'j5 or dc 32.5x3', 'j5 argent rowing 52.5x8']);
    });
  });
}
