import 'dart:convert';

import 'package:ble_core/ble_core.dart';
import 'package:ble_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// A RaceBox Mini's own answers, as it publishes them.
void seedRaceBox(FakeBleConnection connection) {
  connection.characteristicValues.addAll(<String, List<int>>{
    DeviceInformationUuids.modelNumber: utf8.encode('RaceBox Mini'),
    DeviceInformationUuids.serialNumber: utf8.encode('3241059358'),
    DeviceInformationUuids.firmwareRevision: utf8.encode('2.3'),
    DeviceInformationUuids.hardwareRevision: utf8.encode('4.1'),
    DeviceInformationUuids.manufacturer: utf8.encode('RaceBox'),
  });
}

void main() {
  group('readDeviceInformation', () {
    test('reads all five characteristics off the service', () async {
      final FakeBleConnection connection = FakeBleConnection();
      seedRaceBox(connection);

      final DeviceInformation info = await readDeviceInformation(connection);

      expect(info.modelNumber, 'RaceBox Mini');
      expect(info.serialNumber, '3241059358');
      expect(info.firmwareRevision, '2.3');
      expect(info.hardwareRevision, '4.1');
      expect(info.manufacturer, 'RaceBox');
      expect(info.isNotEmpty, isTrue);
    });

    test('a characteristic the device does not carry is null, not a throw', () {
      // Every field in this service is optional, and a module that publishes
      // only its manufacturer is a device we still want to describe.
      final FakeBleConnection connection = FakeBleConnection();
      connection.characteristicValues[DeviceInformationUuids.manufacturer] =
          utf8.encode('Veepeak');

      expect(
        readDeviceInformation(connection),
        completion(
          isA<DeviceInformation>()
              .having(
                (DeviceInformation i) => i.manufacturer,
                'manufacturer',
                'Veepeak',
              )
              .having(
                (DeviceInformation i) => i.serialNumber,
                'serial',
                isNull,
              ),
        ),
      );
    });

    test('a device that publishes nothing reports empty', () async {
      final DeviceInformation info = await readDeviceInformation(
        FakeBleConnection(),
      );

      expect(info.isEmpty, isTrue);
    });

    test('matches a short-form UUID against the full 128-bit one', () async {
      // A stack is free to report either spelling, and treating them as
      // different attributes would hide the whole service.
      final FakeBleConnection connection = FakeBleConnection();
      connection.characteristicValues['2a26'] = utf8.encode('1.9');

      final DeviceInformation info = await readDeviceInformation(connection);

      expect(info.firmwareRevision, '1.9');
    });

    test('strips the NUL padding off a fixed-width field', () async {
      final FakeBleConnection connection = FakeBleConnection();
      connection.characteristicValues[DeviceInformationUuids.serialNumber] =
          <int>[...utf8.encode('3241059358'), 0, 0, 0];

      final DeviceInformation info = await readDeviceInformation(connection);

      expect(info.serialNumber, '3241059358');
    });

    test('an answer with no content reads as absent', () async {
      final FakeBleConnection connection = FakeBleConnection();
      connection.characteristicValues[DeviceInformationUuids.modelNumber] =
          <int>[0, 0];

      final DeviceInformation info = await readDeviceInformation(connection);

      expect(info.modelNumber, isNull);
    });

    test(
      'decodes a malformed byte rather than failing the whole read',
      () async {
        final FakeBleConnection connection = FakeBleConnection();
        connection.characteristicValues[DeviceInformationUuids.modelNumber] =
            <int>[...utf8.encode('Mini'), 0xff];

        final DeviceInformation info = await readDeviceInformation(connection);

        expect(info.modelNumber, startsWith('Mini'));
      },
    );

    test('reads one at a time rather than concurrently', () async {
      // Android's GATT client runs a single operation at a time; five reads in
      // flight at once is four errors.
      final FakeBleConnection connection = FakeBleConnection();
      seedRaceBox(connection);

      await readDeviceInformation(connection);

      expect(connection.reads, <String>[
        DeviceInformationUuids.modelNumber,
        DeviceInformationUuids.serialNumber,
        DeviceInformationUuids.firmwareRevision,
        DeviceInformationUuids.hardwareRevision,
        DeviceInformationUuids.manufacturer,
      ]);
    });

    test(
      'a link that drops mid-read throws rather than reporting absence',
      () async {
        // The distinction the whole contract rests on: "the device has no serial
        // number" is a fact worth caching, and "we could not ask" is not.
        final FakeBleConnection connection = FakeBleConnection();
        seedRaceBox(connection);
        connection.readError = BleConnectionException('link dropped');

        expect(
          readDeviceInformation(connection),
          throwsA(isA<BleConnectionException>()),
        );
      },
    );

    test('reading over a disconnected link throws', () async {
      final FakeBleConnection connection = FakeBleConnection();
      seedRaceBox(connection);
      connection.drop();

      expect(
        readDeviceInformation(connection),
        throwsA(isA<BleConnectionException>()),
      );
    });
  });

  group('bleUuidEquals', () {
    test('a 16-bit UUID equals its full form on the Bluetooth base', () {
      expect(bleUuidEquals('180a', DeviceInformationUuids.service), isTrue);
      expect(bleUuidEquals('0000180A', '180a'), isTrue);
    });

    test('a vendor UUID off the base is compared whole', () {
      expect(
        bleUuidEquals(
          '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
          '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
        ),
        isTrue,
      );
      expect(
        bleUuidEquals(
          '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
          '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        ),
        isFalse,
      );
    });

    test('different attributes on the base do not collide', () {
      expect(
        bleUuidEquals(
          DeviceInformationUuids.modelNumber,
          DeviceInformationUuids.serialNumber,
        ),
        isFalse,
      );
    });
  });
}
