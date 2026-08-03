import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

const rpm = PidDefinition(
  name: 'Engine RPM',
  unit: 'rpm',
  mode: 0x01,
  pidBytes: [0x0C],
  byteCount: 2,
  scale: 0.25,
);

const throttle = PidDefinition(
  name: 'Throttle (%)',
  unit: '%',
  mode: 0x01,
  pidBytes: [0x11],
  scale: 100 / 255,
);

const coolant = PidDefinition(
  name: 'Coolant Temp (C)',
  unit: 'C',
  mode: 0x01,
  pidBytes: [0x05],
  offset: -40,
  minInterval: Duration(seconds: 5),
);

const initSequence = {
  'ATZ': 'ELM327 v2.0',
  'ATE0': 'OK',
  'ATL0': 'OK',
  'ATH0': 'OK',
  'ATSP0': 'OK',
  'ATDPN': '6',
  'ATDP': 'ISO 15765-4 (CAN 11/500)',
};

/// A transport that can answer the same command differently each time.
///
/// The shared [FakeElm327Transport] maps a command to one fixed response,
/// which cannot express the two cases this file exists to pin down: a channel
/// that fails and then recovers, and a link that dies mid-poll.
class SequencedTransport implements Elm327Transport {
  SequencedTransport(Map<String, Object> responses)
    : _responses = {
        for (final entry in responses.entries)
          entry.key: entry.value is List<String>
              ? List<String>.of(entry.value as List<String>)
              : <String>[entry.value as String],
      };

  final Map<String, List<String>> _responses;
  final List<String> sentCommands = [];
  final _output = StreamController<List<int>>.broadcast();

  /// Makes every subsequent write throw, standing in for a dropped BLE link.
  bool failWrites = false;

  @override
  Stream<List<int>> get input => _output.stream;

  @override
  Future<void> write(List<int> bytes) async {
    if (failWrites) throw StateError('link is down');
    final command = String.fromCharCodes(bytes.where((b) => b != 0x0D));
    sentCommands.add(command);
    final queued = _responses[command] ?? const <String>[''];
    // The last entry repeats, so a fixed answer is a one-element list.
    final response = queued.length > 1 ? queued.removeAt(0) : queued.first;
    _output.add(<int>[...response.codeUnits, 0x0D, 0x3E]);
  }

  void dispose() => _output.close();
}

/// A clock a test advances by hand, so a five-second minimum period does not
/// need a five-second test.
class TestClock {
  DateTime value = DateTime.utc(2026, 8, 1, 12);

  DateTime now() => value;

  void advance(Duration by) => value = value.add(by);
}

void main() {
  late SequencedTransport transport;

  Future<Elm327Client> connected(Map<String, Object> responses) async {
    transport = SequencedTransport({...initSequence, ...responses});
    final client = Elm327Client(transport);
    await client.connect();
    return client;
  }

  tearDown(() => transport.dispose());

  test('cycles through the channels and decodes each one', () async {
    final client = await connected({'010C': '41 0C 1A F8', '0111': '41 11 80'});
    final poller = PidPoller(
      client: client,
      definitions: [rpm, throttle],
      idleDelay: Duration.zero,
    );

    final readings = await poller.readings().take(4).toList();
    poller.stop();

    expect(readings.map((r) => r.name), [
      'Engine RPM',
      'Throttle (%)',
      'Engine RPM',
      'Throttle (%)',
    ]);
    expect(readings.first.value, 1726);
    expect(readings[1].value, closeTo(50.196, 0.001));
  });

  test('retires a channel the vehicle never answers', () async {
    final client = await connected({
      '010C': '41 0C 1A F8',
      // Not implemented on this car. A real ELM327 answers this way forever.
      '0111': 'NO DATA',
    });
    final poller = PidPoller(
      client: client,
      definitions: [rpm, throttle],
      maxConsecutiveFailures: 3,
      idleDelay: Duration.zero,
    );

    final readings = await poller.readings().take(6).toList();
    poller.stop();

    expect(poller.retired.map((d) => d.name), ['Throttle (%)']);
    expect(readings.every((r) => r.name == 'Engine RPM'), isTrue);

    // Three attempts, then never again — the whole point. A dead channel
    // retried once a cycle is a permanent tax on the ones that work.
    expect(transport.sentCommands.where((c) => c == '0111').length, 3);
  });

  test('a success resets the failure count', () async {
    // Fails, recovers, fails, recovers. With a threshold of two this must
    // never retire: an intermittent channel is not an absent one.
    final client = await connected({
      '010C': '41 0C 1A F8',
      '0111': <String>['NO DATA', '41 11 80', 'NO DATA', '41 11 80'],
    });
    final poller = PidPoller(
      client: client,
      definitions: [rpm, throttle],
      maxConsecutiveFailures: 2,
      idleDelay: Duration.zero,
    );

    final readings = await poller.readings().take(6).toList();
    poller.stop();

    expect(poller.retired, isEmpty);
    expect(readings.where((r) => r.name == 'Throttle (%)').length, 2);
  });

  test('the stream ends once every channel is retired', () async {
    final client = await connected({'010C': 'NO DATA'});
    final poller = PidPoller(
      client: client,
      definitions: [rpm],
      maxConsecutiveFailures: 2,
      idleDelay: Duration.zero,
    );

    // Not a hang and not an error: an adapter that answers nothing is a
    // finished stream, which is what the caller already handles for a dropped
    // link.
    expect(await poller.readings().toList(), isEmpty);
    expect(poller.isExhausted, isTrue);
  });

  test('a slow channel does not take a fast one\'s share', () async {
    final clock = TestClock();
    final client = await connected({'010C': '41 0C 1A F8', '0105': '41 05 5A'});
    final poller = PidPoller(
      client: client,
      definitions: [rpm, coolant],
      idleDelay: Duration.zero,
      now: clock.now,
    );

    final readings = <ObdReading>[];
    await for (final reading in poller.readings()) {
      readings.add(reading);
      // A tenth of a second per command, about what a cheap BLE adapter
      // manages.
      clock.advance(const Duration(milliseconds: 100));
      if (readings.length >= 20) break;
    }
    poller.stop();

    final slow = readings.where((r) => r.name == 'Coolant Temp (C)').length;
    // Two seconds of simulated time at ten commands a second. Coolant's
    // five-second floor lets it through once; RPM takes everything else.
    expect(slow, lessThanOrEqualTo(2));
    expect(readings.length - slow, greaterThan(15));
  });

  test('stop ends the loop', () async {
    final client = await connected({'010C': '41 0C 1A F8'});
    final poller = PidPoller(
      client: client,
      definitions: [rpm],
      idleDelay: Duration.zero,
    );

    final iterator = StreamIterator<ObdReading>(poller.readings());
    expect(await iterator.moveNext(), isTrue);
    poller.stop();
    expect(await iterator.moveNext(), isFalse);
  });

  test('a transport failure is not mistaken for an unsupported PID', () async {
    final client = await connected({'010C': '41 0C 1A F8'});
    final poller = PidPoller(
      client: client,
      definitions: [rpm],
      idleDelay: Duration.zero,
    );

    final iterator = StreamIterator<ObdReading>(poller.readings());
    expect(await iterator.moveNext(), isTrue);

    // The link dies mid-session. This must surface rather than quietly
    // retiring every channel and reporting a poller that ran out of work.
    transport.failWrites = true;
    await expectLater(iterator.moveNext(), throwsA(isA<StateError>()));
    expect(poller.retired, isEmpty);
  });
}
