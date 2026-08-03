import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  group('decodeBytes', () {
    test('matches the hand-written engine RPM decoder', () {
      final definition = PidDefinition.standardCatalogue.firstWhere(
        (d) => d.name == 'Engine RPM',
      );
      // The datasheet's own worked example: 41 0C 1A F8 -> 1726 rpm.
      expect(definition.decodeBytes([0x1A, 0xF8]), 1726);
      expect(StandardPids.engineRpm.decode([0x1A, 0xF8]), 1726);
    });

    test('an offset produces a negative temperature', () {
      final definition = PidDefinition.standardCatalogue.firstWhere(
        (d) => d.name == 'Coolant Temp (C)',
      );
      expect(definition.decodeBytes([0x00]), -40);
      expect(definition.decodeBytes([0x3C]), 20);
    });

    test('reads a signed two-byte value as two\'s complement', () {
      const definition = PidDefinition(
        name: 'Oil Temp',
        unit: 'C',
        mode: 0x22,
        pidBytes: [0x1E, 0x1C],
        byteCount: 2,
        signed: true,
        scale: 0.1,
      );
      expect(definition.decodeBytes([0x00, 0x64]), closeTo(10, 1e-9));
      // 0xFF9C is -100 signed, which unsigned would read as 6549.2.
      expect(definition.decodeBytes([0xFF, 0x9C]), closeTo(-10, 1e-9));
    });

    test('a forum formula translates to scale and offset', () {
      // (A*256+B)/8 - 48, the shape most boost PIDs are quoted in.
      const boost = PidDefinition(
        name: 'Boost',
        unit: 'psi',
        mode: 0x22,
        pidBytes: [0x11, 0x5C],
        byteCount: 2,
        scale: 0.125,
        offset: -48,
      );
      expect(boost.decodeBytes([0x01, 0x90]), closeTo(2, 1e-9));
    });

    test('ignores trailing bytes beyond the declared width', () {
      const definition = PidDefinition(
        name: 'One byte',
        unit: '',
        mode: 0x01,
        pidBytes: [0x05],
      );
      expect(definition.decodeBytes([0x10, 0xFF, 0xFF]), 16);
    });

    test('refuses a response too short to decode', () {
      const definition = PidDefinition(
        name: 'Two bytes',
        unit: '',
        mode: 0x01,
        pidBytes: [0x0C],
        byteCount: 2,
      );
      // Better a typed protocol error than a value silently built from a
      // truncated frame.
      expect(
        () => definition.decodeBytes([0x1A]),
        throwsA(isA<Elm327ProtocolException>()),
      );
    });
  });

  group('json', () {
    test('round-trips every field', () {
      const original = PidDefinition(
        name: 'Oil Temp',
        unit: 'C',
        mode: 0x22,
        pidBytes: [0x1E, 0x1C],
        byteCount: 2,
        signed: true,
        scale: 0.1,
        offset: -40,
        header: '7E0',
        minInterval: Duration(seconds: 2),
      );

      final restored = PidDefinition.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.unit, original.unit);
      expect(restored.mode, original.mode);
      expect(restored.pidBytes, original.pidBytes);
      expect(restored.byteCount, original.byteCount);
      expect(restored.signed, original.signed);
      expect(restored.scale, original.scale);
      expect(restored.offset, original.offset);
      expect(restored.header, original.header);
      expect(restored.minInterval, original.minInterval);
    });

    test('a stored PID is readable hex, not an array of ints', () {
      const definition = PidDefinition(
        name: 'Oil Temp',
        unit: 'C',
        mode: 0x22,
        pidBytes: [0x1E, 0x1C],
      );
      expect(definition.toJson()['pid'], '1E1C');
    });

    test('fills in defaults for a minimal entry', () {
      final restored = PidDefinition.fromJson({
        'name': 'Engine RPM',
        'mode': 1,
        'pid': '0C',
      });
      expect(restored.byteCount, 1);
      expect(restored.scale, 1);
      expect(restored.offset, 0);
      expect(restored.signed, isFalse);
      expect(restored.minInterval, Duration.zero);
    });
  });

  group('parsePidHex', () {
    test('accepts spacing and colons', () {
      expect(parsePidHex('1E 1C'), [0x1E, 0x1C]);
      expect(parsePidHex('1e:1c'), [0x1E, 0x1C]);
    });

    test('rejects a half byte and non-hex', () {
      expect(() => parsePidHex('1E1'), throwsFormatException);
      expect(() => parsePidHex('ZZ'), throwsFormatException);
      expect(() => parsePidHex(''), throwsFormatException);
    });
  });

  group('query routing', () {
    test('a single-byte PID with no header uses the standard path', () {
      // queryPid also checks the PID echo in the reply, so it catches a
      // response belonging to a different request; queryCustomPid cannot.
      expect(
        PidDefinition.standardCatalogue.every((d) => !d.needsCustomQuery),
        isTrue,
      );
    });

    test('a multi-byte PID or an ECU header needs the custom path', () {
      const twoByte = PidDefinition(
        name: 'x',
        unit: '',
        mode: 0x22,
        pidBytes: [0x1E, 0x1C],
      );
      const headed = PidDefinition(
        name: 'y',
        unit: '',
        mode: 0x01,
        pidBytes: [0x05],
        header: '7E0',
      );
      expect(twoByte.needsCustomQuery, isTrue);
      expect(headed.needsCustomQuery, isTrue);
      expect(() => twoByte.toPid(), throwsArgumentError);
    });

    test('requestHex is what the adapter is sent', () {
      const definition = PidDefinition(
        name: 'x',
        unit: '',
        mode: 0x22,
        pidBytes: [0x1E, 0x1C],
      );
      expect(definition.requestHex, '221E1C');
    });
  });

  test('the default selection leaves vehicle speed out', () {
    // GPS measures road speed better than the drivetrain reports it, and
    // RaceRender already has a Speed column of its own.
    expect(
      PidDefinition.standardCatalogue.any(
        (d) => d.name == 'Vehicle Speed (km/h)',
      ),
      isTrue,
    );
    expect(
      PidDefinition.defaultSelection.any(
        (d) => d.name == 'Vehicle Speed (km/h)',
      ),
      isFalse,
    );
  });
}
