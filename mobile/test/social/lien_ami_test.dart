import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("le lien d'ami est une vraie adresse, et son pseudo se relit", () {
    final lien = SocialRepo.lienAmi(' Tristan.J ');
    expect(lien, 'https://aesthetics-cybertrist.web.app/ami/tristan.j');
    expect(SocialRepo.pseudoDuLien(lien), 'tristan.j');
  });

  test('les anciens codes se lisent encore, les autres adresses non', () {
    expect(SocialRepo.pseudoDuLien('aesthetics://ami?pseudo=alice'), 'alice');
    expect(SocialRepo.pseudoDuLien('https://exemple.fr/ami/alice'), isNull);
    expect(SocialRepo.pseudoDuLien('https://aesthetics-cybertrist.web.app/ami/'), isNull);
    expect(SocialRepo.pseudoDuLien('https://aesthetics-cybertrist.web.app/autre/alice'), isNull);
    expect(SocialRepo.pseudoDuLien(null), isNull);
  });
}
