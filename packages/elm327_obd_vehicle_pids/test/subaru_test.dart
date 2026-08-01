import 'package:elm327_obd/elm327_obd.dart';
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

  test('the definitions decode identically to the closures', () {
    // The CustomPid list is generated from the definitions, so this is really
    // asking that the scale/offset form expresses what the closure did.
    for (final definition in subaruPidDefinitions) {
      final pid = subaruPids.pids.firstWhere((p) => p.name == definition.name);
      expect(definition.decodeBytes([25]), pid.decode([25]));
    }
  });

  test('the definitions survive a round trip through JSON', () {
    // The point of declaring them this way: a picker can store the choice.
    for (final definition in subaruPidDefinitions) {
      final restored = PidDefinition.fromJson(definition.toJson());
      expect(restored.requestHex, definition.requestHex);
      expect(restored.header, definition.header);
      expect(restored.decodeBytes([25]), definition.decodeBytes([25]));
    }
  });

  test('a physically-addressed PID keeps its ECU header', () {
    // Without ATSH the request goes to the protocol's functional address and
    // the ECU that owns this PID never answers.
    expect(subaruPidDefinitions.single.header, '7E0');
    expect(subaruPidDefinitions.single.needsCustomQuery, isTrue);
  });
}
