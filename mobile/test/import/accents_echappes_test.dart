import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/import/logic/csv_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // « é » écrit en toutes lettres, comme dans l'export d'une autre appli.
  const e = r'é', E = r'É', i = r'î';

  test('les accents échappés d\'un autre export redeviennent des accents', () {
    expect(desechapper('S${e}ance du soir'), 'Séance du soir');
    expect(desechapper('DOS / DELTO POST${E}RIEURE'), 'DOS / DELTO POSTÉRIEURE');
    expect(desechapper('Entra${i}nement du matin'), 'Entraînement du matin');
    expect(desechapper('Séance normale'), 'Séance normale');
  });

  test('une séance déjà enregistrée est réparée à la lecture', () {
    final s = WorkoutSession.fromJson({'id': 'a', 'nom': '${E}PAULES / BRAS', 'debut': '2025-01-04T21:10:00', 'notes': "Cr${e}ac'h Gwen"});
    expect(s.nom, 'ÉPAULES / BRAS');
    expect(s.notes, "Créac'h Gwen");
  });

  test('l\'import rend les accents dès la lecture du fichier', () {
    final t = CsvTable.lire('Date,S${e}ance\n2025-01-04,S${e}ance du soir\n');
    expect(t.enTetes.last, 'Séance');
    expect(t.lignes.single.valeurs.last, 'Séance du soir');
  });
}
