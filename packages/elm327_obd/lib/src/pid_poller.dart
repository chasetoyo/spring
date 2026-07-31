import 'dart:async';

import 'client.dart';
import 'errors.dart';
import 'pid_definition.dart';

/// One decoded value from one channel.
class ObdReading {
  const ObdReading({required this.name, required this.value, required this.at});

  /// [PidDefinition.name], which is also the exported column header.
  final String name;
  final num value;
  final DateTime at;

  @override
  String toString() => 'ObdReading($name = $value @ $at)';
}

/// Polls a set of [PidDefinition]s over an [Elm327Client], forever.
///
/// An ELM327 is strictly request/response and answers one command at a time,
/// so there is no such thing as subscribing to engine data — something has to
/// ask, repeatedly, and every channel in the rotation costs every other
/// channel. This is that something.
///
/// Two behaviours matter more than the loop itself:
///
/// * **Channels have their own minimum period.** Coolant temperature at the
///   same rate as throttle position would spend a third of a slow link on a
///   number that moves over minutes.
/// * **A channel that keeps failing is retired.** A vehicle that does not
///   implement a PID answers `NO DATA` every single time, and retrying it once
///   a cycle forever is a permanent tax on the channels that do work. Retired
///   names stay readable through [retired] so a UI can say which, and why.
class PidPoller {
  PidPoller({
    required Elm327Client client,
    required List<PidDefinition> definitions,
    this.maxConsecutiveFailures = 3,
    this.idleDelay = const Duration(milliseconds: 50),
    DateTime Function()? now,
  }) : _client = client,
       _now = now ?? DateTime.now,
       _entries = definitions.map(_Entry.new).toList(growable: false);

  final Elm327Client _client;
  final DateTime Function() _now;
  final List<_Entry> _entries;

  /// How many consecutive failures retire a channel.
  final int maxConsecutiveFailures;

  /// How long to wait when every channel is inside its own minimum period.
  /// Without it the loop spins on a stopwatch.
  final Duration idleDelay;

  bool _stopped = false;

  /// Channels given up on, newest last. Never re-tried: the failure that
  /// causes retirement is a vehicle that does not have the PID at all.
  List<PidDefinition> get retired => <PidDefinition>[
    for (final entry in _entries)
      if (entry.retired) entry.definition,
  ];

  /// Whether anything is still being polled.
  bool get isExhausted => _entries.every((entry) => entry.retired);

  /// Readings as fast as the adapter will produce them.
  ///
  /// Ends when every channel has been retired, when [stop] is called, or when
  /// the link itself fails — an [Elm327Exception] is a vehicle-level answer
  /// and retires a channel, while anything else is the transport dying and is
  /// rethrown, because there is nothing left to poll over.
  Stream<ObdReading> readings() async* {
    while (!_stopped && !isExhausted) {
      var polled = false;

      for (final entry in _entries) {
        if (_stopped) return;
        if (entry.retired) continue;

        final at = _now();
        if (!entry.isDue(at)) continue;
        entry.lastAttempt = at;
        polled = true;

        final num value;
        try {
          value = await _query(entry.definition);
        } on Elm327Exception {
          entry.failures++;
          if (entry.failures >= maxConsecutiveFailures) entry.retired = true;
          continue;
        }

        entry.failures = 0;
        if (_stopped) return;
        yield ObdReading(name: entry.definition.name, value: value, at: at);
      }

      // A zero-duration delay is still a Timer, and that is the point: it
      // hands control back to the event loop once per cycle. Every `await` in
      // the body above can resolve on the microtask queue alone — a transport
      // that answers without a real async gap would otherwise let this loop
      // spin forever without a single timer ever firing, starving the rest of
      // the isolate. When nothing was due, wait properly instead.
      await Future<void>.delayed(polled ? Duration.zero : idleDelay);
    }
  }

  /// Ends [readings] after the command in flight resolves.
  void stop() => _stopped = true;

  Future<num> _query(PidDefinition definition) {
    return definition.needsCustomQuery
        ? _client.queryCustomPid(definition.toCustomPid())
        : _client.queryPid(definition.toPid());
  }
}

class _Entry {
  _Entry(this.definition);

  final PidDefinition definition;
  DateTime? lastAttempt;
  int failures = 0;
  bool retired = false;

  bool isDue(DateTime at) {
    final last = lastAttempt;
    if (last == null) return true;
    return at.difference(last) >= definition.minInterval;
  }
}
