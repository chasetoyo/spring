import 'package:ble_core/testing.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('elm327Profile', () {
    test('uses the common FFF0/FFF1/FFF2 pattern', () {
      expect(elm327Profile.serviceUuid, 'fff0');
      expect(elm327Profile.writeCharacteristicUuid, 'fff1');
      expect(elm327Profile.notifyCharacteristicUuid, 'fff2');
    });

    test('matches a device advertising the short-form service UUID', () {
      const device = BleDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'OBDII',
        rssi: -60,
        serviceUuids: <String>['fff0'],
      );
      expect(elm327Profile.matches(device), isTrue);
    });

    test('matches the 128-bit spelling of the same service', () {
      // BLE lets a 16-bit UUID stand in for its full form on the Bluetooth
      // base UUID. A profile declaring `fff0` that failed to match a device
      // advertising the long form would filter out every device it describes.
      const device = BleDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'OBDII',
        rssi: -60,
        serviceUuids: <String>['0000fff0-0000-1000-8000-00805f9b34fb'],
      );
      expect(elm327Profile.matches(device), isTrue);
    });

    test('rejects a device advertising only unrelated services', () {
      const device = BleDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'Some Fitness Band',
        rssi: -60,
        serviceUuids: <String>['180d'],
      );
      expect(elm327Profile.matches(device), isFalse);
    });

    test('accepts a device that advertises no services at all', () {
      // Some stacks omit service UUIDs until after a connect. Rejecting
      // those would hide real adapters; characteristic resolution at connect
      // time is the authoritative check.
      const device = BleDevice(id: 'AA:BB:CC:DD:EE:FF', name: '', rssi: -60);
      expect(elm327Profile.matches(device), isTrue);
    });
  });

  group('veepeakProfile', () {
    test('carries the same GATT shape as the generic profile', () {
      expect(veepeakProfile.serviceUuid, elm327Profile.serviceUuid);
      expect(
        veepeakProfile.writeCharacteristicUuid,
        elm327Profile.writeCharacteristicUuid,
      );
      expect(
        veepeakProfile.notifyCharacteristicUuid,
        elm327Profile.notifyCharacteristicUuid,
      );
    });

    test('matches the names Veepeak actually advertises under', () {
      for (final String name in <String>[
        'VEEPEAK',
        'Veepeak+',
        'VEEPEAK OBD',
        'veepeak mini',
      ]) {
        expect(
          veepeakProfile.matches(
            BleDevice(id: 'AA:BB:CC:DD:EE:FF', name: name, rssi: -60),
          ),
          isTrue,
          reason: '$name should be recognised',
        );
      }
    });

    test('rejects a device that does not name itself Veepeak', () {
      // The whole point of the filter: `fff0` is the stock HM-10 service and
      // `matches` accepts a device advertising none at all, so without a name
      // check the picker fills up with every module in range.
      const BleDevice band = BleDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'Some Fitness Band',
        rssi: -60,
      );
      expect(veepeakProfile.matches(band), isFalse);

      // Including one on the right service: `fff0` alone is not evidence.
      const BleDevice generic = BleDevice(
        id: '11:22:33:44:55:66',
        name: 'OBDII',
        rssi: -60,
        serviceUuids: <String>['fff0'],
      );
      expect(veepeakProfile.matches(generic), isFalse);
      expect(
        elm327Profile.matches(generic),
        isTrue,
        reason: 'the generic profile still takes anything on fff0',
      );
    });
  });

  group('Elm327BleClient', () {
    test('runs the AT init sequence over the link on connect', () async {
      final backend = FakeBleBackend();
      final connection = FakeBleConnection(deviceId: 'adapter-1');
      backend.connections['adapter-1'] = connection;

      final client = Elm327BleClient(backend: backend, deviceId: 'adapter-1');
      final Future<void> connecting = client.connect();

      // The adapter answers each command with a bare `>` prompt. The client
      // serialises commands, so each reply releases exactly the next one.
      for (int i = 0; i < 5; i++) {
        await _settle();
        connection.emit(<int>[0x3E]);
      }
      await connecting;

      expect(connection.written.map(_asCommand), <String>[
        'ATZ',
        'ATE0',
        'ATL0',
        'ATH0',
        'ATSP0',
      ]);
      expect(client.isConnected, isTrue);
      await client.dispose();
    });

    test('does not strip NUL bytes from the byte channel', () async {
      // The old transport filtered 0x00 here, which was redundant — the
      // ELM327 framer already skips them — and destroys any binary protocol
      // sharing this plumbing. UBX packets are full of legitimate NULs.
      final connection = FakeBleConnection();
      final transport = BleElm327Transport(connection);
      final List<List<int>> received = <List<int>>[];
      transport.input.listen(received.add);

      connection.emit(<int>[0xB5, 0x62, 0xFF, 0x01, 0x50, 0x00]);
      await _settle();

      expect(received.single, <int>[0xB5, 0x62, 0xFF, 0x01, 0x50, 0x00]);
    });

    test('surfaces a mid-session drop on connectionState', () async {
      final backend = FakeBleBackend();
      final connection = FakeBleConnection(deviceId: 'adapter-1');
      backend.connections['adapter-1'] = connection;

      final client = Elm327BleClient(backend: backend, deviceId: 'adapter-1');
      final List<BleConnectionState> states = <BleConnectionState>[];
      client.connectionState.listen(states.add);

      final Future<void> connecting = client.connect();
      for (int i = 0; i < 5; i++) {
        await _settle();
        connection.emit(<int>[0x3E]);
      }
      await connecting;

      connection.drop();
      await _settle();

      expect(states, contains(BleConnectionState.disconnected));
      expect(client.isConnected, isFalse);
      await client.dispose();
    });

    test('leaves no client behind when the link fails to open', () async {
      final backend = FakeBleBackend();
      backend.connectErrors['adapter-1'] = BleConnectionException('refused');

      final client = Elm327BleClient(backend: backend, deviceId: 'adapter-1');

      await expectLater(
        client.connect(),
        throwsA(isA<BleConnectionException>()),
      );
      expect(client.client, isNull);
      expect(client.isConnected, isFalse);
      await client.dispose();
    });
  });
}

/// Lets pending microtasks and stream events drain.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Renders a written command back to text, dropping the trailing carriage
/// return the client appends.
String _asCommand(List<int> bytes) =>
    String.fromCharCodes(bytes.where((int b) => b != 0x0D));
