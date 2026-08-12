import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/honda.dart';
import 'package:flutter/material.dart';

/// Per-cylinder misfire counters for a 2013 Acura TSX.
///
/// A counter that climbs on one cylinder and nowhere else is the answer to
/// "which plug/coil/injector", which a P0300 on its own never gives you. So
/// the screen is built to be watched while the engine runs rather than read
/// once: it shows the live count, and — more usefully — how much each counter
/// has moved since the screen was opened.
///
/// The PID map is partly extrapolated. See `honda.dart`; a cylinder whose PID
/// is wrong shows as retired rather than as zero, so a bad guess never reads
/// as a healthy cylinder.
class MisfireScreen extends StatefulWidget {
  const MisfireScreen({required this.client, super.key});

  final Elm327Client client;

  @override
  State<MisfireScreen> createState() => _MisfireScreenState();
}

class _MisfireScreenState extends State<MisfireScreen> {
  PidPoller? _poller;
  StreamSubscription<ObdReading>? _subscription;

  /// Latest count per channel, and what it read when polling started. The
  /// delta between them is the number that matters — a counter is cumulative
  /// since the last monitor reset, so a large absolute value may be weeks old
  /// while a small one that is still climbing is happening now.
  final Map<String, int> _current = <String, int>{};
  final Map<String, int> _baseline = <String, int>{};

  /// The engine choice is the driver's, not something the ECM will tell us:
  /// both were sold in 2013 and a V6 map polled on a four just retires two
  /// channels.
  bool _isV6 = false;
  bool _running = false;
  String? _error;

  List<PidDefinition> get _definitions =>
      _isV6 ? acuraTsx2013MisfireV6 : acuraTsx2013MisfireI4;

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _stop() async {
    _poller?.stop();
    await _subscription?.cancel();
    _subscription = null;
    _poller = null;
  }

  Future<void> _start() async {
    await _stop();
    setState(() {
      _running = true;
      _error = null;
      _current.clear();
      _baseline.clear();
    });

    final PidPoller poller = PidPoller(
      client: widget.client,
      definitions: _definitions,
    );
    _poller = poller;
    _subscription = poller.readings().listen(
      (ObdReading reading) {
        if (!mounted) return;
        setState(() {
          final int value = reading.value.toInt();
          // First reading for this cylinder is the zero point.
          _baseline.putIfAbsent(reading.name, () => value);
          _current[reading.name] = value;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        // The stream only surfaces transport failures — a vehicle saying "no
        // such PID" retires that one channel and the rest keep going.
        setState(() {
          _error = '$error';
          _running = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _running = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PidDefinition> retired =
        _poller?.retired ?? const <PidDefinition>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SwitchListTile(
          title: const Text('3.5 V6'),
          subtitle: const Text('Off for the 2.4 four'),
          value: _isV6,
          // Changing the engine changes which PIDs are polled, so a run in
          // progress is no longer measuring what the switch now says.
          onChanged: _running
              ? null
              : (bool value) => setState(() => _isV6 = value),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _running ? () => _stop().then((_) => _refresh()) : _start,
          child: Text(_running ? 'Stop' : 'Start watching'),
        ),
        const SizedBox(height: 16),

        if (_error != null) ...<Widget>[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],

        for (final PidDefinition definition in _definitions)
          _CylinderRow(
            label: definition.name,
            count: _current[definition.name],
            since: _sinceStart(definition.name),
            isRetired: retired.any(
              (PidDefinition entry) => entry.name == definition.name,
            ),
          ),

        if (retired.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'A retired cylinder means the ECM refused that PID — the map in '
            'honda.dart is partly extrapolated. Check it in the Terminal tab '
            'with ATSH7E0 then 221600.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  int? _sinceStart(String name) {
    final int? now = _current[name];
    final int? start = _baseline[name];
    if (now == null || start == null) return null;
    return now - start;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}

class _CylinderRow extends StatelessWidget {
  const _CylinderRow({
    required this.label,
    required this.count,
    required this.since,
    required this.isRetired,
  });

  final String label;
  final int? count;
  final int? since;
  final bool isRetired;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Anything moving during this run is the finding, so it is the thing that
    // gets colour. A high absolute count with no movement is history.
    final bool climbing = (since ?? 0) > 0;

    return ListTile(
      title: Text(label),
      subtitle: Text(
        isRetired
            ? 'Not supported at this PID'
            : since == null
            ? 'Waiting…'
            : '+$since since start',
      ),
      trailing: Text(
        isRetired ? '—' : (count?.toString() ?? '—'),
        style: theme.textTheme.headlineSmall?.copyWith(
          color: climbing ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}
