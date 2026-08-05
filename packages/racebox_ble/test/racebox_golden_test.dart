import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:racebox_ble/racebox_ble.dart';

/// The example packet published in *RaceBox BLE Protocol Documentation,
/// Revision 8*, verbatim — headers, payload and checksum.
const String _capturedPacketHex =
    'B562FF015000A0E70C07E607010A0833'
    '0837190000002AAD4D0E0301EA0BC693'
    'E10D3B376F19618C09000F0109009C03'
    '00002C0700002300000000000000D000'
    '000088A9DD002C010059FDFF7100CE03'
    '2FFF5600FCFF06DB';

Uint8List _hexToBytes(String hex) {
  return Uint8List.fromList(<int>[
    for (int i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

void main() {
  // The test that actually pins the byte layout. Every expectation below is
  // the value the protocol document itself prints for this packet, so a wrong
  // offset, scale factor or sign fails here — unlike the round-trip tests,
  // which are written from the same table the decoder reads and could only
  // ever agree with it.
  group('captured packet from the protocol document', () {
    late final Uint8List raw = _hexToBytes(_capturedPacketHex);
    late final UbxFrame frame = UbxFramer().add(raw).single;
    late final RaceBoxData data = RaceBoxData.decode(frame.payload)!;

    test('frames as an 80-byte RaceBox data message with a valid checksum', () {
      // The document notes the checksum is valid; the framer would have
      // yielded nothing otherwise.
      expect(raw, hasLength(88));
      expect(frame.messageClass, 0xFF);
      expect(frame.messageId, 0x01);
      expect(frame.payload, hasLength(80));
      expect(frame.isRaceBoxData, isTrue);
    });

    test('iTOW is 118286240', () {
      expect(data.iTowMs, 118286240);
    });

    test('timestamp is 10 January 2022, 08:51:08.239972 UTC', () {
      // The document prints the second fields as 08:51:08 and the Nanoseconds
      // field as 239972000 separately. They are one instant, and the fraction
      // is not decoration: it is what separates this packet from the other
      // twenty-four in its second.
      expect(data.timestampUtc, DateTime.utc(2022, 1, 10, 8, 51, 8, 239, 972));
    });

    test('fix is 3D and OK, on 11 satellites', () {
      expect(data.fixStatus, RaceBoxFixStatus.fix3d);
      expect(data.satellites, 11);
      expect(data.hasValidFix, isTrue);
      expect(data.hasValidPosition, isTrue);
    });

    test('position is 42.6719035, 23.2887238', () {
      expect(data.latitude, closeTo(42.6719035, 1e-7));
      expect(data.longitude, closeTo(23.2887238, 1e-7));
    });

    test('altitudes are 625.761 m WGS and 590.095 m MSL', () {
      expect(data.wgsAltitudeM, closeTo(625.761, 1e-3));
      expect(data.mslAltitudeM, closeTo(590.095, 1e-3));
    });

    test('accuracy is 0.924 m horizontal and 1.836 m vertical', () {
      expect(data.horizontalAccuracyM, closeTo(0.924, 1e-3));
      expect(data.verticalAccuracyM, closeTo(1.836, 1e-3));
    });

    test('speed is 35 mm/s, which is 0.126 kph', () {
      expect(data.speedMps, closeTo(0.035, 1e-6));
      expect(data.speedKph, closeTo(0.126, 1e-3));
    });

    test('heading is 0 degrees, accurate to 145.26856', () {
      expect(data.headingDegrees, closeTo(0, 1e-9));
      expect(data.headingAccuracyDegrees, closeTo(145.26856, 1e-5));
    });

    test('speed accuracy is 208 mm/s and PDOP is 3', () {
      expect(data.speedAccuracyMps, closeTo(0.208, 1e-6));
      expect(data.pdop, closeTo(3, 1e-6));
    });

    test('battery is 89 percent and not charging', () {
      expect(data.batteryByte, 0x59);
      expect(data.batteryPercent, 89);
      expect(data.isCharging, isFalse);
    });

    test('G-forces are -0.003, 0.113 and 0.974 g', () {
      expect(data.gForceX, closeTo(-0.003, 1e-6));
      expect(data.gForceY, closeTo(0.113, 1e-6));
      expect(data.gForceZ, closeTo(0.974, 1e-6));
    });

    test('rotation rates are -2.09, 0.86 and -0.04 deg/s', () {
      // The document's table prints these without signs, but the raw bytes
      // are signed 16-bit and two of them are negative: 0xFF2F is -209 and
      // 0xFFFC is -4. Reading them unsigned would put roll at +655 deg/s.
      expect(data.rotationRateX, closeTo(-2.09, 1e-6));
      expect(data.rotationRateY, closeTo(0.86, 1e-6));
      expect(data.rotationRateZ, closeTo(-0.04, 1e-6));
    });
  });
}
