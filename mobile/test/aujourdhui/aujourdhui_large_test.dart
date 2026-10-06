import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

void main() {
  setUpAll(preparerAssets);

  testWidgets('accueil et sous-pages avec la démo, Fold ouvert', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: true)))!;
    await parcours(t, data, 'large', const Size(884, 1900));
  });
}
