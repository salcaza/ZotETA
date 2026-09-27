import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/models/permit_profile.dart';

void main() {
  test(
    'P permits reject Zone 2 because UCI does not offer that combination',
    () {
      const profile = PermitProfile(type: PermitType.p, zone: 2);
      expect(profile.isComplete, isFalse);
    },
  );

  test('profile survives a JSON round trip', () {
    const original = PermitProfile(type: PermitType.s, zone: 5);
    final restored = PermitProfile.fromJson(original.toJson());

    expect(restored?.type, PermitType.s);
    expect(restored?.zone, 5);
    expect(restored?.label, 'S Zone 5');
  });

  test('corrupt or incomplete saved data is rejected', () {
    expect(PermitProfile.fromJson({'type': 'futurePermit'}), isNull);
    expect(PermitProfile.fromJson({'type': 'r'}), isNull);
  });
}
