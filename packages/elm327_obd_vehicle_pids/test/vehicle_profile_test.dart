import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:test/test.dart';

void main() {
  final testPidSet = PidSet('Test Set', []);
  final profile = VehicleProfile(
    make: 'Acme',
    model: 'Roadrunner',
    yearStart: 2020,
    yearEnd: 2022,
    pidSet: testPidSet,
  );

  test('matches within the year range, case-insensitively', () {
    expect(
      profile.matches(make: 'acme', model: 'roadrunner', year: 2021),
      isTrue,
    );
    expect(
      profile.matches(make: 'ACME', model: 'ROADRUNNER', year: 2020),
      isTrue,
    );
    expect(
      profile.matches(make: 'Acme', model: 'Roadrunner', year: 2022),
      isTrue,
    );
  });

  test('does not match outside the year range', () {
    expect(
      profile.matches(make: 'Acme', model: 'Roadrunner', year: 2019),
      isFalse,
    );
    expect(
      profile.matches(make: 'Acme', model: 'Roadrunner', year: 2023),
      isFalse,
    );
  });

  test('does not match a different make or model', () {
    expect(
      profile.matches(make: 'Wile', model: 'Roadrunner', year: 2021),
      isFalse,
    );
    expect(profile.matches(make: 'Acme', model: 'Coyote', year: 2021), isFalse);
  });

  test('an open-ended yearEnd matches every year from yearStart onward', () {
    final openEnded = VehicleProfile(
      make: 'Acme',
      model: 'Anvil',
      yearStart: 2020,
      pidSet: testPidSet,
    );
    expect(openEnded.matches(make: 'Acme', model: 'Anvil', year: 2099), isTrue);
  });

  test('findVehicleProfile returns the first match, or null', () {
    expect(
      findVehicleProfile(
        [profile],
        make: 'Acme',
        model: 'Roadrunner',
        year: 2021,
      ),
      same(profile),
    );
    expect(
      findVehicleProfile(
        [profile],
        make: 'Acme',
        model: 'Roadrunner',
        year: 2019,
      ),
      isNull,
    );
  });
}
