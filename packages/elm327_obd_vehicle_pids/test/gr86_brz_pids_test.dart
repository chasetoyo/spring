import 'package:elm327_obd_vehicle_pids/subaru.dart';
import 'package:elm327_obd_vehicle_pids/toyota.dart';
import 'package:test/test.dart';

void main() {
  test(
    'toyota and subaru profiles for the Gen 2 platform share one PidSet',
    () {
      expect(
        identical(toyotaProfiles.first.pidSet, subaruProfiles.first.pidSet),
        isTrue,
      );
    },
  );

  test('engine oil temperature builds a mode 21 request with header 7E0', () {
    final pidSet = toyotaProfiles.first.pidSet;
    final oilTemp = pidSet.pids.firstWhere(
      (p) => p.name == 'Engine Oil Temperature',
    );
    expect(oilTemp.mode, 0x21);
    expect(oilTemp.requestHex, '2101');
    expect(oilTemp.targetHeader, '7E0');
    // first response byte 0x5A (90) - 40 = 50 degrees C
    expect(oilTemp.decode([0x5A]), 50);
  });

  test('fuel level builds a mode 21 request with header 7C0', () {
    final pidSet = toyotaProfiles.first.pidSet;
    final fuelLevel = pidSet.pids.firstWhere(
      (p) => p.name == 'Fuel Level (manufacturer-specific)',
    );
    expect(fuelLevel.mode, 0x21);
    expect(fuelLevel.requestHex, '2129');
    expect(fuelLevel.targetHeader, '7C0');
  });
}
