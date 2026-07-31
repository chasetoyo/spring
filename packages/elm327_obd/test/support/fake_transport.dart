import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';

/// An in-memory [Elm327Transport] for tests. Construct it with a map of
/// exact command strings (without the trailing carriage return) to the
/// raw response text an adapter should send back; every response is
/// automatically terminated the way a real ELM327 does, with a carriage
/// return followed by the `>` prompt byte.
///
/// A command with no scripted entry gets an empty response (just the
/// prompt), which [isErrorResponse]/[parseObdResponse] treat as "no
/// data".
class FakeElm327Transport implements Elm327Transport {
  FakeElm327Transport(this.scriptedResponses);

  final Map<String, String> scriptedResponses;
  final List<String> sentCommands = [];
  final _outputController = StreamController<List<int>>.broadcast();

  @override
  Stream<List<int>> get input => _outputController.stream;

  @override
  Future<void> write(List<int> bytes) async {
    final command = String.fromCharCodes(bytes.where((byte) => byte != 0x0D));
    sentCommands.add(command);
    final response = scriptedResponses[command] ?? '';
    final payload = <int>[...response.codeUnits, 0x0D, 0x3E];
    _outputController.add(payload);
  }

  void dispose() {
    _outputController.close();
  }
}
