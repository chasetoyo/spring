import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  test('builds a mode 22 two-byte PID request', () {
    final pid = CustomPid(
      name: 'Manifold Relative Pressure',
      mode: 0x22,
      pidBytes: [0x11, 0x01],
      unit: 'psi',
      decode: (bytes) => bytes[0] / 10,
      targetHeader: '7E0',
    );
    expect(pid.requestHex, '221101');
    expect(pid.targetHeader, '7E0');
    expect(pid.decode([25]), 2.5);
  });

  test('PidSet groups CustomPids under a name', () {
    final pid = CustomPid(
      name: 'Test PID',
      mode: 0x22,
      pidBytes: [0x00, 0x01],
      unit: '',
      decode: (bytes) => bytes[0],
    );
    final set = PidSet('Test Make', [pid]);
    expect(set.name, 'Test Make');
    expect(set.pids, [pid]);
  });
}
