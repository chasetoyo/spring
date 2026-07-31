/// Base type for every error this library raises in response to an
/// ELM327/OBD-II condition, as opposed to a Dart-level programming error.
class Elm327Exception implements Exception {
  Elm327Exception(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The adapter or vehicle did not respond in time (`NO DATA`).
class Elm327TimeoutException extends Elm327Exception {
  Elm327TimeoutException(super.message);
}

/// A protocol-level failure: bad bus state, failed initialization, a CAN
/// error, or a malformed/corrupted response.
class Elm327ProtocolException extends Elm327Exception {
  Elm327ProtocolException(super.message);
}

/// The ELM327 rejected a command outright (`?`) or a command in progress
/// was interrupted (`STOPPED`).
class Elm327CommandException extends Elm327Exception {
  Elm327CommandException(super.message);
}

/// A failure in the byte channel itself, as opposed to the vehicle/OBD
/// conversation (e.g. the adapter's receive buffer overflowed, or the
/// underlying transport dropped the connection).
class Elm327TransportException extends Elm327Exception {
  Elm327TransportException(super.message);
}

const _errorMarkers = [
  '?',
  'NO DATA',
  'UNABLE TO CONNECT',
  'BUS BUSY',
  'BUS ERROR',
  'CAN ERROR',
  'DATA ERROR',
  'RX ERROR',
  'STOPPED',
  'BUFFER FULL',
  'FB ERROR',
];

final _errCodePattern = RegExp(r'^ERR\d\d');

bool _isErrorLine(String line) {
  if (_errorMarkers.any(line.contains)) return true;
  return _errCodePattern.hasMatch(line);
}

Iterable<String> _nonEmptyLines(String raw) => raw
    .split(RegExp(r'[\r\n]+'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty);

/// Whether any line of a raw ELM327 response text represents one of the
/// datasheet's documented error/alert strings.
bool isErrorResponse(String raw) => _nonEmptyLines(raw).any(_isErrorLine);

/// Converts a raw ELM327 response containing an error line into the
/// matching typed [Elm327Exception].
///
/// Callers should check [isErrorResponse] first; this always returns
/// some exception, falling back to the generic [Elm327Exception] if no
/// specific error line is recognized.
Elm327Exception mapErrorResponse(String raw) {
  final errorLine = _nonEmptyLines(
    raw,
  ).firstWhere(_isErrorLine, orElse: () => raw.trim());

  if (errorLine == '?') {
    return Elm327CommandException('Unrecognized command: $raw');
  }
  if (errorLine.contains('NO DATA')) {
    return Elm327TimeoutException('No response from vehicle (NO DATA)');
  }
  if (errorLine.contains('UNABLE TO CONNECT')) {
    return Elm327ProtocolException('Unable to connect to vehicle protocol');
  }
  if (errorLine.contains('BUS BUSY')) {
    return Elm327ProtocolException('OBD bus busy');
  }
  if (errorLine.contains('BUS ERROR')) {
    return Elm327ProtocolException('OBD bus error');
  }
  if (errorLine.contains('CAN ERROR')) {
    return Elm327ProtocolException('CAN bus error');
  }
  if (errorLine.contains('DATA ERROR') || errorLine.contains('RX ERROR')) {
    return Elm327ProtocolException('Data error in response: $errorLine');
  }
  if (errorLine.contains('STOPPED')) {
    return Elm327CommandException('Command was interrupted');
  }
  if (errorLine.contains('BUFFER FULL')) {
    return Elm327TransportException('RS232 receive buffer overflowed');
  }
  if (errorLine.contains('FB ERROR')) {
    return Elm327ProtocolException('OBD output feedback error');
  }
  if (_errCodePattern.hasMatch(errorLine)) {
    return Elm327ProtocolException('Internal ELM327 error: $errorLine');
  }
  return Elm327Exception('Unrecognized ELM327 response: $errorLine');
}
