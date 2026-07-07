import 'dart:async';

import 'at_commands.dart';
import 'custom_pid.dart';
import 'dtc.dart';
import 'errors.dart';
import 'pid.dart';
import 'response.dart';
import 'transport.dart';

/// Maps a CAN protocol number (as reported by `ATDPN`, with any leading
/// `A` for auto-search already stripped) to the standard OBD-II
/// functional header for that protocol, per the datasheet's "Setting
/// the Headers" section. Returns `null` for non-CAN protocols, which
/// manage their own headers automatically and are out of scope for the
/// header-restore behavior in [Elm327Client.queryCustomPid].
String? _defaultFunctionalHeaderFor(String? protocolNumber) {
  switch (protocolNumber) {
    case '6':
    case '8':
      return '7DF';
    case '7':
    case '9':
      return '18DB33F1';
    default:
      return null;
  }
}

/// Buffers bytes from an [Elm327Transport] and resolves one [Future]
/// per command with the raw text received before the next `>` prompt
/// byte (0x3E), stripping stray NULL bytes per the datasheet's note
/// that the ELM327 can occasionally emit them.
class _Elm327Connection {
  _Elm327Connection(this._transport) {
    _subscription = _transport.input.listen(_onData);
  }

  final Elm327Transport _transport;
  late final StreamSubscription<List<int>> _subscription;
  final List<int> _buffer = [];
  Completer<String>? _pending;

  Future<String> sendRaw(String command) async {
    if (_pending != null) {
      throw StateError('A command is already in progress');
    }
    final completer = Completer<String>();
    _pending = completer;
    await _transport.write([...command.codeUnits, 0x0D]);
    return completer.future;
  }

  void _onData(List<int> chunk) {
    for (final byte in chunk) {
      if (byte == 0x00) continue;
      if (byte == 0x3E) {
        final text = String.fromCharCodes(_buffer);
        _buffer.clear();
        final completer = _pending;
        _pending = null;
        completer?.complete(text);
        continue;
      }
      _buffer.add(byte);
    }
  }

  Future<void> dispose() => _subscription.cancel();
}

/// The main entry point for talking to an ELM327 adapter: builds and
/// sends AT/OBD commands over an [Elm327Transport], serializes them one
/// at a time (matching the ELM327's own prompt-driven, one-command
/// model), and decodes the responses.
class Elm327Client {
  Elm327Client(Elm327Transport transport)
    : _connection = _Elm327Connection(transport);

  final _Elm327Connection _connection;
  Future<void> _lastOperation = Future<void>.value();
  String? _protocolNumber;
  String? _protocolDescription;

  /// The human-readable protocol description last reported by `ATDP`
  /// (e.g. `'SAE J1850 VPW'`), or `null` if it has not been queried yet
  /// (no successful OBD request has completed since [connect] or the
  /// last [setProtocol] call).
  String? get currentProtocol => _protocolDescription;

  /// Resets the adapter and applies this library's default session
  /// settings: echo off, linefeeds off, headers off, automatic protocol
  /// search.
  Future<void> connect() async {
    await _sendCommand(AtCommands.reset);
    await _sendCommand(AtCommands.echo(false));
    await _sendCommand(AtCommands.linefeeds(false));
    await _sendCommand(AtCommands.headers(false));
    await _sendCommand(AtCommands.setProtocol(null));
  }

  /// Forces a specific protocol number (see the datasheet's "Selecting
  /// Protocols" section for the 0-C protocol table), or pass `null` to
  /// return to automatic search.
  Future<void> setProtocol(int? protocolNumber) async {
    await _sendCommand(AtCommands.setProtocol(protocolNumber));
    await _refreshProtocol();
  }

  Future<void> _refreshProtocol() async {
    final numberRaw = await _sendCommand(AtCommands.describeProtocolNumber);
    _protocolNumber = numberRaw.trim().replaceFirst('A', '');
    final description = await _sendCommand(AtCommands.describeProtocol);
    _protocolDescription = description.trim();
  }

  /// Sends any raw AT or OBD command string and returns the adapter's
  /// raw response text, throwing a typed [Elm327Exception] if the
  /// response is one of the documented error strings.
  Future<String> sendRawCommand(String command) => _sendCommand(command);

  Future<String> _sendCommand(String command) {
    final result = _lastOperation
        .then((_) => _connection.sendRaw(command))
        .then((raw) {
          if (isErrorResponse(raw)) {
            throw mapErrorResponse(raw);
          }
          return raw;
        });
    _lastOperation = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _sendObdCommand(String hex) async {
    final raw = await _sendCommand(hex);
    if (_protocolDescription == null) {
      await _refreshProtocol();
    }
    return raw;
  }

  /// Requests and decodes one standard Mode 01 PID.
  Future<num> queryPid(Pid pid) async {
    final raw = await _sendObdCommand(pid.requestHex);
    final frame = parseObdResponse(raw).firstFrame;
    final expectedResponseMode = pid.mode + 0x40;
    if (frame.length < 2 ||
        frame[0] != expectedResponseMode ||
        frame[1] != pid.pid) {
      throw Elm327ProtocolException(
        'Unexpected response for ${pid.name}: $frame',
      );
    }
    return pid.decode(frame.sublist(2));
  }

  /// Requests and decodes one manufacturer-specific PID, temporarily
  /// setting the CAN header if [CustomPid.targetHeader] is set, and
  /// restoring the current CAN protocol's default functional header
  /// afterward (see [_defaultFunctionalHeaderFor]).
  Future<num> queryCustomPid(CustomPid pid) async {
    final needsHeaderChange = pid.targetHeader != null;
    if (needsHeaderChange) {
      await _sendCommand(AtCommands.setHeader(pid.targetHeader!));
    }
    try {
      final raw = await _sendObdCommand(pid.requestHex);
      final frame = parseObdResponse(raw).firstFrame;
      final expectedResponseMode = pid.mode + 0x40;
      final skip = 1 + pid.pidBytes.length;
      if (frame.isEmpty ||
          frame[0] != expectedResponseMode ||
          frame.length < skip) {
        throw Elm327ProtocolException(
          'Unexpected response for ${pid.name}: $frame',
        );
      }
      return pid.decode(frame.sublist(skip));
    } finally {
      if (needsHeaderChange) {
        final restoreHeader = _defaultFunctionalHeaderFor(_protocolNumber);
        if (restoreHeader != null) {
          await _sendCommand(AtCommands.setHeader(restoreHeader));
        }
      }
    }
  }

  /// Reads diagnostic trouble codes. Defaults to Mode 03 (current
  /// codes); pass `pending: true` for Mode 07, or `permanent: true` for
  /// Mode 0A.
  Future<List<String>> readDtcs({
    bool pending = false,
    bool permanent = false,
  }) async {
    final mode = permanent ? 0x0A : (pending ? 0x07 : 0x03);
    final requestHex = mode.toRadixString(16).padLeft(2, '0').toUpperCase();
    final raw = await _sendObdCommand(requestHex);
    final response = parseObdResponse(raw);
    final codes = <String>[];
    for (final frame in response.frames) {
      if (frame.isEmpty) continue;
      codes.addAll(decodeDtcFrame(frame, startIndex: 1));
    }
    return codes;
  }

  /// Sends Mode 04, clearing trouble codes, freeze frame data, and
  /// Mode 06/07 test results — per the datasheet's "Resetting Trouble
  /// Codes" warning, this is more than just the check-engine light.
  Future<void> clearDtcs() async {
    await _sendObdCommand('04');
  }

  /// Reads the 17-character vehicle identification number (Mode 09,
  /// PID 02).
  Future<String> readVin() async {
    final raw = await _sendObdCommand('0902');
    final frame = parseObdResponse(raw).firstFrame;
    final dataStart = (frame.length >= 3 && frame[0] == 0x49 && frame[1] == 0x02)
        ? 3
        : 0;
    return frame
        .sublist(dataStart)
        .where((byte) => byte != 0)
        .map((byte) => String.fromCharCode(byte))
        .join()
        .trim();
  }

  /// Releases the underlying transport subscription.
  Future<void> dispose() => _connection.dispose();
}
