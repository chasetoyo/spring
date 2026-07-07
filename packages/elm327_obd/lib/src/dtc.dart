/// Maps the first nibble of a DTC's high byte to its letter+digit
/// prefix, per the ELM327 datasheet's "Interpreting Trouble Codes"
/// table.
const _dtcPrefixes = {
  0x0: 'P0',
  0x1: 'P1',
  0x2: 'P2',
  0x3: 'P3',
  0x4: 'C0',
  0x5: 'C1',
  0x6: 'C2',
  0x7: 'C3',
  0x8: 'B0',
  0x9: 'B1',
  0xA: 'B2',
  0xB: 'B3',
  0xC: 'U0',
  0xD: 'U1',
  0xE: 'U2',
  0xF: 'U3',
};

/// Decodes one two-byte DTC pair into its human-readable code (e.g.
/// `P0133`), or `null` if the pair is `00 00` padding (used by the
/// vehicle to fill unused trouble-code slots in a response).
String? decodeDtc(int highByte, int lowByte) {
  if (highByte == 0 && lowByte == 0) return null;
  final firstNibble = (highByte >> 4) & 0xF;
  final secondDigit = (highByte & 0xF).toRadixString(16).toUpperCase();
  final lastTwoDigits = lowByte.toRadixString(16).toUpperCase().padLeft(
    2,
    '0',
  );
  return '${_dtcPrefixes[firstNibble]}$secondDigit$lastTwoDigits';
}

/// Decodes every two-byte DTC pair in [bytes], starting at [startIndex]
/// (use `startIndex: 1` to skip a mode-echo byte like `0x43`), skipping
/// `00 00` padding pairs.
List<String> decodeDtcFrame(List<int> bytes, {int startIndex = 0}) {
  final codes = <String>[];
  for (var i = startIndex; i + 1 < bytes.length; i += 2) {
    final code = decodeDtc(bytes[i], bytes[i + 1]);
    if (code != null) codes.add(code);
  }
  return codes;
}
