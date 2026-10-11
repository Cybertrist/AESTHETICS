import 'dart:convert';

import 'package:aesthetic/features/sante/services/corps_hc.dart';
import 'package:aesthetic/features/sante/services/pesees_fichier.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Export d'une balance connectée : weight.csv seul ou dans le zip.
void main() {
  const csv = 'Date,"Poids (kg)","Gras (kg)","Masse osseuse (kg)","Masse musculaire (kg)","Hydratation (kg)",Commentaires\n'
      '"2026-10-09 07:47:34",112.84,34.06,3.90,74.87,55.10,\n'
      '"2026-10-09 07:35:14",112.89,34.25,3.89,74.74,54.73,\n'
      '"2026-07-14 07:30:00",124.10,40.00,3.90,75.00,55.00,\n'
      '"2024-04-01 10:00:00",125.40,,,,,\n';

  test('weight.csv : date, poids, gras ramené en pourcentage', () {
    final r = PeseesFichier.lire(utf8.encode(csv));
    expect(r, hasLength(4));
    expect(r.first.date, DateTime(2026, 10, 9, 7, 47, 34));
    expect(r.first.poidsKg, 112.84);
    expect(r.first.grasPct, closeTo(30.18, 0.01));
    expect(r.last.poidsKg, 125.4);
    expect(r.last.grasPct, isNull);
  });

  test('rangé : une saisie par jour, la dernière pesée du jour', () {
    final f = CorpsHc.fusionner(const [], PeseesFichier.lire(utf8.encode(csv)));
    expect(f.aEcrire, hasLength(3));
    final jour = f.aEcrire.firstWhere((m) => m.id == 'hc-2026-10-09');
    expect(jour.poidsKg, 112.84);
    expect(jour.masseGrassePct, 30.2);
    expect(f.aEcrire.any((m) => m.id == 'hc-2026-07-14'), isTrue);
  });

  test('le zip de l\'export complet', () {
    final a = Archive()
      ..addFile(ArchiveFile.string('README.txt', 'x'))
      ..addFile(ArchiveFile.string('weight.csv', csv));
    expect(PeseesFichier.lire(ZipEncoder().encodeBytes(a)), hasLength(4));
  });

  test('fichier sans pesées : message clair', () {
    expect(() => PeseesFichier.lire(utf8.encode('a,b\n1,2\n')), throwsA(isA<PeseesIllisibles>()));
    final a = Archive()..addFile(ArchiveFile.string('sleep.csv', 'x'));
    expect(() => PeseesFichier.lire(ZipEncoder().encodeBytes(a)), throwsA(isA<PeseesIllisibles>()));
  });
}
