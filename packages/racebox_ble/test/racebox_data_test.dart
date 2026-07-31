import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:racebox_ble/racebox_ble.dart';

/// Builds a payload by writing fields at the offsets the decoder reads.
///
/// **This cannot validate the offsets themselves.** It is written from the
/// same table the decoder uses, so it proves scaling, sign handling, endianness
/// and bit-field extraction are right *given* that table — and would catch a
/// millimetres-vs-metres slip or a signed/unsigned mistake — but if the table
/// is wrong against real firmware, these tests stay green. Only a capture from
/// a device can settle that; see the note on [RaceBoxDataOffsets].
Uint8List buildPayload({
  int iTow = 0,
  int year = 2026,
  int month = 7,
  int day = 31,
  int hour = 14,
  int minute = 30,
  int second = 15,
  int fixStatus = 3,
  int satellites = 12,
  int longitudeE7 = -1038917433,
  int latitudeE7 = 397355600,
  int wgsAltitudeMm = 1530000,
  int mslAltitudeMm = 1520000,
  int horizontalAccuracyMm = 2500,
  int verticalAccuracyMm = 3000,
  int speedMmps = 25000,
  int headingE5 = 21080000,
  int speedAccuracyMmps = 100,
  int gForceXMilli = 125,
  int gForceYMilli = -250,
  int gForceZMilli = 1000,
  int rotationXCenti = 150,
  int rotationYCenti = -75,
  int rotationZCenti = 0,
  int battery = 0x55,
}) {
  final Uint8List bytes = Uint8List(RaceBoxDataOffsets.payloadLength);
  final ByteData view = ByteData.sublistView(bytes);

  view.setUint32(RaceBoxDataOffsets.iTow, iTow, Endian.little);
  view.setUint16(RaceBoxDataOffsets.year, year, Endian.little);
  view.setUint8(RaceBoxDataOffsets.month, month);
  view.setUint8(RaceBoxDataOffsets.day, day);
  view.setUint8(RaceBoxDataOffsets.hour, hour);
  view.setUint8(RaceBoxDataOffsets.minute, minute);
  view.setUint8(RaceBoxDataOffsets.second, second);
  view.setUint8(RaceBoxDataOffsets.fixStatus, fixStatus);
  view.setUint8(RaceBoxDataOffsets.numberOfSvs, satellites);
  view.setInt32(RaceBoxDataOffsets.longitude, longitudeE7, Endian.little);
  view.setInt32(RaceBoxDataOffsets.latitude, latitudeE7, Endian.little);
  view.setInt32(RaceBoxDataOffsets.wgsAltitude, wgsAltitudeMm, Endian.little);
  view.setInt32(RaceBoxDataOffsets.mslAltitude, mslAltitudeMm, Endian.little);
  view.setUint32(
    RaceBoxDataOffsets.horizontalAccuracy,
    horizontalAccuracyMm,
    Endian.little,
  );
  view.setUint32(
    RaceBoxDataOffsets.verticalAccuracy,
    verticalAccuracyMm,
    Endian.little,
  );
  view.setInt32(RaceBoxDataOffsets.speed, speedMmps, Endian.little);
  view.setInt32(RaceBoxDataOffsets.heading, headingE5, Endian.little);
  view.setUint32(
    RaceBoxDataOffsets.speedAccuracy,
    speedAccuracyMmps,
    Endian.little,
  );
  view.setInt16(RaceBoxDataOffsets.gForceX, gForceXMilli, Endian.little);
  view.setInt16(RaceBoxDataOffsets.gForceY, gForceYMilli, Endian.little);
  view.setInt16(RaceBoxDataOffsets.gForceZ, gForceZMilli, Endian.little);
  view.setInt16(
    RaceBoxDataOffsets.rotationRateX,
    rotationXCenti,
    Endian.little,
  );
  view.setInt16(
    RaceBoxDataOffsets.rotationRateY,
    rotationYCenti,
    Endian.little,
  );
  view.setInt16(
    RaceBoxDataOffsets.rotationRateZ,
    rotationZCenti,
    Endian.little,
  );
  view.setUint8(RaceBoxDataOffsets.batteryStatus, battery);

  return bytes;
}

void main() {
  group('RaceBoxData', () {
    test('scales position, altitude and accuracy out of wire units', () {
      final RaceBoxData data = RaceBoxData.decode(buildPayload())!;

      expect(data.latitude, closeTo(39.73556, 1e-7));
      expect(data.longitude, closeTo(-103.8917433, 1e-7));
      expect(data.wgsAltitudeM, closeTo(1530, 0.001));
      expect(data.mslAltitudeM, closeTo(1520, 0.001));
      expect(data.horizontalAccuracyM, closeTo(2.5, 0.001));
      expect(data.verticalAccuracyM, closeTo(3.0, 0.001));
    });

    test('converts speed from mm/s', () {
      final RaceBoxData data = RaceBoxData.decode(buildPayload())!;
      expect(data.speedMps, closeTo(25.0, 0.001));
      expect(data.speedKph, closeTo(90.0, 0.01));
      expect(data.speedMph, closeTo(55.92, 0.01));
    });

    test('keeps the sign on negative G and rotation', () {
      // Braking and left-hand cornering are negative; reading these as
      // unsigned would silently mirror the trace.
      final RaceBoxData data = RaceBoxData.decode(buildPayload())!;
      expect(data.gForceX, closeTo(0.125, 1e-6));
      expect(data.gForceY, closeTo(-0.25, 1e-6));
      expect(data.gForceZ, closeTo(1.0, 1e-6));
      expect(data.rotationRateX, closeTo(1.5, 1e-6));
      expect(data.rotationRateY, closeTo(-0.75, 1e-6));
    });

    test('handles a west/south position without wrapping', () {
      final RaceBoxData data = RaceBoxData.decode(
        buildPayload(latitudeE7: -337868000, longitudeE7: -1512090000),
      )!;
      expect(data.latitude, closeTo(-33.7868, 1e-6));
      expect(data.longitude, closeTo(-151.209, 1e-6));
    });

    test('splits the battery byte into level and charging flag', () {
      expect(
        RaceBoxData.decode(buildPayload(battery: 0x55))!.batteryPercent,
        85,
      );
      expect(
        RaceBoxData.decode(buildPayload(battery: 0x55))!.isCharging,
        isFalse,
      );
      // Top bit set: same level, charging.
      expect(
        RaceBoxData.decode(buildPayload(battery: 0xD5))!.batteryPercent,
        85,
      );
      expect(
        RaceBoxData.decode(buildPayload(battery: 0xD5))!.isCharging,
        isTrue,
      );
    });

    test('reads the fix status, and which ones carry a position', () {
      expect(
        RaceBoxData.decode(buildPayload(fixStatus: 0))!.fixStatus,
        RaceBoxFixStatus.none,
      );
      expect(
        RaceBoxData.decode(buildPayload(fixStatus: 3))!.fixStatus.hasPosition,
        isTrue,
      );
      // Time-only has no position at all, and dead reckoning drifts.
      expect(
        RaceBoxData.decode(buildPayload(fixStatus: 5))!.fixStatus.hasPosition,
        isFalse,
      );
      expect(
        RaceBoxData.decode(buildPayload(fixStatus: 1))!.fixStatus.hasPosition,
        isFalse,
      );
    });

    test('builds a UTC timestamp from the date fields', () {
      final RaceBoxData data = RaceBoxData.decode(buildPayload())!;
      expect(data.timestampUtc, DateTime.utc(2026, 7, 31, 14, 30, 15));
      expect(data.timestampUtc!.isUtc, isTrue);
    });

    test('reports no timestamp before the receiver has the date', () {
      // The fields read as zeroes until there is a fix, and a timestamp built
      // from those is worse than none.
      expect(RaceBoxData.decode(buildPayload(year: 0))!.timestampUtc, isNull);
    });

    test('returns null for a payload that is not this message', () {
      expect(RaceBoxData.decode(Uint8List(20)), isNull);
      expect(RaceBoxData.decode(Uint8List(0)), isNull);
    });
  });

  group('raceBoxProfile', () {
    test('uses the Nordic UART service and characteristics', () {
      expect(raceBoxProfile.serviceUuid, startsWith('6e400001'));
      expect(raceBoxProfile.writeCharacteristicUuid, startsWith('6e400002'));
      expect(raceBoxProfile.notifyCharacteristicUuid, startsWith('6e400003'));
    });

    test('matches the advertised names and pulls out the serial', () {
      expect(raceBoxSerialFrom('RaceBox Mini 3241059358'), '3241059358');
      expect(raceBoxSerialFrom('RaceBox Mini S 1234567890'), '1234567890');
      expect(raceBoxSerialFrom('RaceBox Micro 0001'), '0001');
    });

    test('rejects a device that merely shares the Nordic UART service', () {
      // Nordic UART is generic — without the name filter the picker would
      // fill with dev boards and unrelated peripherals.
      expect(raceBoxSerialFrom('Some Dev Board'), isNull);
      expect(raceBoxSerialFrom('RaceBox'), isNull);
      expect(
        raceBoxProfile.matches(
          const BleDevice(
            id: 'x',
            name: 'Nordic_UART',
            rssi: -50,
            serviceUuids: <String>['6e400001-b5a3-f393-e0a9-e50e24dcca9e'],
          ),
        ),
        isFalse,
      );
    });

    test('matches a real RaceBox advertisement', () {
      expect(
        raceBoxProfile.matches(
          const BleDevice(
            id: 'x',
            name: 'RaceBox Mini 3241059358',
            rssi: -50,
            serviceUuids: <String>['6e400001-b5a3-f393-e0a9-e50e24dcca9e'],
          ),
        ),
        isTrue,
      );
    });
  });
}
