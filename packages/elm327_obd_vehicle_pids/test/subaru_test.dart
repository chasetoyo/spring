import 'package:elm327_obd_vehicle_pids/subaru.dart';
import 'package:test/test.dart';

void main() {
  test('subaruPids exposes at least one CustomPid with a valid request', () {
    expect(subaruPids.name, 'Subaru');
    expect(subaruPids.pids, isNotEmpty);
    for (final pid in subaruPids.pids) {
      expect(pid.requestHex, matches(RegExp(r'^[0-9A-F]+$')));
    }
  });

  test('manifoldRelativePressure decodes a raw byte to psi', () {
    final pid = subaruPids.pids.firstWhere(
      (p) => p.name == 'Manifold Relative Pressure',
    );
    expect(pid.mode, 0x22);
    expect(pid.decode([25]), closeTo(2.5, 0.001));
  });
}
