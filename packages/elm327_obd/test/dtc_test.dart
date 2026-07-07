import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  group('decodeDtc', () {
    test('decodes a powertrain SAE-defined code (P0133)', () {
      expect(decodeDtc(0x01, 0x33), 'P0133');
    });

    test('decodes a network manufacturer-defined code (U1016)', () {
      expect(decodeDtc(0xD0, 0x16), 'U1016');
    });

    test('decodes a powertrain manufacturer-defined code (P1131)', () {
      expect(decodeDtc(0x11, 0x31), 'P1131');
    });

    test('treats 00 00 as padding, not a real code', () {
      expect(decodeDtc(0x00, 0x00), isNull);
    });
  });

  group('decodeDtcFrame', () {
    test('decodes the mode 03 example from the datasheet', () {
      // 43 01 33 00 00 00 00 -> one real code, the rest is 00-padding.
      final frame = [0x43, 0x01, 0x33, 0x00, 0x00, 0x00, 0x00];
      expect(decodeDtcFrame(frame, startIndex: 1), ['P0133']);
    });
  });
}
