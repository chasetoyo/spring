/// The decoded result of one OBD-II request: zero or more data-byte
/// "frames". With headers off (this library's default), a single-frame
/// reply is one frame; a multi-ECU reply is one frame per responding
/// ECU; a multiline CAN/ISO-TP reply (see the datasheet's "Multiline
/// Responses" section) is reassembled into a single merged frame.
class ObdResponse {
  const ObdResponse(this.frames);

  final List<List<int>> frames;

  /// The first frame, or an empty list if there were no data frames at
  /// all (e.g. the adapter reported `NO DATA`, which callers should have
  /// already turned into an [Elm327TimeoutException] before reaching
  /// here).
  List<int> get firstFrame => frames.isNotEmpty ? frames.first : const [];
}

final _segmentLine = RegExp(r'^([0-9A-Fa-f]):\s*(.*)$');

bool _isInformationalLine(String line) {
  if (line == 'OK') return true;
  return line.startsWith('SEARCHING') || line.startsWith('BUS INIT');
}

List<int> _hexBytes(String text) {
  final hex = text.replaceAll(' ', '');
  final bytes = <int>[];
  for (var i = 0; i + 2 <= hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

/// Parses the raw text of one ELM327 response (already stripped of the
/// trailing `>` prompt by the connection layer) into an [ObdResponse].
ObdResponse parseObdResponse(String raw) {
  final lines = raw
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !_isInformationalLine(line))
      .toList();

  if (lines.isEmpty) return const ObdResponse([]);

  final isMultiline = lines.any((line) => _segmentLine.hasMatch(line));

  if (isMultiline) {
    final segments = <int, List<int>>{};
    for (final line in lines) {
      final match = _segmentLine.firstMatch(line);
      if (match == null) continue; // the leading total-length line
      final sequence = int.parse(match.group(1)!, radix: 16);
      segments[sequence] = _hexBytes(match.group(2)!);
    }
    final orderedKeys = segments.keys.toList()..sort();
    final merged = <int>[for (final key in orderedKeys) ...segments[key]!];
    return ObdResponse([merged]);
  }

  return ObdResponse([for (final line in lines) _hexBytes(line)]);
}
