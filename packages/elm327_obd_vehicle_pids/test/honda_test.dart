import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/honda.dart';
import 'package:test/test.dart';

void main() {
  test('the four-cylinder map is one counter per cylinder', () {
    expect(acuraTsx2013MisfireI4, hasLength(4));
    expect(acuraTsx2013MisfireI4.map((PidDefinition d) => d.name), <String>[
      'Misfire Cylinder 1',
      'Misfire Cylinder 2',
      'Misfire Cylinder 3',
      'Misfire Cylinder 4',
    ]);
  });

  test('the V6 map extends the four rather than replacing it', () {
    // If the four-cylinder PIDs turn out to be wrong, the V6 has to be wrong
    // in exactly the same way — two maps that could drift apart would mean
    // fixing the same mistake twice.
    expect(acuraTsx2013MisfireV6.take(4), acuraTsx2013MisfireI4);
    expect(acuraTsx2013MisfireV6, hasLength(6));
  });

  test('the PIDs step by two per cylinder, from the reported pair', () {
    // 16-00 and 16-02 are the two that came from outside this repo; the rest
    // continue that stride. This test is what pins the extrapolation down, so
    // if the real map turns out to be different, it fails here rather than
    // producing quiet nonsense on a car.
    expect(
      acuraTsx2013MisfireV6.map((PidDefinition d) => d.pidBytes),
      <List<int>>[
        <int>[0x16, 0x00],
        <int>[0x16, 0x02],
        <int>[0x16, 0x04],
        <int>[0x16, 0x06],
        <int>[0x16, 0x08],
        <int>[0x16, 0x0A],
      ],
    );
  });

  test('every counter is an unscaled two-byte read of the ECM', () {
    for (final PidDefinition definition in acuraTsx2013MisfireV6) {
      expect(definition.mode, 0x22, reason: 'enhanced, not standard OBD');
      // Without ATSH the request goes to the protocol's functional address and
      // the ECM never answers a manufacturer PID.
      expect(definition.header, '7E0');
      expect(definition.needsCustomQuery, isTrue);
      // A counter past 255 is ordinary on a bad plug, and reading two bytes as
      // one turns 256 into 1.
      expect(definition.byteCount, 2);
      expect(definition.scale, 1);
      expect(definition.offset, 0);
      expect(definition.signed, isFalse);
    }
  });

  test('a two-byte count decodes big-endian and unscaled', () {
    final PidDefinition cylinder1 = acuraTsx2013MisfireI4.first;
    expect(cylinder1.decodeBytes(<int>[0x00, 0x00]), 0);
    expect(cylinder1.decodeBytes(<int>[0x00, 0x2A]), 42);
    // The case a one-byte read would get wrong.
    expect(cylinder1.decodeBytes(<int>[0x01, 0x00]), 256);
  });

  test('polling is throttled so six cylinders cannot starve the link', () {
    // An ELM327 answers one command at a time, so every channel costs every
    // other one. A misfire counter that moves at all has already said what it
    // needs to.
    for (final PidDefinition definition in acuraTsx2013MisfireV6) {
      expect(definition.minInterval, greaterThan(Duration.zero));
    }
  });

  test('the request hex is what a terminal check would type', () {
    // The doc comment tells a driver to send `221600` to confirm the map by
    // hand; this is that string, so the instruction cannot drift from the code.
    expect(acuraTsx2013MisfireI4.first.requestHex, '221600');
    expect(acuraTsx2013MisfireI4[1].requestHex, '221602');
  });

  test('the definitions survive a round trip through JSON', () {
    for (final PidDefinition definition in acuraTsx2013MisfireV6) {
      final PidDefinition restored = PidDefinition.fromJson(
        definition.toJson(),
      );
      expect(restored.requestHex, definition.requestHex);
      expect(restored.header, definition.header);
      expect(restored.byteCount, definition.byteCount);
      expect(
        restored.decodeBytes(<int>[0x01, 0x00]),
        definition.decodeBytes(<int>[0x01, 0x00]),
      );
    }
  });

  test('the PidSet form carries the same requests', () {
    expect(acuraTsx2013MisfirePids.pids, hasLength(4));
    for (final CustomPid pid in acuraTsx2013MisfirePids.pids) {
      expect(pid.requestHex, matches(RegExp(r'^[0-9A-F]+$')));
      expect(pid.targetHeader, '7E0');
    }
  });
}
