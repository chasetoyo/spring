import 'dart:typed_data';

import 'package:ble_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racebox_ble/racebox_ble.dart';

import 'racebox_data_test.dart' show buildPayload;

Uint8List _dataPacket({int speedMmps = 25000}) {
  return UbxFramer.encode(
    messageClass: UbxFramer.raceBoxDataClass,
    messageId: UbxFramer.raceBoxDataId,
    payload: buildPayload(speedMmps: speedMmps),
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('RaceBoxClient', () {
    test('emits a reading per packet, with no handshake', () async {
      // Live data is on by default — subscribing to notifications is the
      // whole setup, unlike the ELM327's AT sequence.
      final FakeBleBackend backend = FakeBleBackend();
      final FakeBleConnection connection = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = connection;

      final RaceBoxClient client = RaceBoxClient(
        backend: backend,
        deviceId: 'rb-1',
      );
      final List<RaceBoxData> readings = <RaceBoxData>[];
      client.data.listen(readings.add);

      await client.connect();
      expect(connection.written, isEmpty, reason: 'nothing is asked of it');

      connection.emit(_dataPacket(speedMmps: 10000));
      connection.emit(_dataPacket(speedMmps: 20000));
      await _settle();

      expect(readings, hasLength(2));
      expect(readings.first.speedMps, closeTo(10.0, 0.001));
      expect(readings.last.speedMps, closeTo(20.0, 0.001));
      await client.dispose();
    });

    test('reassembles a packet arriving as MTU-sized chunks', () async {
      final FakeBleBackend backend = FakeBleBackend();
      final FakeBleConnection connection = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = connection;

      final RaceBoxClient client = RaceBoxClient(
        backend: backend,
        deviceId: 'rb-1',
      );
      final List<RaceBoxData> readings = <RaceBoxData>[];
      client.data.listen(readings.add);
      await client.connect();

      final Uint8List packet = _dataPacket();
      for (int i = 0; i < packet.length; i += 20) {
        connection.emit(packet.sublist(i, (i + 20).clamp(0, packet.length)));
      }
      await _settle();

      expect(readings, hasLength(1));
      await client.dispose();
    });

    test('ignores a frame that is not the data message', () async {
      final FakeBleBackend backend = FakeBleBackend();
      final FakeBleConnection connection = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = connection;

      final RaceBoxClient client = RaceBoxClient(
        backend: backend,
        deviceId: 'rb-1',
      );
      final List<RaceBoxData> readings = <RaceBoxData>[];
      final List<UbxFrame> frames = <UbxFrame>[];
      client.data.listen(readings.add);
      client.frames.listen(frames.add);
      await client.connect();

      connection.emit(
        UbxFramer.encode(
          messageClass: 0x01,
          messageId: 0x07,
          payload: <int>[1, 2, 3],
        ),
      );
      await _settle();

      // Still surfaced for diagnostics, just not decoded as a reading.
      expect(frames, hasLength(1));
      expect(readings, isEmpty);
      await client.dispose();
    });

    test('surfaces a mid-session drop', () async {
      // A logger streaming at 25 Hz from a moving car will drop, and a stale
      // "connected" is worse than a visible disconnect.
      final FakeBleBackend backend = FakeBleBackend();
      final FakeBleConnection connection = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = connection;

      final RaceBoxClient client = RaceBoxClient(
        backend: backend,
        deviceId: 'rb-1',
      );
      final List<BleConnectionState> states = <BleConnectionState>[];
      client.connectionState.listen(states.add);
      await client.connect();

      connection.drop();
      await _settle();

      expect(states, contains(BleConnectionState.disconnected));
      expect(client.isConnected, isFalse);
      await client.dispose();
    });

    test('does not carry a half-packet across a reconnect', () async {
      // Whatever was mid-flight when the link died can only corrupt the first
      // packet of the next one.
      final FakeBleBackend backend = FakeBleBackend();
      final FakeBleConnection first = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = first;

      final RaceBoxClient client = RaceBoxClient(
        backend: backend,
        deviceId: 'rb-1',
      );
      final List<RaceBoxData> readings = <RaceBoxData>[];
      client.data.listen(readings.add);

      await client.connect();
      first.emit(_dataPacket().sublist(0, 40));
      await _settle();
      await client.disconnect();

      final FakeBleConnection second = FakeBleConnection(deviceId: 'rb-1');
      backend.connections['rb-1'] = second;
      await client.connect();
      second.emit(_dataPacket());
      await _settle();

      expect(readings, hasLength(1));
      await client.dispose();
    });
  });
}
