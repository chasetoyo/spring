import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:racebox_ble/racebox_ble.dart';

/// A well-formed packet with a recognisable payload.
Uint8List _packet({int messageClass = 0xFF, int id = 0x01, int length = 80}) {
  return UbxFramer.encode(
    messageClass: messageClass,
    messageId: id,
    payload: List<int>.generate(length, (int i) => i & 0xFF),
  );
}

void main() {
  // These are the tests that mean something regardless of whether the payload
  // offsets are right: framing, checksums and reassembly are independent of
  // what the bytes inside a packet turn out to signify.
  group('UbxFramer', () {
    test('decodes a whole packet delivered in one chunk', () {
      final UbxFramer framer = UbxFramer();
      final List<UbxFrame> frames = framer.add(_packet());

      expect(frames, hasLength(1));
      expect(frames.single.messageClass, 0xFF);
      expect(frames.single.messageId, 0x01);
      expect(frames.single.payload, hasLength(80));
      expect(frames.single.isRaceBoxData, isTrue);
      expect(framer.bufferedBytes, isZero);
    });

    test('reassembles a packet split across notifications', () {
      // The whole reason this class exists: a RaceBox packet is 88 bytes and
      // the default ATT MTU carries 20.
      final Uint8List packet = _packet();
      final UbxFramer framer = UbxFramer();

      final List<UbxFrame> collected = <UbxFrame>[];
      for (int i = 0; i < packet.length; i += 20) {
        final int end = (i + 20).clamp(0, packet.length);
        collected.addAll(framer.add(packet.sublist(i, end)));
      }

      expect(collected, hasLength(1));
      expect(collected.single.payload, hasLength(80));
    });

    test('yields nothing until the last byte of a packet arrives', () {
      final Uint8List packet = _packet();
      final UbxFramer framer = UbxFramer();

      expect(framer.add(packet.sublist(0, packet.length - 1)), isEmpty);
      expect(framer.add(packet.sublist(packet.length - 1)), hasLength(1));
    });

    test('decodes several packets coalesced into one notification', () {
      final UbxFramer framer = UbxFramer();
      final List<UbxFrame> frames = framer.add(<int>[
        ..._packet(),
        ..._packet(),
        ..._packet(),
      ]);
      expect(frames, hasLength(3));
    });

    test('skips leading garbage and finds the packet after it', () {
      final UbxFramer framer = UbxFramer();
      final List<UbxFrame> frames = framer.add(<int>[
        0x01, 0x02, 0x03, 0xB5, 0x00, // noise, including a lone sync char
        ..._packet(),
      ]);
      expect(frames, hasLength(1));
    });

    test('rejects a packet whose checksum does not match', () {
      final Uint8List packet = _packet();
      packet[packet.length - 1] = packet[packet.length - 1] ^ 0xFF;

      final UbxFramer framer = UbxFramer();
      expect(framer.add(packet), isEmpty);
    });

    test('recovers the next good packet after a corrupt one', () {
      // A dropped notification leaves a partial packet behind, and everything
      // after it is garbage until the next sync pair — the framer has to find
      // its way back rather than stall forever.
      final Uint8List corrupt = _packet();
      corrupt[corrupt.length - 2] = corrupt[corrupt.length - 2] ^ 0xFF;

      final UbxFramer framer = UbxFramer();
      final List<UbxFrame> frames = framer.add(<int>[...corrupt, ..._packet()]);

      expect(frames, hasLength(1));
      expect(frames.single.payload, hasLength(80));
    });

    test('matches a sync pair split across two notifications', () {
      final Uint8List packet = _packet();
      final UbxFramer framer = UbxFramer();

      expect(framer.add(<int>[0x00, 0x00, packet[0]]), isEmpty);
      expect(framer.add(packet.sublist(1)), hasLength(1));
    });

    test('does not stall on an absurd length field', () {
      // A mis-sync can land on a byte pair that looks like a header. Without
      // the length guard the framer would wait forever for bytes that are
      // never coming.
      final UbxFramer framer = UbxFramer();
      final List<UbxFrame> frames = framer.add(<int>[
        0xB5, 0x62, 0xFF, 0x01, 0xFF, 0xFF, // claims a 65535-byte payload
        ..._packet(),
      ]);
      expect(frames, hasLength(1));
    });

    test('does not accumulate unbounded noise', () {
      final UbxFramer framer = UbxFramer();
      framer.add(List<int>.filled(10000, 0x00));
      expect(framer.bufferedBytes, lessThanOrEqualTo(1));
    });

    test('reset drops a half-received packet', () {
      final Uint8List packet = _packet();
      final UbxFramer framer = UbxFramer()..add(packet.sublist(0, 40));
      expect(framer.bufferedBytes, 40);

      framer.reset();

      expect(framer.bufferedBytes, isZero);
      // The tail of the abandoned packet must not be mistaken for a new one.
      expect(framer.add(packet.sublist(40)), isEmpty);
    });

    test('encode and decode round-trip', () {
      final Uint8List encoded = UbxFramer.encode(
        messageClass: 0xFF,
        messageId: 0x01,
        payload: <int>[1, 2, 3],
      );
      expect(encoded, hasLength(UbxFramer.overheadBytes + 3));
      expect(encoded[0], UbxFramer.syncChar1);
      expect(encoded[1], UbxFramer.syncChar2);

      final UbxFrame frame = UbxFramer().add(encoded).single;
      expect(frame.payload, <int>[1, 2, 3]);
    });

    test('passes through a message it does not recognise', () {
      // Diagnostics against firmware sending something this version has never
      // seen: the frame still surfaces, it just is not RaceBox data.
      final UbxFrame frame = UbxFramer()
          .add(_packet(messageClass: 0x01, id: 0x07, length: 4))
          .single;
      expect(frame.isRaceBoxData, isFalse);
    });
  });
}
