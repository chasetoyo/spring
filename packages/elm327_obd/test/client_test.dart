import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

import 'support/fake_transport.dart';

void main() {
  late FakeElm327Transport transport;
  late Elm327Client client;

  Future<Elm327Client> connectedClient(Map<String, String> responses) async {
    transport = FakeElm327Transport({
      'ATZ': 'ELM327 v2.0',
      'ATE0': 'OK',
      'ATL0': 'OK',
      'ATH0': 'OK',
      'ATSP0': 'OK',
      ...responses,
    });
    client = Elm327Client(transport);
    await client.connect();
    return client;
  }

  tearDown(() => transport.dispose());

  test('connect runs the default init sequence in order', () async {
    await connectedClient({});
    expect(transport.sentCommands, ['ATZ', 'ATE0', 'ATL0', 'ATH0', 'ATSP0']);
  });

  test('queryPid sends the request and decodes the response', () async {
    final client = await connectedClient({'010C': '41 0C 1A F8'});
    expect(await client.queryPid(StandardPids.engineRpm), 1726);
  });

  test('queryPid throws a typed exception on NO DATA', () async {
    final client = await connectedClient({'010C': 'NO DATA'});
    await expectLater(
      client.queryPid(StandardPids.engineRpm),
      throwsA(isA<Elm327TimeoutException>()),
    );
  });

  test('readDtcs decodes the mode 03 datasheet example', () async {
    final client = await connectedClient({'03': '43 01 33 00 00 00 00'});
    expect(await client.readDtcs(), ['P0133']);
  });

  test(
    'clearDtcs sends mode 04 and does not throw on a plain OK/44 reply',
    () async {
      final client = await connectedClient({
        '04': '44',
        'ATDPN': '0',
        'ATDP': 'AUTO',
      });
      await client.clearDtcs();
      expect(transport.sentCommands, contains('04'));
    },
  );

  test('readVin reassembles the multiline datasheet example', () async {
    final client = await connectedClient({
      '0902':
          '014\r0: 49 02 01 31 44 34\r1: 47 50 30 30 52 35 35\r'
          '2: 42 31 32 33 34 35 36',
    });
    expect(await client.readVin(), '1D4GP00R55B123456');
  });

  test('setProtocol updates currentProtocol from ATDP', () async {
    final client = await connectedClient({
      'ATSP2': 'OK',
      'ATDPN': '2',
      'ATDP': 'SAE J1850 VPW',
    });
    await client.setProtocol(2);
    expect(client.currentProtocol, 'SAE J1850 VPW');
  });

  test('queryCustomPid sets and restores the CAN header', () async {
    final client = await connectedClient({
      'ATSH7E0': 'OK',
      '221101': '62 11 01 19',
      'ATDPN': '6',
      'ATDP': 'ISO 15765-4 CAN (11 bit ID, 500 kbaud)',
      'ATSH7DF': 'OK',
    });
    final pid = CustomPid(
      name: 'Manifold Relative Pressure',
      mode: 0x22,
      pidBytes: [0x11, 0x01],
      unit: 'psi',
      decode: (bytes) => bytes[0] / 10,
      targetHeader: '7E0',
    );
    expect(await client.queryCustomPid(pid), closeTo(2.5, 0.001));
    expect(transport.sentCommands, containsAllInOrder(['ATSH7E0', '221101']));
    expect(transport.sentCommands.last, 'ATSH7DF');
  });
}
