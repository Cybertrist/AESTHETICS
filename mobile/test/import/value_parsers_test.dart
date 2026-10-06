import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lireNombre', () {
    test('point, virgule, milliers, null', () {
      expect(lireNombre('55.000'), 55);
      expect(lireNombre('82,5'), 82.5);
      expect(lireNombre('1 234,5'), 1234.5);
      expect(lireNombre('1,234.5'), 1234.5);
      expect(lireNombre('60kg'), 60);
      expect(lireNombre('null'), isNull);
      expect(lireNombre(''), isNull);
      expect(lireNombre('-'), isNull);
    });
  });

  group('lireDureeSec', () {
    test('formats horaires et textuels', () {
      expect(lireDureeSec('01:07:22'), 4042);
      expect(lireDureeSec('1:30'), 90);
      expect(lireDureeSec('1h 5m'), 3900);
      expect(lireDureeSec('45m'), 2700);
      expect(lireDureeSec('45 min'), 2700);
      expect(lireDureeSec('90s'), 90);
      expect(lireDureeSec('3900'), 3900);
      expect(lireDureeSec('null'), isNull);
    });
  });

  group('lireDate', () {
    test('format principal', () {
      expect(lireDate('2026-07-13 07:30:19'), DateTime(2026, 7, 13, 7, 30, 19));
    });
    test('mois en toutes lettres', () {
      expect(lireDate('22 Dec 2025, 08:00'), DateTime(2025, 12, 22, 8));
      expect(lireDate('22 déc. 2025, 08:00'), DateTime(2025, 12, 22, 8));
      expect(lireDate('Dec 22, 2025 8:05 pm'), DateTime(2025, 12, 22, 20, 5));
    });
    test('jour d\'abord par défaut, mois d\'abord si demandé', () {
      expect(lireDate('05/07/2026'), DateTime(2026, 7, 5));
      expect(lireDate('05/07/2026', moisDabord: true), DateTime(2026, 5, 7));
      expect(lireDate('07/13/2026'), DateTime(2026, 7, 13));
      expect(lireDate('13/07/2026 18:30'), DateTime(2026, 7, 13, 18, 30));
    });
    test('refuse les dates impossibles', () {
      expect(lireDate('2026-02-31'), isNull);
      expect(lireDate('pas une date'), isNull);
    });
    test('détection de l\'ordre jour et mois', () {
      expect(detecterMoisDabord(['05/07/2026', '07/13/2026']), isTrue);
      expect(detecterMoisDabord(['05/07/2026', '13/07/2026']), isFalse);
    });
  });

  group('lireTypeSerie', () {
    test('toutes les écritures connues', () {
      expect(lireTypeSerie('NORMAL_SET'), SetKind.normale);
      expect(lireTypeSerie('WARMUP_SET'), SetKind.echauffement);
      expect(lireTypeSerie('DROP_SET'), SetKind.degressive);
      expect(lireTypeSerie('FAILURE_SET'), SetKind.echec);
      expect(lireTypeSerie('NEGATIVE_REPS_SET'), SetKind.negative);
      expect(lireTypeSerie('BACK_OFF_SET'), SetKind.retour);
      expect(lireTypeSerie('warmup'), SetKind.echauffement);
      expect(lireTypeSerie('dropset'), SetKind.degressive);
      expect(lireTypeSerie('W'), SetKind.echauffement);
      expect(lireTypeSerie('Échauffement'), SetKind.echauffement);
      expect(lireTypeSerie(''), SetKind.normale);
      expect(lireTypeSerie('bizarre'), isNull);
    });
  });

  group('CsvTable', () {
    test('guillemets doublés, retour à la ligne dans un champ, BOM', () {
      final t = CsvTable.lire('﻿a,b\r\n"x ""y""","ligne 1\nligne 2"\r\n');
      expect(t.enTetes, ['a', 'b']);
      expect(t.lignes.single.valeurs, ['x "y"', 'ligne 1\nligne 2']);
    });
    test('séparateur détecté', () {
      expect(CsvTable.lire('a;b;c\n1;2;3').separateur, ';');
      expect(CsvTable.lire('a\tb\n1\t2').separateur, '\t');
      expect(CsvTable.lire('"a;b",c\n1,2').separateur, ',');
    });
    test('en-tête avec espace devant et casse différente', () {
      final t = CsvTable.lire(' Title,"Set Type"\nA,NORMAL_SET');
      expect(t.lignes.single.get(['title']), 'A');
      expect(t.lignes.single.get(['set type']), 'NORMAL_SET');
    });
    test('Latin-1 accepté', () {
      expect(CsvTable.decoder([0x53, 0xE9, 0x61, 0x6E, 0x63, 0x65]), 'Séance');
    });
  });
}
