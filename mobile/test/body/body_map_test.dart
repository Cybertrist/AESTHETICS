import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/models/muscle.dart';
import 'package:aesthetic/core/theme/app_theme.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Lit les assets directement sur le disque (indépendant du paquet d'assets de test).
class _Disque extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  final disque = _Disque();
  TestWidgetsFlutterBinding.ensureInitialized();

  final manif = jsonDecode(File('assets/body/pack/manifeste.json').readAsStringSync()) as Map<String, dynamic>;

  Future<ui.Image> decode(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  test('chaque muscle du contrat a un masque sur au moins une vue du corps', () {
    final face = (manif['face']['masques'] as List).toSet(), dos = (manif['dos']['masques'] as List).toSet();
    for (final m in Muscle.values) {
      expect(face.contains(m.name) || dos.contains(m.name), isTrue, reason: m.name);
    }
    for (final p in manif.keys) {
      for (final n in manif[p]['masques'] as List) {
        expect(Muscle.tryParse(n), isNotNull, reason: n);
        expect(File('assets/body/pack/${p}_$n.webp').existsSync(), isTrue, reason: '${p}_$n');
      }
    }
  });

  testWidgets('masques alignés au pixel sur la base, toucher au centre de chaque masque', (tester) async {
    await tester.runAsync(() async {
      for (final p in manif.keys) {
        final base = await decode('assets/body/pack/${p}_base.webp');
        final view = p.startsWith('face') ? BodyView.front : BodyView.back;
        final framing = p.endsWith('buste') ? BodyFraming.buste : (p.endsWith('jambes') ? BodyFraming.jambes : BodyFraming.corps);
        final imgs = await BodyImageRepository.load(view, framing, bundle: disque);
        for (final n in manif[p]['masques'] as List) {
          final m = Muscle.tryParse(n)!;
          final mask = await decode('assets/body/pack/${p}_$n.webp');
          expect([mask.width, mask.height], [base.width, base.height], reason: '${p}_$n');
          // point le plus couvert du masque (au pas de 4 px) : le toucher doit y trouver ce muscle
          final data = (await mask.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          var best = -1, bx = 0, by = 0;
          for (var y = 0; y < mask.height; y += 4) {
            for (var x = 0; x < mask.width; x += 4) {
              var s = 0;
              for (var k = -12; k <= 12; k += 6) {
                for (var l = -12; l <= 12; l += 6) {
                  final xx = x + k, yy = y + l;
                  if (xx < 0 || yy < 0 || xx >= mask.width || yy >= mask.height) continue;
                  s += data.getUint8((yy * mask.width + xx) * 4 + 3);
                }
              }
              if (s > best) {
                best = s;
                bx = x;
                by = y;
              }
            }
          }
          // les masques en simple liseré (muscle vu de biais) ne se visent pas au doigt
          if (best < 25 * 255 * 0.9) continue;
          // les deltoïdes latéraux partagent le calque des antérieurs (face) et des postérieurs (dos)
          if (m == Muscle.deltoidesLateraux) continue;
          final hit = await BodyImageRepository.hitTest(imgs, Offset(bx / mask.width, by / mask.height), bundle: disque);
          expect(hit, m, reason: '${p}_$n au point $bx,$by');
        }
      }
    });
  });

  test('teinte : la couleur est multipliée par la luminance', () {
    final mat = BodyImageRepository.tintMatrix(const Color(0xFFE0393E));
    expect(mat.length, 20);
    // un calque de luminance 0,62 redonne exactement la couleur
    expect((mat[0] + mat[1] + mat[2]) * 0.62, closeTo(0xE0 / 255, 1e-6));
    expect((mat[5] + mat[6] + mat[7]) * 0.62, closeTo(0x39 / 255, 1e-6));
    expect(mat[18], 1);
  });

  testWidgets('rendu du widget (capture)', (tester) async {
    const red = Color(0xFFE0393E);
    final inten = {Muscle.pectoraux: 1.0, Muscle.deltoidesAnterieurs: 1.0, Muscle.deltoidesLateraux: 1.0, Muscle.trapezes: 0.6, Muscle.deltoidesPosterieurs: 1.0};
    await tester.runAsync(() async {
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          final imgs = await BodyImageRepository.load(v, f, bundle: disque);
          for (final m in [...inten.keys, Muscle.abdominaux, Muscle.grandDorsal]) {
            if (imgs.muscles.contains(m)) await BodyImageRepository.loadMask(imgs, m, bundle: disque);
          }
        }
      }
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(const Color(0xFFF0A042)),
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFF1E1F22),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            BodyMapDual(intensities: inten, height: 520, highlight: red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                Expanded(child: BodyMap(framing: BodyFraming.buste, intensities: const {Muscle.abdominaux: 1})),
                Expanded(child: BodyMap(view: BodyView.back, framing: BodyFraming.buste, intensities: const {Muscle.grandDorsal: 1}, selected: const {Muscle.trapezes})),
              ]),
            ),
          ]),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('rendu_flutter.png'));
  });
}
