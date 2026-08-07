import 'package:elm327_obd_vehicle_pids/toyota.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:test/test.dart';

void main() {
  test(
    'toyotaProfiles resolves a 2022 GR86 to the shared GR86/BRZ PID set',
    () {
      final profile = findVehicleProfile(
        toyotaProfiles,
        make: 'Toyota',
        model: 'GR86',
        year: 2022,
      );
      expect(profile, isNotNull);
      expect(profile!.pidSet.name, contains('GR86'));
    },
  );

  test('toyotaProfiles does not match an unrelated Toyota model', () {
    final profile = findVehicleProfile(
      toyotaProfiles,
      make: 'Toyota',
      model: 'Corolla',
      year: 2022,
    );
    expect(profile, isNull);
  });
}
