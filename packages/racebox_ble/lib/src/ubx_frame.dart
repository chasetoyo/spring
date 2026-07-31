import 'dart:typed_data';

/// One decoded UBX packet: a class/id pair and its payload.
class UbxFrame {
  const UbxFrame({
    required this.messageClass,
    required this.messageId,
    required this.payload,
  });

  final int messageClass;
  final int messageId;
  final Uint8List payload;

  /// Whether this is the periodic RaceBox Data Message.
  bool get isRaceBoxData =>
      messageClass == UbxFramer.raceBoxDataClass &&
      messageId == UbxFramer.raceBoxDataId;

  @override
  String toString() =>
      'UbxFrame(0x${messageClass.toRadixString(16)} '
      '0x${messageId.toRadixString(16)}, ${payload.length} bytes)';
}

/// Reassembles UBX packets from a stream of BLE notification chunks.
///
/// Three things make this necessary rather than a matter of reading a packet
/// per notification:
///
/// * **Packets split across notifications.** A RaceBox data packet is 88
///   bytes; the default ATT MTU carries 20. Even with a negotiated MTU, a
///   packet can straddle a boundary.
/// * **Several packets per notification.** At 25 Hz with a large MTU the
///   device coalesces.
/// * **Resynchronisation.** A dropped notification leaves a partial packet in
///   the buffer, and everything after it is garbage until the next sync pair
///   is found.
///
/// This is also the reason `ble_core`'s connection deliberately does not
/// filter its byte stream: the old ELM327 transport stripped `0x00`, which
/// would corrupt roughly every UBX packet, since lengths, class bytes and
/// payload fields are all full of legitimate NULs.
class UbxFramer {
  /// UBX sync characters, always the first two bytes of a packet.
  static const int syncChar1 = 0xB5;
  static const int syncChar2 = 0x62;

  /// The RaceBox Data Message: a vendor class, outside u-blox's own range.
  static const int raceBoxDataClass = 0xFF;
  static const int raceBoxDataId = 0x01;

  /// Sync (2) + class (1) + id (1) + length (2) + checksum (2).
  static const int overheadBytes = 8;

  /// Guard against a corrupt length field claiming an absurd payload and
  /// pinning the buffer open until it is satisfied.
  static const int maxPayloadBytes = 4096;

  final List<int> _buffer = <int>[];

  /// Packets recovered from [chunk], in order.
  ///
  /// Returns empty until enough bytes have arrived; a chunk completing two
  /// packets returns both.
  List<UbxFrame> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final List<UbxFrame> frames = <UbxFrame>[];

    while (true) {
      final UbxFrame? frame = _takeOne();
      if (frame == null) break;
      frames.add(frame);
    }
    return frames;
  }

  /// Drops any partially-accumulated bytes.
  ///
  /// Called on reconnect: whatever was mid-packet when the link dropped can
  /// only corrupt the first packet of the new one.
  void reset() => _buffer.clear();

  /// Bytes held pending more input. Exposed for tests and diagnostics.
  int get bufferedBytes => _buffer.length;

  UbxFrame? _takeOne() {
    _discardUntilSync();
    // Not enough yet to read the header, let alone the length.
    if (_buffer.length < overheadBytes) return null;

    final int messageClass = _buffer[2];
    final int messageId = _buffer[3];
    final int length = _buffer[4] | (_buffer[5] << 8);

    if (length > maxPayloadBytes) {
      // A length this large is a mis-sync that happened to land on a sync
      // pair, not a real packet. Skip the pair and hunt for the next one.
      _buffer.removeRange(0, 2);
      return _takeOne();
    }

    final int total = overheadBytes + length;
    if (_buffer.length < total) return null;

    final int checksumStart = 2;
    final int checksumEnd = 6 + length;
    final (int ckA, int ckB) = _checksum(_buffer, checksumStart, checksumEnd);

    if (ckA != _buffer[checksumEnd] || ckB != _buffer[checksumEnd + 1]) {
      // Corrupt, or a false sync inside a payload. Either way the safe move
      // is to skip only the sync pair — skipping the whole claimed length
      // would swallow a real packet that started inside it.
      _buffer.removeRange(0, 2);
      return _takeOne();
    }

    final Uint8List payload = Uint8List.fromList(
      _buffer.sublist(6, 6 + length),
    );
    _buffer.removeRange(0, total);

    return UbxFrame(
      messageClass: messageClass,
      messageId: messageId,
      payload: payload,
    );
  }

  /// Aligns the buffer so it starts at a sync pair, discarding whatever
  /// preceded it.
  void _discardUntilSync() {
    for (int i = 0; i + 1 < _buffer.length; i++) {
      if (_buffer[i] == syncChar1 && _buffer[i + 1] == syncChar2) {
        if (i > 0) _buffer.removeRange(0, i);
        return;
      }
    }
    // No pair present. Keep at most one byte: a sync char split across two
    // notifications must still be matched when its partner arrives.
    if (_buffer.length > 1) {
      _buffer.removeRange(0, _buffer.length - 1);
    }
    if (_buffer.length == 1 && _buffer[0] != syncChar1) _buffer.clear();
  }

  /// The 8-bit Fletcher checksum UBX uses, over class, id, length and
  /// payload — the sync characters are excluded.
  static (int, int) _checksum(List<int> bytes, int start, int end) {
    int ckA = 0;
    int ckB = 0;
    for (int i = start; i < end; i++) {
      ckA = (ckA + bytes[i]) & 0xFF;
      ckB = (ckB + ckA) & 0xFF;
    }
    return (ckA, ckB);
  }

  /// Builds a complete UBX packet, for tests and for config writes.
  static Uint8List encode({
    required int messageClass,
    required int messageId,
    List<int> payload = const <int>[],
  }) {
    final Uint8List out = Uint8List(overheadBytes + payload.length);
    out[0] = syncChar1;
    out[1] = syncChar2;
    out[2] = messageClass;
    out[3] = messageId;
    out[4] = payload.length & 0xFF;
    out[5] = (payload.length >> 8) & 0xFF;
    out.setRange(6, 6 + payload.length, payload);

    final (int ckA, int ckB) = _checksum(out, 2, 6 + payload.length);
    out[6 + payload.length] = ckA;
    out[7 + payload.length] = ckB;
    return out;
  }
}
