import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

void main() {
  setUpAll(preparerAssets);

  testWidgets('accueil et sous-pages avec la démo, Fold fermé', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: true)))!;
    await parcours(t, data, 'etroit', const Size(390, 2400));
  });
}
